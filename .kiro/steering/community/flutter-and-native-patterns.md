# Flutter, React Native, and Native (.so) Patching Patterns

Techniques for analyzing and patching cross-platform frameworks (Flutter, React Native, Unity/IL2CPP) and native C++ libraries using Morphe `rawResourcePatch` and `hexPatch`.

---

## 1. Flutter Applications

Flutter compiles application code ahead-of-time (AOT) into `lib/arm64-v8a/libapp.so`, while the Flutter framework runtime is in `libflutter.so`.

### Architecture Points
- **Java/Kotlin Layer**: Houses the `FlutterActivity`, plugins, and `MethodChannel` bridges.
- **Native Layer**: Houses all UI widgets, business logic, state management (Bloc, Provider, Riverpod), and HTTP networking (Dart `HttpClient` using BoringSSL).

### Strategy A: Java Platform Channel Interception (`MethodChannel`)
Most Flutter plugins (e.g. in-app purchases, local notifications, device info, secure storage) communicate across platform channels:
```kotlin
// In smali/Java: target io.flutter.plugin.common.MethodChannel$IncomingMethodCallHandler
// Intercept calls before they return to Flutter
MethodChannelFingerprint.method.apply {
    val index = indexOfFirstInstruction(Opcode.INVOKE_INTERFACE)
    // Wrap the Result.success() callback to supply mock data
}
```

### Strategy B: Native ARM64 Hex Patching (BoringSSL Cert Pinning)
Flutter bypasses Android system CA stores by embedding BoringSSL in `libflutter.so`. To inspect traffic:
```kotlin
rawResourcePatch(name = "Disable Flutter SSL Pinning") {
    dependsOn(hexPatch(ignoreMissingTargetFiles = true, block = {
        // Target: session_verify_cert_chain in libflutter.so
        // Replace conditional branch or verification check with MOV W0, #0 (Success)
        "F4 4F 01 A9 FD 7B 02 A9 FD 03 00 91" asPatternTo
        "E0 03 1F 2A C0 03 5F D6" inFile "lib/arm64-v8a/libflutter.so"
    }))
}
```

### Strategy C: Business Logic Hex Patching (`libapp.so`)
Use REA MCP (or Ghidra) to locate the native symbol in `libapp.so`:
1. Search strings for feature names or error messages.
2. Locate the function cross-reference.
3. Identify the ARM64 return instruction:
   - `MOV W0, #1`: `20 00 80 52`
   - `RET`: `C0 03 5F D6`
4. Formulate the pattern:
```kotlin
rawResourcePatch {
    dependsOn(hexPatch(ignoreMissingTargetFiles = true, block = {
        "ORIGINAL_BYTES_AT_ENTRY" asPatternTo "20 00 80 52 C0 03 5F D6" inFile "lib/arm64-v8a/libapp.so"
    }))
}
```

---

## 2. React Native & Hermes Bytecode

Modern React Native apps compile JavaScript into Hermes bytecode (`assets/index.android.bundle`).

### Strategy A: Java Native Module Bridge Hooks
React Native components interact with native Android APIs via `@ReactMethod` classes:
```kotlin
// Target the NativeModule method that returns entitlement/subscription status to JavaScript
// Override the Promise.resolve() call to pass true
val index = method.indexOfFirstInstruction(Opcode.INVOKE_INTERFACE)
method.addInstructions(index, """
    const/4 v1, 0x1
    invoke-static { v1 }, Ljava/lang/Boolean;->valueOf(Z)Ljava/lang/Boolean;
    move-result-object p1
""")
```

### Strategy B: Raw Bundle Replacement via `rawResourcePatch`
If JS logic needs direct modification:
```kotlin
rawResourcePatch(name = "Patch React Native Bundle") {
    execute {
        val bundleFile = get("assets/index.android.bundle")
        // Read, modify strings/constants, and save back
    }
}
```

---

## 3. Unity & IL2CPP Native Games

Unity games compile C# code into C++ via IL2CPP, producing `lib/arm64-v8a/libil2cpp.so` and `assets/bin/Data/Managed/Metadata/global-metadata.dat`.

### Analysis & Patching Workflow
1. Use Il2CppDumper (or REA MCP) with `libil2cpp.so` and `global-metadata.dat` to extract `dump.cs` method offsets.
2. Note the relative virtual address (RVA) of the target method (e.g. `isPurchased() -> RVA: 0x1A2B3C`).
3. Disassemble at the RVA to extract the first 8-16 bytes.
4. Replace function preamble with:
   - `MOV W0, #1; RET` (`20 00 80 52 C0 03 5F D6`)
5. In Morphe patch:
```kotlin
rawResourcePatch(name = "Unity Feature Enablement") {
    dependsOn(hexPatch(ignoreMissingTargetFiles = true, block = {
        "ORIGINAL_16_BYTES" asPatternTo "20 00 80 52 C0 03 5F D6" inFile "lib/arm64-v8a/libil2cpp.so"
    }))
}
```

---

## ARM64 Opcode Cheat Sheet

| Opcode / Instruction | Hex Representation (Little-Endian) | Purpose |
|---|---|---|
| `RET` | `C0 03 5F D6` | Return from function |
| `NOP` | `1F 20 03 D5` | No operation (neutralize instruction) |
| `MOV W0, #1` | `20 00 80 52` | Return boolean true (W0 = 1) |
| `MOV W0, #0` | `E0 03 1F 2A` | Return boolean false (W0 = 0) |
| `MOV X0, #0` | `E0 03 1F AA` | Return null pointer (X0 = 0) |
