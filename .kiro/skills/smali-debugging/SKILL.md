---
name: smali-debugging
description: Smali register budgeting, register expansion, parameter register mapping (p vs v), Dalvik opcodes, and diagnosing VerifyError and RegisterOutOfBoundsException. Use when writing or debugging smali bytecode instructions.
---

# Smali Bytecode Debugging & Register Management

Authoritative guidance for writing and debugging Dalvik smali instructions in Morphe patches.

## 1. Register Architecture: Locals (`v`) vs Parameters (`p`)

Every Dalvik method declares register allocation at its head:
- `.registers N`: Total registers allocated (locals + parameters).
- `.locals M`: Number of local registers only.

### Parameter Register Mapping
Parameters always occupy the **highest** registers in the method frame:
- For an instance method with `.locals 3` and 2 parameters:
  - `p0` (this instance) = `v3`
  - `p1` (first argument) = `v4`
  - `p2` (second argument) = `v5`
  - Total registers = 6 (`v0..v5`).
- For a static method:
  - `p0` is the first parameter (no `this`).

> [!CAUTION]
> If you inject code using `v0` without saving its state or ensuring it's dead, you clobber existing local variables!
> When you need temporary registers, either use `FreeRegisterProvider` or increase register allocation.

---

## 2. Register Expansion & Preservation

When injecting instructions into an existing method where all registers are occupied:

```kotlin
// In Morphe patcher:
val method = fingerprint.method
// Check free registers at insertion index:
val provider = method.getFreeRegisterProvider(index, numberOfFreeRegistersNeeded = 2)
val freeReg = provider.get()
```

If you manually expand registers via Smali:
- Remember that expanding `.registers` shifts the `v`-index of all `p` registers!
- Morphe's `addInstructions(...)` handles label resolution and register references, but when referencing raw `v` numbers, verify whether `p` registers were shifted.

---

## 3. Instruction Size & Register Limits (4-bit vs 8-bit vs 16-bit)

Many Dalvik opcodes restrict register indexes:
- `const/4 vA, #+B`: `vA` must be between `v0` and `v15` (4-bit register).
- `const/16 vA, #+B`: `vA` must be between `v0` and `v255` (8-bit register).
- `move-result vA`: `vA` can address `v0` to `v255`.
- `invoke-virtual { vC, vD, vE, vF, vG }`: takes up to 5 4-bit registers (`v0..v15`).
- `invoke-virtual/range { vCCCC .. vNNNN }`: takes a contiguous register range of 16-bit registers.

### The "Register Out of Bounds" Error
If your method has 20 registers and you write:
```smali
const/4 v18, 0x1  # CRASH! const/4 only accepts v0..v15
```
**Fix:** Use `const/16 v18, 0x1` or `const v18, 0x1`.

---

## 4. Diagnosing Common Dalvik Runtime Errors

### `java.lang.VerifyError`
- **Cause 1: Orphaned `move-result`**: A `move-result` or `move-result-object` MUST immediately follow an `invoke-*` or `filled-new-array` instruction. If you insert ANY instruction between an `invoke-*` and its `move-result`, the Android runtime verifier rejects the DEX at class-load time!
  - *Fix:* Insert instructions AFTER the `move-result`, or replace the `move-result` entirely.
- **Cause 2: Type Mismatch**: Using `move-result` (primitive) instead of `move-result-object` (object reference), or `return` instead of `return-object`.
- **Cause 3: Wide Register Pairs**: 64-bit primitives (`long`, `double`) occupy TWO registers (`v0` and `v1`). Calling an instruction that overwrites `v1` corrupts the pair.

### `java.lang.IncompatibleClassChangeError`
- Calling `invoke-virtual` on an interface method instead of `invoke-interface`.
- Calling `invoke-direct` on an overridden virtual method.

---

## 5. Safe Patching Recipes

### Return True at Method Start (Safest)
```kotlin
method.returnEarly(true)
// Equivalent to injecting:
// const/4 v0, 0x1
// return v0
```

### Overriding Result After Method Call
```kotlin
val index = method.indexOfFirstInstruction(Opcode.INVOKE_VIRTUAL)
val moveResultIndex = method.indexOfFirstInstruction(index, Opcode.MOVE_RESULT)
val reg = method.getInstruction<OneRegisterInstruction>(moveResultIndex).registerA

// Replace the move-result with a constant
method.replaceInstruction(moveResultIndex, "const/4 v$reg, 0x1")
```
