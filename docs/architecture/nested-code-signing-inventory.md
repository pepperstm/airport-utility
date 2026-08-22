# Nested code-signing inventory (Developer ID / hardened runtime)

This inventory supports Phase C (notarised distribution) and assumes
ADR-0001's decision (freeze the backend into a self-contained `--onedir`
executable) has been implemented. It lists every category of file that will
exist inside `AirPort Utility.app` once that lands, and what signing each one
needs. It was produced without access to a Mac; the concrete file list below
comes from running the same freezer (PyInstaller) against the same backend
code in this repository's Linux prototype (`Prototype/self-contained-runtime/`)
as a structural proxy. **The exact filenames will differ on macOS** — Linux
`.so`/`.so.N` becomes macOS `.dylib`/`.framework`, and macOS CPython builds
typically ship individual extension modules as separate files (a
`lib-dynload`-style directory of many small `.so` bundles) rather than the
handful of shared libraries this Linux build produced. Re-run
`Prototype/self-contained-runtime/build-prototype.sh` on macOS and diff its
`dist/airportbackend/_internal/` output against this table before relying on
it for a release.

## Current app (before ADR-0001)

| Item | Path (inside .app) | Needs Developer ID signature? |
| --- | --- | --- |
| Main app binary | `Contents/MacOS/AirPort Utility` | Yes (already ad-hoc signed today) |
| SwiftPM resource bundle | `Contents/Resources/AirPortUtility_AirPortUtilityCore.bundle` | No — data only (images, strings) |
| Python backend source | `Contents/Resources/backend/*.py` | No — plain text, not a Mach-O; not independently signed (it is covered by the outer app's seal, but adds no signature of its own) |

Today's signing surface is small: one signature covers everything, because
there is no bundled interpreter or nested executable.

## After ADR-0001 (frozen backend)

| Item | Path (inside .app) | Needs its own Developer ID signature? | Notes |
| --- | --- | --- | --- |
| Frozen backend executable | `Contents/Resources/backend/airportbackend/airportbackend` | **Yes** | This is a Mach-O executable; must be signed with the hardened runtime flag before the outer app is signed. |
| Embedded `libpython3.x` | `.../airportbackend/_internal/libpython3.x.dylib` | **Yes** | Dynamic library, loaded by the frozen executable. |
| Vendored OpenSSL (`libssl`, `libcrypto`) | `.../_internal/libssl.*.dylib`, `libcrypto.*.dylib` | **Yes**, if PyInstaller vendors its own copies rather than linking the system ones | `hashlib`/`_hashlib` pulls these in transitively (confirmed present in the Linux prototype even though this project's own code never imports `ssl`). Prefer a PyInstaller/CPython build configuration that links macOS's system `libSystem`-provided crypto instead of vendoring OpenSSL, if that's achievable, to shrink this list — otherwise each vendored copy needs signing and needs to stay on Apple's/notarisation's good side version-wise. |
| Compression libraries (`libbz2`, `liblzma`, `libz`) | `.../_internal/lib{bz2,lzma,z}.*.dylib` | **Yes**, if bundled rather than linked from `/usr/lib` | These come from stdlib hooks (`pickle`, `xml`, `multiprocessing` — see `Prototype/.../build/airportbackend/warn-airportbackend.txt` for exactly why PyInstaller decided to pull each one in). None of this app's own code imports `bz2`, `lzma`, or `xml` directly; a follow-up should check whether `--exclude-module` can drop the transitive stdlib hooks that pull these in, shrinking both the signing surface and the bundle. |
| Any C-extension modules PyInstaller extracts as separate files (`_socket`, `_ctypes`, `_struct`, etc.) | `.../_internal/lib-dynload/*.so` (macOS naming) | **Yes**, one signature per file | Not visible as separate files in the Linux prototype (this Linux CPython build compiles most of these in statically); macOS CPython builds commonly ship them as individual loadable bundles. Must be enumerated for real once built on macOS. |
| `base_library.zip` / the PYZ archive of Python bytecode | `.../_internal/base_library.zip`, `.../_internal/PYZ-*.pyz` (or embedded in the executable, depending on `--onedir` vs archive layout) | No | Data, not a Mach-O; not independently executable. |
| SwiftPM resource bundle | `Contents/Resources/AirPortUtility_AirPortUtilityCore.bundle` | No | Unchanged from today. |
| Main app binary | `Contents/MacOS/AirPort Utility` | **Yes** | Must be signed *last*, after every nested item above, per Apple's inside-out signing requirement. |

## Signing order

Apple's codesign tooling requires nested code to be signed before the code
that contains it. The rough order for the post-ADR-0001 bundle is:

1. Every `.dylib` / `.so` under `_internal/` (order among these doesn't
   matter, they don't nest each other).
2. The `airportbackend` executable itself (it links against the above).
3. `codesign` currently runs once on the whole app in `build-app.sh`; this
   will need to become an explicit loop over the frozen backend's nested
   files (`codesign --deep` can do this automatically for simple cases, but
   Apple's own guidance is to avoid `--deep` for anything going through
   notarisation and instead sign each nested item explicitly, because
   `--deep`'s automatic discovery has known gaps).
4. `Contents/MacOS/AirPort Utility` (the outer app), signed last, with
   `--options runtime` (hardened runtime) and the entitlements file (see
   `Packaging/entitlements-draft.plist`).

## Verification

`codesign --verify --strict --verbose=4 "AirPort Utility.app"` after the full
signing pass should report all nested code as valid. `spctl -a -vvv --type
execute "AirPort Utility.app"` is the closer approximation to what Gatekeeper
will actually check on a clean Mac, and should be run before every release
once a Developer ID and notarisation profile exist.

## Open question for the macOS-side spike

Whether PyInstaller's macOS output can be built to link the compression and
crypto libraries dynamically against the ones macOS already ships (reducing
the signing surface and bundle size) instead of vendoring its own copies is
unresolved from this environment and should be the first thing checked when
this work continues on a Mac.
