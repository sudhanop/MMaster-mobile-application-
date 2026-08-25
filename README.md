# MMaster - Personal Ledger & Dual-Account Expense Tracker 💰

<p align="center">
  <img src="assets/icon.png" width="120" height="120" alt="MMaster Logo" style="border-radius: 24px;" />
</p>

<p align="center">
  <b>A modern, high-performance, offline-first personal financial ledger built with Flutter and Hive.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Storage-Hive%20NoSQL-F39C12?logo=hive&logoColor=white" alt="Hive" />
  <img src="https://img.shields.io/badge/UI-Material%203-6200EE" alt="Material 3" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen" alt="Platform" />
  <img src="https://img.shields.io/badge/Tests-15%2F15%20Passing-success" alt="Tests" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" />
</p>

---

## 📖 Overview

**MMaster** is a secure, privacy-focused, multi-profile expense tracker and personal ledger application. It gives you complete visibility over your finances by separating physical **👛 Purse (Cash)** from **🏦 Bank** balances while maintaining an accurate global net worth.

All data is stored **100% locally on your device** using lightning-fast Hive NoSQL storage—no servers, no logins, and zero data tracking.

---

## ✨ Key Features

### 1. 👥 Multi-Profile Management
- Create and manage independent profiles (e.g., *Personal*, *Home*, *Business*, *Savings*).
- Individual running balance ledgers for each profile.
- Rename or delete profiles with automatic cascade deletion of linked transactions.

### 2. 👛 Purse (Cash) vs 🏦 Bank Breakdown
- **Dual-Account Allocation:** Assign any income or expense directly to your **Purse (Cash)** or **Bank**.
- **Real-Time Split:** View exactly how much cash you have on hand versus what is stored in your bank account.
- **Combined Net Worth:** Automatically aggregates overall balance across all profiles on the home dashboard.

### 3. ⇄ Quick Account Transfers
- Transfer money between **Bank ⇄ Purse** with one tap (e.g., ATM cash withdrawals or bank deposits).
- Creates linked double-entry transaction records without distorting overall net worth.

### 4. 🔍 Search & Advanced Filtering
- **Live Search:** Quickly locate any transaction by note or reason.
- **Filter Chips:** Instant one-tap filters for:
  - `All` records
  - `🏦 Bank` transactions
  - `👛 Purse` transactions
  - `📈 Income` records
  - `📉 Expense` records

### 5. 🛡️ Rock-Solid Offline Storage & Self-Healing
- Powered by **Hive NoSQL** key-value storage for near-instant read/writes.
- **Resilient Type Deserialization:** Gracefully handles integers, doubles, and ISO date conversions without crashing.
- **Startup Auto-Sync:** Automatically verifies and recalculates balances on launch to fix any legacy data inconsistencies.

### 6. 🎨 Modern Minimalist UI & Custom Icon
- Built on Material 3 with dark navy gradients and color-coded financial chips.
- Edge-to-edge adaptive high-resolution app icon.

---

## 📱 App Structure & Flow

```
MMaster/
├── 🏠 HomeScreen
│   ├── 📊 Global Net Worth Banner (Total Net Worth, Total Bank, Total Purse)
│   ├── 👥 Profile List (with live Bank/Purse balance chips)
│   └── ➕ Add/Edit/Delete Profile Modal
│
└── 📋 ProfileDetailScreen
    ├── 💳 Profile Total Balance Banner
    ├── 👛 Purse & 🏦 Bank Split Overview Cards
    ├── 🔍 Real-Time Transaction Search & Filter Chips
    ├── 📜 Transaction Ledger (Income/Expense badges, running balance)
    ├── ➕ Add Money Dialog (with Account Selector)
    ├── ➖ Spend Money Dialog (with Account Selector)
    └── ⇄ Bank <-> Purse Transfer Dialog
```

---

## 📂 Project Architecture

```
expense_tracker_mobile_app/
├── android/                   # Android native configuration & launcher icons
├── assets/                    # App icons and graphics
│   ├── icon.png               # High-res master logo
│   └── icon.jpg
├── lib/
│   ├── main.dart              # App initialization & startup balance repair
│   ├── models/
│   │   ├── profile.dart       # Profile Hive model & adapter (TypeId: 0)
│   │   └── ledger_tx.dart     # Transaction Hive model & adapter (TypeId: 1)
│   └── screens/
│       ├── home.dart          # Dashboard & profiles management screen
│       └── profile_detail.dart# Detailed transaction ledger & transfer screen
├── test/
│   ├── logic_test.dart        # Unit tests for balances, transfers, and CRUD
│   └── widget_test.dart       # Widget UI smoke tests
├── pubspec.yaml               # Dependencies & app metadata
└── README.md                  # Documentation
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 2.17.0`)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extension
- Android SDK (`minSdkVersion: 21`)

### 1. Clone & Install Dependencies
```bash
git clone <repository-url>
cd "expense tracker mobile app"
flutter pub get
```

### 2. Run the App
Connect your Android device or emulator, then run:
```bash
flutter run
```

### 3. Run Automated Tests
Execute the comprehensive test suite (15/15 passing unit and widget tests):
```bash
flutter test
```

---

## 📦 Building Production Release APK

To compile an optimized, standalone release APK:

```bash
flutter build apk --release
```

The compiled APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔒 Data & Privacy

- **100% Offline:** MMaster requires **zero** internet permissions.
- **No Analytics / Telemetry:** No user data or financial records leave your device.
- **Data Persistence:** Records are saved in the device's local app storage directory via binary Hive boxes (`profiles.hive` and `transactions.hive`).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
# MMaster-mobile-application-
