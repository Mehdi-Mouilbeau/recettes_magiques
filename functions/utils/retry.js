const logger = require("firebase-functions/logger");

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function withRetry(fn, maxAttempts = 5) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      const msg = String(err?.message || "");
      const is429 = /429|RESOURCE_EXHAUSTED|quota|rate/i.test(msg);

      if (!is429 || attempt === maxAttempts) throw err;

      const delay = Math.min(65000 * attempt, 180000);
      logger.warn(`⏳ Retry ${attempt}/${maxAttempts} dans ${delay / 1000}s`);
      await sleep(delay);
    }
  }
}

module.exports = { withRetry };