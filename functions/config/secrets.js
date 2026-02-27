const { defineSecret } = require("firebase-functions/params");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

module.exports = {
  GEMINI_API_KEY,
};