const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const logger = require("firebase-functions/logger");
const admin = require("../config/admin");

const { runImageGeneration } = require("../services/imageService");

exports.generateRecipeImageOnCreate = onDocumentCreated(
  {
    document: "recipes/{recipeId}",
    region: "europe-west1",
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const recipeId = event.params.recipeId;

    const locked = await admin.firestore().runTransaction(async (tx) => {
      const ref = snap.ref;
      const fresh = await tx.get(ref);
      const data = fresh.data() || {};

      if (data.imageUrl && !data.imageIsPlaceholder) return { ok: false };
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

    const freshSnap = await snap.ref.get();
    if (!freshSnap.exists) return;

    const data = freshSnap.data() || {};
    await runImageGeneration({ snap, recipeId, data });
  },
);

exports.generateRecipeImageOnQueued = onDocumentUpdated(
  {
    document: "recipes/{recipeId}",
    region: "europe-west1",
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

    const locked = await admin.firestore().runTransaction(async (tx) => {
      const ref = after.ref;
      const fresh = await tx.get(ref);
      const d = fresh.data() || {};

      if (d.imageUrl && !d.imageIsPlaceholder) return { ok: false };
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