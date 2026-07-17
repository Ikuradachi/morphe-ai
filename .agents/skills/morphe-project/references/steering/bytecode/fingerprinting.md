# Morphe Fingerprinting — Official Reference

A fingerprint is a partial description of a method used to uniquely match it by stable characteristics that survive app updates. Obfuscated names change every release — fingerprints match on return type, access flags, parameters, and instruction patterns instead.

## Fingerprint Declaration

All fields are optional — use only what's needed to uniquely identify:

```kotlin
object MyFingerprint : Fingerprint(
    definingClass = "Lcom/example/Class;",   // StringComparisonType semantics
    name = "methodName",                      // Only for non-obfuscated methods
    accessFlags = listOf(AccessFlags.PUBLIC, AccessFlags.FINAL),
    returnType = "Z",
    parameters = listOf("Ljava/lang/String;", "I", "L"),  // "L" for obfuscated classes

    // Ordered instruction filters (must appear in same order as target method)
    filters = listOf(
        fieldAccess(opcode = Opcode.IGET, definingClass = "this", type = "Ljava/util/Map;"),
        string("showBannerAds"),
        methodCall(definingClass = "Ljava/lang/String;", name = "equals"),
        opcode(Opcode.MOVE_RESULT, InstructionLocation.MatchAfterImmediately()),
        literal(1337),
        opcode(Opcode.IF_EQ),
    ),

    // Unordered string matching (for methods with many strings in random order)
    strings = listOf("unordered1", "unordered2"),

    // Custom predicate
    custom = { method, classDef -> classDef.type == "Lcom/target/Class;" },

    // Find class via another fingerprint first
    classFingerprint = AnotherFingerprint,
)
```

## Filter Types

| Filter | Usage |
|--------|-------|
| `string("text")` | Match const-string instruction |
| `methodCall(definingClass, name, parameters, returnType)` | Match invoke-* instruction |
| `methodCall(smali = "Landroid/net/Uri;->parse(Ljava/lang/String;)Landroid/net/Uri;")` | Smali shorthand |
| `fieldAccess(opcode, definingClass, name, type)` | Match field get/put |
| `fieldAccess(smali = "Landroid/os/Build;->MODEL:Ljava/lang/String;")` | Smali shorthand |
| `opcode(Opcode.X)` | Match specific opcode |
| `literal(value)` | Match const literal |
| `anyInstruction(filter1, filter2)` | Match any alternative (for version differences) |

## InstructionLocation Options

- Default: match anywhere after previous filter
- `MatchAfterImmediately()`: must be immediately after previous filter
- `MatchAfterWithin(n)`: within n instructions of previous filter
- `MatchFirst()`: must be first instruction in method

## String Declarations — Two Ways

1. **Preferred — ordered via filters**: `filters = listOf(string("foo"), string("bar"))` — order must match target method
2. **Unordered via strings**: `strings = listOf("foo", "bar")` — matches in any order, useful for enums with many strings

## Using Fingerprints in Patches

```kotlin
execute {
    // Auto-matches on first access, cached for reuse
    MyFingerprint.method.addInstructions(0, "...")

    // Access instruction match indices
    val index = MyFingerprint.instructionMatches[0].index
    val reg = MyFingerprint.instructionMatches[0].getInstruction<OneRegisterInstruction>().registerA

    // Access class
    val classDef = MyFingerprint.originalClassDef

    // Null-safe access
    val methodOrNull = MyFingerprint.methodOrNull

    // Match all occurrences
    Fingerprint(filters = listOf(string("target"))).matchAllOrNull()?.forEach { match ->
        match.method.apply { /* modify */ }
    }

    // Manual matching in specific class
    MyFingerprint.match(SomeOtherFingerprint.originalClassDef)
}
```

## Fingerprint Properties

| Property | Returns | On no match |
|----------|---------|-------------|
| `originalClassDef` | Immutable class | Exception |
| `originalClassDefOrNull` | Immutable class | null |
| `originalMethod` | Immutable method | null |
| `classDef` | Mutable class (replaces original) | Exception |
| `method` | Mutable method (replaces original) | Exception |
| `methodOrNull` | Mutable method | null |

Use `original*` for read-only access (avoids creating mutable copy).

## Class-Based Fingerprint Chaining

Find class via one fingerprint, then find method within it:

```kotlin
val showAdFingerprint = Fingerprint(
    classFingerprint = Fingerprint(name = "toString", strings = listOf("classField=")),
    returnType = "Z",
    filters = listOf(
        methodCall(name = "getValue", returnType = "Z"),
        opcode(Opcode.MOVE_RESULT, MatchAfterImmediately())
    )
)
```

## Dynamic Fingerprints (using prior match results)

```kotlin
execute {
    val dynamicFingerprint = Fingerprint(
        definingClass = SomeFingerprint.originalClassDef.type,
        returnType = "V",
        filters = listOf(fieldAccess(opcode = Opcode.IPUT_BOOLEAN, reference = someField))
    )
    dynamicFingerprint.method.apply { /* modify */ }
}
```

## Multiple Modifications — Index Safety

When modifying multiple instructions, work from last index to first:

```kotlin
AdLoaderFingerprint.let {
    // Last filter first
    val filter6 = it.instructionMatches[5]
    it.method.removeInstruction(filter6.index)

    // Then earlier filter
    val filter4 = it.instructionMatches[3]
    val reg = filter4.getInstruction<OneRegisterInstruction>().registerA
    it.method.addInstructions(filter4.index + 1, "const/4 v$reg, 0x0")
}
```

Or use `clearMatch()` + `match()` to refresh indices after modifications.

## Critical Rules

- NEVER use obfuscated class/method names (`a`, `b`, `H`)
- Non-obfuscated names (`isPremium`, `getEntitlements`) are safe
- Filters must appear in same order as target method instructions
- Declare as `object` classes for named stack traces on match failure
- Always verify against smali bytecode, not jadx Java output
- Fingerprints match once and cache — safe to share between patches
- Use `"L"` for obfuscated parameter types
- Use `definingClass = "this"` for self-referencing fields
