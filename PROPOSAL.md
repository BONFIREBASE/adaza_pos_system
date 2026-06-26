# ADAZA POS — Project Proposal & Scope of Work

**Prepared by:** BONFIRE BASE Studio
**Prepared for:** Adaza School and Office Supplies Trading and Apparel ("the Client")
**Document type:** Development & Maintenance Proposal
**Date:** June 2026
**Status:** For client review

---

## 1. Overview

BONFIRE BASE Studio proposes the design, development, deployment, and ongoing
maintenance of **ADAZA POS** — a cloud-based point-of-sale and business
management system for Adaza School and Office Supplies Trading and Apparel.

The system is delivered as a single codebase that runs on **web, mobile
(Android/iOS), and Windows desktop**, backed by a managed cloud database with
live, multi-device synchronization.

The software and its data are **owned by the Client**. BONFIRE BASE Studio acts
as the **developer and maintenance provider**.

---

## 2. Scope of work — what is delivered

The following is delivered and live in production at **https://adazacloud.web.app**.

### 2.1 Core platform
- Cross-platform Flutter application (web-first; mobile and Windows-ready from one codebase)
- Firebase / Firestore cloud backend with **real-time sync** across all accounts and devices
- Offline persistence (the app keeps working with intermittent connectivity)
- Branded loading splash, favicon, and clean URLs

### 2.2 Authentication & accounts
- Secure email/password sign-in (Firebase Authentication)
- Branded landing page
- **Forced password change on first login** for new staff accounts
- Self-service profile (display name + photo) and password change

### 2.3 Roles & permissions
- **Custom, owner-defined roles** — the Owner can create any role (e.g. Cashier, Stockkeeper) and assign exactly which features each role can access
- Reserved, protected **Owner** role with full access
- Permissions enforced in **three layers**: UI gating, route guards, and server-side database security rules

### 2.4 Products & inventory
- Searchable product catalog with photos, price, cost (margin), stock, and low-stock threshold
- Full create / edit / delete via modals
- Row gestures: double-click to edit, swipe to delete, swipe to pin
- **Auto-generated barcodes** for new products; barcode locked when editing so price changes don't alter it
- Stock status badges (in stock / low / out of stock)

### 2.5 Sales
- Cart-based sale entry in a modal
- Stock decrement and income recording happen **atomically** in a single transaction (cannot be manipulated or double-counted)
- Insufficient-stock and empty-sale guards
- **Void sale** (restocks items and reverses income safely)
- **Per-sale printable receipt** (80mm thermal format)

### 2.6 Income & expenses (finance)
- Record income and expense entries; totals and profit
- Manager-level edit/delete; sale-derived income is locked to protect integrity

### 2.7 Barcode label designer
- Drag-and-drop barcode placement onto a real paper canvas
- Multiple paper sizes (A4, Letter, Long, Legal, A5), portrait/landscape, zoom and pan
- Layout persists across navigation; exports a print-ready PDF

### 2.8 Dashboard
- KPI cards (sales today/week, profit, transactions, inventory value with day-over-day trend)
- 7-day sales chart, recent sales, low-stock alerts
- **Live ticking clock** and greeting
- Skeleton loaders throughout (no blank spinners)

### 2.9 Management & payroll
- Owner/Admin manage staff: create real accounts, set role, position, salary, and photo
- Monthly **payroll summary**
- Enable/disable and remove accounts

### 2.10 Reports
- Branded **PDF reports**: Products, Sales, Income & Expense
- Print preview to print or save as PDF

### 2.11 Branding & UX
- Custom ADAZA palette (teal/copper/gold on cream), flat/minimalist design
- Three bundled font families (National Park, SF Pro, Monospace)
- Philippine Peso (₱) currency formatting throughout
- Consistent minimalist notification system

---

## 3. Technology

| Layer | Technology |
|---|---|
| App framework | Flutter (web, mobile, Windows from one codebase) |
| State management | Riverpod |
| Routing | go_router with auth + permission guards |
| Backend | Firebase Authentication + Cloud Firestore |
| Reports / labels | `pdf` + `printing` + `barcode_widget` |
| Hosting | Firebase Hosting (web) |

Architecture: feature-first with clean layering (domain / data / presentation)
and swappable abstractions for cloud sync and barcode input, keeping the system
extensible and testable.

---

## 4. Pricing

> All figures are in Philippine Peso (₱). Final amounts to be confirmed in a
> signed agreement. International/USD pricing available on request.

### 4.1 One-time build (delivered system)
Covers full design, development, multi-platform delivery, Firebase setup,
production deployment, and handover of the system described in Section 2.

| Tier | Range | Notes |
|---|---|---|
| Build (as delivered) | **₱80,000 – ₱200,000** | Reflects scope: cross-platform app, custom roles, inventory, sales, finance, payroll, label designer, reports, live sync |

### 4.2 Ongoing maintenance (monthly retainer)
Keeps the system healthy, secure, and up to date after launch.

| Tier | Range | Includes |
|---|---|---|
| Maintenance retainer | **₱5,000 – ₱10,000 / month** | Bug fixes, security/dependency updates, minor adjustments, deployment, priority support |

### 4.3 Running / infrastructure costs
| Item | Cost | Notes |
|---|---|---|
| Firebase (Auth, Firestore, Hosting) | **~₱0 / month** at current scale | Runs comfortably on the free (Spark) tier; images stored efficiently in the database |
| Domain (optional) | Variable | If a custom domain is desired instead of `adazacloud.web.app` |

If usage grows substantially (much larger catalog, high traffic, or file
storage needs), a paid Firebase plan may later be advisable. The system is
currently designed to **avoid** that and stay free to run.

---

## 5. What maintenance includes

- Bug fixes and stability improvements
- Security patches and dependency/framework updates
- Minor feature tweaks and UI adjustments
- Re-deployment of updates to production
- Priority support via email
- Guidance and remote assistance for the Client's staff

> Major new features or new modules outside the current scope are quoted
> separately as enhancements.

---

## 6. Ownership & handover

- The **Client owns** the software and all business data.
- **BONFIRE BASE Studio** is the developer and maintenance provider.
- Source code is held in a private repository; access is for authorized
  collaborators only (see `LICENSE`).
- On request and subject to the agreement, project assets and credentials can
  be handed over to the Client.

---

## 7. Current status

- ✅ Live in production at **https://adazacloud.web.app**
- ✅ Owner account provisioned (Client advised to set a permanent password)
- ✅ Web build deployed; mobile and Windows builds available from the same codebase
- ✅ Firestore security rules deployed and enforced

---

## 8. Contact

**BONFIRE BASE Studio** — Development & Maintenance

- Website: https://bonfire.base69.studio
- Email: bonfire@base69.studio
- Support: support@base69.studio

---

*This proposal is confidential and prepared exclusively for Adaza School and
Office Supplies Trading and Apparel. Pricing ranges are estimates for planning
purposes and are finalized in a signed agreement.*
