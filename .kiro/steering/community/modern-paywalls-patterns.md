# Modern Paywalls & Reactive Architecture Patterns

Techniques for analyzing and adapting modern subscription frameworks (Adapty v2/v3, Superwall, Qonversion) and Kotlin Coroutines / StateFlow reactive architectures.

---

## 1. Adapty SDK (v2 & v3)

Adapty is a popular alternative to RevenueCat. It delivers paywalls dynamically and exposes `AdaptyProfile.accessLevels`.

### Identifying Adapty in Code
```text
Packages: com.adapty, com.adapty.models, com.adapty.internal
Key Classes: Adapty, AdaptyProfile, AdaptyProfile.AccessLevel, AdaptyResult
```

### Strategy A: Stubbing `AdaptyProfile.AccessLevel.isActive()`
Adapty checks access level validity using `isActive`:
```kotlin
object AdaptyAccessLevelIsActiveFingerprint : Fingerprint(
    returnType = "Z",
    accessFlags = listOf(AccessFlags.PUBLIC, AccessFlags.FINAL),
    filters = listOf(
        fieldAccess(opcode = Opcode.IGET_BOOLEAN, definingClass = "this", type = "Z"),
        opcode(Opcode.RETURN),
    )
)

// Patch
AdaptyAccessLevelIsActiveFingerprint.method.returnEarly(true)
```

### Strategy B: AdaptyResult Callback Interception
When an app makes asynchronous calls to `Adapty.getProfile()`:
```kotlin
// Target the AdaptyCallback implementation where onResult(AdaptyResult) is called
// Modify the profile model inside AdaptyResult.Success
```

---

## 2. Superwall

Superwall gates application features using remote paywall presentations (`Superwall.shared.register()`).

### Identifying Superwall in Code
```text
Packages: com.superwall.sdk, com.superwall.sdk.paywall.presentation
Key Methods: register, getSubscriptionStatus, dismiss
```

### Strategy: Bypass Paywall Presentation Gate
Superwall evaluates user presentation rules before displaying a paywall:
```kotlin
// Override internal presentation evaluator to treat trigger as "already subscribed" / bypass
SuperwallGateFingerprint.method.returnEarly()
```

---

## 3. Qonversion

### Identifying Qonversion
```text
Packages: com.qonversion.android.sdk
Key Classes: Qonversion, QEntitlementsMap, QEntitlement
```

### Strategy: Entitlement Map Override
```kotlin
// Target QEntitlement.isActive() getter
QonversionIsActiveFingerprint.method.returnEarly(true)
```

---

## 4. Kotlin Coroutines (`suspend fun`) & Reactive StateFlow

Modern apps use Kotlin Coroutines instead of callback interfaces.

### Anatomy of a `suspend fun` in Smali
In compiled Dalvik bytecode, a `suspend fun checkEntitlements(): Boolean` has the signature:
```smali
.method public final checkEntitlements(Lkotlin/coroutines/Continuation;)Ljava/lang/Object;
```
It takes a hidden `Continuation` parameter and returns `Ljava/lang/Object;`. The return value can be either:
1. The actual result boxed as an object (e.g. `java.lang.Boolean.TRUE`).
2. `kotlin.coroutines.intrinsics.CoroutineSingletons.COROUTINE_SUSPENDED`.

### Patching a `suspend fun` directly
```kotlin
// Return boxed Boolean.TRUE immediately without suspending
SuspendEntitlementFingerprint.method.addInstructions(0, """
    const/4 v0, 0x1
    invoke-static { v0 }, Ljava/lang/Boolean;->valueOf(Z)Ljava/lang/Boolean;
    move-result-object v0
    return-object v0
""")
```

### Patching Reactive `StateFlow` / `LiveData` Observers
When an app observes entitlement status as a stream:
```kotlin
// Target the StateFlow emitter or getter
// Replace emitted value with simulated active state
```
