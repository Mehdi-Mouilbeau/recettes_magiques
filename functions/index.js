/* eslint-disable */

const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const admin = require("firebase-admin");
const crypto = require("crypto");
const sharp = require("sharp");

admin.initializeApp();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

/* ----------------------------- Utils (core) ----------------------------- */

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

/**
 * Retry helper with exponential backoff for transient errors (429/503/timeouts/network).
 */
async function withRetry(fn, { retries = 3, baseMs = 500 } = {}) {
  let lastErr;
  for (let i = 0; i <= retries; i++) {
    try {
      return await fn(i);
    } catch (e) {
      lastErr = e;
      const msg = String(e?.message || e);
      const retryable =
        /429|quota|rate|503|timeout|ETIMEDOUT|ECONNRESET|ENOTFOUND|fetch failed|EAI_AGAIN|aborted|AbortError/i.test(
          msg
        );
      if (!retryable || i === retries) break;
      await sleep(baseMs * Math.pow(2, i));
    }
  }
  throw lastErr;
}

/**
 * fetch with timeout via AbortController.
 */
async function fetchWithTimeout(url, options = {}, timeoutMs = 25000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const resp = await fetch(url, { ...options, signal: controller.signal });
    return resp;
  } finally {
    clearTimeout(id);
  }
}

/**
 * @google/genai responses can differ by version/shape.
 * This makes text extraction robust.
 */
function getModelText(result) {
  if (!result) return "";

  // Most common in some SDK shapes
  if (typeof result.text === "function") return result.text();
  if (typeof result.text === "string") return result.text;

  // Alternate shapes
  if (result.response?.text && typeof result.response.text === "function") return result.response.text();
  if (typeof result.response?.text === "string") return result.response.text;

  // Candidates fallback
  const cand = result.candidates?.[0];
  const parts = cand?.content?.parts;
  if (Array.isArray(parts)) {
    return parts
      .map((p) => (typeof p?.text === "string" ? p.text : ""))
      .filter(Boolean)
      .join("\n");
  }
  return "";
}

/**
 * Extract JSON from a string (strict parse, then brace-match fallback).
 */
function safeJsonParse(s) {
  const raw = String(s || "").trim();
  if (!raw) throw new Error("Empty model output");

  try {
    return JSON.parse(raw);
  } catch {
    // Try to extract the first JSON object/array substring
    const objMatch = raw.match(/\{[\s\S]*\}/);
    if (objMatch) return JSON.parse(objMatch[0]);

    const arrMatch = raw.match(/\[[\s\S]*\]/);
    if (arrMatch) return JSON.parse(arrMatch[0]);

    throw new Error("Model did not return valid JSON");
  }
}

/**
 * Auth helper for callable HTTP endpoints (regenerate).
 */
async function verifyFirebaseIdToken(req) {
  const authHeader = req.headers.authorization || "";
  const m = authHeader.match(/^Bearer (.+)$/);
  if (!m) throw new Error("Missing Authorization Bearer token");
  const decoded = await admin.auth().verifyIdToken(m[1]);
  return decoded; // { uid, ... }
}

/* ----------------------------- OCR hardening ---------------------------- */

function normalizeOcrText(raw) {
  let t = String(raw || "");

  // normalize newlines + remove soft hyphen
  t = t.replace(/\r\n/g, "\n").replace(/\u00AD/g, "");
  // trim weird spaces
  t = t.replace(/[ \t]+/g, " ");
  t = t.replace(/\n{3,}/g, "\n\n");

  // join hyphenated words across line breaks: "choco-\nlat" -> "chocolat"
  t = t.replace(/(\p{L}+)-\n(\p{L}+)/gu, "$1$2");

  // normalize bullets
  t = t.replace(/[•●▪◆◦]/g, "-");

  // remove lines that are almost empty
  const lines = t.split("\n").map((l) => l.trimEnd());
  const kept = lines.filter((l) => l.trim().length > 0);
  t = kept.join("\n");

  return t.trim();
}

