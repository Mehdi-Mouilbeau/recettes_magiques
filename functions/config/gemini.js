const { GEMINI_API_KEY } = require("./secrets");
const { GoogleGenAI } = require("@google/genai");

let geminiTextInstance = null;


async function getGeminiText() {
  if (!geminiTextInstance) {
    const apiKey = await GEMINI_API_KEY.value(); 
    if (!apiKey) throw new Error("GEMINI_API_KEY not set");
    geminiTextInstance = new GoogleGenAI({ apiKey });
  }
  return geminiTextInstance;
}

function getGeminiImage() {
  return new GoogleGenAI({
    vertexai: true,
    project: process.env.GCLOUD_PROJECT,
    location: "us-central1",
  });
}

module.exports = {
  getGeminiText,
  getGeminiImage,
};