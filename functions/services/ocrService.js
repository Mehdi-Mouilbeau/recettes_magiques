const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const { getGeminiText } = require("../config/gemini");
const { withRetry } = require("../utils/retry");
const { getModelText, safeJsonParse } = require("../utils/json");
const {
  normalizeOcrText,
  autocorrectOcrFrench,
  sanitizeRecipeJson,
  salvageFromRawText,
} = require("../utils/ocr");
const { calculateTotalTime } = require("../utils/time");

// fonction utilitaire pour limiter les lignes trop courtes ou bruit OCR
function filterShortLines(text) {
  return text
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 2)
    .join("\n");
}

exports.processRecipe = onRequest(
  { region: "europe-west1", cors: true, secrets: ["GEMINI_API_KEY"], timeoutSeconds: 120 },
  async (req, res) => {
    try {
      const { text } = req.body || {};
      if (!text || text.length < 10) {
        return res.status(400).json({ error: "Invalid text" });
      }

      // 1️⃣ nettoyage complet du texte OCR
      let cleaned = normalizeOcrText(text);
      cleaned = autocorrectOcrFrench(cleaned);
      cleaned = filterShortLines(cleaned);

      // 2️⃣ récupérer l'instance Gemini
      const ai = await getGeminiText();

      // 3️⃣ construction du prompt
      const prompt = `
Tu es un expert culinaire français spécialisé dans la classification des recettes.

CATÉGORIES (choix OBLIGATOIRE parmi 4 uniquement): "entrée" | "plat" | "dessert" | "boisson"

RÈGLES:
- Si c'est une SOUPE/VELOUTÉ/POTAGE → TOUJOURS "entrée"
- Si c'est une SALADE (sans viande grillée comme plat principal) → "entrée"
- Si c'est une TERRINE/PÂTÉ → "entrée"
- Si c'est SUCRÉ → "dessert"
- Si c'est de la VIANDE/POISSON avec garniture → "plat"
- Si c'est un GRATIN/QUICHE → "plat"
- Si c'est à boire → "boisson"

RÈGLES POUR LES TEMPS:
- Sépare préparation et cuisson s'ils sont mentionnés
- Format: "X min" ou "X h Y min"
- Si absent, laisse ""

FORMAT JSON (retourne UNIQUEMENT ce JSON, sans texte avant/après, sans markdown):
{
  "title": "Nom exact de la recette",
  "category": "entrée | plat | dessert | boisson",
  "servings": 0,
  "ingredients": ["ingrédient 1 avec quantité", "ingrédient 2"],
  "steps": ["étape 1", "étape 2"],
  "tags": ["tag1", "tag2"],
  "source": "",
  "preparationTime": "",
  "cookingTime": ""
}

RÈGLES POUR servings:
- Si le texte mentionne "pour X personnes / X pers / X portions / X couverts" => servings = X
- Sinon => 0

TEXTE OCR À ANALYSER:
"""
${cleaned}
"""

IMPORTANT: Retourne UNIQUEMENT le JSON, rien d'autre.`;

      // 4️⃣ envoi à l'IA
      const result = await withRetry(() =>
        ai.models.generateContent({
          model: "gemini-2.0-flash",
          config: {
            responseMimeType: "application/json",
            temperature: 0,
            safetySettings: [
              {
                category: "HARM_CATEGORY_HARASSMENT",
                threshold: "BLOCK_ONLY_HIGH",
              },
              {
                category: "HARM_CATEGORY_HATE_SPEECH",
                threshold: "BLOCK_ONLY_HIGH",
              },
              {
                category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                threshold: "BLOCK_ONLY_HIGH",
              },
              {
                category: "HARM_CATEGORY_DANGEROUS_CONTENT",
                threshold: "BLOCK_ONLY_HIGH",
              },
            ],
          },
          contents: [{ role: "user", parts: [{ text: prompt }] }],
        }),
      );

      // 4️⃣ parsing sécurisé
      const parsed = safeJsonParse(getModelText(result));

      // 5️⃣ création de la recette structurée
      let recipe = sanitizeRecipeJson(parsed);
      recipe = salvageFromRawText(recipe, cleaned);

      // 6️⃣ calcul temps total
      recipe.estimatedTime = calculateTotalTime(
        recipe.preparationTime,
        recipe.cookingTime,
      );

      return res.json(recipe);
    } catch (err) {
      logger.error(err);
      return res.status(500).json({
        error: "AI processing failed",
        details: String(err?.message || err),
      });
    }
  },
);
