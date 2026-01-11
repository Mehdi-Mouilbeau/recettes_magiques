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
 * Helper: génère une image (base64) via Imagen (predict endpoint)
 * Retourne: { b64, mimeType }
 */
async function generateImageBase64({ title, category, ingredients }) {
  const ing = Array.isArray(ingredients)
    ? ingredients
        .map((x) => String(x || "").trim())
        .filter(Boolean)
        .slice(0, 6)
    : [];

  const safeTitle = String(title || "")
    .trim()
    .slice(0, 80);
  const cat = String(category || "")
    .trim()
    .toLowerCase();

  const promptText = [
    //  Ancrage fort: C'EST UNE PHOTO CULINAIRE RÉALISTE
    `Photorealistic food photography of the finished dish (edible meal) for the recipe "${safeTitle}".`,
    cat ? `Dish type: ${cat}.` : "",
    ing.length ? `Key visible ingredients: ${ing.join(", ")}.` : "",

    //  Contraintes de cadrage/plating pour éviter paysages / affiches
    "Single plated dish as the main subject, centered in frame, on a ceramic plate or bowl.",
    "Three-quarter angle (about 45 degrees), shallow depth of field, DSLR look, 50mm lens, f/2.8, realistic lighting.",
    "Natural soft daylight, subtle shadows, true-to-life colors, high detail, appetizing texture, slight steam if hot.",
    "Simple neutral background (kitchen table), minimal props only (e.g., fork), no busy scenery.",

    //  Anti-texte/anti-overlay très explicite
    "ABSOLUTELY NO text of any kind: no letters, no words, no subtitles, no captions, no labels, no menu, no typography.",
    "No logos, no watermarks, no branding, no packaging, no book pages, no screenshots, no UI elements.",
    "No people, no hands, no faces, no animals.",
    "Do not generate landscapes, buildings, islands, castles, posters, banners, or graphic designs — only the plated food photo.",
  ]
    .filter(Boolean)
    .join(" ");

  // ✅ Endpoint correct (predict)
  // Tu peux changer le modèle si besoin
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
 *  1) HTTP: Transforme texte OCR -> JSON recette structurée
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

      // Tu utilises déjà @google/genai dans ton code (OK)
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
 *  3) OPTION B (background): Trigger Firestore
 * Quand une recette est créée -> génère l'image + upload Storage + update Firestore.imageUrl
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

    //  Anti double-run
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

    // statut (optionnel mais recommandé pour ton UI)
    await snap.ref.set(
      {
        imageStatus: "processing",
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    try {
      // 1) Générer base64
      const { b64 } = await generateImageBase64({
        title,
        category,
        ingredients,
      });

      const inputBuffer = Buffer.from(b64, "base64");

      //  1bis) Optimisation: resize + WebP
      // 512x512 est un super compromis perf/qualité pour une app
      const webpBuffer = await sharp(inputBuffer)
        .resize(512, 512, { fit: "cover" })
        .webp({ quality: 78 }) // tu peux ajuster 70-85
        .toBuffer();

      // 2) Upload Storage (image optimisée)
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

      // 3) Générer une download URL Firebase (token)
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
