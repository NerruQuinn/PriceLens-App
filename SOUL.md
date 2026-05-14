# SOUL.md — PriceLens ID

## Identitas Project
- **Nama:** PriceLens ID
- **Tagline:** Belanja Lebih Cerdas
- **Kontes:** JuaraVibeCoding by Google 2026
- **Dev:** Solo developer (Joshua)
- **Platform:** Flutter (Android focus)

## Tech Stack
| Layer | Tech |
|---|---|
| Frontend | Flutter + Material Design 3 |
| AI | Gemini 1.5 Flash (google_generative_ai) |
| Database | Firebase Firestore |
| Auth | Firebase Auth + Google Sign-In |
| Storage | Firebase Storage |
| Functions | Cloud Functions Node.js |
| State | Riverpod |
| Navigation | GoRouter |
| Charts | fl_chart |
| Env | flutter_dotenv (.env) |

- Firebase Project: `comparison-price-app`
- Seed Color: `#4285F4`
- Firestore Region: `asia-southeast2` (Jakarta)
- Flutter path: `C:\Users\User\Documents\1ST APPS\Price Comparison Apps\pricelens_id`

## Folder Structure
```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── constants/        # app_colors, app_strings, gemini_prompts
│   ├── theme/            # app_theme, skin_theme_resolver
│   └── utils/            # price_validator, point_calculator, image_helper
├── data/
│   ├── models/           # product, price_entry, submission, basket, user, skin
│   ├── repositories/     # product, price, submission, user, basket
│   └── services/         # gemini, firestore, auth, storage, cache
├── presentation/
│   ├── screens/
│   │   ├── splash/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── scan/
│   │   ├── result/
│   │   ├── basket/
│   │   ├── submit/
│   │   ├── profile/
│   │   ├── shop/
│   │   └── explore/
│   └── widgets/
└── providers/
functions/
├── index.js
.env                      # JANGAN commit ke Git
firestore.rules
SOUL.md
```

## Routes (GoRouter)
| Path | Screen |
|---|---|
| `/splash` | SplashScreen |
| `/login` | LoginScreen |
| `/home` | HomeScreen |
| `/scan` | CameraScreen |
| `/result/:productId` | PriceResultScreen(productId) |
| `/basket` | BasketEstimatorScreen |
| `/submit?productId=` | PriceSubmissionScreen(productId?) |
| `/profile` | ProfileScreen |
| `/shop` | SkinShopScreen |
| `/explore` | ExploreScreen |

## Firestore Collections
```
users/{userId}
products/{productId}
price_history/{productId}/entries/{entryId}
community_submissions/{submissionId}
baskets/{basketId}
skins/{skinId}
promo_cache/{productId}
```

## Point & Badge System
| Aksi | Poin |
|---|---|
| Submit harga | +10 |
| Upload foto struk | +5 bonus |
| Submission approved | +5 bonus |
| First submission produk baru | +20 |
| Daily check-in | +2 |
| Setiap 10 submission | +20 bonus |

| Badge | Poin |
|---|---|
| Bronze | 0–99 |
| Silver | 100–499 |
| Gold | 500–1999 |
| Legend | 2000+ |

## Skin System
- Kategori: `card_design` | `app_theme` | `frame`
- Rarity: `common` | `uncommon` | `rare` | `epic`
- Dibeli dengan poin
- Disimpan di Firestore collection `skins`

## Gemini Prompts
Semua di `lib/core/constants/gemini_prompts.dart`:
- `systemInstructionSingleProduct` — analisis foto/barcode → JSON harga
- `systemInstructionBasket` — analisis foto keranjang → JSON items + total
- `systemInstructionValidator` — validasi harga submission komunitas

## Cloud Functions (asia-southeast2)
| Function | Trigger |
|---|---|
| `onSubmissionCreated` | Firestore onCreate community_submissions |
| `onSubmissionValidated` | Firestore onUpdate → status == 'approved' |
| `onUpvoteAdded` | Firestore onUpdate → upvotes bertambah |
| `scheduledPromoCache` | Pub/Sub setiap 6 jam |

## Konvensi Koding
- Gunakan `ref.watch` untuk data, `ref.read` untuk aksi
- Semua text UI dalam Bahasa Indonesia
- Loading state: shimmer (Container abu animated)
- Empty state: ikon + teks deskriptif
- Error state: teks error + tombol retry
- Prompt ke AI selalu diakhiri: "Jika sudah selesai tidak perlu menjelaskan, cukup bilang Done"

## Status Komponen
| Komponen | Status |
|---|---|
| pubspec.yaml + dependencies | ✅ Done |
| Firebase setup | ✅ Done |
| main.dart + GoRouter | ✅ Done |
| app_theme.dart | ✅ Done |
| Data Models (6) | ✅ Done |
| GeminiService | ✅ Done |
| AuthService | ✅ Done |
| FirestoreService | ✅ Done |
| StorageService | ✅ Done |
| Riverpod Providers | ✅ Done |
| SplashScreen | ✅ Done |
| LoginScreen | ✅ Done |
| HomeScreen | ✅ Done |
| CameraScreen | ✅ Done |
| PriceResultScreen | ✅ Done |
| BasketEstimatorScreen | ✅ Done |
| PriceSubmissionScreen | ✅ Done |
| ProfileScreen | ✅ Done |
| SkinShopScreen | ✅ Done |
| ExploreScreen | ✅ Done |
| GoRouter complete | ✅ Done |
| Gemini API Key (.env) | ✅ Done |
| Cloud Functions (4) | ✅ Done |
| Firestore Security Rules | ✅ Done |
| Seed data skins | ✅ Done |
| End-to-end testing | ⬜ Belum |

## Catatan Penting
- Gemini API key via `.env` → `dotenv.env['GEMINI_API_KEY']`
- `.env` wajib ada di `.gitignore`
- UI design referensi: Google Stitch (10 screens)
- Budget: Google Cloud credit JuaraVibeCoding (180 hari)
- Gemini via `google_generative_ai` package, bukan Vertex AI
- AI tool: Antigravity (Docker + MCP 7 context)