function sanitizeRecipeJson(obj) {
  const out = {
    title: String(obj?.title || "").trim().slice(0, 120),
    category: String(obj?.category || "").trim().toLowerCase(),
    ingredients: Array.isArray(obj?.ingredients)
      ? obj.ingredients.map((x) => String(x).trim()).filter(Boolean)
      : [],
    steps: Array.isArray(obj?.steps) ? obj.steps.map((x) => String(x).trim()).filter(Boolean) : [],
    tags: Array.isArray(obj?.tags) ? obj.tags.map((x) => String(x).trim()).filter(Boolean) : [],
    source: String(obj?.source || "").trim().slice(0, 160),
    estimatedTime: String(obj?.estimatedTime || "").trim().slice(0, 60),
  };

  const allowed = new Set(["entrée", "plat", "dessert", "boisson"]);
  if (!allowed.has(out.category)) out.category = "plat";

  if (!out.title) out.title = "Recette";

  // Trim overly long lists
  if (out.ingredients.length > 40) out.ingredients = out.ingredients.slice(0, 40);
  if (out.steps.length > 40) out.steps = out.steps.slice(0, 40);

  // Clean step numbering "1) ..." / "2. ..." / "3 - ..."
  out.steps = out.steps.map((s) => s.replace(/^\s*\d+\s*[\).\-\:]\s*/g, ""));

  // Remove clearly non-food noise in ingredients
  out.ingredients = out.ingredients.filter((x) => !/https?:\/\/|www\.|@|€|\bqr\b|\bcode\b/i.test(x));

  return out;
}

/* ---------------------------- Prompt (image) ---------------------------- */

