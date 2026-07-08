# DoseWise

A privacy-first, offline-only medication schedule and adherence tracker.
Part of the `secure_suite` monorepo. **v1.2.0**

DoseWise keeps every byte on the device: no network calls, no analytics,
no accounts. All data is AES-256-GCM encrypted at rest with a random key
held in the platform keychain — and now it can be backed up as an
encrypted, passphrase-protected file you control.

## Screenshots

| Today | Medication detail | Stats & heatmap | Dark mode |
| --- | --- | --- | --- |
| _screenshot placeholder_ | _screenshot placeholder_ | _screenshot placeholder_ | _screenshot placeholder_ |

## Features

- **Multiple profiles** *(new in 1.2)* — track medications for the whole
  family from one phone. A compact avatar chip on Today opens the
  profile switcher: switch, add, rename, or delete (with typed
  confirmation — deleting cascades that person's medications and
  history). Every screen (Today, Medications, Stats, Log, reports)
  scopes to the person you're viewing, while reminders keep firing for
  **everyone's** doses; with more than one profile, notifications say
  whose dose it is ("Amma — Metformin 500 mg"). Existing data migrates
  automatically into a "Me" profile on first launch.
- **Encrypted backup & restore** *(new in 1.2)* — Settings → Backup
  exports a `.dwbackup` file: your full data encrypted with AES-256-GCM
  under an Argon2id key derived from a backup passphrase you choose
  (independent of the device key). Restore via file picker → passphrase
  → preview (medication + log counts) → **Merge** (by id, the newer
  version of anything wins) or **Replace**. Backups from pre-profile
  versions import and migrate cleanly.
- **Take/Skip from the notification** *(new in 1.2)* — dose reminders
  carry action buttons. Tapping **Take** or **Skip** records the dose
  (and updates tracked stock) in a background isolate without opening
  the app; the app picks the change up next time it resumes.
- **Doctor-visit PDF report** *(new in 1.2)* — from Stats, export a
  clean A4 PDF for the last 30 or 90 days: patient (profile) name,
  overall adherence, a per-medication table (dosage, schedule,
  adherence, taken/skipped/missed), a daily adherence trend, and a full
  dose log appendix. Rendered off the UI thread with the bundled Inter
  typeface and shared via the system share sheet.
- **Onboarding** *(new in 1.2)* — a three-page, skippable intro shown
  once (never miss a dose / private by design / act right from the
  notification), ending in a guided "Add your first medication" CTA.
- **Medications** — name, dosage text, form (tablet/capsule/liquid/
  injection/topical/other), color tag, notes, and an active date range
  (start date, optional end date).
- **Flexible schedules** — fixed times of day on selected weekdays,
  every-N-days at fixed times (anchored to the start date), or as-needed
  with manual logging.
- **Today timeline** — today's doses grouped chronologically, with
  upcoming / due / late / taken / skipped states, one-tap
  Take/Skip/Undo, an animated progress ring, and a minute ticker so
  states stay fresh without interaction.
- **Snooze** — push a due or late dose back 15 minutes; its spot on the
  timeline and its reminder move, while adherence history keeps the
  original scheduled time.
- **Refill tracking** — optionally track doses on hand per medication;
  stock counts down as doses are taken (and back up on undo), a "Low
  supply" warning appears on Today, the list, and the detail screen,
  and a one-tap Refill action tops the supply up.
- **Medication detail screen** — header with color tag + form icon,
  schedule summary, supply status with estimated days left, 7/30-day
  adherence with a 14-day mini chart, recent dose history, and edit /
  archive / delete actions.
- **Adherence stats** — 7-day and 30-day adherence, perfect-day streak,
  per-medication adherence, a weekly bar chart, and a monthly calendar
  heatmap (tap any day for its doses) — all per profile.
- **Shareable text report** — a clean plain-text 30-day adherence
  summary through the system share sheet, alongside the PDF.
- **Reminders** — local notifications for the next 7 days of doses
  across all profiles, rescheduled automatically whenever data changes,
  with a global toggle and a per-medication opt-out. Snoozed doses move
  their reminder. No servers involved.
- **App lock** — optional biometric lock (fingerprint / face unlock,
  with device-credential fallback) toggled in Settings → Security;
  locks on cold start and after 30+ seconds in the background.
- **Settings** — reminders toggle, Backup section, app lock, an About
  section, and a confirmed "erase all data" action that destroys both
  the vault file and the encryption key.
- **Branding** — suite theme with the DoseWise teal accent, bundled
  Inter typeface (fully offline), full light **and** dark mode, and
  adaptive launcher icons on Android and iOS.

## Architecture

Feature-first and deliberately lean: models + services + providers +
screens per feature, a small `core` for app-wide wiring, and pure-Dart
domain logic (scheduler, snooze, refill, adherence math, backup codec,
notification-action handling, PDF layout) that never imports Flutter
platform channels.

