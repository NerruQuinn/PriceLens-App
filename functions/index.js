const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ─── 1. onSubmissionCreated ───────────────────────────────────────
exports.onSubmissionCreated = functions
  .region("asia-southeast2")
  .firestore.document("community_submissions/{submissionId}")
  .onCreate(async (snap, context) => {
    const submission = snap.data();
    const { productId, userId } = submission;

    // Tambah poin +10 ke user
    const userRef = db.collection("users").doc(userId);
    await userRef.update({
      points: admin.firestore.FieldValue.increment(10),
      totalSubmissions: admin.firestore.FieldValue.increment(1),
    });

    // Cek apakah ini first submission untuk produk ini dari user
    const existing = await db
      .collection("community_submissions")
      .where("productId", "==", productId)
      .where("userId", "==", userId)
      .limit(2)
      .get();

    if (existing.size === 1) {
      // First submission produk ini → bonus +20
      await userRef.update({
        points: admin.firestore.FieldValue.increment(20),
      });
    }

    // Cek milestone setiap 10 submission
    const userSnap = await userRef.get();
    const total = userSnap.data().totalSubmissions;
    if (total % 10 === 0) {
      await userRef.update({
        points: admin.firestore.FieldValue.increment(20),
      });
    }

    // Update submissionCount di produk
    await db.collection("products").doc(productId).update({
      submissionCount: admin.firestore.FieldValue.increment(1),
    });
  });

// ─── 2. onSubmissionValidated ─────────────────────────────────────
exports.onSubmissionValidated = functions
  .region("asia-southeast2")
  .firestore.document("community_submissions/{submissionId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Hanya proses jika status berubah menjadi 'approved'
    if (before.status === after.status) return null;
    if (after.status !== "approved") return null;

    const { userId, productId, price, storeName } = after;

    // Bonus +5 poin approved
    await db.collection("users").doc(userId).update({
      points: admin.firestore.FieldValue.increment(5),
    });

    // Tambahkan ke price_history
    await db
      .collection("price_history")
      .doc(productId)
      .collection("entries")
      .add({
        price,
        storeName,
        submittedBy: userId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        source: "community",
      });

    // Update badge user berdasarkan total poin
    const userSnap = await db.collection("users").doc(userId).get();
    const points = userSnap.data().points;
    let badge = "bronze";
    if (points >= 2000) badge = "legend";
    else if (points >= 500) badge = "gold";
    else if (points >= 100) badge = "silver";

    await db.collection("users").doc(userId).update({ badge });

    return null;
  });

// ─── 3. onUpvoteAdded ────────────────────────────────────────────
exports.onUpvoteAdded = functions
  .region("asia-southeast2")
  .firestore.document("community_submissions/{submissionId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const beforeUpvotes = before.upvotes || 0;
    const afterUpvotes = after.upvotes || 0;

    // Hanya proses jika upvote bertambah
    if (afterUpvotes <= beforeUpvotes) return null;

    // Auto-approve jika upvote >= 5 dan belum approved
    if (afterUpvotes >= 5 && after.status === "pending") {
      await change.after.ref.update({ status: "approved" });
    }

    return null;
  });

// ─── 4. scheduledPromoCache ──────────────────────────────────────
exports.scheduledPromoCache = functions
  .region("asia-southeast2")
  .pubsub.schedule("every 6 hours")
  .timeZone("Asia/Jakarta")
  .onRun(async (context) => {
    // Ambil 20 produk dengan harga terendah terbaru
    const submissionsSnap = await db
      .collection("community_submissions")
      .where("status", "==", "approved")
      .orderBy("timestamp", "desc")
      .limit(100)
      .get();

    const promoMap = {};
    submissionsSnap.forEach((doc) => {
      const data = doc.data();
      const { productId, price, storeName } = data;
      if (!promoMap[productId] || price < promoMap[productId].price) {
        promoMap[productId] = { price, storeName };
      }
    });

    // Tulis ke promo_cache collection
    const batch = db.batch();
    Object.entries(promoMap).forEach(([productId, data]) => {
      const ref = db.collection("promo_cache").doc(productId);
      batch.set(ref, {
        ...data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    console.log(`Promo cache updated: ${Object.keys(promoMap).length} products`);
    return null;
  });
