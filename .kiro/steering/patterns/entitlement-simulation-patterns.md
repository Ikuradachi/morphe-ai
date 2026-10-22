# Entitlement Simulation & In-App Purchase Adaptation Patterns

Techniques for stubbing, simulating, and adapting in-app entitlement and billing architectures in Morphe patches.

## Overview & Architecture Scope
Mobile applications evaluate entitlement state via local client SDKs (RevenueCat, Adapty, Google Play Billing, Qonversion, Superwall) or local SharedPreferences. In offline, testing, or custom environments, Morphe patches adapt these decision points by stubbing getter methods or returning simulated entitlement data models.

---

## 1. RevenueCat Purchases SDK

**Architecture:** The client application requests entitlement status from `CustomerInfo` -> `EntitlementInfos` -> `getActive()`.

```kotlin
// Fingerprint targets: CustomerInfo → getEntitlements() → getActive()
object EntitlementCheckFingerprint : Fingerprint(
    returnType = "Z",
    accessFlags = listOf(AccessFlags.PUBLIC, AccessFlags.STATIC),
    parameters = listOf("Lcom/revenuecat/purchases/CustomerInfo;"),
    filters = listOf(
        methodCall(definingClass = "Lcom/revenuecat/purchases/CustomerInfo;", name = "getEntitlements"),
        methodCall(definingClass = "Lcom/revenuecat/purchases/EntitlementInfos;", name = "getActive")
    )
)

// Patch: return true at start to simulate active subscription
EntitlementCheckFingerprint.method.returnEarly(true)
```

### Deeper RevenueCat Hook: `EntitlementInfo.isActive()`
For hybrid apps (Flutter, React Native) or apps querying individual entitlement identifiers:
```kotlin
// Force EntitlementInfo.isActive() to return true
// Covers both direct Java access and bridge serialization mappers
EntitlementIsActiveFingerprint.method.returnEarly(true)
```

---

## 2. Google Play Billing Client (`BillingClient`)

**Architecture:** Client queries purchase records using `queryPurchasesAsync` or checks `Purchase.isAcknowledged()` / `PurchaseState`.

### Approach A: Acknowledge Method Override
```kotlin
// Override purchase acknowledgement check
PurchaseCheckFingerprint.method.returnEarly(true)
```

### Approach B: BillingResult.getResponseCode() Stubbing
```kotlin
// Ensure BillingResponseCode returns OK (0)
BillingResultFingerprint.method.addInstructions(0, """
    const/4 v0, 0x0  // BillingResponseCode.OK = 0
    return v0
""")
```

---

## 3. Play Integrity / Pairip Client-Side Adapter

**Architecture:** Google Play Integrity client-side callback processes attestation response tokens.

```kotlin
// 1. Set responseCode parameter (p1) to 0 (Success)
ProcessLicenseResponseFingerprint.method.addInstruction(0, "const/4 p1, 0x0")

// 2. Clear repeated check flag register
RepeatedCheckFingerprint.matchOrNull(originalMethod)?.apply {
    val reg = instructionMatches.first().getInstruction<OneRegisterInstruction>().registerA
    method.replaceInstruction(index + 1, "const/4 v$reg, 0x0")
}

// 3. Early return on validation verification routine
ValidateLicenseResponseFingerprint.method.returnEarly()
```

---

## 4. Adapty SDK (v2 & v3)

**Architecture:** Adapty exposes `AdaptyProfile.accessLevels` containing subscribed tier definitions.

```kotlin
// Stub access level check to simulate active tier
AdaptyAccessLevelIsActiveFingerprint.method.returnEarly(true)
```

---

## 5. Local State & Shared Preferences

Many apps store subscription flags in local preferences (`is_pro`, `has_premium`, `unlocked`):

### Approach A: Override SharedPreferences Reader
```kotlin
// Replace SharedPreferences.getBoolean() call result
val index = method.indexOfFirstInstruction(Opcode.INVOKE_INTERFACE)
val resultReg = method.getInstruction<OneRegisterInstruction>(index + 1).registerA
method.replaceInstruction(index + 1, "const/4 v$resultReg, 0x1")
```

### Approach B: Direct Getter Override
```kotlin
// Override UserState.isPremium() -> Boolean
IsPremiumFingerprint.method.returnEarly(true)
```
