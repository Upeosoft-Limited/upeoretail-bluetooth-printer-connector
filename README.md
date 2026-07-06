# UpeoRetail Print — Bluetooth Thermal Printer Connector for Web Apps (Android) 🖨️

> A lightweight **Android WebView wrapper** that adds **native Bluetooth Classic (SPP)
> ESC/POS thermal printing** to any web app — **no RawBT, no third-party print app, no
> watermark**. Print crisp **58mm / 80mm** receipts (e.g. the **P58E**) straight from
> your existing Next.js / web POS via a simple JavaScript bridge.

![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B?logo=flutter&logoColor=white)
![Printing](https://img.shields.io/badge/printing-ESC%2FPOS%2058%2F80mm-blueviolet)
![Bluetooth](https://img.shields.io/badge/Bluetooth-Classic%20SPP-0082FC?logo=bluetooth&logoColor=white)
![No RawBT](https://img.shields.io/badge/no%20RawBT-no%20watermark-success)

**Keywords:** bluetooth thermal printer android · ESC/POS printer app · 58mm 80mm
receipt printer · flutter webview printer bridge · P58E printer · web app to bluetooth
printer · POS receipt printing · print from website android · no RawBT · thermal
printer connector · javascript to bluetooth printer.

---

## What is UpeoRetail Print?

**UpeoRetail Print is an open-source Android app that turns a web-based POS into a
native receipt-printing app.** It loads your website in a full-screen WebView and
exposes a secure JavaScript bridge (`UpeoRetailPrinter`) that your web app calls with
receipt JSON. The app renders that JSON to **ESC/POS bytes** and sends them to a paired
**Bluetooth Classic (SPP) thermal printer** — the same protocol used by the **P58E** and
most 58mm/80mm receipt printers.

It exists to remove a painful gap: **browsers can't talk to Bluetooth Classic thermal
printers.** The usual workarounds — RawBT (adds a watermark), cloud print services, or
rewriting your POS as a native app — are all heavier than the problem. UpeoRetail Print
is a **thin, single-purpose wrapper**: keep your web POS exactly as it is, and gain
one-tap thermal printing.

> Built for the **[UpeoRetail](https://upeoretail.com)** platform, but works with **any
> web app** — point it at your URL and call the bridge.

---

## Table of contents

- [Why UpeoRetail Print?](#why-upeoretail-print)
- [Features](#features)
- [How it works](#how-it-works)
- [Project layout](#project-layout)
- [Quick start (build the APK)](#quick-start-build-the-apk)
- [Point it at your web app](#point-it-at-your-web-app)
- [Pair your Bluetooth printer (P58E & similar)](#pair-your-bluetooth-printer-p58e--similar)
- [Select the default printer](#select-the-default-printer)
- [Calling the print bridge from JavaScript](#calling-the-print-bridge-from-javascript)
- [What gets printed](#what-gets-printed)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Tech stack](#tech-stack)
- [Contributing](#contributing)
- [License](#license)

---

## Why UpeoRetail Print?

| Approach | Watermark | Extra app | Keeps your web POS | Native speed |
|---|---|---|---|---|
| **UpeoRetail Print** | ❌ none | ❌ none | ✅ yes | ✅ direct SPP |
| RawBT | ⚠️ yes (free tier) | ✅ required | ✅ yes | ⚠️ via intent |
| Cloud print service | ❌ | ✅ | ✅ | ❌ needs internet |
| Rewrite POS as native app | ❌ | — | ❌ full rewrite | ✅ |

**Ideal for:** retail POS, restaurants, pharmacies, and any web/Next.js app that needs
to print receipts on cheap Bluetooth thermal printers **without** re-architecting.

---

## Features

- 🌐 **WebView host** for your existing web app — loading indicator, offline/error
  screen with retry, pull-to-refresh, persistent login (cookies/storage survive
  restarts).
- 🔌 **Secure JS bridge** (`UpeoRetailPrinter`) — the web app posts receipt JSON; the
  app validates and prints. The bridge **only** accepts messages while the WebView is
  on an **allowed host**.
- 🖨️ **Bluetooth Classic (SPP) ESC/POS printing** — works with **P58E** and most
  58/80mm printers. No BLE-only limitations, no RawBT, no external print app.
- 📏 **58mm & 80mm** paper support, switchable at runtime.
- 🧾 **Rich receipt layout** — business header, itemized lines with wrapping, totals,
  VAT, payment info, **QR code**, and paper cut.
- ⚙️ **Printer settings screen** — pick a paired printer, choose paper width, see live
  connection status, run a **test print**. Default printer + paper + URL saved locally.
- 🔁 **Auto-reconnect** before each print if the connection dropped.
- 🔒 **Paired-devices only** — no location-based scanning needed on Android 12+.

---

## How it works

```
┌──────────────────────── Android device ────────────────────────┐
│                                                                 │
│  WebView (webview_flutter) ── loads your web POS (HTTPS)        │
│      │                                                          │
│      │  window.UpeoRetailPrinter.postMessage(receiptJSON)      │
│      ▼                                                          │
│  JS Bridge  ── validates type=PRINT_RECEIPT + allowed host     │
│      │                                                          │
│      ▼                                                          │
│  Receipt model ─► ESC/POS builder (esc_pos_utils_plus, 58/80mm)│
│      │                                                          │
│      ▼                                                          │
│  PrinterService (print_bluetooth_thermal) ──SPP──► 🖨️ Printer  │
│                                                                 │
│  SettingsStore (shared_preferences): default printer, mm, URL  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project layout

```
lib/
├── main.dart                       # entry point
├── config.dart                     # default URL, bridge channel name, allowed hosts
├── models/receipt.dart             # receipt parsing + validation
├── services/
│   ├── settings_store.dart         # SharedPreferences (printer, paper size, URL)
│   ├── escpos_builder.dart         # ESC/POS byte generator (58/80mm, QR, cut)
│   └── printer_service.dart        # Bluetooth Classic connect/print + typed errors
├── screens/
│   ├── webview_screen.dart         # main screen + JS bridge
│   └── printer_settings_screen.dart
└── widgets/error_view.dart         # offline/error screen
android/app/src/main/AndroidManifest.xml   # Bluetooth permissions
integration/printReceipt.js         # helper to drop into your web app
```

---

## Quick start (build the APK)

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.3+**
- Android Studio / Android SDK
- A paired Bluetooth thermal printer (P58E or similar 58/80mm ESC/POS)

### Build & install

```bash
git clone git@github.com:Upeosoft-Limited/upeoretail-bluetooth-printer-connector.git
cd upeoretail-bluetooth-printer-connector

# Generate the Android platform scaffold (icons, Gradle wrapper) WITHOUT
# overwriting lib/, pubspec.yaml, or the provided AndroidManifest.xml:
flutter create --org com.upeoretail --project-name upeoretail_print --platforms=android .

flutter pub get

# Debug run on a connected phone:
flutter run

# Release APK → build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release
flutter install    # or: adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> If `flutter create` offers to overwrite `pubspec.yaml` or `AndroidManifest.xml`,
> **keep the versions in this repo** — they carry the dependencies and Bluetooth
> permissions.

---

## Point it at your web app

- Default URL lives in `lib/config.dart → defaultUrl` (ships as
  `https://upeoretail.com`). Edit it to your domain, **or** change it at runtime in
  **Printer settings → set URL → Save URL**.
- **Security:** the print bridge only accepts messages when the WebView is on an
  **allowed host**. Edit `allowedHosts` in `lib/config.dart` to match your domain
  (subdomains are allowed automatically).

---

## Pair your Bluetooth printer (P58E & similar)

1. Power on the printer and load paper.
2. Android **Settings → Bluetooth** → scan → pair the printer (often shows as `P58E`,
   `Printer001`, `BlueTooth Printer`…). PIN is usually `0000` or `1234`.
3. In **UpeoRetail Print** → printer button → **Printer settings** → pull to refresh →
   your printer appears under **Paired Bluetooth printers**.

> The app lists **paired** devices only, so it never needs location scanning on
> Android 12+.

---

## Select the default printer

In **Printer settings**:

- Tap your printer → it's saved as default (name + MAC) and connects immediately.
  **Connection: Connected** confirms it.
- Choose **58 mm** (default) or **80 mm** to match your paper.
- Tap **Test print** to verify.

The choice persists (SharedPreferences). Before every print the app auto-reconnects to
this printer if the connection dropped.

---

## Calling the print bridge from JavaScript

Copy [`integration/printReceipt.js`](integration/printReceipt.js) into your web app and
call it:

```js
import { printReceipt } from "@/lib/printReceipt";

printReceipt({
  businessName: "UPEO RETAIL DEMO",
  receiptTitle: "TAX INVOICE",
  branch: "Thika Superhighway",
  city: "NAIROBI",
  phone: "0116888777",
  email: "sales@upeoretail.com",
  pin: "P051234567X",
  invoiceNo: "ACC-SINV-2026-00041",
  customer: "Walk-in Customer",
  date: "23/06/2026 19:12",
  items: [
    { name: "AMP Small Black Watch", qty: 1, tax: 799.86, price: 5199.0, total: 5199.0 },
  ],
  subtotal: 9654.31,
  discount: 0,
  vat: 1544.69,
  total: 11199.0,
  paid: 11199.0,
  change: 0,
  paymentMethod: "Cash",
  footer: "Goods exchangeable within 14 days upon proof of receipt.",
  qrData: "ACC-SINV-2026-00041",
});
```

Or call the channel directly (the app also injects `window.printReceipt` for you):

```js
window.UpeoRetailPrinter.postMessage(JSON.stringify({
  type: "PRINT_RECEIPT",
  payload: { /* ...receipt... */ }
}));
```

The bridge **ignores** anything that isn't `type: "PRINT_RECEIPT"`, isn't valid JSON,
or is sent while the WebView is not on an allowed host.

---

## What gets printed

Centered business name (large/bold) · receipt title · branch/city/phone/email · PIN ·
invoice no · customer · date · separators · each item (name wraps, then `qty x price` …
line total) · subtotal · discount · VAT · **grand total (large/bold)** · payment method
· paid · change · **QR code** (if `qrData`) · footer · paper feed + cut.

Tune the layout in [`lib/services/escpos_builder.dart`](lib/services/escpos_builder.dart).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| **"No default printer selected"** | Open Printer settings and pick a printer. |
| **Printer not in the list** | Pair it in Android Bluetooth settings first, then pull-to-refresh. |
| **"Bluetooth is turned off"** | Turn Bluetooth on and retry. |
| **"Bluetooth permission denied"** | Android 12+: allow **Nearby devices** in App info → Permissions. |
| **Connect/print times out** | Wake the printer, keep it within ~5 m, re-select it to force a fresh connect. SPP is single-session — disconnect other phones. |
| **Garbled / tiny text** | Wrong paper width — switch 58 ↔ 80 mm in settings. |
| **No QR prints** | Some clones lack QR support; the rest of the receipt still prints. |
| **Page won't load** | Offline screen shows **Try again**; check the URL in settings and the network. |
| **Login keeps dropping** | Ensure the device clock is correct and the site uses HTTPS; cookies persist by default. |

---

## FAQ

**Can a website print directly to a Bluetooth thermal printer?**
Not by itself — browsers can't reach Bluetooth Classic (SPP) printers. UpeoRetail Print
bridges that gap: your web app posts receipt JSON to a native app that talks SPP.

**Does it work with the P58E printer?**
Yes. It targets Bluetooth Classic (SPP) ESC/POS, which is what the P58E and most 58/80mm
receipt printers use.

**Do I need RawBT?**
No. UpeoRetail Print prints directly — **no RawBT, no watermark, no third-party print
app**.

**Does it change my existing web POS?**
No. Keep your web app as-is; add one small JS helper to call the print bridge.

**58mm or 80mm — which is supported?**
Both, switchable at runtime in Printer settings.

**Does it need internet to print?**
No — printing is local over Bluetooth. Internet is only needed to load your web app.

**Is iOS supported?**
No. Bluetooth Classic SPP isn't available on iOS; this app is Android-first.

**Can I use it with a non-UpeoRetail website?**
Yes. Set your URL and allowed hosts in `lib/config.dart` and call the bridge from your
own front end.

---

## Tech stack

**Flutter (Dart)** · `webview_flutter` (WebView host) · `print_bluetooth_thermal`
(Bluetooth Classic SPP) · `esc_pos_utils_plus` (ESC/POS byte generation) ·
`permission_handler` (Android 10–14+) · `shared_preferences` (local settings).

> Android-first, null-safe. `usesCleartextTraffic` is enabled so you can point at a
> LAN/`http://` test server — **use HTTPS in production**.

---

## Contributing

Issues and pull requests welcome. If UpeoRetail Print saves you from RawBT watermarks,
**please ⭐ star the repo** so other merchants can find it.

## License

Copyright © Upeo Soft Limited. See [`LICENSE`](LICENSE) if present, or contact
[Upeosoft-Limited](https://github.com/Upeosoft-Limited) for licensing terms.

---

<sub>**Topics:** bluetooth-thermal-printer · esc-pos · escpos · 58mm · 80mm ·
receipt-printer · thermal-printer · flutter · android · webview · pos ·
point-of-sale · p58e · bluetooth-classic · spp · print-from-web · no-rawbt · upeoretail
· kenya. Built by [Upeosoft Limited](https://upeosoft.com) for the [UpeoRetail](https://upeoretail.com) platform.</sub>
