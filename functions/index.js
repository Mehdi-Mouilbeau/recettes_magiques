/* eslint-disable */

const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const sharp = require("sharp");

const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

/**
 * Build a robust food-only prompt.
 * strict=false: normal
 * strict=true: extra locked-down
 */
function buildPrompt({ title, category, ingredients, strict = false }) {
  const safeTitle = String(title || "").trim().replace(/\s+/g, " ").slice(0, 80);
  const cat = String(category || "").trim().toLowerCase();

  // If OCR title looks noisy, don't push it (prevents poster/cover generations)
  const titleLooksWeird =
    safeTitle.length < 4 ||
    /[^a-zA-ZÀ-ÿ0-9'’\-\s]/.test(safeTitle) ||
    (safeTitle.match(/[A-Z]/g)?.length || 0) > safeTitle.length * 0.7;

  const dishName = titleLooksWeird ? "" : `Dish name: "${safeTitle}".`;

  // Normalize ambiguous ingredients (ex: "piment oiseau" -> avoid "oiseau" => birds)
  const normalizeIngredient = (s) => {
    let t = String(s || "").trim().toLowerCase();
    t = t.replace(/\bpiment\s+oiseau\b/g, "small red chili pepper");
    t = t.replace(/\boiseau(x)?\b/g, ""); // remove the trigger word entirely
    t = t.replace(/[()]/g, " ");
    t = t.replace(/\s+/g, " ").trim();
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

  const base = [
    // Strong anchor: must be an edible dish photo
    "Photorealistic food photography of a real cooked dish (edible meal).",
    dishName,
    cat ? `Dish type: ${cat}.` : "",
    ing.length ? `Visible key ingredients in the dish: ${ing.join(", ")}.` : "",

    // Plating constraints to avoid landscapes/posters
    "Single plated dish as the main subject, centered in frame, on a ceramic plate or bowl, on a table.",
    "Three-quarter angle (about 45 degrees), shallow depth of field, DSLR look, 50mm lens, f/2.8, realistic lighting.",
    "Natural soft daylight, subtle shadows, true-to-life colors, high detail, appetizing texture, slight steam if hot.",
    "Simple neutral background (kitchen table), minimal props only (e.g., fork), no busy scenery.",

    // Strict bans
    "ABSOLUTELY NO text of any kind: no letters, no words, no subtitles, no captions, no labels, no menu, no typography.",
    "No logos, no watermarks, no branding, no packaging, no book pages, no screenshots, no UI elements.",
    "No people, no hands, no faces, no animals.",
    "Do not generate landscapes, buildings, islands, castles, posters, banners, or graphic designs — only the plated food photo.",
  ].filter(Boolean);

  if (!strict) return base.join(" ");

  // Strict mode: even more locked down
  const strictAdd = [
    "Food-only packshot: image must contain ONLY the plated dish and a neutral tabletop background.",
    "No decorative scenery, no nature, no architecture, no fashion, no portraits.",
    "If uncertain, generate a simple realistic plated dish photo rather than anything else.",
  ];

  return base.concat(strictAdd).filter(Boolean).join(" ");
}

/**
 * Helper: generates an image (base64) via Imagen predict endpoint.
 * Returns: { b64, mimeType }
 */
async function generateImageBase64({ title, category, ingredients, strict = false }) {
  const promptText = buildPrompt({ title, category, ingredients, strict });

  const model = "imagen-4.0-generate-001";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict`;

  const payload = {
    instances: [{ prompt: promptText }],
    parameters: {
      sampleCount: 1,
      aspectRatio: "1:1",
    },
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": GEMINI_API_KEY.value(),
    },
    body: JSON.stringify(payload),
  });

  const raw = await resp.text();

  if (!resp.ok) {
    logger.error("Imagen predict failed:", resp.status, raw);
    throw new Error(raw || `HTTP ${resp.status}`);
  }

  const data = raw ? JSON.parse(raw) : {};
  const pred = data?.predictions?.[0];
  const b64 = pred?.bytesBase64Encoded;

  if (!b64) {
    logger.error("No bytesBase64Encoded in response:", data);
    throw new Error("No image bytesBase64Encoded in response");
  }

  return { b64, mimeType: "image/png" };
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
- The image clearly shows a plated cooked food dish (edible meal).
- NO visible text/letters/typography anywhere.
- NO people, NO animals, NO landscapes, NO buildings, NO posters/covers/UI, NO fashion product photos.
- Should look like photorealistic food photography.

Recipe context:
title: ${String(title || "").slice(0, 120)}
category: ${String(category || "")}
ingredients: ${(Array.isArray(ingredients) ? ingredients : []).slice(0, 12).join(", ")}
`;

  const result = await ai.models.generateContent({
    model: "gemini-2.0-flash",
    contents: [
      {
        role: "user",
        parts: [
          { text: prompt },
          {
            inlineData: {
              // Imagen returns png bytes; even if format differs, the judge generally still works.
              mimeType: "image/png",
              data: b64,
            },
          },
        ],
      },
    ],
  });

  const out = result?.text || "";
  let json;
  try {
    json = JSON.parse(out);
  } catch {
    const m = out.match(/\{[\s\S]*\}/);
    json = m ? JSON.parse(m[0]) : { ok: false, reason: "Validator returned non-JSON" };
  }

  return {
    ok: Boolean(json.ok),
    reason: String(json.reason || "").slice(0, 200),
  };
}

/**
 * 1) HTTP: OCR text -> structured recipe JSON
 */
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
"""${text}"""
`;

      const result = await ai.models.generateContent({
        model: "gemini-2.0-flash",
        contents: [{ role: "user", parts: [{ text: prompt }] }],
      });

      const output = result?.text || "";
      let json;

      try {
        json = JSON.parse(output);
      } catch (e) {
        const match = output.match(/\{[\s\S]*\}/);
        if (!match) throw new Error("Model did not return JSON.");
        json = JSON.parse(match[0]);
      }

      return res.status(200).json(json);
    } catch (err) {
      logger.error(err);
      return res.status(500).json({
        error: "AI processing failed",
        details: String(err?.message || err),
      });
    }
  }
);

/**
 * 3) Firestore trigger: on recipe create -> generate image -> upload -> set imageUrl
 * With safety: validate image; if rejected, retry once with stricter prompt.
 */
exports.generateRecipeImageOnCreate = onDocumentCreated(
  {
    document: "recipes/{recipeId}",
    region: "europe-west1",
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const recipeId = event.params.recipeId;
    const data = snap.data() || {};

    // Anti double-run
    if (data.imageUrl) {
      logger.info("Image already exists, skipping", { recipeId });
      return;
    }

    const title = String(data.title || "").trim();
    const category = String(data.category || "").trim();
    const userId = String(data.userId || "").trim();
    const ingredients = Array.isArray(data.ingredients) ? data.ingredients : [];

    if (!title || !userId) {
      logger.warn("Missing title or userId, skipping", { recipeId });
      return;
    }

    // status (optional but useful for UI)
    await snap.ref.set(
      {
        imageStatus: "processing",
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    try {
      // 1) Generate + validate (up to 2 attempts)
      let b64 = null;
      let lastReason = "";

      for (let attempt = 1; attempt <= 2; attempt++) {
        const strict = attempt === 2;

        const gen = await generateImageBase64({
          title,
          category,
          ingredients,
          strict,
        });

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

        lastReason = check.reason || "rejected";
        logger.warn(`Image rejected (attempt ${attempt})`, {
          recipeId,
          reason: lastReason,
        });
      }

      if (!b64) {
        throw new Error(`AI image rejected twice: ${lastReason}`);
      }

      const inputBuffer = Buffer.from(b64, "base64");

      // 1bis) Optimize: resize + WebP
      const webpBuffer = await sharp(inputBuffer)
        .resize(512, 512, { fit: "cover" })
        .webp({ quality: 78 })
        .toBuffer();

      // 2) Upload to Storage
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

      // 3) Create download URL
      const token = crypto.randomUUID();
      await file.setMetadata({
        metadata: {
          firebaseStorageDownloadTokens: token,
        },
      });

      const bucketName = bucket.name;
      const encodedPath = encodeURIComponent(filePath);
      const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${token}`;

      // 4) Update Firestore
      await snap.ref.set(
        {
          imageUrl: downloadUrl,
          imageStatus: "ready",
          imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      logger.info("✅ Optimized WebP image generated & attached", {
        recipeId,
        filePath,
      });
    } catch (err) {
      logger.error("generateRecipeImageOnCreate failed", err);
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
);
