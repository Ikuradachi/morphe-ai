# Target Discovery Index

Use this as an index, not as proof. Search results become viable targets only after exact call-chain analysis and smali verification.

For community bundle precedents and multi-app patch examples, consult the community directory at [https://morphe-patches.software/#bundles](https://morphe-patches.software/#bundles).

## Architecture routing

| Indicator | Likely architecture | Analysis implication |
|---|---|---|
| Java/Kotlin DEX and no cross-platform marker | Native Android | jadx plus baksmali is the primary path |
| `assets/index.android.bundle` | React Native | Inspect native bridge modules, Hermes bytecode assets, or patch via `rawResourcePatch` on the bundle |
| `libflutter.so` and `libapp.so` | Flutter | App logic is native AOT; inspect platform MethodChannels or evaluate ARM64 disassembly via REA MCP for `hexPatch` |
| `libil2cpp.so` + `global-metadata.dat` | Unity / IL2CPP | Managed assemblies compiled to C++; analyze offsets with Il2CppDumper and patch native binaries with `hexPatch` |
| `DexClassLoader` / `PathClassLoader` | Dynamic code | Identify loaded DEX/JAR and whether it is present locally |
| Packed/encrypted DEX | Packer/protector | Static targets may be unavailable; document the blocker rather than inventing one |

## Billing and entitlement SDK indicators

Search case-insensitively for package names and calls, then trace application-owned consumers:

```text
RevenueCat: CustomerInfo, EntitlementInfos, getEntitlements, getActive, isActive
Google Play Billing: BillingClient, queryPurchases, Purchase, BillingResult, isAcknowledged
Adapty (v2 & v3): AdaptyProfile, accessLevels, isActive, AdaptyResult
Superwall: Superwall, checkEntitlements, paywallPresentation
Qonversion: QEntitlement, checkEntitlements
Local state: isPremium, isPro, isSubscribed, hasPremium, SharedPreferences.getBoolean
Reactive state: StateFlow, SharedFlow, Continuation (Kotlin Coroutine suspend fun)
Remote flags: FirebaseRemoteConfig, getBoolean, getString
Legacy licensing: LicenseChecker, Policy.processServerResponse
```

Prefer the deepest stable client-side decision consumed by the app. Record when a feature is server-validated; do not attempt to compromise remote payment, account, entitlement, or attestation systems.

## Content and layout filtering indicators

```text
AdMob: MobileAds, AdView, InterstitialAd, RewardedAd, loadAd, show
Unity: UnityAds, BannerView
AppLovin MAX: MaxAd, MaxInterstitialAd, loadAd, showAd
Meta Audience Network: com.facebook.ads
Litho / ComponentContext: ComponentContext, ComponentTree, LayoutState (hook parser + .mpe extension)
Analytics: FirebaseAnalytics, Crashlytics, logEvent, recordException
```

Identify the exact SDK version and app call sites. A global SDK modification can have broad side effects; prefer an app-owned gate or scoped call site when possible.

## Environment and integrity indicators

```text
Signature: getPackageInfo, GET_SIGNATURES, SigningInfo, checkSignature
Root/emulator: RootBeer, isRooted, magisk, test-keys, isEmulator
TLS/Pinning: CertificatePinner, X509TrustManager, checkServerTrusted, network_security_config.xml
Integrity/license: IntegrityManager, Pairip, validateLicenseResponse
Debug: isDebuggerConnected, waitForDebugger
```

Only analyze environment self-checks when they prevent local execution of the authorized modification. Client-side observations do not imply that server-side validation can or should be bypassed.

## Native binary analysis (.so) with REA MCP

When logic resides in native shared libraries (`lib/**/*.so`):
1. **Locate the JNI boundary**: Find `System.loadLibrary()` and native method signatures in Java/smali.
2. **Analyze via REA MCP**: Query symbols (`Java_<package>_<class>_<method>`), search string references, and view ARM64 disassembly.
3. **Design hex patch**: Formulate byte patterns (e.g. `20 00 80 52 C0 03 5F D6` for `mov w0, #1; ret`) and target files (`lib/arm64-v8a/libfoo.so`) for `rawResourcePatch`.

## Search progression

1. Identify architecture and SDK.
2. Find application-owned callers/consumers.
3. Trace to the smallest decision point.
4. Locate the exact smali class across all DEX directories.
5. Reject candidates that lack stable structural identity or sufficient behavioral evidence.
