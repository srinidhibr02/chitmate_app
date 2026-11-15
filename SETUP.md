# ChitMate – setup and verification

ChitMate is a Flutter app for organisers of chit funds / savings circles (amounts in ₹).

## 1. Run the checks (one command)

Install Flutter (stable, Dart 3.9+), then from this folder:

```bash
./tool/verify.sh
```

It creates the `android/` and `ios/` folders if missing, fetches packages, generates the
launcher icons from your logo (and removes the sample `test/widget_test.dart` that `flutter create` adds), then runs `flutter analyze` and `flutter test`.

> **Honest status:** this project was written in an environment with no Flutter/Dart toolchain,
> so `analyze` and `test` have **not been run yet**. What was checked there: every Dart file
> parses, every import resolves, an independent Python simulation of the chit rules passed, and
> the code was reviewed by a separate reviewer. Please run `./tool/verify.sh` and send me any
> output that fails; those are small fixes.

## 2. Android notification setup (one time, after `flutter create`)

Reminders use `flutter_local_notifications`.

1. `android/app/build.gradle.kts` – inside `android { compileOptions { ... } }` add
   `isCoreLibraryDesugaringEnabled = true`, and in `dependencies { }` add
   `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
2. `android/app/src/main/AndroidManifest.xml` – inside `<manifest>` add:
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   ```
   and inside `<application>` add:
   ```xml
   <receiver android:exported="false"
       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
   <receiver android:exported="false"
       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
     <intent-filter>
       <action android:name="android.intent.action.BOOT_COMPLETED"/>
       <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
       <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
       <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
     </intent-filter>
   </receiver>
   ```
3. Set the app label to `ChitMate` in the manifest (`android:label`).

Reminders are inexact (they may arrive a few minutes late), so no exact-alarm permission is needed.

## 3. Behaviour to know about

- **Local-first (v1).** Data lives on the organiser's phone; the organiser records each member's
  vote. `ChitRepository` (`lib/data/repository.dart`) is the seam for a Firebase/Supabase backend
  later so members can vote from their own phones.
- **Time zone** is fixed to India (Asia/Kolkata) for reminders (09:00, 3 days before).
- **Payments are tracked only**; no money moves through the app.
- **Rules** live in `lib/domain` (pure Dart, heavily tested): voting power, random draw with the
  no-consecutive rule (eased and flagged when it would leave no chit), tie handling, locks.

## 4. Layout

```
lib/domain   rules, actions, models, notices (pure Dart)
lib/data     repository (local storage)
lib/services reminders
lib/state    AppState (+ rollback on rule violations)
lib/ui       screens, sheets, widgets, animations
test         rules, actions, state, reminders, widget flows
tool         verify.sh, simulate_rules.py
```
