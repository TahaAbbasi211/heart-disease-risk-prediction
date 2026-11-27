# Android Release Signing (`ir.biovanta.heartrisk`)

Release builds fail closed unless `android_app/android/key.properties` is present.
Debug builds and `flutter test` continue to work without `key.properties`.

If you intentionally need a local debug-signed release build without `key.properties`
(e.g., for local phone UI preview), pass `-PallowDebugRelease=true` explicitly:

```powershell
cd android_app
flutter build apk --release --split-per-abi --android-project-arg allowDebugRelease=true
```

---

## Permanent Dedicated Release Keystore (Recommended)

1. Generate `android_app/android/release.jks` (`CN=BioVanta Heart Risk, O=BioVanta, C=IR`):

```powershell
cd android_app\android
powershell -ExecutionPolicy Bypass -File signing_setup.ps1 -Action create
```

2. Create `android_app/android/key.properties` (git-ignored) pointing to `release.jks`:

```properties
storeFile=../release.jks
keyAlias=release
storePassword=<the password you typed>
keyPassword=<the same password>
```

3. Build the split-ABI release APKs:

```powershell
cd android_app
flutter build apk --release --split-per-abi
```

4. Back up `release.jks`, `key.properties`, and your passwords safely **outside** the repository.

---

## Never Commit

`key.properties`, `*.jks`, `*.keystore`, and `lineage.bin` are ignored by both root `.gitignore` and `android_app/android/.gitignore`. Never commit them to version control.
