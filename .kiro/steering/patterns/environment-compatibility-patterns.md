# Environment Compatibility & Runtime Attestation Patterns

Techniques for adapting environment detection, root checks, SSL certificate verification, and signature validation in Morphe patches.

## Overview
When running modified APKs in customized environments (rooted testing devices, emulators, local diagnostic network proxies), applications may fail environment self-checks. These patterns adapt runtime checks to ensure application compatibility.

---

## 1. Root & Superuser Environment Adaptation

### Firebase `CommonUtils.isRooted()`
```kotlin
classDefBy("Lcom/google/firebase/crashlytics/internal/common/CommonUtils;")
    .methods.first { it.name == "isRooted" }
    .toMutable().addInstructions(0, "const/4 v0, 0x0\nreturn v0")
```

### RootBeer & Custom Root Checkers
Search indicators: `su`, `/system/app/Superuser.apk`, `com.topjohnwu.magisk`, `test-keys`
```kotlin
// Return false on each root validation method
RootBeerCheckFingerprint.method.returnEarly(false)
```

### Xposed & Hooking Framework Detection Dialogs
```kotlin
classDefBy("Lcom/app/utils/SecurityUtils;")
    .methods.first { it.name == "showXposedFrameworkDetectionDialog" }
    .toMutable().addInstructions(0, "return-void")
```

---

## 2. TLS & SSL Certificate Pinning Neutralization

For local network diagnostics and traffic capture using tools like mitmproxy or Charles:

### OkHttp3 `CertificatePinner`
```kotlin
classDefBy("Lokhttp3/CertificatePinner;")
    .methods.filter { it.name == "check" }
    .forEach { it.toMutable().addInstructions(0, "return-void") }
```

### Legacy OkHttp (`com.squareup.okhttp`)
```kotlin
runCatching { classDefBy("Lcom/squareup/okhttp/CertificatePinner;") }.getOrNull()?.let {
    it.methods.filter { m -> m.name == "check" }
        .forEach { m -> m.toMutable().addInstructions(0, "return-void") }
}
```

### Custom Network Security Configuration XML
Modify `AndroidManifest.xml` to trust user-installed CA certificates:
```kotlin
resourcePatch {
    execute {
        document("AndroidManifest.xml").use { doc ->
            val app = doc.getElementsByTagName("application").item(0) as Element
            app.setAttribute("android:networkSecurityConfig", "@xml/network_security_config")
        }
    }
}
```

---

## 3. Signature & Certificate Verification

When an app validates its own signing certificate (e.g. comparing against hardcoded SHA-1 hashes):

### Approach A: Return Hardcoded Original Signature String
```kotlin
SignatureVerificationFingerprint.method.returnEarly(Constants.ORIGINAL_SIGNATURE_SHA1)
```

### Approach B: Array Data Replacement
```kotlin
SignatureBytesFingerprint.method.addInstructions(0, """
    const/16 v0, ${signature.size}
    new-array v0, v0, [B
    fill-array-data v0, :array_sig
    return-object v0
    :array_sig
    .array-data 1
        ${signature.joinToString("\n") { "${it}t" }}
    .end array-data
""")
```

---

## 4. Emulator & Debugger Detection

### Debugger Check Neutralization
```kotlin
IsDebuggerConnectedFingerprint.method.returnEarly(false)
```

### Build Fingerprint & Hardware Checks
Replace hardware checks (`ro.hardware`, `goldfish`, `ranchu`) with standard device profile values.
