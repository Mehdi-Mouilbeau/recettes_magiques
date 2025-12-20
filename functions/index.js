const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { GoogleGenAI } = require("@google/genai");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

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

// Génération d'image de recette avec Imagen via Gemini API (REST predict)
exports.generateRecipeImage = onRequest(
  {
    region: "europe-west1",
    secrets: [GEMINI_API_KEY],
    cors: true,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "Use POST" });
      }

      const { title, category, ingredients } = req.body || {};
      if (!title || typeof title !== "string") {
        return res.status(400).json({ error: "Missing 'title'" });
      }

      const ing = Array.isArray(ingredients)
        ? ingredients.map((x) => String(x || "").trim()).filter(Boolean).slice(0, 6)
        : [];

      const promptText = [
        `High quality food photography of a dish for a recipe named "${title.trim()}".`,
        category ? `Course type: ${String(category).toLowerCase()}.` : "",
        ing.length ? `Ingredients focus: ${ing.join(", ")}.` : "",
        "Natural light, appetizing styling, clean neutral background, shallow depth of field.",
        "No text, no logos, no branding, no hands, no people.",
      ]
        .filter(Boolean)
        .join(" ");

      // ✅ Endpoint correct (predict)
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
        return res.status(500).json({
          error: "Image generation failed",
          details: raw || `HTTP ${resp.status}`,
        });
      }

      const data = raw ? JSON.parse(raw) : {};
      const pred = data?.predictions?.[0];
      const b64 = pred?.bytesBase64Encoded;

      if (!b64) {
        logger.error("No bytesBase64Encoded in response:", data);
        return res.status(500).json({ error: "No image in response", details: raw });
      }

      // On renvoie une clé "b64" simple côté Flutter
      return res.status(200).json({
        mimeType: "image/png",
        b64,
      });
    } catch (err) {
      logger.error(err);
      return res.status(500).json({
        error: "Image generation exception",
        details: String(err?.message || err),
      });
    }
  }
);
