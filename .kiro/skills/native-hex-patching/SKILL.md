---
name: native-hex-patching
description: Native library (.so) patching using rawResourcePatch and hexPatch, ARM64 opcodes, offset calculation, and REA MCP disassembly workflows. Use when modifying native C++, Flutter, or Unity binaries.
---

# Native Hex Patching & REA MCP Workflow

Comprehensive methodology for modifying native shared libraries (`lib/**/*.so`) using Morphe `rawResourcePatch` with `hexPatch` and the Reverse Engineer Anything (REA) MCP server.

---

## 1. When to Use Native Hex Patching

Use `rawResourcePatch` with `hexPatch` when:
1. Target logic is compiled into C/C++ native libraries (e.g. `libnative.so`, `libibispaint.so`, `liborbit-jni-spotify.so`).
2. The application is built with Flutter (`libflutter.so`, `libapp.so`) and bypasses Dalvik bytecode.
3. The application is a Unity game running IL2CPP (`libil2cpp.so`).
4. JNI native methods execute client self-checks or certificate verification.

---

## 2. Reverse Engineering with REA MCP

Target Hunter utilizes REA MCP (`morluto/rea`) to inspect native libraries without leaving the AI workflow:

### Step A: Locate Exported Symbols
```bash
# REA tool query for JNI symbols:
# e.g. "Find symbols matching Java_ in libtarget.so"
```
JNI functions follow standard naming: `Java_<package_with_underscores>_<class>_<method>`.

### Step B: Disassemble ARM64 Function Entry
Inspect the function prologue and return instructions. For example, a boolean check:
```asm
; Original function prologue
stp x29, x30, [sp, #-16]!
mov x29, sp
...
; Decision branch
cbz w0, loc_fail
mov w0, #1
ret
loc_fail:
mov w0, #0
ret
```

### Step C: Formulate the Byte Replacement
To force the function to return `true` immediately:
- Replace the function prologue with:
  ```asm
  mov w0, #1
  ret
  ```
- In hex (little-endian ARM64):
  - `MOV W0, #1` = `20 00 80 52`
  - `RET` = `C0 03 5F D6`
  - Pattern: `20 00 80 52 C0 03 5F D6`

---

## 3. Morphe `hexPatch` Syntax

In Morphe patch code, wrap hex replacements in `rawResourcePatch`:

```kotlin
package <group>.patches.<app>.native

import app.morphe.patcher.patch.rawResourcePatch
import app.morphe.patcher.util.hex.HexPatchBuilder.hexPatch
import <group>.patches.<app>.shared.Constants.COMPATIBILITY_<APP>

@Suppress("unused")
val nativeFeaturePatch = rawResourcePatch(
    name = "Native Feature Enablement",
    description = "Adapts native binary function return values via ARM64 byte replacement."
) {
    compatibleWith(COMPATIBILITY_<APP>)
    dependsOn(hexPatch(ignoreMissingTargetFiles = true, block = {
        val originalHex = "F4 4F 01 A9 FD 7B 02 A9 FD 03 00 91"
        val patchedHex  = "20 00 80 52 C0 03 5F D6 1F 20 03 D5"

        // Apply to 64-bit ARM
        originalHex asPatternTo patchedHex inFile "lib/arm64-v8a/libfoo.so"
    }))
}
```

### Critical Rules
1. **Always use `ignoreMissingTargetFiles = true`**: APKs may be split APKs or contain only specific ABIs on certain target devices. If `ignoreMissingTargetFiles = false`, patching fails if an APK lacks one of the ABIs!
2. **Byte length must match**: When using `asPatternTo`, the replacement string must have the **exact same number of bytes** as the original target pattern. Pad remaining bytes with ARM64 `NOP` (`1F 20 03 D5`).

---

## 4. ARM64 Common Opcode Table

| Instruction | Hex (Little-Endian) | Purpose |
|---|---|---|
| `ret` | `C0 03 5F D6` | Return immediately |
| `nop` | `1F 20 03 D5` | No-op (fill/neutralize instruction) |
| `mov w0, #1` | `20 00 80 52` | Return boolean true / int 1 |
| `mov w0, wzr` (`mov w0, #0`) | `E0 03 1F 2A` | Return boolean false / int 0 |
| `mov x0, xzr` (`mov x0, #0`) | `E0 03 1F AA` | Return null pointer |
