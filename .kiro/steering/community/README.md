# Morphe Community Patches & Bundle Ecosystem

A comprehensive index, decision matrix, and technique reference synthesized from 18+ community patch repositories and the official Morphe community catalog.

## Official Community Bundle Catalog

The community directory for discovering community bundles, supported applications, and upstream GitHub repositories is hosted at:
👉 **[https://morphe-patches.software/#bundles](https://morphe-patches.software/#bundles)**

### Key Community Repositories Indexed
| Repository | Developer | Focus / Highlights |
|---|---|---|
| `hoo-dles/morphe-patches` | hoo-dles | 42+ apps (Prime Video, AdGuard, WPS, Nova), method injection, signature spoofing, native ARM64 hex patching |
| `crimera/piko` | crimera | Instagram: Entity architecture, UI download button injection, ad filtering, link sanitization |
| `wchill/patcheddit` | wchill | Reddit clients: OkHttp interceptor injection, Parcelable model extension, JSON extraction |
| `RookieEnough/De-ReVanced` | RookieEnough | Strava, ProtonMail: XML resource limit overrides, multi-language strings, configurable patch options |
| `anddea/revanced-patches` | anddea | YouTube/Music/Reddit: named fingerprint pairs, version-aware patching, `classDefForEach` predicates |
| `rabilrbl/fluffy-patches` | rabilrbl | JioTV: Root environment adaptation, SSL pinning removal, emulator compatibility |
| `MorpheApp/morphe-patches` | MorpheApp | Official: Litho component filtering, settings framework, GmsCore MicroG support, video stream spoofing |

---

## Pattern Decision Matrix

Use this matrix to identify the right file, API, and smali pattern for your specific target app and requirement:

| Goal / Objective | Target App / Framework | Recommended Guide | Primary Mechanism & APIs |
|---|---|---|---|
| **Entitlement Simulation** | RevenueCat / Adapty / Qonversion | `modern-paywalls-patterns.md` | `method.returnEarly(true)`, `AdaptyProfile` mocking |
| **Reactive Feature Gates** | Kotlin Coroutines / StateFlow | `modern-paywalls-patterns.md` | Flow emissions, `Continuation` interception |
| **Component UI Ad Filtering** | Litho / YouTube | `official-morphe-patches-analysis.md` | Parser hook, Litho filter registration, `.mpe` extension |
| **Feed Item Filtering** | RecyclerView / Reddit / Instagram | `patcheddit-reddit-patterns.md`, `piko-instagram-patterns.md` | List mutation in `.mpe`, `indexOfFirstInstruction` |
| **Native Library Modification** | C/C++ `.so`, Flutter `libapp.so`, Unity `libil2cpp.so` | `flutter-and-native-patterns.md` | `rawResourcePatch` with `hexPatch`, ARM64 opcodes, REA MCP |
| **Flutter Channel Hooks** | Flutter Platform Channels | `flutter-and-native-patterns.md` | `io.flutter.plugin.common.MethodChannel` hook |
| **Network Traffic Inspection** | OkHttp3, CertificatePinner | `patcheddit-reddit-patterns.md`, `community-patches-analysis.md` | OkHttp client builder interceptor, `CertificatePinner.check` NOP |
| **Environment Compatibility** | Play Integrity, Root, Emulator | `hoodles-patch-catalog.md`, `community-patches-analysis.md` | `processLicenseResponse` stubbing, `isRooted` return false |
| **Toggleable Settings UI** | SharedPreferences / Settings Screen | `official-morphe-patches-analysis.md` | `PreferenceScreen.ADS.addPreferences(SwitchPreference(...))` |
| **XML / Resource Overrides** | Limits, Manifest metadata, strings | `de-revanced-patterns.md` | `resourcePatch`, `document("...").use { ... }` |

---

## Guide Index in this Directory

1. [`community-patches-analysis.md`](community-patches-analysis.md): Broad cross-repo review of 15 fundamental patching techniques.
2. [`official-morphe-patches-analysis.md`](official-morphe-patches-analysis.md): Advanced Litho component filtering, settings integration, MicroG/GmsCore redirection.
3. [`hoodles-patch-catalog.md`](hoodles-patch-catalog.md): Complete catalog of 78 patches across 42 apps from the largest community bundle.
4. [`flutter-and-native-patterns.md`](flutter-and-native-patterns.md): Specialized patterns for Flutter, React Native/Hermes, Unity IL2CPP, and ARM64 hex patching.
5. [`modern-paywalls-patterns.md`](modern-paywalls-patterns.md): Modern paywalls (Adapty v2/v3, Superwall, Qonversion) and Kotlin Coroutine StateFlow patterns.
6. [`piko-instagram-patterns.md`](piko-instagram-patterns.md): Entity pattern, UI menu button injection, link sanitization.
7. [`patcheddit-reddit-patterns.md`](patcheddit-reddit-patterns.md): OkHttp builder interceptor, Parcelable model extension, WebView URL interception.
8. [`de-revanced-patterns.md`](de-revanced-patterns.md): Resource value overrides, multi-language string removal, configurable patch options.
9. [`revanced-extended-patterns.md`](revanced-extended-patterns.md): Named fingerprint pairs, version-aware patching, runtime predicate scanning.
10. [`ample-revanced-patterns.md`](ample-revanced-patterns.md): Native URL redirection, local HTTP proxy in extensions, JSON stream hooks.
11. [`small-repos-patterns.md`](small-repos-patterns.md): Niche patterns (call-site return replacement, single-point RevenueCat hook, Gboard XML).
