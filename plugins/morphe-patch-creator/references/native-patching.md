# Native Library (.so) Patching & REA Analysis Reference

This guide covers analyzing native Android libraries (`.so`) using **REA (Reverse Engineer Anything)** and applying binary/hex patches using Morphe's `rawResourcePatch` and `HexPatchBuilder`.

---

## 1. When Native Patching is Required

Android applications often delegate critical security, media, networking, or core logic to native C/C++ libraries or non-JVM runtimes:
- **Flutter apps**: Core Dart logic is compiled AOT into `libapp.so` / `libflutter.so`.
- **Unity / Unreal games**: C# logic compiled to native code via IL2CPP (`libil2cpp.so`, `libunity.so`).
- **JNI security gates**: Root detection, emulator checks, signature verification, integrity checks, or DRM implemented in C/C++ (e.g. `libnative-lib.so`, `libcore.so`).
- **Network / API endpoints**: Hardcoded client tokens, cryptographic seeds, or API base URLs inside native binaries (e.g. Spotify `liborbit-jni-spotify.so`).

Bytecode patching cannot modify machine code inside `.so` files. You must use native analysis and binary hex patching.

---

## 2. Reverse Engineering Native Libraries with REA

REA provides semantic analysis, disassembly, and decompilation across architectures (ARM64, ARMv7, x86, x86_64).

### Step 1: Extract Target `.so` from APK
```bash
# List native libraries in APK
unzip -l <apk-path> | grep "\.so"

# Extract library for target ABI (prefer arm64-v8a for modern 64-bit devices)
mkdir -p analysis/<app>/native/arm64-v8a
unzip -p <apk-path> "lib/arm64-v8a/<libname>.so" > analysis/<app>/native/arm64-v8a/<libname>.so
```

### Step 2: Semantic Analysis with REA
Use REA via CLI or MCP tools:

1. **Locate JNI exports and symbols**:
   ```bash
   rea search-procedures analysis/<app>/native/arm64-v8a/<libname>.so "Java_"
   rea list-names analysis/<app>/native/arm64-v8a/<libname>.so
   ```
2. **Search strings and URLs**:
   ```bash
   rea search-strings analysis/<app>/native/arm64-v8a/<libname>.so "http"
   rea search-strings analysis/<app>/native/arm64-v8a/<libname>.so "isPremium"
   ```
3. **Disassemble target procedure**:
   ```bash
   rea procedure-assembly analysis/<app>/native/arm64-v8a/<libname>.so <procedure_name_or_address>
   ```
4. **Decompile to pseudo-code**:
   ```bash
   rea procedure-pseudo-code analysis/<app>/native/arm64-v8a/<libname>.so <procedure_name_or_address>
   ```
5. **Inspect surrounding bytes**:
   ```bash
   rea read-bytes analysis/<app>/native/arm64-v8a/<libname>.so <address> <byte_length>
   ```

---

## 3. Designing Hex Patches (Opcode Reference)

When modifying native machine code, replace target instructions with equivalent-length opcodes.

### A. ARM64 (AArch64) — 4-byte aligned instructions (Little-Endian)

| Intent | Assembly | Hex bytes (Little Endian) |
|---|---|---|
| **NOP** (No operation) | `nop` | `1F 20 03 D5` |
| **Return immediately** | `ret` | `C0 03 5F D6` |
| **Return true / 1** | `mov w0, #1` | `20 00 80 52` |
| **Return false / 0** | `mov w0, wzr` | `E0 03 1F 2A` |
| **Return null / 0 (64-bit)** | `mov x0, xzr` | `E0 03 1F AA` |
| **Return true immediately** | `mov w0, #1`<br>`ret` | `20 00 80 52 C0 03 5F D6` |
| **Return false immediately** | `mov w0, wzr`<br>`ret` | `E0 03 1F 2A C0 03 5F D6` |

### B. ARMv7 (Thumb-2 / ARM32)

