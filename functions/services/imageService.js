const admin = require("../config/admin");
const crypto = require("crypto");
const sharp = require("sharp");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

const { getGeminiImage } = require("../config/gemini");
const { withRetry } = require("../utils/retry");
const { buildPrompt } = require("../utils/prompt");
const { verifyFirebaseIdToken } = require("../utils/auth"); 
const PLACEHOLDER_IMAGE_URL = process.env.PLACEHOLDER_IMAGE_URL || "";

async function generateImageBase64(prompt) {
  const ai = getGeminiImage();
  const result = await withRetry(() =>
    ai.models.generateImages({
      model: "imagen-3.0-generate-002",
      prompt,
      config: {
        numberOfImages: 1,
        aspectRatio: "1:1",
        outputMimeType: "image/jpeg",
      },
    }),
  );
  const img = result.generatedImages?.[0]?.image?.imageBytes;
  if (!img) throw new Error("No image returned by Imagen");
  return img;
}

async function runImageGeneration({ snap, recipeId, data }) {
  try {
    const prompt = buildPrompt(data);
    const b64 = await generateImageBase64(prompt);

    const buffer = Buffer.from(b64, "base64");
    const webp = await sharp(buffer)
      .resize(512, 512)
      .webp({ quality: 80 })
      .toBuffer();

    const bucket = admin.storage().bucket();
    const path = `recipes/${data.userId}/${recipeId}/${Date.now()}.webp`;
    const file = bucket.file(path);

    await file.save(webp, { contentType: "image/webp", resumable: false });

    const token = crypto.randomUUID();
    await file.setMetadata({
      metadata: { firebaseStorageDownloadTokens: token },
    });

    const url =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(path)}?alt=media&token=${token}`;

    await snap.ref.update({
      imageStatus: "ready",
      imageUrl: url,
    });
  } catch (err) {
    await snap.ref.update({
      imageStatus: "error",
      imageError: String(err?.message || err),
    });
    throw err;
  }
}

const regenerateRecipeImage = onRequest(
  {
    region: "europe-west1",
    cors: true,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "Use POST" });
      }

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
      if (String(data.userId || "") !== uid) {
        return res.status(403).json({ error: "Forbidden" });
      }

      const regenCount = Number(data.imageRegenCount || 0);
      if (regenCount >= 1) {
        return res.status(429).json({ error: "regen_limit_reached" });
      }

      const placeholderPatch =
        PLACEHOLDER_IMAGE_URL && PLACEHOLDER_IMAGE_URL.startsWith("http")
          ? { imageUrl: PLACEHOLDER_IMAGE_URL, imageIsPlaceholder: true }
          : {};

      await ref.set(
        {
          ...placeholderPatch,
          imageStatus: "queued",
          imageError: admin.firestore.FieldValue.delete(),
          regenNonce: crypto.randomUUID(),
          imageRegenCount: admin.firestore.FieldValue.increment(1),
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

module.exports = {
  runImageGeneration,
  generateImageBase64,
  regenerateRecipeImage,
};