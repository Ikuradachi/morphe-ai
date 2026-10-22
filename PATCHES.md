# Morphe Patches Guide & Best Practices

Comprehensive guide, rules, tips, and conventions for developing, configuring, maintaining, and releasing Morphe patch repositories based on [`morphe-patches-template`](https://github.com/MorpheApp/morphe-patches-template).

---

## 1. Repository Setup & Configuration

When initializing a new patch repository from [`morphe-patches-template`](https://github.com/MorpheApp/morphe-patches-template), follow this checklist carefully.

### 1.1 Checklist for New Repositories

- [ ] **Include All Branches**: When creating the repository on GitHub from the template, **check "Include all branches"**. Both `main` and `dev` branches are required for the automated release workflow and PR backmerge.
- [ ] **GitHub Actions Permissions**:
  - Navigate to **Settings > Actions > General > Workflow permissions**.
  - Check **"Read and write permissions"**.
  - Check **"Allow GitHub Actions to create and approve pull requests"** (required for `open_pull_request.yml` when pushing to `dev`).
- [ ] **GitHub Personal Access Token (PAT)**:
  - Configure environment and Gradle credentials with a GitHub PAT with `read:packages` to download Morphe dependencies from GitHub Packages Maven registry.
- [ ] **Project Naming Rules (NOTICE 7c)**:
  - **DO NOT** name the repository or project "Morphe", "Morphe Patches", or any name implying official authorship or endorsement by the Morphe project.
  - **DO** use clear personal or app-specific descriptive names, e.g., `UserXYZ Morphe Patches`, `carbit-patches`, or `Example Patches for Morphe`.
- [ ] **Configure `patches/build.gradle.kts`**:
  - Update `group` (e.g. `group = "com.yourname"`).
  - Update the `patches { about { ... } }` metadata block:
    ```kotlin
    group = "com.example.patches"

    patches {
        about {
            name = "Example Patches"
            description = "Morphe patches for Example App"
            source = "git@github.com:youruser/example-patches.git"
            author = "youruser"
            contact = "https://example.com/contact"
            website = "https://example.com"
            license = "GPLv3"
        }
    }
    ```
- [ ] **Configure `README.md`**:
  - Update description and about sections.
  - **DO NOT** manually edit between `<!-- PATCHES_START -->` and `<!-- PATCHES_END -->`. This section is auto-populated by the release workflow from `patches-list.json`.
  - Use `<!-- PATCHES_START EXPANDED -->` if you want patch details expanded by default, or remove `EXPANDED` to collapse them.
  - Update the source URL link: `https://morphe.software/add-source?github=youruser/your-patches-repo`.
- [ ] **Update Issue Templates**:
  - Update links in `.github/ISSUE_TEMPLATE/bug_report.yml` and `feature_request.yml` to point to your repository rather than the template placeholder.
- [ ] **Optional Branding**:
  - Add a square icon or banner named `patches-bundle.png` at the project root for display in Morphe Manager.

---

## 2. Git Branching & Release Workflow

The template relies on `semantic-release` to generate versions, release bundles (`.mpp`), update changelogs, and maintain documentation.

```
       [Feature / Bugfix / Bump Commit]
                      │
                      ▼
               Push to `dev`
                      │
                      ├──> Triggers `open_pull_request.yml` (dev -> main)
                      │
                      ├──> Compiles & publishes prerelease (if configured)
                      │
                      ▼
               Merge PR to `main`
                      │
                      ├──> Runs `release.yml`
                      ├──> Calculates semver bump from conventional commits
                      ├──> Builds `patches-<version>.mpp`
                      ├──> Updates CHANGELOG.md, gradle.properties, patches-*.json, README.md
                      ├──> Commits with `chore: Release v<version> [skip ci]`
                      ├──> Creates GitHub Release with .mpp asset & build provenance
                      └──> Backmerges `main` back into `dev`
```

### 2.1 Commit Message Rules (Conventional Commits)

Releases are strictly driven by commit messages:

| Commit Type | Scope / Example | Release Impact | Section in Changelog |
|-------------|-----------------|----------------|----------------------|
| `feat:` | `feat: add ad-blocking patch` | **Minor** (`x.Y.0`) | ✨ New Features |
| `fix:` | `fix: resolve crash on app launch` | **Patch** (`x.y.Z`) | 🐛 Bug Fixes |
| `bump:` | `bump: support app version 2.4.0` | **Patch** (`x.y.Z`) | 🚀 Updated App Support |
| `perf:` | `perf: optimize fingerprint search` | **Patch** (`x.y.Z`) | 🔧 Improvements |
| `build:` | `build(Needs bump): update deps` | **Patch** (`x.y.Z`) | (Only when scope is `Needs bump`) |
| `chore:` | `chore: update issue templates` | **No release** | Hidden |
| `docs:` | `docs: clarify setup steps` | **No release** | Hidden |

> [!IMPORTANT]
> - **Always work on `dev`**, never push directly to `main`.
> - **Always run `git pull`** on your local machine after a release or push, because CI auto-commits generated release artifacts (`CHANGELOG.md`, `gradle.properties`, `patches-bundle.json`, `patches-list.json`, `README.md`) back to the branch.

---

## 3. Patch Architecture & Source Conventions

### 3.1 Patch Types

Choose the most lightweight patch type suitable for the task:

1. **`bytecodePatch` (Preferred)**:
   - Operates on Dalvik bytecode classes.
   - Use whenever you are mutating methods, hooking calls, adding instructions, or integrating extensions.
   - Fast and does not incur resource de-compilation or re-compilation overhead.
2. **`rawResourcePatch`**:
   - Operates directly on files/assets in the APK archive without decoding resource tables (e.g. deleting or replacing native `.so` files, adding raw assets).
3. **`resourcePatch`**:
   - Decodes resources and AndroidManifest XML.
   - Highest performance overhead; only use when modifying `strings.xml`, XML layouts, or manifest attributes.

### 3.2 Compatibility Definitions

Each patch or group of patches defines target compatibility:

```kotlin
val COMPATIBILITY_EXAMPLE = Compatibility(
    packageName = "com.example.app",
    name = "Example App",
    description = "Optional description",
    apkFileType = ApkFileType.XAPK, // or APK, APKM, APKS (use _REQUIRED to strictly enforce)
    appIconColor = 0x1A73E8,        // 0xRRGGBB integer (DO NOT include alpha byte!)
    signatures = setOf(
        "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789", // SHA-256
    ),
    targets = listOf(
        AppTarget(version = "2.5.0", minSdk = 26),
        AppTarget(version = "2.4.1", minSdk = 26, isExperimental = true),
    ),
)
```

**Key Rules for Compatibility**:
- `packageName` requires a non-blank `name`.
- `appIconColor`: Must be a 6-hex RGB format (`0xRRGGBB` or `"#RRGGBB"`). **Never use `0xFF...` with alpha byte**, which causes an assertion/format error.
- Signatures: 64-hex SHA-256 certificate digest from `apksigner verify --print-certs <apk>`.
- `AppTarget(version = null)` can be used to target any version without strict version gating.
- Use `COMPATIBILITY.including(...)` or `.excluding(...)` to derive variant targets for specific sub-patches.

### 3.3 Extensions

- Extension modules live under `extensions/<name>/` and compile helper Java/Kotlin code bundled into `.mpe` DEX artifacts (Morphe Patch Extension).
- In patches, attach extensions with:
  ```kotlin
  extendWith("extensions/my-extension.mpe")
  ```
- Note the distinction: `.mpe` is an extension DEX artifact; `.mpp` is the overall patch bundle.

---

## 4. Fingerprinting & Smali Mutation Rules

Fingerprints identify target bytecode methods across different app releases without relying on unstable names.

### 4.1 Fingerprint Declarations

- **Use Named Objects**:
  ```kotlin
  object BillingCheckFingerprint : Fingerprint(
      returnType = "Z",
      accessFlags = listOf(AccessFlags.PUBLIC, AccessFlags.FINAL),
      parameters = listOf("Landroid/content/Context;"),
      filters = listOf(
          methodCall(
              definingClass = "Lcom/android/billingclient/api/Purchase;",
              name = "getPurchaseState",
          ),
          opcode(Opcode.MOVE_RESULT, InstructionLocation.MatchAfterImmediately()),
      ),
  )
  ```
  - Named objects provide clear method names in failure stack traces.
  - **DO NOT** use the deprecated `fingerprint { ... }` builder DSL.

### 4.2 Target Selection & Fingerprint Stability

- **DO NOT target obfuscated names**: Never match against obfuscated class names (`La/b/c;`), obfuscated method names (`method a()`), or obfuscated field names. They change between version builds.
- **DO target stable elements**:
  - Android framework APIs (`Landroid/...`, `Ljava/...`).
  - Third-party SDK signatures (e.g. Google Play Billing, OkHttp, Firebase).
  - Constant string literals (log tags, error messages, configuration keys).
  - Numerical constants and resource ID literals (`resourceLiteral`).
  - Ordered filter chains with `InstructionLocation.MatchAfterImmediately()` or `MatchAfterWithin(n)`.
- **Parameter descriptors**: Use `"L"` as a wildcard prefix for obfuscated parameter types where the class name cannot be guaranteed.

### 4.3 Bytecode Instruction Mutation Rules

- **Use indexed instruction methods**:
  ```kotlin
  // CORRECT
  method.addInstructions(index, "const/4 v0, 0x1\nreturn v0")

  // DEPRECATED (Do not use)
  method.addInstructions("const/4 v0, 0x1\nreturn v0")
  ```
- **Descending Index Order**: When adding or removing instructions at multiple indexes in the same method, **always perform modifications from the highest index to lowest index**. Modifying earlier indexes shifts the positions of all subsequent instructions. Alternatively, clear and re-match the fingerprint.
- **Preserve Bytecode Invariants**:
  - **`move-result` / `move-result-object` / `move-result-wide`**: Must immediately follow the invoke instruction. Never insert instructions between an `invoke-*` and its corresponding `move-result`.
  - **Branch targets and labels**: Do not clobber target branch offsets. Use `addInstructionsWithLabels` with `ExternalLabel` if branching across injected code.
  - **Try/catch blocks**: Ensure injected instructions do not unintentionally split or invalidate exception handler ranges.
  - **Register types and pairs**: Wide types (`long`, `double`) use two register slots (`v0`, `v1`). Respect register counts and parameter registers (`p0`, `p1`, ...).

---

## 5. Local Building, Testing & CLI Validation

Always validate patches locally before committing or opening pull requests.

### 5.1 Local Build

```bash
# Build the patch bundle (.mpp)
./gradlew buildAndroid
# or from root if multi-repo:
cd "${MORPHE_PATCHES_DIR:-patches-repo}" && ./gradlew buildAndroid
```

The compiled patch bundle will be located at:
`patches/build/libs/patches-<version>.mpp`

### 5.2 Patch Verification with Morphe CLI

Verify patch bundle registration and inspect options:

```bash
MPP="patches/build/libs/patches-$(grep '^version' gradle.properties | cut -d= -f2 | tr -d ' ').mpp"

# Verify patch registration and compatibility
java -jar morphe-cli.jar list-patches --patches "$MPP" --with-packages --with-versions --with-options

# Test patch application on target APK
java -jar morphe-cli.jar patch \
  --patches "$MPP" \
  --exclusive \
  --enable "My Patch Name" \
  --out "output-patched.apk" \
  "path/to/target.apk"
```

### 5.3 Working with Split APKs (APKM / XAPK / APKS)

- When testing split APK packages, **always pass the full container (`.apkm`, `.xapk`, `.apks`) to Morphe CLI**.
- The CLI natively unpacks and merges split containers.
- **DO NOT** test solely on an extracted `base.apk` if the application relies on resources or native libraries located in split slices.

---

## 6. Critical Safety Rules & Pitfalls

### ⛔ What NEVER to Do

| Action | Why it is prohibited | Correct Alternative |
|---|---|---|
| **DO NOT execute `utility clear-cache`** | It immediately deletes downloaded bundles, logs, and temporary cache without confirmation. | Inspect flags with `utility clear-cache --help` only. |
| **DO NOT push directly to `main`** | Bypasses pull request checks, risks breaking semantic release backmerges, and bypasses test gates. | Push feature/fix branches or commits to `dev`. |
| **DO NOT edit `README.md` patch table by hand** | GitHub Actions overwrites everything between `<!-- PATCHES_START -->` and `<!-- PATCHES_END -->` during release. | Let CI update it, or remove comment tags completely if manual maintenance is explicitly desired. |
| **DO NOT use alpha bytes in `appIconColor`** | `0xFF6200EE` throws invalid color format error. | Use 6-hex RGB format: `0x6200EE` or `"#6200EE"`. |
| **DO NOT fingerprint obfuscated method/class names** | Obfuscated names (`a.b.c.d()`) change in every app update, instantly breaking patches. | Match SDK methods, string literals, and opcodes. |
| **DO NOT insert instructions between invoke and `move-result`** | Breaks Dalvik bytecode verification; the APK will crash with `VerifyError`. | Insert before the invoke or after the `move-result`. |
| **DO NOT add `--force` to patch commands without cause** | `--force` disables app version checks and masks incompatibility bugs. | Fix the fingerprint or explicitly register the new version in `AppTarget`. |
| **DO NOT name project with official "Morphe" marks** | Violates Morphe project license NOTICE (7c). | Use distinct branding (e.g. `UserXYZ Patches for Morphe`). |

---

## 7. Quick Reference: DOs and DON'Ts

```
┌──────────────────────────────────────────────┬──────────────────────────────────────────────┐
│                    DO                        │                    DON'T                     │
├──────────────────────────────────────────────┼──────────────────────────────────────────────┤
│ Enable "Include all branches" from template  │ Forget 'dev' branch when creating repo       │
│ Enable Actions PR permissions in Settings    │ Let 'open_pull_request.yml' fail silently    │
│ Commit using Conventional Commits            │ Use generic messages like "update", "fix"    │
│ Develop on 'dev' and let CI open PR to 'main'│ Push commits directly to 'main'              │
│ Run 'git pull' after CI creates a release    │ Leave local branch behind remote CI commits  │
│ Use 'bytecodePatch' whenever possible        │ Default to 'resourcePatch' for simple hooks  │
│ Use named 'object X : Fingerprint(...)'      │ Use deprecated 'fingerprint { }' DSL         │
│ Mutate instructions from high to low index   │ Insert at low index and shift later offsets  │
│ Target full split containers (.apkm, .xapk)  │ Test on bare extracted base.apk only         │
│ Use 6-digit RGB color (0xRRGGBB)             │ Use 8-digit ARGB color with alpha (0xFF...)  │
└──────────────────────────────────────────────┴──────────────────────────────────────────────┘
```
