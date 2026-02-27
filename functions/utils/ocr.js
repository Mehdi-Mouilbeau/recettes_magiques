function autocorrectOcrFrench(text) {
  let t = String(text || "");

  t = t.replace(/['´`]/g, "'");
  t = t
    .replace(/½/g, "1/2")
    .replace(/¼/g, "1/4")
    .replace(/¾/g, "3/4")
    .replace(/⅓/g, "1/3")
    .replace(/⅔/g, "2/3");

  t = t.replace(/\blh([a-zà-ÿ])/gi, "l'h$1");

  t = t.replace(/(\d)à(\d)/g, "$1 à $2");
  t = t.replace(/(\d)-(\d)/g, "$1 - $2");
  t = t.replace(/([a-zà-ÿ])(\d)/gi, "$1 $2");
  t = t.replace(/(\d)([a-zà-ÿ])/gi, "$1 $2");

  t = t.replace(/([a-zà-ÿ])([A-ZÀ-Ý])/g, "$1 $2");

  t = t.replace(
    /\b(mélangez|ajoutez|faites|coupez|émincez|versez|chauffez|hachez|lavez)(bien)\b/gi,
    "$1 $2",
  );

  t = t
    .replace(/\bcuill?\.?\s*à\s*s(oupe)?\b/gi, "cuil. à soupe")
    .replace(/\bcàs\b/gi, "cuil. à soupe")
    .replace(/\bcas\b/gi, "cuil. à soupe")
    .replace(/\bcs\b/gi, "cuil. à soupe")
    .replace(/\bcuill?\.?\s*à\s*c(afé)?\b/gi, "cuil. à café")
    .replace(/\bcàc\b/gi, "cuil. à café")
    .replace(/\bcac\b/gi, "cuil. à café");

  t = t.replace(/\bgr\b/gi, "g");
  t = t.replace(/\bgrammes?\b/gi, "g");

  t = t.replace(/\bmillilitres?\b/gi, "ml");
  t = t.replace(/\bcentilitres?\b/gi, "cl");
  t = t.replace(/\blitres?\b/gi, "l");

  t = t.replace(/\bloignon\b/gi, "l'oignon");
  t = t.replace(/\blail\b/gi, "l'ail");
  t = t.replace(/\blhuile\b/gi, "l'huile");

  t = t
    .replace(/^\s*page\s*\d+\s*\/\s*\d+\s*$/gim, "")
    .replace(/^\s*(www\.)\S+\s*$/gim, "")
    .replace(/^\s*©\s*\d{4}.*$/gim, "");

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

  t = t.replace(/(\p{L}+)-\n(\p{L}+)/gu, "$1$2");
  t = t.replace(/[•●▪◆◦]/g, "-");

  t = t.replace(/^\s*\d+\s*-\s*[A-Z\s&\-]+\s*$/gim, "");
  t = t.replace(/^\s*(Coût|Difficulté|Préparation|Cuisson)\s*.*$/gim, "");

  const lines = t.split("\n").map((l) => l.trimEnd());
  const kept = lines.filter((l) => l.trim().length > 0);
  t = kept.join("\n");

  return t.trim();
}

function calculateTotalTime(prepTime, cookTime) {
  if (!prepTime && !cookTime) return "";
  if (!cookTime) return prepTime;
  if (!prepTime) return cookTime;

  const parseTime = (timeStr) => {
    if (!timeStr) return 0;
    const hourMatch = timeStr.match(/(\d+)\s*h/i);
    const minMatch = timeStr.match(/(\d+)\s*min/i);
    const hours = hourMatch ? parseInt(hourMatch[1], 10) : 0;
    const mins = minMatch ? parseInt(minMatch[1], 10) : 0;
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
  const toInt = (v) => {
    if (v == null) return 0;
    if (typeof v === "number" && Number.isFinite(v)) return Math.round(v);
    const m = String(v).match(/(\d+)/);
    return m ? parseInt(m[1], 10) : 0;
  };

  const out = {
    title: String(obj?.title || "")
      .trim()
      .slice(0, 120)
      .toLowerCase()
      .replace(/\b\w/g, (c) => c.toUpperCase()),
    category: String(obj?.category || "")
      .trim()
      .toLowerCase(),
    servings: toInt(obj?.servings),
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

  if (out.servings < 0) out.servings = 0;
  if (out.servings > 50) out.servings = 50;

  const allowed = new Set(["entrée", "plat", "dessert", "boisson"]);
  out.category = out.category.normalize("NFD").replace(/[\u0300-\u036f]/g, "");

  if (out.category === "entree") out.category = "entrée";
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

function salvageFromRawText(recipe, rawText) {
  const r = { ...recipe };
  const txt = String(rawText || "");

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
    const stepLike = blocks
      .filter((b) => b.length > 25)
      .filter((b) => !/^(coût|difficulté|préparation|cuisson)$/i.test(b))
      .filter((b) => !/^\d+\s*-/.test(b))
      .filter((b) => !/^[A-Z\s&\-]{10,}$/.test(b)) // lignes en majuscules type chapitre
      .slice(0, 20);
    if (stepLike.length) r.steps = stepLike;
  }

  r.ingredients = (r.ingredients || []).map(autocorrectOcrFrench);
  r.steps = (r.steps || []).map(autocorrectOcrFrench);

  return r;
}

module.exports = {
  autocorrectOcrFrench,
  normalizeOcrText,
  calculateTotalTime,
  sanitizeRecipeJson,
  salvageFromRawText,
};
