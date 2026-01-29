/* eslint-disable */

const { onRequest } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
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
 * Retry helper with exponential backoff for transient errors.
 * IMPORTANT: do NOT retry daily quota exhaustion.
 */
async function withRetry(fn, { retries = 3, baseMs = 500 } = {}) {
  let lastErr;
  for (let i = 0; i <= retries; i++) {
    try {
      return await fn(i);
    } catch (e) {
      lastErr = e;
      const msg = String(e?.message || e);

      const is429 = /(^| )429( |$)|code":\s*429|HTTP 429/i.test(msg);
      const isDailyQuota =
        /predict_requests_per_model_per_day|PerDay|per_day|Quota exceeded for metric|PredictRequestsPerDay/i.test(
          msg,
        );

      const retryable =
        /503|timeout|ETIMEDOUT|ECONNRESET|ENOTFOUND|fetch failed|EAI_AGAIN|aborted|AbortError/i.test(
          msg,
        ) ||
        (is429 && !isDailyQuota);

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

  if (typeof result.text === "function") return result.text();
  if (typeof result.text === "string") return result.text;

  if (result.response?.text && typeof result.response.text === "function")
    return result.response.text();
  if (typeof result.response?.text === "string") return result.response.text;

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

function isQuotaErrorMessage(msg) {
  const s = String(msg || "");
  return /HTTP 429|RESOURCE_EXHAUSTED|predict_requests_per_model_per_day|Quota exceeded/i.test(
    s,
  );
}

/* ----------------------------- OCR hardening ---------------------------- */

/**
 * Heuristic OCR fixer for French cooking recipes.
 * Goal: fix common OCR glue/spacing/apostrophe/unit issues WITHOUT extra AI cost.
 */
function autocorrectOcrFrench(text) {
  let t = String(text || "");

  // --- Normalize apostrophes ---
  t = t.replace(/['´`]/g, "'");

  // --- Normalize unicode fractions ---
  t = t
    .replace(/½/g, "1/2")
    .replace(/¼/g, "1/4")
    .replace(/¾/g, "3/4")
    .replace(/⅓/g, "1/3")
    .replace(/⅔/g, "2/3");

  // --- Fix common OCR "l h ..." -> "l'h..." (lhhuile) ---
  t = t.replace(/\blh([a-zà-ÿ])/gi, "l'h$1"); // lhhuile -> l'huile

  // --- Restore spaces around numbers and 'à' ---
  t = t.replace(/(\d)à(\d)/g, "$1 à $2"); // 2à3 -> 2 à 3
  t = t.replace(/(\d)-(\d)/g, "$1 - $2"); // 8-10 -> 8 - 10
  t = t.replace(/([a-zà-ÿ])(\d)/gi, "$1 $2"); // min8 -> min 8
  t = t.replace(/(\d)([a-zà-ÿ])/gi, "$1 $2"); // 10min -> 10 min

  // --- Restore spaces between words stuck together in steps ---
  // ex: "Mélangezbien" => "Mélangez bien"
  t = t.replace(/([a-zà-ÿ])([A-ZÀ-Ý])/g, "$1 $2");

  // Common glued verbs
  t = t.replace(
    /\b(mélangez|ajoutez|faites|coupez|émincez|versez|chauffez|hachez|lavez)(bien)\b/gi,
    "$1 $2",
  );

  // --- Units normalization ---
  t = t
    .replace(/\bcuill?\.?\s*à\s*s(oupe)?\b/gi, "cuil. à soupe")
    .replace(/\bcàs\b/gi, "cuil. à soupe")
    .replace(/\bcas\b/gi, "cuil. à soupe")
    .replace(/\bcs\b/gi, "cuil. à soupe")
    .replace(/\bcuill?\.?\s*à\s*c(afé)?\b/gi, "cuil. à café")
    .replace(/\bcàc\b/gi, "cuil. à café")
    .replace(/\bcac\b/gi, "cuil. à café");

  // g / gr / grammes
  t = t.replace(/\bgr\b/gi, "g");
  t = t.replace(/\bgrammes?\b/gi, "g");

  // ml / cl / l
  t = t.replace(/\bmillilitres?\b/gi, "ml");
  t = t.replace(/\bcentilitres?\b/gi, "cl");
  t = t.replace(/\blitres?\b/gi, "l");

  // --- Restore French elisions often broken/merged ---
  t = t.replace(/\bloignon\b/gi, "l'oignon");
  t = t.replace(/\blail\b/gi, "l'ail");
  t = t.replace(/\blhuile\b/gi, "l'huile");

  // --- Targeted fixes from your screenshots ---
  t = t.replace(/\bcOupe-les\b/g, "coupe-les");
  t = t.replace(/\bMélangezbien\b/g, "Mélangez bien");
  t = t.replace(/\brevenirloignon\b/gi, "revenir l'oignon");
  t = t.replace(/\brevenir\s+loignon\b/gi, "revenir l'oignon");

  // --- Remove common "parasite" lines ---
  t = t
    .replace(/^\s*page\s*\d+\s*\/\s*\d+\s*$/gim, "")
    .replace(/^\s*(www\.)\S+\s*$/gim, "")
    .replace(/^\s*©\s*\d{4}.*$/gim, "");

  // --- Cleanup whitespace ---
  t = t
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  return t;
}

function normalizeOcrText(raw) {
  let t = String(raw || "");

  t = t.replace(/\r\n/g, "\n").replace(/\u00AD/g, "");
  t = t.replace(/[ \t]+/g, " ");
  t = t.replace(/\n{3,}/g, "\n\n");

  // join hyphenated words across line breaks
  t = t.replace(/(\p{L}+)-\n(\p{L}+)/gu, "$1$2");

  // normalize bullets
  t = t.replace(/[•●▪◆◦]/g, "-");

  // drop empty lines
  const lines = t.split("\n").map((l) => l.trimEnd());
  const kept = lines.filter((l) => l.trim().length > 0);
  t = kept.join("\n");

  return t.trim();
}

/**
 * Fonction helper pour calculer le temps total (rétrocompatibilité)
 */
function calculateTotalTime(prepTime, cookTime) {
  if (!prepTime && !cookTime) return "";
  if (!cookTime) return prepTime;
  if (!prepTime) return cookTime;

  // Parse et additionne les temps
  const parseTime = (timeStr) => {
    if (!timeStr) return 0;
    const hourMatch = timeStr.match(/(\d+)\s*h/i);
    const minMatch = timeStr.match(/(\d+)\s*min/i);
    const hours = hourMatch ? parseInt(hourMatch[1]) : 0;
    const mins = minMatch ? parseInt(minMatch[1]) : 0;
    return hours * 60 + mins;
  };

  const totalMins = parseTime(prepTime) + parseTime(cookTime);
  const hours = Math.floor(totalMins / 60);
  const mins = totalMins % 60;

  if (hours > 0 && mins > 0) return `${hours} h ${mins} min`;
  if (hours > 0) return `${hours} h`;
  return `${mins} min`;
}

function sanitizeRecipeJson(obj) {
  const out = {
    title: String(obj?.title || "")
      .trim()
      .slice(0, 120),
    category: String(obj?.category || "")
      .trim()
      .toLowerCase(),
    ingredients: Array.isArray(obj?.ingredients)
      ? obj.ingredients.map((x) => String(x).trim()).filter(Boolean)
      : [],
    steps: Array.isArray(obj?.steps)
      ? obj.steps.map((x) => String(x).trim()).filter(Boolean)
      : [],
    tags: Array.isArray(obj?.tags)
      ? obj.tags.map((x) => String(x).trim()).filter(Boolean)
      : [],
    source: String(obj?.source || "")
      .trim()
      .slice(0, 160),
    preparationTime: String(obj?.preparationTime || "")
      .trim()
      .slice(0, 60),
    cookingTime: String(obj?.cookingTime || "")
      .trim()
      .slice(0, 60),
    estimatedTime: String(obj?.estimatedTime || "")
      .trim()
      .slice(0, 60),
  };

  const allowed = new Set(["entrée", "plat", "dessert", "boisson"]);
  if (!allowed.has(out.category)) out.category = "plat";
  if (!out.title) out.title = "Recette";

  if (out.ingredients.length > 40)
    out.ingredients = out.ingredients.slice(0, 40);
  if (out.steps.length > 40) out.steps = out.steps.slice(0, 40);

  out.steps = out.steps.map((s) => s.replace(/^\s*\d+\s*[\).\-\:]\s*/g, ""));
  out.ingredients = out.ingredients.filter(
    (x) => !/https?:\/\/|www\.|@|€|\bqr\b|\bcode\b/i.test(x),
  );

  return out;
}

/**
 * Optional salvage (0 AI cost): if model output is missing fields, recover some from raw text.
 */
function salvageFromRawText(recipe, rawText) {
  const r = { ...recipe };
  const txt = String(rawText || "");

  // Salvage times if missing
  if (!r.preparationTime && !r.cookingTime && !r.estimatedTime) {
    const m = txt.match(/\b(\d+\s*(?:min|minutes|h|heures))\b/i);
    if (m) r.preparationTime = m[1];
  }

  if (!Array.isArray(r.ingredients) || r.ingredients.length === 0) {
    const lines = txt.split("\n").map((l) => l.trim());
    const guessed = lines
      .filter((l) => /^[-•]\s+/.test(l))
      .map((l) => l.replace(/^[-•]\s+/, "").trim())
      .filter(Boolean)
      .slice(0, 40);
    if (guessed.length) r.ingredients = guessed;
  }

  if (!Array.isArray(r.steps) || r.steps.length === 0) {
    const blocks = txt
      .split(/\n{2,}/)
      .map((b) => b.trim())
      .filter(Boolean);
    const stepLike = blocks.filter((b) => b.length > 20).slice(0, 30);
    if (stepLike.length) r.steps = stepLike;
  }

  // Post-fix text again for safety
  r.ingredients = (r.ingredients || []).map(autocorrectOcrFrench);
  r.steps = (r.steps || []).map(autocorrectOcrFrench);

  return r;
}

/* ---------------------------- Prompt (image) ---------------------------- */
function buildPrompt({ title, category, ingredients, strict = false }) {
  const safeTitle = String(title || "")
    .trim()
    .replace(/\s+/g, " ")
    .slice(0, 80);

  const cat = String(category || "")
    .trim()
    .toLowerCase();
  const lowerTitle = safeTitle.toLowerCase();

  const titleLooksWeird =
    safeTitle.length < 4 ||
    /[^a-zA-ZÀ-ÿ0-9''\-\s()]/.test(safeTitle) ||
    (safeTitle.match(/[A-Z]/g)?.length || 0) > safeTitle.length * 0.7;

  const dishName = titleLooksWeird ? "" : `Dish name: "${safeTitle}".`;

  const drinkHint =
    cat === "boisson"
      ? "This MUST be a beverage served in a glass or cup (cocktail/smoothie/juice). Not a product photo."
      : "";

  // ---------- helpers ----------
  const normalizeIngredient = (s) => {
    let t = String(s || "")
      .trim()
      .toLowerCase();
    t = t.replace(/\bpiment\s+oiseau\b/g, "small red chili pepper");
    t = t.replace(/\boiseau(x)?\b/g, "");
    t = t.replace(/[()]/g, " ");
    t = t.replace(/\s+/g, " ").trim();
    t = t.replace(/https?:\/\/\S+|www\.\S+|[@€]/g, "").trim();
    return t;
  };

  // ingrédients très génériques => on les enlève, mais garde l'essentiel
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

  const ingAll = (Array.isArray(ingredients) ? ingredients : [])
    .map(normalizeIngredient)
    .filter(Boolean)
    .filter((x) => !STOP.has(x));

  // Mets un peu plus d’ingrédients visibles (évite les sorties trop “génériques”)
  const ing = ingAll.slice(0, 7);

  // ---------- dish shape detection ----------
  const isSoupLike =
    /\b(soupe|potage|velout[eé]|bouillon|consomm[eé]|ramen|pho)\b/.test(
      lowerTitle,
    ) || /\b(soupe|potage|velout[eé]|bouillon)\b/.test(cat);

  const isStewLike =
    /\b(rago[uû]t|curry|chili|daube|tajine|ragout|stew)\b/.test(lowerTitle);

  const isSaladLike = /\b(salade)\b/.test(lowerTitle);

  const dishVessel = (() => {
    if (cat === "boisson") return "in a glass or cup";
    if (isSoupLike) return "in a bowl";
    if (isStewLike) return "in a bowl";
    if (isSaladLike) return "in a bowl";
    return "on a ceramic plate or bowl";
  })();

  // ---------- accompaniment / extra foods ----------
  // Objectif: 1–2 éléments “autour” du plat (sans devenir une scène chargée)
  const hasTomato =
    ingAll.some((x) => /\btomate(s)?\b/.test(x)) ||
    /\btomate(s)?\b/.test(lowerTitle);
  const hasBasil =
    ingAll.some((x) => /\bbasilic\b/.test(x)) ||
    /\bbasil\b/.test(ingAll.join(" "));
  const hasCream = ingAll.some((x) => /\b(cr[eè]me|cream)\b/.test(x));

  const extraFoods = (() => {
    if (cat === "boisson") return ["a citrus garnish", "ice cubes"];
    if (isSoupLike && hasTomato) {
      // Soupe tomate: le trio gagnant visuel
      const arr = ["a slice of crusty bread or croutons"];
      arr.push(
        hasCream
          ? "a visible cream swirl on top"
          : "a small cream swirl on top",
      );
      arr.push(
        hasBasil ? "fresh basil leaves as garnish" : "fresh herbs as garnish",
      );
      return arr.slice(0, 2); // 1–2 éléments max
    }
    if (isSoupLike)
      return ["a slice of crusty bread", "fresh herbs garnish"].slice(0, 2);
    if (isStewLike) return ["a small side of rice or flatbread"].slice(0, 1);
    return ["a simple garnish (herbs/lemon wedge)"].slice(0, 1);
  })();

  // ---------- anchors for common failures ----------
  const dishAnchor = (() => {
    if (/\bcr[eê]pe(s)?\b/.test(lowerTitle)) {
      return "The dish must look like French crepes: thin folded pancakes, lightly golden, on a plate, optionally with sugar or lemon.";
    }
    if (/\btzatziki\b/.test(lowerTitle)) {
      return "The dish must look like tzatziki: creamy white yogurt dip with grated cucumber and herbs in a bowl.";
    }
    if (/\bdaiquiri\b/.test(lowerTitle) || cat === "boisson") {
      return "The dish must look like a drink: a cold cocktail in a glass with condensation and a garnish (lime).";
    }
    if (isSoupLike) {
      return "The dish MUST clearly be a soup: a liquid/velvety texture served in a bowl, with a spoon nearby, slight steam if hot. Not sliced tomatoes, not a salad, not raw ingredients.";
    }
    return "";
  })();

  // ---------- negatives (targeted) ----------
  const soupNegatives = isSoupLike
    ? [
        "Do NOT depict whole raw tomatoes on a plate as the main subject.",
        "Do NOT show a salad-like arrangement or sliced tomatoes as a dish.",
        "Avoid ingredient still-life or raw produce photography; it must be a cooked soup in a bowl.",
      ].join(" ")
    : "";

  const base = [
    "Photorealistic food photography of a real cooked dish (edible meal).",
    dishName,
    cat ? `Dish type: ${cat}.` : "",
    drinkHint,
    dishAnchor,

    ing.length
      ? `Visible key ingredients cooked into the dish: ${ing.join(", ")}.`
      : "",

    extraFoods.length
      ? `Also include 1–2 small complementary foods/garnishes near the main dish: ${extraFoods.join(
          ", ",
        )}.`
      : "",

    `Single main dish centered in frame, served ${dishVessel}, on a neutral tabletop.`,
    "Three-quarter angle (about 45 degrees), shallow depth of field, DSLR look, 50mm lens, f/2.8, realistic lighting.",
    "Natural soft daylight, subtle shadows, true-to-life colors, high detail, appetizing texture, slight steam if hot.",
    "Simple neutral background, minimal props only (e.g., spoon for soup, fork for mains).",
    soupNegatives,

    "ABSOLUTELY NO text of any kind: no letters, no words, no subtitles, no captions, no labels, no menu, no typography.",
    "No logos, no watermarks, no branding, no packaging, no book pages, no screenshots, no UI elements.",
    "No people, no hands, no faces, no animals.",
    "Do not generate landscapes, buildings, posters, fashion items, clothing, jackets, jeans, or product shots — only the food/drink photo.",
  ].filter(Boolean);

  if (!strict) return base.join(" ");

  const strictAdd = [
    "Food-only packshot: image must contain ONLY the main dish plus up to two small complementary foods/garnishes, and a neutral tabletop background.",
    "No decorative scenery, no nature, no architecture, no fashion, no portraits, no products.",
    "If uncertain, generate a simple realistic cooked dish photo that matches the dish type.",
  ];

  return base.concat(strictAdd).filter(Boolean).join(" ");
}

/* ---------------------- Imagen generation (single-pass) ------------------ */

async function generateImageBase64({
  title,
  category,
  ingredients,
  strict = true,
}) {
  const promptText = buildPrompt({ title, category, ingredients, strict });
  const encodedPrompt = encodeURIComponent(promptText);
  const url = `https://image.pollinations.ai/prompt/${encodedPrompt}?width=512&height=512&model=flux&nologo=true&enhance=false`;

  const doCall = async () => {
    const resp = await fetchWithTimeout(url, {}, 30000);
    if (!resp.ok) throw new Error(`Pollinations HTTP ${resp.status}`);

    const arrayBuffer = await resp.arrayBuffer();
    const b64 = Buffer.from(arrayBuffer).toString("base64");

    return { b64, mimeType: "image/jpeg" };
  };

  return await withRetry(doCall, { retries: 2, baseMs: 700 });
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
      if (req.method !== "POST")
        return res.status(405).json({ error: "Use POST" });

      const { text } = req.body || {};
      if (!text || typeof text !== "string" || text.trim().length < 10) {
        return res.status(400).json({ error: "Missing or invalid 'text'." });
      }

      const normalizedText = autocorrectOcrFrench(normalizeOcrText(text));

      logger.info("📝 OCR INPUT:", {
        textLength: normalizedText.length,
        preview: normalizedText.slice(0, 200),
      });

      const { GoogleGenAI } = require("@google/genai");
      const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

      const prompt = `
Tu es un expert culinaire français spécialisé dans la classification des recettes.

ÉTAPE 1 - ANALYSE DU TYPE DE PLAT:
Lis attentivement le titre et les ingrédients pour déterminer la catégorie.

CATÉGORIES (choix OBLIGATOIRE parmi ces 4 uniquement):

"entrée" = Tout plat servi EN DÉBUT DE REPAS:
  ✓ Toutes les soupes (chaudes ou froides): velouté, potage, gaspacho, minestrone, soupe à l'oignon
  ✓ Toutes les salades servies en début de repas: salade composée, salade de chèvre chaud, salade niçoise
  ✓ Terrines et pâtés: terrine de campagne, terrine de saumon, pâté en croûte
  ✓ Plats froids d'entrée: carpaccio, tartare (saumon, bœuf), ceviche
  ✓ Verrines et amuse-bouches: verrine avocat crevette, œufs mimosa
  ✓ Feuilletés apéritifs: feuilleté au fromage, vol-au-vent
  ✓ Toasts et bruschetta: toast au saumon fumé, bruschetta tomate
  ✓ Œufs en entrée: œufs cocotte, œufs en meurette

"plat" = Plat principal, CŒUR DU REPAS:
  ✓ Viandes: poulet rôti, bœuf bourguignon, côtelettes d'agneau
  ✓ Poissons en plat: saumon grillé, sole meunière, poisson au four
  ✓ Gratins: gratin dauphinois, gratin de pâtes
  ✓ Quiches et tartes salées: quiche lorraine, tarte aux légumes
  ✓ Plats de pâtes/riz: spaghetti bolognaise, risotto, paella
  ✓ Plats végétariens principaux: curry de légumes, tajine
  ✓ Pizzas

"dessert" = Plat sucré servi EN FIN DE REPAS:
  ✓ Gâteaux: gâteau au chocolat, cake, brownie
  ✓ Tartes sucrées: tarte aux pommes, tarte au citron
  ✓ Crèmes et mousses: crème brûlée, mousse au chocolat, panna cotta
  ✓ Glaces et sorbets
  ✓ Fruits cuits: compote, fruits rôtis
  ✓ Biscuits et cookies

"boisson" = Liquide à boire:
  ✓ Cocktails: mojito, daiquiri
  ✓ Smoothies et milkshakes
  ✓ Jus de fruits frais
  ✓ Boissons chaudes: chocolat chaud, infusions

ÉTAPE 2 - RÈGLE DÉCISIVE:
- Si c'est une SOUPE → TOUJOURS "entrée"
- Si c'est une SALADE (sans viande grillée comme plat principal) → "entrée"
- Si c'est une TERRINE/PÂTÉ → "entrée"
- Si c'est SUCRÉ → "dessert"
- Si c'est de la VIANDE/POISSON avec garniture → "plat"
- Si c'est un GRATIN/QUICHE → "plat"

RÈGLES POUR LES TEMPS:
- Sépare le temps de préparation et le temps de cuisson s'ils sont mentionnés
- Format: "X min" ou "X h Y min"
- Si absent, laisse ""

FORMAT JSON (retourne UNIQUEMENT ce JSON, sans texte avant/après, sans markdown):
{
  "title": "Nom exact de la recette",
  "category": "entrée | plat | dessert | boisson",
  "ingredients": ["ingrédient 1 avec quantité", "ingrédient 2"],
  "steps": ["étape 1", "étape 2"],
  "tags": ["tag1", "tag2"],
  "source": "",
  "preparationTime": "",
  "cookingTime": ""
}

EXEMPLES CONCRETS POUR T'AIDER:
"Velouté de butternut" → category: "entrée" (c'est une soupe)
"Soupe à l'oignon gratinée" → category: "entrée" (c'est une soupe)
"Salade de chèvre chaud" → category: "entrée" (salade d'entrée)
"Terrine de saumon" → category: "entrée" (terrine)
"Gaspacho andalou" → category: "entrée" (soupe froide)
"Carpaccio de bœuf" → category: "entrée" (plat froid d'entrée)
"Poulet rôti et pommes de terre" → category: "plat" (viande + garniture)
"Quiche lorraine" → category: "plat" (plat principal)
"Tarte au citron meringuée" → category: "dessert" (tarte sucrée)
"Smoothie mangue passion" → category: "boisson" (boisson)

TEXTE OCR À ANALYSER:
"""
${normalizedText}
"""

IMPORTANT: Retourne UNIQUEMENT le JSON, rien d'autre.`;

      const result = await withRetry(
        async () => {
          return await ai.models.generateContent({
            model: "gemini-2.0-flash",
            generationConfig: {
              responseMimeType: "application/json",
              temperature: 0.0,
            },
            contents: [{ role: "user", parts: [{ text: prompt }] }],
          });
        },
        { retries: 2, baseMs: 700 },
      );

      const output = getModelText(result);
      const parsed = safeJsonParse(output);

      // Sanitize + salvage
      let recipe = sanitizeRecipeJson(parsed);
      recipe = salvageFromRawText(recipe, normalizedText);

      // Validation finale de la catégorie
      const validCategories = ["entrée", "plat", "dessert", "boisson"];
      if (!validCategories.includes(recipe.category)) {
        recipe.category = "plat"; // Fallback sécurisé
      }

      // Rétrocompatibilité: calculer estimatedTime si non fourni
      if (!recipe.estimatedTime) {
        recipe.estimatedTime = calculateTotalTime(
          recipe.preparationTime,
          recipe.cookingTime,
        );
      }

      logger.info("✅ AI OUTPUT:", {
        title: recipe.title,
        category: recipe.category,
      });
      return res.status(200).json(recipe);
    } catch (err) {
      logger.error(err);
      return res.status(500).json({
        error: "AI processing failed",
        details: String(err?.message || err),
      });
    }
  },
);

/* ------------------- 2) HTTP: request regeneration ---------------------- */
/**
 * Policy:
 * - allow at most ONE manual regeneration per recipe (imageRegenCount max 1)
 * - if quota reached, still allow setting queued, but generation will mark quota
 */
exports.regenerateRecipeImage = onRequest(
  {
    region: "europe-west1",
    secrets: [GEMINI_API_KEY],
    cors: true,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    try {
      if (req.method !== "POST")
        return res.status(405).json({ error: "Use POST" });

      const decoded = await verifyFirebaseIdToken(req);
      const uid = decoded.uid;

      const { recipeId } = req.body || {};
      if (!recipeId || typeof recipeId !== "string") {
        return res.status(400).json({ error: "Missing recipeId" });
      }

      const ref = admin.firestore().doc(`recipes/${recipeId}`);
      const snap = await ref.get();
      if (!snap.exists)
        return res.status(404).json({ error: "Recipe not found" });

      const data = snap.data() || {};
      if (String(data.userId || "") !== uid)
        return res.status(403).json({ error: "Forbidden" });

      const regenCount = Number(data.imageRegenCount || 0);
      if (regenCount >= 1) {
        return res.status(429).json({ error: "regen_limit_reached" });
      }

      await ref.set(
        {
          imageUrl: admin.firestore.FieldValue.delete(),
          imageStatus: "queued",
          imageError: admin.firestore.FieldValue.delete(),
          regenNonce: crypto.randomUUID(),
          imageRegenCount: admin.firestore.FieldValue.increment(1),
          imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      return res.status(200).json({ ok: true });
    } catch (err) {
      logger.error(err);
      return res.status(500).json({
        error: "Failed",
        details: String(err?.message || err),
      });
    }
  },
);

/* ------------------ 3) Firestore triggers: generate image ---------------- */

async function runImageGeneration({ snap, recipeId, data }) {
  const title = String(data.title || "").trim();
  const category = String(data.category || "").trim();
  const userId = String(data.userId || "").trim();
  const ingredients = Array.isArray(data.ingredients) ? data.ingredients : [];

  if (!title || !userId) {
    await snap.ref.set(
      {
        imageStatus: "error",
        imageError: "Missing title or userId",
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return;
  }

  try {
    const gen = await generateImageBase64({
      title,
      category,
      ingredients,
      strict: true,
    });

    const inputBuffer = Buffer.from(gen.b64, "base64");

    const webpBuffer = await sharp(inputBuffer)
      .resize(512, 512, { fit: "cover" })
      .webp({ quality: 78 })
      .toBuffer();

    const bucket = admin.storage().bucket();

    // versioned filename to bust cache
    const filePath = `recipes/${userId}/${recipeId}/ai_${Date.now()}.webp`;
    const file = bucket.file(filePath);

    await file.save(webpBuffer, {
      contentType: "image/webp",
      resumable: false,
      metadata: {
        cacheControl: "public, max-age=31536000, immutable",
      },
    });

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
      { merge: true },
    );

    logger.info("✅ Image generated (single pass)", { recipeId, filePath });
  } catch (err) {
    const msg = String(err?.message || err);
    const isQuota = isQuotaErrorMessage(msg);

    logger.error("runImageGeneration failed", err);

    await snap.ref.set(
      {
        imageStatus: isQuota ? "quota" : "error",
        imageError: isQuota ? "quota_exceeded" : msg.slice(0, 800),
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
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

    // Lock to avoid double-run
    const locked = await admin.firestore().runTransaction(async (tx) => {
      const ref = snap.ref;
      const fresh = await tx.get(ref);
      const data = fresh.data() || {};

      if (data.imageUrl) return { ok: false };
      if (data.imageStatus === "processing") return { ok: false };

      tx.set(
        ref,
        {
          imageStatus: "processing",
          imageError: admin.firestore.FieldValue.delete(),
          imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      return { ok: true };
    });

    if (!locked?.ok) return;

    const data = (await snap.ref.get()).data() || {};
    await runImageGeneration({ snap, recipeId, data });
  },
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

    const queuedNow = afterData.imageStatus === "queued";
    const wasQueued = beforeData.imageStatus === "queued";
    const nonceChanged =
      afterData.regenNonce && afterData.regenNonce !== beforeData.regenNonce;

    if (!(queuedNow && (!wasQueued || nonceChanged))) return;

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
        },
        { merge: true },
      );

      return { ok: true };
    });

    if (!locked?.ok) return;

    const data = (await after.ref.get()).data() || {};
    await runImageGeneration({ snap: after, recipeId, data });
  },
);
