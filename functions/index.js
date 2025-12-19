const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { GoogleGenAI } = require("@google/genai");

// ✅ Secret (remplace functions.config(), compatible après 2026)
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.processRecipe = onRequest(
  {
    region: "europe-west1", // tu peux laisser, ou mettre us-central1
    secrets: [GEMINI_API_KEY],
    cors: true, // gère OPTIONS automatiquement
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
