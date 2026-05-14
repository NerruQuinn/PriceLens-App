<div align="center">

# 🔍 PriceLens ID

### *Belanja Cerdas, Hemat Lebih Banyak*

**PriceLens ID** is a community-powered price comparison app for Indonesian consumers.  
Scan products, compare prices across stores, and earn points by submitting real prices — all in one app.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/Gemini_AI-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-00BCD4?style=for-the-badge&logo=dart&logoColor=white)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 📱 Tentang Aplikasi

**PriceLens ID** hadir sebagai solusi bagi konsumen Indonesia yang ingin berbelanja lebih cerdas. Dengan memanfaatkan **kecerdasan buatan (AI)** dan **kekuatan komunitas**, pengguna dapat:

- 📷 **Scan produk** dengan kamera untuk langsung mendapatkan perbandingan harga
- 🏷️ **Scan barcode** untuk identifikasi produk secara instan
- 🛒 **Analisis keranjang belanja** sekaligus — foto semua produk, AI kenali semua
- 💰 **Submit harga real** yang ditemukan di toko dan dapatkan poin reward
- 🏆 **Naik badge** dari Bronze → Silver → Gold → Legend berdasarkan kontribusi
- 🎨 **Unlock skin** eksklusif untuk tampilan profil yang unik

---

## ✨ Fitur Unggulan

| Fitur | Deskripsi |
|-------|-----------|
| 🤖 **AI Price Analysis** | Gemini AI menganalisis foto produk dan memberikan estimasi harga dari berbagai toko |
| 📊 **Price Comparison** | Bandingkan harga online & offline dari Indomaret, Alfamart, Tokopedia, Shopee, dll |
| 📈 **Tren Harga** | Grafik tren harga 7 hari untuk keputusan beli yang lebih tepat |
| 🌍 **Community Submit** | Submit harga real dan bantu jutaan konsumen lainnya |
| ✅ **AI Validation** | Setiap submission divalidasi AI untuk memastikan akurasi data |
| 🎯 **Smart Advisor** | Rekomendasi kapan dan di mana sebaiknya membeli produk |
| 🛡️ **Legit Check** | Deteksi produk palsu atau harga yang mencurigakan |
| 🏅 **Gamification** | Sistem poin, badge, dan skin untuk mendorong kontribusi komunitas |
| 📦 **Basket Estimator** | Estimasi total belanjaan sebelum ke kasir |

---

## 🏗️ Arsitektur Proyek

```
pricelens_id/
├── lib/
│   ├── core/
│   │   ├── constants/          # App colors, strings, Gemini prompts
│   │   ├── theme/              # Material 3 theming & skin resolver
│   │   └── utils/              # Image helper, point calculator, price validator
│   │
│   ├── data/
│   │   ├── models/             # UserModel, ProductModel, SubmissionModel, dll
│   │   ├── repositories/       # Data layer abstraction
│   │   └── services/           # Firebase Auth, Firestore, Storage, Gemini AI
│   │
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── auth/           # Login screen (Google Sign-In)
│   │   │   ├── home/           # Home screen dengan promo & komunitas feed
│   │   │   ├── explore/        # Explore & trending products
│   │   │   ├── scan/           # Camera screen (foto produk, barcode, keranjang)
│   │   │   ├── result/         # Price result & comparison screen
│   │   │   ├── basket/         # Basket estimator screen
│   │   │   ├── submit/         # Submit harga real screen
│   │   │   ├── profile/        # User profile, badge, skin collection
│   │   │   └── shop/           # Skin shop
│   │   └── widgets/            # Reusable UI components
│   │
│   ├── providers/              # Riverpod state management
│   ├── firebase_options.dart
│   └── main.dart               # App entry + GoRouter config
│
├── functions/                  # Firebase Cloud Functions (Node.js)
│   └── index.js                # Submission rewards, status updates, cache sync
│
├── android/
├── ios/
└── pubspec.yaml
```

---

## 🛠️ Tech Stack

### Frontend
| Teknologi | Versi | Kegunaan |
|-----------|-------|---------|
| **Flutter** | 3.x | Cross-platform UI framework |
| **Dart** | 3.x | Programming language |
| **Riverpod** | ^2.x | State management |
| **GoRouter** | ^14.x | Declarative routing + ShellRoute |
| **Material 3** | - | Design system dengan dynamic colors |

