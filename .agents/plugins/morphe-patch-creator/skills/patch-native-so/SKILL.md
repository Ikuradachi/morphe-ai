---
name: patch-native-so
description: Analyze native Android ELF libraries (.so) using REA and implement Morphe hex/binary patches. Use when targets reside in native code (C/C++, Flutter AOT libapp.so, Unity libil2cpp.so, or JNI libraries) rather than DEX bytecode.
context: fork
background: false
argument-hint: [app-key] [library-name] [target-function-or-behavior]
---

# Patch Native Library (.so)

Use this workflow when target behavior lives in native C/C++, Flutter AOT (`libapp.so`), or Unity IL2CPP (`libil2cpp.so`) instead of DEX bytecode.

Before starting, read `plugins/morphe-patch-creator/references/native-patching.md`.

## 1. Extract Target Native Library
1. List architectures and libraries:
   ```bash
   unzip -l <apk-path> | grep "\.so"
   ```
2. Extract the library for target ABI (e.g. `arm64-v8a`):
   ```bash
   mkdir -p analysis/<app>/native/arm64-v8a
   unzip -p <apk-path> "lib/arm64-v8a/<libname>.so" > analysis/<app>/native/arm64-v8a/<libname>.so
   ```

## 2. REA Semantic Analysis
Use REA via CLI or MCP tools to locate functions, symbols, and instruction sequences:

1. **Symbol & Export Discovery**:
   - `rea search-procedures analysis/<app>/native/arm64-v8a/<libname>.so "Java_"`
   - `rea list-names analysis/<app>/native/arm64-v8a/<libname>.so`
2. **String & URL Discovery**:
   - `rea search-strings analysis/<app>/native/arm64-v8a/<libname>.so "<search_term>"`
3. **Disassembly & Decompilation**:
   - `rea procedure-assembly analysis/<app>/native/arm64-v8a/<libname>.so <procedure_or_address>`
   - `rea procedure-pseudo-code analysis/<app>/native/arm64-v8a/<libname>.so <procedure_or_address>`
4. **Byte Verification**:
   - `rea read-bytes analysis/<app>/native/arm64-v8a/<libname>.so <address> <length>`
   - Verify that the target byte sequence with 8–16 bytes of surrounding context occurs **exactly once** in the binary.

## 3. Formulate Hex Patch
Determine the target opcodes based on architecture:

- **ARM64**:
  - NOP: `1F 20 03 D5`
  - Return early: `C0 03 5F D6` (`ret`)
  - Force True (1): `20 00 80 52 C0 03 5F D6` (`mov w0, #1; ret`)
  - Force False (0): `E0 03 1F 2A C0 03 5F D6` (`mov w0, wzr; ret`)
- **ARMv7 (Thumb-2)**:
  - NOP: `00 BF`
  - Return True (1): `01 20 70 47` (`movs r0, #1; bx lr`)
  - Return False (0): `00 20 70 47` (`movs r0, #0; bx lr`)
- **String/URL Redirect**:
  - Overwrite in `.rodata`, padding with `\x00` if replacement is shorter.

## 4. Write Morphe Patch
Implement in the configured patch repository (`${MORPHE_PATCHES_DIR}`):

```kotlin
@Patch(
    name = "PatchName",
    description = "Hex-patches native library.",
    target = AppTarget("<package-name>")
)
fun patchName() = rawResourcePatch {
    dependsOn(hexPatch(ignoreMissingTargetFiles = true, block = {
        val lib = "lib/arm64-v8a/<libname>.so"
        "<unique-original-hex-with-context>" asPatternTo
        "<unique-patched-hex-with-context>" inFile lib
    }))
}
```

Fallback: If `HexPatchBuilder` is not imported, use `context.get("lib/<abi>/<libname>.so")` inside `execute { context -> ... }`.

## 5. Verification & Report
1. Verify with `./gradlew buildAndroid` in the patch repository.
2. Confirm patch registration via Morphe CLI: `java -jar morphe-cli.jar list-patches --patches <mpp-path>`.
3. Document exact file offset, architecture, original opcodes, replacement opcodes, and REA procedure findings in `analysis/<app>/notes/native-<target>.md`.
