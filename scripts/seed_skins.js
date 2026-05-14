const admin = require("firebase-admin");
const serviceAccount = require("../service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const skins = [
  // ─── COMMON ────────────────────────────────────────────────
  {
    id: "skin_classic_white",
    name: "Classic White",
    category: "app_theme",
    rarity: "common",
    price: 0,
    previewColor: "#FFFFFF",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: true,
  },
  {
    id: "skin_soft_pink",
    name: "Soft Pink",
    category: "card_design",
    rarity: "common",
    price: 50,
    previewColor: "#F48FB1",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },
  {
    id: "skin_mint_fresh",
    name: "Mint Fresh",
    category: "card_design",
    rarity: "common",
    price: 50,
    previewColor: "#A5D6A7",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },

  // ─── UNCOMMON ───────────────────────────────────────────────
  {
    id: "skin_neon_blue",
    name: "Neon Blue",
    category: "card_design",
    rarity: "uncommon",
    price: 250,
    previewColor: "#448AFF",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },
  {
    id: "skin_forest_green",
    name: "Forest Green",
    category: "app_theme",
    rarity: "uncommon",
    price: 250,
    previewColor: "#43A047",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },
  {
    id: "skin_sunset_orange",
    name: "Sunset Orange",
    category: "frame",
    rarity: "uncommon",
    price: 300,
    previewColor: "#FF7043",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },

  // ─── RARE ───────────────────────────────────────────────────
  {
    id: "skin_galaxy_dark",
    name: "Galaxy Dark",
    category: "app_theme",
    rarity: "rare",
    price: 500,
    previewColor: "#1A237E",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },
  {
    id: "skin_rose_gold",
    name: "Rose Gold",
    category: "card_design",
    rarity: "rare",
    price: 500,
    previewColor: "#E91E63",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },
  {
    id: "skin_ocean_wave",
    name: "Ocean Wave",
    category: "frame",
    rarity: "rare",
    price: 600,
    previewColor: "#0288D1",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },

  // ─── EPIC ───────────────────────────────────────────────────
  {
    id: "skin_cyberpunk",
    name: "Skin Cyberpunk",
    category: "app_theme",
    rarity: "epic",
    price: 1200,
    previewColor: "#7B1FA2",
    thumbnailUrl: null,
    isFeatured: true,
    featuredDeadline: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 jam dari sekarang
    isDefault: false,
  },
  {
    id: "skin_aurora",
    name: "Aurora Borealis",
    category: "app_theme",
    rarity: "epic",
    price: 1500,
    previewColor: "#00BCD4",
    thumbnailUrl: null,
    isFeatured: false,
    featuredDeadline: null,
    isDefault: false,
  },
];

async function seedSkins() {
  const batch = db.batch();

  skins.forEach((skin) => {
    const ref = db.collection("skins").doc(skin.id);
    batch.set(ref, {
      ...skin,
      featuredDeadline: skin.featuredDeadline
        ? admin.firestore.Timestamp.fromDate(skin.featuredDeadline)
        : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();
  console.log(`✅ ${skins.length} skins berhasil di-seed ke Firestore`);
  process.exit(0);
}

seedSkins().catch((err) => {
  console.error("❌ Seed failed:", err);
  process.exit(1);
});
