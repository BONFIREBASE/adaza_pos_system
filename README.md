# ADAZA POS

A point-of-sale system for **Adaza School and Office Supplies Trading and Apparel**, built with Flutter (web-first, with mobile and Windows desktop in mind) and a Firebase/Firestore cloud backend.

It covers product & inventory management, sales recording, income/expense tracking, a live dashboard, role-based staff accounts with payroll, and branded PDF reports — wrapped in a flat, minimalist ADAZA-branded UI.

> Developed and maintained by **[BONFIRE BASE Studio](https://bonfire.base69.studio)** · support@base69.studio

---

## Table of contents
- [Features](#features)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
- [Roles & permissions](#roles--permissions)
- [Getting started](#getting-started)
- [Running the app](#running-the-app)
- [Firebase setup](#firebase-setup)
- [Security model](#security-model)
- [Project structure](#project-structure)
- [Fonts & branding](#fonts--branding)
- [Roadmap](#roadmap)

---

## Features

- **Authentication** — Firebase email/password sign-in with a branded landing splash. Roles and profile are resolved from Firestore and applied live.
- **Dashboard** — sales today/this week, profit, transactions, inventory value (with day-over-day trend), a 7-day sales bar chart, recent sales, and low-stock alerts. Skeleton loaders throughout.
- **Products** — searchable catalog with photos, price/cost (margin), stock, and low-stock threshold. Full CRUD via modals. Row gestures: **double-click to edit, swipe left to delete, swipe right to pin**.
- **Sales** — build a cart in a modal, confirm a sale; stock decrements and an income record is created **atomically** in one transaction. Insufficient-stock and empty-sale guards.
- **Income & expenses** — record entries, see totals and profit.
- **Lookup** — barcode lookup built for a connected scanner/receipt machine (keyboard-wedge) on desktop and the device camera on mobile. *(Currently under construction.)*
- **Management** — Owner/Admin manage staff accounts: create real Firebase accounts, set role, position, salary (with monthly payroll summary), enable/disable, and remove. Same swipe/double-click gestures.
- **Profile menu** — edit display name + photo, change password, generate reports, and (Owner) settings.
- **Reports** — branded **PDF** reports (Products, Sales, Income & Expense) that open a print preview to **print or save as PDF**.
- **Cloud sync** — all data persists to Firestore and is shared across devices, with offline persistence enabled.

---

## Tech stack

- **Flutter** (Material 3, restyled to a flat/minimal design language)
- **Riverpod** — state management & dependency injection
- **go_router** — routing with auth + permission guards
- **Firebase**: `firebase_auth`, `cloud_firestore`, `firebase_core`
- **mobile_scanner** — camera barcode scanning (mobile)
- **image_picker** — product & profile photos
- **pdf** + **printing** — branded report generation and printing
- **flutter_dotenv** — local/demo configuration
- **intl** — Peso (₱) currency & date formatting

---

## Architecture

Feature-first with clean layering. Each feature is split into:

- **domain** — models + repository contracts (no Flutter/Firebase imports)
- **data** — Firestore/in-memory implementations of the contracts
- **presentation** — screens, modals, and widgets

Two key abstractions keep the app extensible and testable:

- **`SyncService`** — cloud persistence contract. `FirestoreSyncService` is the production implementation; `InMemorySyncService` powers demo mode. Feature repositories depend on this, never on Firestore directly.
- **`ScanSource`** — barcode input contract, so a hardware scanner/IoT device can be added without changing callers.

State flows through Riverpod providers (`core/providers.dart`) as the composition root.

---

## Roles & permissions

| Capability            | Owner | Admin | Cashier |
|-----------------------|:-----:|:-----:|:-------:|
| Dashboard             |  ✅   |  ✅   |   ✅    |
| Record sales / lookup |  ✅   |  ✅   |   ✅    |
| Manage products       |  ✅   |  ✅   |   ❌    |
| Income & expenses     |  ✅   |  ✅   |   ❌    |
| Manage staff          |  ✅   |  ✅*  |   ❌    |
| Create accounts       |  ✅   |  ❌   |   ❌    |
| Settings              |  ✅   |  ❌   |   ❌    |

\* Admins can manage **Cashiers only** — never Owners or other Admins. Only the Owner can create accounts.

Permissions are enforced in three layers: UI gating, router redirects, and Firestore security rules.

---

## Getting started

### Prerequisites
- Flutter SDK (Dart >= 3.4)
- A modern browser (Chrome/Edge/Brave)
- For production: a Firebase project + the Firebase & FlutterFire CLIs

### Install
```bash
flutter pub get
```

---

## Running the app

### Demo mode (no Firebase needed)
Runs entirely in memory with seeded data; auth uses the password in `.env`.
```bash
flutter run -t lib/main_demo.dart -d web-server
```
Open the printed `localhost` URL. Sign in with the email/password from `.env`.

### Production mode (real Firebase)
```bash
flutter run -t lib/main.dart -d web-server
```

> Brave/other browsers: use `-d web-server` and open the printed URL. To auto-launch a Chromium browser with hot reload, set `CHROME_EXECUTABLE` to its path and use `-d chrome`.

---

## Firebase setup

The project is linked to a Firebase project and `lib/firebase_options.dart` is generated by FlutterFire. To set up from scratch:

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure          # generates lib/firebase_options.dart
```

In the Firebase console:
1. **Authentication → enable Email/Password.**
2. **Firestore → create database** (production mode).
3. Create the first **Owner**: add the Auth user, then create `users/{uid}` with fields `email`, `role: owner`, `active: true`.

Deploy security rules:
```bash
firebase deploy --only firestore:rules
```

Configuration lives in `.env` (git-ignored; see `.env.example`). These values are used by demo mode and to pre-fill the sign-in email — production credentials are managed by Firebase Auth.

---

## Security model

- **Authentication**: Firebase Auth (email/password).
- **Authorization**: enforced server-side in `firestore.rules`, not just the UI:
  - Business data (`products`, `sales`, `finance`) requires an account with an assigned role.
  - Products: read by any signed-in user; **create/edit/delete restricted to Owner/Admin**; a Cashier's sale may only decrement `stockQuantity`.
  - `users`: Owner manages everyone; Admin manages Cashiers only; any user may edit **only their own** name/photo. Disabled accounts are denied at sign-in.
- **Data namespacing**: shared top-level collections so Owner and staff operate on the same catalog and ledger.

Known hardening opportunities: lock finance/salary **reads** to Owner/Admin, and add an audit log.

---

## Project structure

```
lib/
├── main.dart                 # production entry (Firebase)
├── main_demo.dart            # demo entry (in-memory)
├── firebase_options.dart     # generated by FlutterFire
├── app.dart                  # MaterialApp.router + theme
├── core/
│   ├── config/               # env config
│   ├── providers.dart        # Riverpod composition root
│   ├── routing/              # go_router + auth/permission guards
│   ├── services/
│   │   ├── scan/             # ScanSource abstraction
│   │   └── sync/             # SyncService (Firestore + in-memory)
│   ├── theme/                # ADAZA colors, fonts, flat theme
│   └── widgets/              # nav dock, skeletons, snackbar, etc.
└── features/
    ├── auth/        {data, domain, presentation}
    ├── products/    {data, domain, presentation}
    ├── sales/       {data, domain, presentation}
    ├── finance/     {data, domain, presentation}
    ├── dashboard/   {presentation}
    ├── lookup/      {presentation}
    ├── management/  {data, domain, presentation}
    ├── profile/     {presentation}
    └── export/      # PDF report service + modal
```

---

## Fonts & branding

- **National Park** — ADAZA brand wordmark + headings
- **SF Pro** (Text + Display) — body and UI
- **Monospace** — prices, totals, barcodes (aligned digits)
- Palette: teal, copper/bronze, gold on a cream background
- Currency: Philippine Peso (₱), `en_PH` formatting

Brand assets live in `assets/images/` (logo, background); fonts in `assets/font/`.

---

## Roadmap

- Per-sale **receipt** PDF for checkout
- Functional **Settings** (tax, receipt header, low-stock defaults)
- Harden finance/salary read access by role
- Stock-adjustment quick action
- Hardware scanner / receipt-printer integration for the Lookup page
- Audit log of account & catalog changes

---

## License & usage restrictions

**Proprietary and confidential.** This repository is owned by Adaza School and
Office Supplies Trading and Apparel and developed by BONFIRE BASE Studio.

You may **not** clone, fork, copy, mirror, redistribute, sublicense, or reuse
this code or any part of it — in whole or in part — **without prior written
permission**. No license is granted by the availability of this repository.

To request permission, contact BONFIRE BASE Studio at support@base69.studio.

See [LICENSE](LICENSE) for the full terms.

---

## Developer & contact

Developed and maintained by **BONFIRE BASE Studio** for the client, Adaza
School and Office Supplies Trading and Apparel. The software and its data are
owned by the client; BONFIRE BASE Studio provides development and ongoing
maintenance and support.

- Website: https://bonfire.base69.studio
- Email: bonfire@base69.studio
- Support: support@base69.studio

For support, feature requests, or maintenance, contact BONFIRE BASE Studio at
the addresses above.

