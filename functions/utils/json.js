function getModelText(result) {
  if (!result) return "";

  if (typeof result.text === "function") return result.text();
  if (typeof result.text === "string") return result.text;

  const cand = result.candidates?.[0];
  const parts = cand?.content?.parts || [];

  return parts
    .map((p) => (typeof p.text === "string" ? p.text : ""))
    .join("\n");
}

function safeJsonParse(s) {
  const raw = String(s || "").trim();
  try {
    return JSON.parse(raw);
  } catch {
    const m = raw.match(/\{[\s\S]*\}/);
    if (!m) throw new Error("Invalid JSON from model");
    return JSON.parse(m[0]);
  }
}

module.exports = {
  getModelText,
  safeJsonParse,
};