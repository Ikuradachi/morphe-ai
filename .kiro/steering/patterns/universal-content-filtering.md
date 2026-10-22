# Universal Content Filtering & Layout Optimization Patterns

Patterns for filtering promotional elements, sponsored layout items, and ad SDK containers across major mobile frameworks.

## Architecture: Modular Content Filtering
Each content network has an isolated filter patch that can be toggled by the user:

```kotlin
val disableSponsoredContentPatch = bytecodePatch(name = "Filter sponsored content", default = true) {
    val filterAdMobOption = booleanOption("filterAdMob", "Filter Google AdMob", true)
    val filterUnityOption = booleanOption("filterUnity", "Filter Unity Ads", true)

    execute {
        if (filterAdMobOption.value) applyGoogleAdMobFilter()
        if (filterUnityOption.value) applyUnityFilter()
    }
}
```

---

## 1. Google AdMob

**Targets:** `loadAd`, `show`, `requestBannerAd` across `AdView`, `InterstitialAd`, `RewardedAd`.

```kotlin
classDefForEach { classDef ->
    classDef.filterMethods { _, method ->
        method.returnType == "V" &&
        method.parameters.firstOrNull()?.type == "Landroid/content/Context;" &&
        containsAllStrings(setOf("Context cannot be null.", "AdUnitId cannot be null."))
    }.forEach { method ->
        mutableClassDefBy(method.definingClass)
            .findMutableMethodOf(method).returnEarly()
    }
}
```

---

## 2. Unity Ads SDK

**Targets:** `initialize`, `load`, `show`, `BannerView`

```kotlin
val adMethods = setOf("initialize", "isInitialized", "isSupported", "load", "show", "loadWebPlayer")

setOf("Lcom/unity3d/services/UnityAds;", "Lcom/unity3d/services/banners/BannerView;").forEach { definingClass ->
    mutableClassDefBy(definingClass)
        .filterMethods { _, method -> method.name in adMethods }
        .forEach { it.returnEarly() }
}
```

---

## 3. AppLovin MAX & Meta Audience Network

**AppLovin MAX:** Neutralize `loadAd`, `showAd`, `startAutoRefresh`.
**Meta Audience Network:** Neutralize `loadAd`, `show` on `com.facebook.ads.AdView` and `InterstitialAd`.

---

## 4. Litho Component Filtering (YouTube / Dynamic UIs)

For applications utilizing declarative component frameworks (Litho, ComponentContext):
- Intercept component deserialization parser.
- Register custom filter predicates in an `.mpe` extension artifact to hide component nodes before UI rendering.
