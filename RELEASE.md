# Releasing ChitMate on Google Play

App ID (permanent): `app.zerolpa.chit_mate`

## 1. Point Firebase at the new app ID (once)
1. Firebase console → Project settings → Your apps → **Add app → Android**.
2. Package name: `app.zerolpa.chit_mate`. Register, then download the new `google-services.json`.
3. Replace `android/app/google-services.json` with it (this file is not committed).
4. Add your **debug** SHA-1 and SHA-256 to this new app (`cd android && ./gradlew signingReport`).
5. Re-add nothing else: sign-in method, test number and SMS region settings are project-wide.
6. Uninstall the old app from the phone, then `flutter clean && flutter run`.

## 2. Create the upload key (once, keep it safe)
```
keytool -genkey -v -keystore ~/chitmate-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Back the `.jks` file and its passwords up in two places. Then create `android/key.properties`:
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/chitmate-upload.jks
```
Neither file is committed (see `.gitignore`).

## 3. Build
```
flutter build appbundle --release
```
Upload `build/app/outputs/bundle/release/app-release.aab`. Raise the number after `+` in
`pubspec.yaml` (`version: 1.0.0+1`) for every new upload.

## 4. Release-build login
Play Console → App integrity → App signing: copy the **SHA-1 and SHA-256 of the app signing
key** and also of the **upload key**, and add them all to the Firebase Android app. Without them,
phone login works in debug but fails in the store build.
