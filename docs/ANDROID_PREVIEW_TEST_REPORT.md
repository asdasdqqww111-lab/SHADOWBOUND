# SHADOWBOUND v0.3.0 — Android Preview Build Verification

## Download

- [Direct APK](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/download/v0.3.0-android-preview-2/SHADOWBOUND-v0.3.0-preview.apk)
- [Release page](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/tag/v0.3.0-android-preview-2)
- [SHA-256 file](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/download/v0.3.0-android-preview-2/SHADOWBOUND-v0.3.0-preview.apk.sha256)
- Size: **159,637,580 bytes** (about 160 MB / 152 MiB).
- SHA-256: `6bf0961c5e678a002c51c37dac8bc2f4efccbe05eab33d1e46e22c90f08b74f9`.

## Provenance

- Source: `7a1107e75906f16dd5828b7e079b0507fbd5393c` on `arena/1e3db61b-shadowbound`.
- Engine: official Godot **4.3 stable** and matching Android source export template.
- Build: Ubuntu 24.04, Temurin Java 17, Android SDK 34 / build tools 34.0.0, Gradle APK debug export.
- Successful APK workflow: https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44422671140
- Successful native/static regression workflow for the same source: https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44422671163
- Build logs are published as the **Android preview diagnostics** check and the workflow artifact. The APK itself is a public release asset; no GitHub sign-in is required for its direct download.

## Executed Verification — PASS

- Godot asset import and native script compilation, then successful actual APK export.
- `apksigner verify --verbose --print-certs`: **Verifies**, APK Signature Scheme **v2**, one RSA-2048 signer.
- `aapt dump badging`: package **com.shadowbound.rpg**, version name **0.3.0-preview**, version code **3**.
- Manifest: minimum SDK **28** (Android 9), target SDK **34**, launchable Godot activity, landscape, OpenGL ES **3.0**.
- Both native engine architectures packaged: **arm64-v8a**, **armeabi-v7a**.
- `aapt dump permissions`: **no requested permissions** (including no Internet permission).
- ZIP integrity checked for every entry; compiled project, combat config and Arabic localization are present.
- No `.keystore`, `.jks` or Python build tools are inside the APK.
- SHA-256 checksum generated in CI and matched the GitHub release asset digest.
- Source regression checks remain green: **326 project checks + 56 geometry/config checks + 147 native Godot tests**.

## Build Issue Resolved

The earlier example preset disabled Gradle while overriding min/target SDK. Godot 4.3 rejects that combination. The preset now enables Gradle, the workflow installs the matching `android_source.zip` template and records its version, and the actual exported manifest confirms SDK 28/34. Credentials and the generated test keystore remain outside Git.

## Installation / تجربة النسخة

نزّل ملف APK وافتحه من المتصفح أو مدير الملفات. اسمح لهذا التطبيق بتثبيت التطبيقات من هذا المصدر إذا طلب Android ذلك. النسخة تجريبية للاختبار البصري وليست إصدار متجر. جرّب نمطَي اللعب، اللغة العربية، أزرار اللمس، سلسلة الضربات، الصد والمراوغة والزعيم، وأرسل صورًا أو فيديو مع موديل الجهاز وإصدار Android عند ظهور مشكلة.

## Limitations

- **No physical Android device or emulator launch has been performed in this environment.** A successful signed build does not certify visual quality, gameplay feel, frame rate or compatibility on every device.
- Debug/test signing uses a disposable CI key. A future build may require uninstalling this preview before installation; it is not a stable production upgrade path.
- This build is intentionally an unoptimized dual-architecture debug preview. Production size optimization, stable signing, release certification and device coverage are not claimed complete.
- No gameplay code or Phase 4 functionality was added for this build.
