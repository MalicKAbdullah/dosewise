<div align="center">

# 💊 DoseWise

### Never miss a dose.

A calm, private medication tracker that keeps your health data where it belongs — on your device.

![License](https://img.shields.io/badge/License-MIT-0D9488?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-0D9488?style=flat-square)
![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-027DFD?style=flat-square&logo=flutter)
![Privacy](https://img.shields.io/badge/Data-Offline%20%26%20Encrypted-34D399?style=flat-square)
![Trackers](https://img.shields.io/badge/Trackers-0-34D399?style=flat-square)

</div>

> ### 🔒 Private by design
> DoseWise works **completely offline**. Your medications, schedules, and adherence history are **encrypted on your device and never leave it** — no account, no servers, no analytics, no tracking. Ever.

DoseWise helps you take the right medication at the right time, and shows you how you're doing over weeks and months — without ever asking you to trust a cloud with your health.

## ✨ Features

**Stay on schedule**
- Flexible schedules — fixed times on chosen weekdays, every-N-days, or as-needed
- A clean daily timeline with a "doses taken today" progress ring
- **Take or Skip a dose right from the notification** — no need to open the app
- Snooze a dose when life gets in the way

**Understand your adherence**
- Adherence rate over 7 and 30 days, plus your current streak
- A month **heatmap** and per-medication breakdowns
- Export a polished **doctor-visit PDF report** to share at appointments

**Made for real life**
- **Refill tracking** with low-supply warnings so you never run out
- **Family profiles** — manage medications for yourself and people you care for
- Optional reminders per medication

**Peace of mind**
- **Biometric app lock** (fingerprint / face) — prompts automatically every time the app locks, and never locks you out if the device has no biometrics set up (your data stays encrypted regardless)
- **Encrypted backup & restore** — a passphrase-protected file you control

## 🔒 Privacy & Security

Your health data is among the most sensitive there is, so DoseWise treats it that way:

- **Offline-only.** There is no network code in the app — nothing to leak.
- **Encrypted at rest.** All data is stored in a single file encrypted with **AES-256-GCM**; the key is generated on your device and held in the platform keystore (Android Keystore / iOS Keychain).
- **Your backups, your key.** Backups are encrypted with a separate passphrase only you know — a backup file alone reveals nothing.
- **No accounts, no telemetry, no ads.**

## 📸 Screenshots

| Today | Medication detail | Stats & heatmap | Backup |
| :---: | :---: | :---: | :---: |
| _coming soon_ | _coming soon_ | _coming soon_ | _coming soon_ |

## 🚀 Getting Started

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) and Android Studio / Xcode.

```sh
# 1. Clone
git clone https://github.com/MalicKAbdullah/dosewise.git
cd dosewise

# 2. Install dependencies (also fetches secure-suite-core)
flutter pub get

# 3. Run on a connected device or emulator
flutter run
```

**Build a release APK:**

```sh
flutter build apk --release
```

Run the checks the way CI does:

```sh
flutter analyze
flutter test
```

## 🧱 Built With

- **Flutter** & **Dart** — one codebase, Android & iOS
- **Riverpod** (state) · **go_router** (navigation) · **fl_chart** (analytics)
- [**secure-suite-core**](https://github.com/MalicKAbdullah/secure-suite-core) — shared encryption, storage & design system

## 📄 License

[MIT](LICENSE) © 2026 Abdullah Malik — part of the [Secure Suite](https://github.com/MalicKAbdullah/secure-suite-core).