### Backend & Cloud
| Teknologi | Kegunaan |
|-----------|---------|
| **Firebase Auth** | Google Sign-In authentication |
| **Cloud Firestore** | Real-time NoSQL database |
| **Firebase Storage** | Receipt & product photo storage |
| **Cloud Functions** | Serverless backend logic |
| **Gemini AI** | Product recognition & price validation |

### Key Packages
```yaml
dependencies:
  flutter_riverpod: ^2.x      # State management
  go_router: ^14.x            # Navigation
  firebase_core: ^3.x         # Firebase initialization
  cloud_firestore: ^5.x       # Database
  firebase_auth: ^5.x         # Authentication
  firebase_storage: ^12.x     # File storage
  google_sign_in: ^6.x        # Google OAuth
  camera: ^0.11.x             # Camera access
  google_mlkit_barcode_scanning: ^0.x  # Barcode scanner
  fl_chart: ^0.x              # Price trend charts
  cached_network_image: ^3.x  # Image caching
  shimmer: ^3.x               # Loading skeletons
  intl: ^0.x                  # Currency & date formatting
  image_picker: ^1.x          # Gallery access
```

---

## 🚀 Cara Menjalankan

### Prerequisites
- Flutter SDK `>= 3.0.0`
- Dart SDK `>= 3.0.0`
- Android Studio / VS Code
- Firebase project yang sudah dikonfigurasi
- Gemini API Key

### 1. Clone Repository
```bash
git clone https://github.com/NerruQuinn/PriceLens-App.git
cd PriceLens-App
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Konfigurasi Environment
Buat file `.env` di root project:
```env
GEMINI_API_KEY=your_gemini_api_key_here
```

### 4. Firebase Setup
Pastikan `google-services.json` (Android) dan `GoogleService-Info.plist` (iOS) sudah ada di folder yang benar. File `firebase_options.dart` sudah ter-generate via FlutterFire CLI.

### 5. Jalankan Aplikasi
```bash
flutter run
```

---

## 📸 Alur Aplikasi

```
Splash Screen
    │
    ▼
Login (Google Sign-In)
    │
    ▼
Home Screen ──── Drawer Menu ──── Profil Saya
    │                         ──── Submit Harga
    │                         ──── Toko Skin
    │                         ──── Keluar
    │
    ├──► Explore (Trending Products)
    │
    ├──► Scan Screen
    │         ├── Foto Produk ──► Price Result ──► Submit Harga
    │         ├── Scan Barcode ──► Price Result
    │         └── Foto Keranjang ──► Basket Estimator
    │
    ├──► Basket Estimator
    │
    └──► Profile Screen ──► Skin Shop
```

---

## 🎮 Sistem Gamifikasi

### Badge System
| Badge | Threshold | Warna |
|-------|-----------|-------|
| 🥉 Bronze | 0 - 99 poin | Cokelat |
| 🥈 Silver | 100 - 499 poin | Abu-abu |
| 🥇 Gold | 500 - 1999 poin | Emas |
| 👑 Legend | 2000+ poin | Ungu |

### Cara Dapat Poin
- ✅ Submit harga: **+10 poin**
- 📷 Submit dengan foto bukti: **+5 poin bonus**
- 👍 Submission di-upvote komunitas: **+1 poin/upvote**
- ✔️ Submission diverifikasi AI: **+5 poin bonus**

---

## 🔥 Firebase Cloud Functions

```
functions/
└── index.js
    ├── onSubmissionCreate    → Award poin ke user saat submit
    ├── onSubmissionUpdate    → Notifikasi status approved/rejected
    ├── onUpvote              → Award poin per upvote
    └── syncPriceCache        → Sinkronisasi cache harga terbaru
```

---

## 🤝 Kontribusi

Kontribusi sangat diterima! Silakan:

1. Fork repository ini
2. Buat branch fitur: `git checkout -b feature/nama-fitur`
3. Commit perubahan: `git commit -m 'feat: tambah fitur X'`
4. Push ke branch: `git push origin feature/nama-fitur`
5. Buat Pull Request

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah [MIT License](LICENSE).

---

<div align="center">

**Dibuat dengan ❤️ untuk konsumen Indonesia yang lebih cerdas**

*PriceLens ID — Transparansi harga untuk semua*

</div>