function buildPrompt({ title, category, ingredients, strict = false }) {
  const safeTitle = String(title || "").trim().replace(/\s+/g, " ").slice(0, 80);
  const cat = String(category || "").trim().toLowerCase();

  // If OCR title looks noisy, don't push it (prevents poster/cover generations)
  const titleLooksWeird =
    safeTitle.length < 4 ||
    /[^a-zA-ZÀ-ÿ0-9'’\-\s()]/.test(safeTitle) ||
    (safeTitle.match(/[A-Z]/g)?.length || 0) > safeTitle.length * 0.7;

  // If category is "boisson", avoid any ambiguity by forcing drink terms
  const drinkHint =
    cat === "boisson"
      ? 'This MUST be a beverage in a glass or cup (cocktail/smoothie/juice). Not a product photo.'
      : "";

  const dishName = titleLooksWeird ? "" : `Dish name: "${safeTitle}".`;

  // Normalize ambiguous ingredients
  const normalizeIngredient = (s) => {
    let t = String(s || "").trim().toLowerCase();
    t = t.replace(/\bpiment\s+oiseau\b/g, "small red chili pepper");
    t = t.replace(/\boiseau(x)?\b/g, "");
    t = t.replace(/[()]/g, " ");
    t = t.replace(/\s+/g, " ").trim();
    // Remove obvious OCR junk
    t = t.replace(/https?:\/\/\S+|www\.\S+|[@€]/g, "").trim();
    return t;
  };

  // Filter ingredients that don't help visual grounding
  const STOP = new Set([
    "sel",
    "poivre",
    "eau",
    "huile",
    "huile d'olive",
    "huile de pépins de raisin",
    "vinaigre",
    "sucre",
    "farine",
  ]);

  const ing = (Array.isArray(ingredients) ? ingredients : [])
    .map(normalizeIngredient)
    .filter(Boolean)
    .filter((x) => !STOP.has(x))
    .slice(0, 5);

  // Add dish-specific anchors for common cases to reduce “wrong dish”
  const lowerTitle = safeTitle.toLowerCase();
  const dishAnchor = (() => {
    if (/\bcr[eê]pe(s)?\b/.test(lowerTitle)) {
      return "The dish must look like French crepes: thin folded pancakes, lightly golden, on a plate, optionally with sugar or lemon.";
    }
    if (/\btzatziki\b/.test(lowerTitle)) {
      return "The dish must look like tzatziki: creamy white yogurt dip with grated cucumber and herbs in a bowl.";
    }
    if (/\bdaiquiri\b/.test(lowerTitle) || cat === "boisson") {
      return "The dish must look like a drink: a cold blended cocktail in a glass with ice, condensation, and a garnish (lime).";
    }
    return "";
  })();

  const base = [
    "Photorealistic food photography of a real cooked dish (edible meal).",
    dishName,
    cat ? `Dish type: ${cat}.` : "",
    drinkHint,
    dishAnchor,
    ing.length ? `Visible key ingredients in the dish: ${ing.join(", ")}.` : "",
    "Single plated dish as the main subject, centered in frame, on a ceramic plate or bowl, on a table.",
    "Three-quarter angle (about 45 degrees), shallow depth of field, DSLR look, 50mm lens, f/2.8, realistic lighting.",
    "Natural soft daylight, subtle shadows, true-to-life colors, high detail, appetizing texture, slight steam if hot.",
    "Simple neutral background (kitchen table), minimal props only (e.g., fork), no busy scenery.",
    "ABSOLUTELY NO text of any kind: no letters, no words, no subtitles, no captions, no labels, no menu, no typography.",
    "No logos, no watermarks, no branding, no packaging, no book pages, no screenshots, no UI elements.",
    "No people, no hands, no faces, no animals.",
    "Do not generate landscapes, buildings, islands, castles, posters, banners, fashion items, clothing, or product shots — only the plated food photo.",
  ].filter(Boolean);

  if (!strict) return base.join(" ");

  const strictAdd = [
    "Food-only packshot: image must contain ONLY the plated dish (or drink in a glass) and a neutral tabletop background.",
    "No decorative scenery, no nature, no architecture, no fashion, no portraits, no products.",
    "If uncertain, generate a simple realistic plated dish photo rather than anything else.",
  ];

  return base.concat(strictAdd).filter(Boolean).join(" ");
}

/* ---------------------- Imagen generation + validation ------------------- */

/**
 * Generates an image (base64) via Imagen predict endpoint.
 * Returns: { b64, mimeType }
 */
async function generateImageBase64({ title, category, ingredients, strict = false }) {
  const promptText = buildPrompt({ title, category, ingredients, strict });

  const model = "imagen-4.0-generate-001";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict`;

  // Some Imagen variants accept negativePrompt; if unsupported, API will error.
  // We'll try with it, and fallback without if needed.
  const payloadWithNeg = {
    instances: [{ prompt: promptText }],
    parameters: {
      sampleCount: 1,
      aspectRatio: "1:1",
      negativePrompt:
        "text, letters, typography, watermark, logo, poster, packaging, product, clothing, jacket, denim, jeans, people, hands, animals, landscape, building, ui, screenshot",
    },
  };

  const payloadNoNeg = {
    instances: [{ prompt: promptText }],
    parameters: { sampleCount: 1, aspectRatio: "1:1" },
  };

  const doCall = async (payload) => {
    const resp = await fetchWithTimeout(
      url,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": GEMINI_API_KEY.value(),
        },
        body: JSON.stringify(payload),
      },
      30000
    );

    const raw = await resp.text();
    if (!resp.ok) {
      throw new Error(`Imagen HTTP ${resp.status}: ${raw}`);
    }

    const data = raw ? JSON.parse(raw) : {};
    const pred = data?.predictions?.[0];
    const b64 = pred?.bytesBase64Encoded;

    if (!b64) {
      throw new Error("No image bytesBase64Encoded in Imagen response");
    }
    return { b64, mimeType: "image/png" };
  };

  // Retry network/quota issues. Also fallback if negativePrompt unsupported.
  return await withRetry(
    async () => {
      try {
        return await doCall(payloadWithNeg);
      } catch (e) {
        const msg = String(e?.message || e);
        // if negativePrompt unsupported, fallback without it
        if (/negativePrompt|unknown field|Invalid JSON payload|Unrecognized field/i.test(msg)) {
          return await doCall(payloadNoNeg);
        }
        throw e;
      }
    },
    { retries: 3, baseMs: 700 }
  );
}

/**
 * Validator: uses Gemini Vision as a strict judge.
 * Returns: { ok: boolean, reason: string }
 */
async function validateGeneratedImage({ b64, title, category, ingredients }) {
  const { GoogleGenAI } = require("@google/genai");
  const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

  const prompt = `
You are a strict image quality checker for a recipe app.
Return ONLY JSON: {"ok": boolean, "reason": string}

Requirements for ok=true:
- The image clearly shows a plated cooked food dish OR, if category is "boisson", a drink in a glass/cup.
- NO visible text/letters/typography anywhere.
- NO people, NO animals, NO landscapes, NO buildings, NO posters/covers/UI.
- NO fashion, NO clothing items (jackets, jeans), NO product photos, NO packshots.
- Should look like photorealistic food photography.

If the image shows clothing, fashion items, or any non-food product photo, ok MUST be false.

Recipe context:
title: ${String(title || "").slice(0, 120)}
category: ${String(category || "")}
ingredients: ${(Array.isArray(ingredients) ? ingredients : []).slice(0, 12).join(", ")}
`;

  const result = await withRetry(
    async () => {
      return await ai.models.generateContent({
        model: "gemini-2.0-flash",
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0,
        },
        contents: [
          {
            role: "user",
            parts: [
              { text: prompt },
              {
                inlineData: {
                  mimeType: "image/png",
                  data: b64,
                },
              },
            ],
          },
        ],
      });
    },
    { retries: 2, baseMs: 600 }
  );

  const out = getModelText(result);
  let json;
  try {
    json = safeJsonParse(out);
  } catch {
    return { ok: false, reason: "validator_non_json" };
  }

  return {
    ok: Boolean(json.ok),
    reason: String(json.reason || "").slice(0, 220),
  };
}

/* ----------------------------- 1) OCR -> JSON ---------------------------- */

exports.processRecipe = onRequest(
  {
    region: "europe-west1",
    secrets: [GEMINI_API_KEY],
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "Use POST" });
      }

      const { text } = req.body || {};
      if (!text || typeof text !== "string" || text.trim().length < 10) {
        return res.status(400).json({ error: "Missing or invalid 'text'." });
      }

      const normalizedText = normalizeOcrText(text);

      const { GoogleGenAI } = require("@google/genai");
      const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

      const prompt = `
Transforme ce texte OCR de recette en JSON structuré. Retourne UNIQUEMENT un objet JSON valide (sans markdown, sans texte autour).

Contraintes:
- category doit être exactement l'une de: "entrée", "plat", "dessert", "boisson"
- ingredients: liste de chaînes
- steps: liste de chaînes
- tags: liste de chaînes (peut être vide)
- source: chaîne ("" si inconnu)
- estimatedTime: chaîne ("" si inconnu)

Format:
{
  "title": "",
  "category": "entrée | plat | dessert | boisson",
  "ingredients": [],
  "steps": [],
  "tags": [],
  "source": "",
  "estimatedTime": ""
}

Texte OCR:
"""${normalizedText}"""
`;

      const result = await withRetry(
        async () => {
          return await ai.models.generateContent({
            model: "gemini-2.0-flash",
            generationConfig: {
              responseMimeType: "application/json",
              temperature: 0.2,
            },
            contents: [{ role: "user", parts: [{ text: prompt }] }],
          });
        },
        { retries: 2, baseMs: 700 }
      );

      const output = getModelText(result);
      const parsed = safeJsonParse(output);
      const recipe = sanitizeRecipeJson(parsed);

      return res.status(200).json(recipe);
    } catch (err) {
      logger.error(err);
      return res.status(500).json({
        error: "AI processing failed",
        details: String(err?.message || err),
      });
    }
  }
);

/* ------------------- 2) HTTP: request regeneration ---------------------- */

exports.regenerateRecipeImage = onRequest(
  {
    region: "europe-west1",
    secrets: [GEMINI_API_KEY],
    cors: true,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") return res.status(405).json({ error: "Use POST" });

      const decoded = await verifyFirebaseIdToken(req);
      const uid = decoded.uid;

      const { recipeId } = req.body || {};
      if (!recipeId || typeof recipeId !== "string") {
        return res.status(400).json({ error: "Missing recipeId" });
      }

      const ref = admin.firestore().doc(`recipes/${recipeId}`);
      const snap = await ref.get();
      if (!snap.exists) return res.status(404).json({ error: "Recipe not found" });

      const data = snap.data() || {};
      if (String(data.userId || "") !== uid) return res.status(403).json({ error: "Forbidden" });

      await ref.set(
        {
          imageUrl: admin.firestore.FieldValue.delete(),
          imageStatus: "queued",
          imageError: admin.firestore.FieldValue.delete(),
          imageRejectReasons: [],
          imageAttemptCount: 0,
          regenNonce: crypto.randomUUID(),
          imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return res.status(200).json({ ok: true });
    } catch (err) {
      logger.error(err);
      return res.status(500).json({
        error: "Failed",
        details: String(err?.message || err),
      });
    }
  }
);

/* ------------------ 3) Firestore triggers: generate image ---------------- */

async function runImageGeneration({ snap, recipeId, data }) {
  const title = String(data.title || "").trim();
  const category = String(data.category || "").trim();
  const userId = String(data.userId || "").trim();
  const ingredients = Array.isArray(data.ingredients) ? data.ingredients : [];

  if (!title || !userId) {
    logger.warn("Missing title or userId, skipping", { recipeId });
    await snap.ref.set(
      {
        imageStatus: "error",
        imageError: "Missing title or userId",
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return;
  }

  try {
    let b64 = null;
    let rejectReasons = [];
    let attemptCount = 0;

    // Try up to 2 generations (normal then strict)
    for (let attempt = 1; attempt <= 2; attempt++) {
      attemptCount = attempt;

      const strict = attempt === 2;
      const gen = await generateImageBase64({ title, category, ingredients, strict });

      const check = await validateGeneratedImage({
        b64: gen.b64,
        title,
        category,
        ingredients,
      });

      if (check.ok) {
        b64 = gen.b64;
        break;
      }

      // If validator bugged (non-json), don't waste a full regen immediately:
      if (check.reason === "validator_non_json") {
        const check2 = await validateGeneratedImage({
          b64: gen.b64,
          title,
          category,
          ingredients,
        });
        if (check2.ok) {
          b64 = gen.b64;
          break;
        }
        if (check2.reason === "validator_non_json") {
          logger.warn("Validator returned non-JSON twice; accepting image", { recipeId });
          b64 = gen.b64;
          break;
        }
        rejectReasons.push(check2.reason || "rejected");
      } else {
        rejectReasons.push(check.reason || "rejected");
      }

      logger.warn(`Image rejected (attempt ${attempt})`, {
        recipeId,
        reason: rejectReasons[rejectReasons.length - 1],
      });
    }

    // Fallback (never return without image): generic safe dish / drink
    if (!b64) {
      const fallbackTitle = category.toLowerCase() === "boisson" ? "Boisson maison" : "Plat maison";
      logger.warn("Both attempts rejected; using fallback prompt", { recipeId, rejectReasons });

      const fallbackGen = await generateImageBase64({
        title: fallbackTitle,
        category: category || "plat",
        ingredients: ingredients.slice(0, 3),
        strict: true,
      });

      const fallbackCheck = await validateGeneratedImage({
        b64: fallbackGen.b64,
        title: fallbackTitle,
        category: category || "plat",
        ingredients: ingredients.slice(0, 3),
      });

      if (fallbackCheck.ok || fallbackCheck.reason === "validator_non_json") {
        b64 = fallbackGen.b64;
      } else {
        b64 = fallbackGen.b64;
        rejectReasons.push(`fallback_rejected:${fallbackCheck.reason || "rejected"}`);
      }
    }

    await snap.ref.set(
      {
        imageAttemptCount: attemptCount,
        imageRejectReasons: rejectReasons,
      },
      { merge: true }
    );

    const inputBuffer = Buffer.from(b64, "base64");

    // Optimize: resize + WebP
    const webpBuffer = await sharp(inputBuffer)
      .resize(512, 512, { fit: "cover" })
      .webp({ quality: 78 })
      .toBuffer();

    // Upload to Storage
    const bucket = admin.storage().bucket();
    const filePath = `recipes/${userId}/${recipeId}/ai.webp`;
    const file = bucket.file(filePath);

    await file.save(webpBuffer, {
      contentType: "image/webp",
      resumable: false,
      metadata: {
        cacheControl: "public, max-age=31536000, immutable",
      },
    });

    // Create download URL (token)
    const token = crypto.randomUUID();
    await file.setMetadata({
      metadata: { firebaseStorageDownloadTokens: token },
    });

    const bucketName = bucket.name;
    const encodedPath = encodeURIComponent(filePath);
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${token}`;

    await snap.ref.set(
      {
        imageUrl: downloadUrl,
        imageStatus: "ready",
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info("✅ Optimized WebP image generated & attached", { recipeId, filePath });
  } catch (err) {
    logger.error("runImageGeneration failed", err);
    await snap.ref.set(
      {
        imageStatus: "error",
        imageError: String(err?.message || err).slice(0, 800),
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
}

exports.generateRecipeImageOnCreate = onDocumentCreated(
  {
    document: "recipes/{recipeId}",
    region: "europe-west1",
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const recipeId = event.params.recipeId;

    // Transaction-based lock to prevent double-run/concurrency
    const locked = await admin.firestore().runTransaction(async (tx) => {
      const ref = snap.ref;
      const fresh = await tx.get(ref);
      const data = fresh.data() || {};

      if (data.imageUrl) {
        logger.info("Image already exists, skipping", { recipeId });
        return { ok: false };
      }
      if (data.imageStatus === "processing") {
        logger.info("Image already processing, skipping", { recipeId });
        return { ok: false };
      }

      tx.set(
        ref,
        {
          imageStatus: "processing",
          imageError: admin.firestore.FieldValue.delete(),
          imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          imageAttemptCount: 0,
          imageRejectReasons: [],
        },
        { merge: true }
      );

      return { ok: true };
    });

    if (!locked?.ok) return;

    const data = (await snap.ref.get()).data() || {};
    await runImageGeneration({ snap, recipeId, data });
  }
);

/**
 * Regeneration trigger:
 * when imageStatus becomes "queued" (set by regenerateRecipeImage HTTP endpoint)
 */
exports.generateRecipeImageOnQueued = onDocumentUpdated(
  {
    document: "recipes/{recipeId}",
    region: "europe-west1",
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const recipeId = event.params.recipeId;
    const beforeData = before.data() || {};
    const afterData = after.data() || {};

    // Only when queued now, and either wasn't queued or regenNonce changed
    const queuedNow = afterData.imageStatus === "queued";
    const wasQueued = beforeData.imageStatus === "queued";
    const nonceChanged = afterData.regenNonce && afterData.regenNonce !== beforeData.regenNonce;

    if (!(queuedNow && (!wasQueued || nonceChanged))) return;

    if (afterData.imageUrl) return;
    if (afterData.imageStatus === "processing") return;

    // Lock to avoid double processing
    const locked = await admin.firestore().runTransaction(async (tx) => {
      const ref = after.ref;
      const fresh = await tx.get(ref);
      const d = fresh.data() || {};

      if (d.imageUrl) return { ok: false };
      if (d.imageStatus === "processing") return { ok: false };
      if (d.imageStatus !== "queued") return { ok: false };

      tx.set(
        ref,
        {
          imageStatus: "processing",
          imageError: admin.firestore.FieldValue.delete(),
          imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          imageAttemptCount: 0,
          imageRejectReasons: [],
        },
        { merge: true }
      );

      return { ok: true };
    });

    if (!locked?.ok) return;

    const data = (await after.ref.get()).data() || {};
    await runImageGeneration({ snap: after, recipeId, data });
  }
);
