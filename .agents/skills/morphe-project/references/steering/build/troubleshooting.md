# Troubleshooting & FAQ

## Build Issues

**Auth failure**: Add GitHub PAT to `~/.gradle/gradle.properties`:
```properties
gpr.user = <username>
gpr.key = <token with read:packages>
```
Or use `gh auth` with GitHub CLI.

**Wrong JDK**: Ensure JDK 17 is set. Check `JAVA_HOME` and IDE settings.

**MPP file names change**: After pulling new commits, update paths in run configurations.

## Patching Issues

**Fingerprint match failure**: The target app version likely changed the method. Update the fingerprint filters to match the new bytecode. Use jadx to decompile and inspect.

**Patch fails silently**: Check if `default = false` — patch may not be enabled. Use `-e "Patch Name"` to explicitly enable.

**Extension class not found**: Ensure `extendWith("extensions/name.mpp")` path matches the extension build output.

## App-Specific Notes

**YouTube**: Requires MicroG-RE for Google account login on non-root. Package: `com.google.android.youtube`. APK type: `APK_REQUIRED`.

**YouTube Music**: Same MicroG requirement. Package: `com.google.android.apps.youtube.music`.

**Reddit**: Uses APKM format (split APKs). Package: `com.reddit.frontpage`. Signature spoofing needed.

## Common Patterns for Debugging

```bash
# List all patches and their status
java -jar morphe-cli.jar list-patches --with-packages --with-versions --with-options patches.mpp

# Capture Android logs
adb logcat | grep 'morphe\|AndroidRuntime'

# Check patch version in app
# Settings > Morphe > About
```

## Key URLs
- Website: https://morphe.software
- Patches issues: https://github.com/MorpheApp/morphe-patches/issues
- MicroG download: https://morphe.software/microg
- Translations: https://morphe.software/translate