- **Thumb-2 (2-byte / 4-byte)**:
  - `nop`: `00 BF`
  - `bx lr` (return): `70 47`
  - `movs r0, #1` + `bx lr`: `01 20 70 47`
  - `movs r0, #0` + `bx lr`: `00 20 70 47`
- **ARM32 (4-byte)**:
  - `nop`: `00 F0 20 E3`
  - `bx lr`: `1E FF 2F E1`
  - `mov r0, #1`: `01 00 A0 E3`
  - `mov r0, #0`: `00 00 A0 E3`

### C. String / URL Redirection
When redirecting URLs or endpoints:
- Replacement string must **not exceed** the length of the original string in the `.rodata` section.
- Pad shorter strings with null bytes (`\x00`).
- Example: `"https://clienttoken.spotify.com/v1/clienttoken"` → `"http://127.0.0.1:8080/v1/clienttoken\x00..."`

---

## 4. Morphe Patch Implementation

Morphe provides two primary approaches for `.so` binary patching:

### Pattern 1: `rawResourcePatch` with `HexPatchBuilder` (Preferred)
```kotlin
package app.morphe.patches.myapp.nativepatch

import app.morphe.patcher.patch.AppTarget
import app.morphe.patcher.patch.Patch
import app.morphe.patcher.patch.rawResourcePatch
import app.morphe.patches.all.misc.hex.hexPatch

@Patch(
    name = "BypassNativeCheck",
    description = "Hex-patches ARM64 instructions in libnative.so to disable integrity verification.",
    target = AppTarget("com.example.app")
)
fun bypassNativeCheckPatch() = rawResourcePatch {
    dependsOn(hexPatch(ignoreMissingTargetFiles = true, block = {
        val libPath = "lib/arm64-v8a/libnative.so"

        // Search for unique context pattern and replace target instruction:
        // Example: Replace conditional branch with return true (mov w0, #1; ret)
        "28 AE 00 90 08 55 47 F9 08 FD DF 88 1F 05 00 71" asPatternTo
        "28 AE 00 90 08 55 47 F9 20 00 80 52 C0 03 5F D6" inFile libPath
    }))
}
```

### Pattern 2: Multi-Architecture URL Redirection
```kotlin
fun redirectNativeApiPatch() = rawResourcePatch {
    dependsOn(hexPatch(ignoreMissingTargetFiles = true, block = {
        listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64").forEach { arch ->
            val lib = "lib/$arch/libnetwork.so"
            "https://license.example.com/api/v1/check" to
                "http://127.0.0.1:8080/api/v1/check\u0000" inFile lib
        }
    }))
}
```

### Pattern 3: Fallback Direct File Mutation
If `HexPatchBuilder` is unavailable in the target repository setup, use direct file operations via `ResourcePatchContext`:
```kotlin
fun directBinaryPatch() = rawResourcePatch {
    execute { context ->
        listOf("arm64-v8a", "armeabi-v7a").forEach { arch ->
            val soFile = context.get("lib/$arch/libnative.so")
            if (soFile.exists()) {
                val bytes = soFile.readBytes()
                val target = byteArrayOf(0x02, 0x00, 0x00, 0x14) // original bytes
                val replacement = byteArrayOf(0x1F, 0x20, 0x03, 0xD5.toByte()) // NOP

                val patched = replaceFirstOccurrence(bytes, target, replacement)
                soFile.writeBytes(patched)
            }
        }
    }
}
```

---

## 5. Verification Rules

1. **Uniqueness**: Search the entire `.so` binary for the original hex pattern before patching to ensure it matches **exactly once**. Never replace an ambiguous pattern.
2. **Context Window**: Include 8–16 bytes of surrounding unchanged opcodes in `asPatternTo` to guarantee precise anchoring.
3. **Multi-ABI Check**: Verify if the APK ships multiple ABIs. If supporting 32-bit (`armeabi-v7a`) alongside 64-bit (`arm64-v8a`), provide distinct architecture-appropriate opcodes.
4. **Idempotence**: Running the patch twice should safely detect that the original pattern is already replaced or handled without corruption.