```
main.dart                      -> ProviderContainer, real ReminderService,
                                  notification launch/foreground actions
lib/src/
  app.dart                     -> MaterialApp.router + resume reload +
                                  root snackbar key
  core/
    data/                      -> AppData envelope (v2, versioned),
                                  AppDataMigrator (v1 -> v2 profiles),
                                  repository, key manager, IFileStore
    interfaces/                -> IKeyDerivation (Argon2id impl)
    providers/                 -> Riverpod wiring (clock, repo, services,
                                  AppDataNotifier = single mutation point)
    router/                    -> go_router: onboarding redirect, 4-tab
                                  shell + pushed routes (backup, log, ...)
  features/
    profiles/                  -> Profile model, active-profile scoping
                                  providers, avatar chip + switcher sheet
    backup/                    -> BackupService (envelope, encrypt/decrypt,
                                  merge), backup screen, import preview
    medications/               -> Medication + Schedule models, RefillService,
                                  list / form / detail UI
    schedule/                  -> ScheduledDose + DoseScheduler + SnoozeService
    today/                     -> timeline providers, Today screen, ring
    dose_log/                  -> DoseRecord model, history screen
    stats/                     -> AdherenceCalculator, text report builder,
                                  PDF report service (pdf + Inter), charts
    reminders/                 -> ReminderService interface + plugin impl,
                                  NotificationActionHandler (pure Dart),
                                  background isolate entry point
    onboarding/                -> first-run flag + 3-page intro
    settings/                  -> toggles, backup entry, About, erase-all
```

Data flow:

```
UI (screens/widgets)
  -> watches derived providers (activeMedications/activeRecords scope to
     the active profile; todayDoses, stats, heatmap, log build on them)
  -> calls AppDataNotifier mutations (markDose, snoozeDose, refill,
     switchProfile, importBackup, ...)
       -> DoseWiseRepository (load-decrypt-cache; encrypt-write on
          mutation; migration runs on every load)
            -> CipherService (core_crypto, AES-256-GCM)
            -> IFileStore (single vault file in app documents dir)
            -> DataKeyManager -> ISecureStorage (core_storage / keychain)
       -> ReminderService.scheduleAll(next 7 days of unactioned doses for
          ALL profiles, honoring opt-outs and snoozes; each notification
          carries a {medicationId, scheduledTime} payload)

Notification "Take"/"Skip" tap (app closed or backgrounded)
  -> background isolate entry point (@pragma('vm:entry-point'))
       -> builds its own storage stack, decrypts the vault
       -> NotificationActionHandler: payload -> DoseRecord (+ stock)
       -> main isolate reloads the vault on next resume
```

Shared packages reused via path dependencies: `core_crypto` (AES-GCM +
Argon2id), `core_storage` (secure storage), `core_theme` (design
tokens, bundled Inter, per-app accents), `core_ui` (VaultButton/...).

## Security model

- On first launch a random **256-bit data key** is generated and stored
  in `flutter_secure_storage` (iOS Keychain / Android Keystore-backed).
- The entire app state (profiles, medications, dose records, snoozes,
  settings) is serialized to JSON, encrypted with **AES-GCM-256**
  (`core_crypto` `CipherService`, fresh nonce per write), and written
  atomically (temp file + rename) as a single vault file.
- **Backups** are a JSON envelope `{formatVersion, appVersion,
  createdAt, salt, nonce, ciphertext}` where the ciphertext is the full
  state encrypted under an **Argon2id**-derived key from a user-chosen
  passphrase (min 8 chars, confirmed). A wrong passphrase or a tampered
  file fails GCM authentication and is rejected; files from newer
  format versions are refused with a clear message.
- "Erase all data" deletes both the vault file and the key, making any
  residual data unrecoverable.
- No network permission is used anywhere in the app; sharing hands the
  report/backup file to the OS share sheet and nothing else.

## Data migration

The persisted state is versioned (`version: 2` as of 1.2.0).
`AppDataMigrator` runs on **every** load (vault or imported backup):

- a v1 payload is wrapped into a default profile "Me" exactly once —
  medications and dose records gain a `profileId`, nothing else changes;
- self-healing invariants: at least one profile always exists, the
  active profile id always resolves, and dangling `profileId`s are
  reassigned to the first profile;
- the migration is idempotent and covered by fixture tests.

## Run

```sh
cd apps/dose_wise
flutter pub get
flutter run            # iOS simulator or Android device/emulator
```

## Test

```sh
flutter test           # 182 tests
dart analyze           # zero issues
```

Test coverage focuses on the pure domain core: the schedule engine,
snooze semantics, refill transitions, adherence math, both report
generators (text + PDF bytes: sample data, multi-page appendix, unicode
names), the backup codec (round trip, unicode, wrong passphrase,
tampering, version gate, v1-import migration, merge in both
directions), the v1 → v2 state migration matrix (fixture, idempotency,
nothing lost, integrity healing), the notification action handler
(payload codec, take/skip persistence, stock, idempotency, bad input),
profile scoping (per-profile adherence isolation, reminder titles,
cascade delete), repository round trips with in-memory fakes, and
widget tests for Today (take/skip/undo/snooze/stock, first-run CTA),
the profile switcher (switch/add/rename/typed delete), onboarding, the
medication form, detail screen, and app lock.

## Known limitations

- Deleting a medication (or a profile) also deletes its dose history —
  no orphaned records by design.
- Archiving a medication removes its doses from schedules **and** past
  adherence aggregates (history records remain visible in the log).
- Reminders use inexact Android scheduling (no exact-alarm permission
  prompts); delivery may shift by a few minutes on some devices.
- Notification count is capped at 60 pending doses (iOS system limit),
  shared across all profiles.
- Notification actions persist in a background isolate; if the app is
  in the **foreground** while an action is tapped from the shade, the
  change appears after the next app resume (a same-moment in-app edit
  could race it in that narrow window).
- Restoring a backup with **Replace** applies the backup's profiles and
  data wholesale; device-local settings (reminder toggle) come along
  from the backup in that mode.
