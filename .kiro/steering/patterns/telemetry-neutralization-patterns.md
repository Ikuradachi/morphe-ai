# Telemetry Neutralization & Privacy Enhancement Patterns

Techniques for disabling background telemetry, analytics collection, and diagnostic tracking in Morphe patches.

## 1. Firebase Analytics — Manifest Configuration

Add meta-data flags to `AndroidManifest.xml` via `resourcePatch`:

```kotlin
resourcePatch(name = "Deactivate Firebase Analytics") {
    execute {
        document("AndroidManifest.xml").use { doc ->
            val app = doc.getElementsByTagName("application").item(0) as Element
            val metaData = doc.createElement("meta-data").apply {
                setAttribute("android:name", "firebase_analytics_collection_deactivated")
                setAttribute("android:value", "true")
            }
            app.appendChild(metaData)
        }
    }
}
```

Additional recommended privacy flags:
```xml
<meta-data android:name="firebase_analytics_collection_deactivated" android:value="true"/>
<meta-data android:name="firebase_crashlytics_collection_enabled" android:value="false"/>
<meta-data android:name="firebase_performance_collection_deactivated" android:value="true"/>
<meta-data android:name="google_analytics_adid_collection_enabled" android:value="false"/>
```

---

## 2. Advertising ID Interception

Prevent apps from obtaining persistent hardware advertising identifiers:

```kotlin
// Return null on AdvertisingIdClient.getAdvertisingIdInfo()
classDefBy("Lcom/google/android/gms/ads/identifier/AdvertisingIdClient;")
    .methods.first { it.name == "getAdvertisingIdInfo" }
    .toMutable().returnEarly(null)

// Or return zeroed UUID
SpoofAdvertisingIdFingerprint.method.returnEarly("00000000-0000-0000-0000-000000000000")
```

---

## 3. Crashlytics & Performance Monitoring Deactivation

```kotlin
// Neutralize Crashlytics at initialization point
classDefBy("Lcom/google/firebase/crashlytics/FirebaseCrashlytics;")
    .methods.first { it.name == "getInstance" }
    .toMutable().returnEarly(null)
```
