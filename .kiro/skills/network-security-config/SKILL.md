---
name: network-security-config
description: Network security configuration XML injection, user CA certificate trust, OkHttp CertificatePinner neutralization, and TLS diagnostic setups. Use when diagnosing or intercepting network traffic.
---

# Network Security Config & TLS Instrumentation

Methodology for configuring Android network security, enabling user CA certificate trust, and neutralizing SSL certificate pinning in Morphe patches.

---

## 1. Network Security Config Injection (Android 7.0+ / API 24+)

By default on Android 7.0 and higher, applications do not trust user-installed CA certificates (such as those installed for mitmproxy, Charles, or Burp Suite).

### Step A: Create `res/xml/network_security_config.xml`
Using a `resourcePatch`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

### Step B: Wire into `AndroidManifest.xml`
```kotlin
resourcePatch(name = "Trust User Certificates") {
    compatibleWith(COMPATIBILITY_APP)
    execute {
        document("AndroidManifest.xml").use { doc ->
            val app = doc.getElementsByTagName("application").item(0) as Element
            app.setAttribute("android:networkSecurityConfig", "@xml/network_security_config")
        }
    }
}
```

---

## 2. OkHttp3 `CertificatePinner` Neutralization

Even with user CAs trusted in the manifest, applications using OkHttp may enforce certificate pinning via `CertificatePinner.check(...)`.

### Bytecode Neutralization (Fastest)
```kotlin
val disableOkHttpPinningPatch = bytecodePatch(
    name = "Disable OkHttp Certificate Pinning",
    description = "Neutralizes OkHttp3 CertificatePinner check routine."
) {
    compatibleWith(COMPATIBILITY_APP)
    execute {
        classDefBy("Lokhttp3/CertificatePinner;")
            .methods.filter { it.name == "check" }
            .forEach { method ->
                // Return void immediately before pinning validation executes
                method.toMutable().addInstructions(0, "return-void")
            }
    }
}
```

---

## 3. TrustManager & Conscrypt / Cronet

When an app uses a custom `X509TrustManager`:
- Locate the implementation of `checkServerTrusted(chain, authType)`.
- Stub the method with `return-void`:
  ```kotlin
  CustomTrustManagerFingerprint.method.returnEarly()
  ```
