# Self-contained runtime prototype — what this does and does not prove

This directory holds a runtime-packaging spike for
[ADR-0001](../../docs/architecture/ADR-0001-self-contained-backend-runtime.md).
It was originally built and run inside a Linux cloud container (no Xcode/
Swift available), which could validate the packaging *technique* but not any
macOS-specific mechanics. It has since been rebuilt for real on macOS — see
"What was validated on real macOS" below, which supersedes the Linux-only
findings for anything the two sections disagree on.

## What was validated on real macOS (2026-08-22, Apple Silicon, macOS 27)

Rebuilt via `build-prototype.sh`, unmodified, run for real (not simulated)
using `backend/airport_backend.py` on this machine. Two separate builds were
produced, one per architecture available on this machine, since no
universal2 CPython is installed here (see "Universal binary" below):

- **arm64**, using the arm64-native Python 3.9.6 that ships with Xcode
  Command Line Tools (`/usr/bin/python3`, a `Python3.framework` build).
- **x86_64**, using Homebrew's Python 3.12.4 (`/usr/local/bin/python3`,
  which itself runs under Rosetta 2 on this arm64 machine — Homebrew has no
  arm64-native install here).

Both were built in isolated venvs (`pip install pyinstaller` — no
`--break-system-packages` needed since each venv is disposable) to avoid
touching system site-packages.

Findings:

- **`--help` with `PATH` stripped of `python3` passes on real macOS, both
  architectures.** This was the core open question from the Linux spike and
  it's now confirmed for real: `env -i PATH=/nonexistent HOME="$HOME"
  dist/airportbackend/airportbackend --help` exits 0 with correct usage text,
  on both the arm64 and x86_64 builds. `build-prototype.sh`'s own smoke test
  (identical assertion) passes unmodified.
- **Universal binary: no universal2 CPython was available to test, but the
  "two arch-specific builds" path (ADR-0001's stated fallback) is now
  concretely validated** — both architectures freeze cleanly and independently
  from the same source tree with no spec-file changes, confirming that path
  works if a universal2 CPython build (e.g. python.org's official installer)
  isn't adopted. Installing python.org's universal2 build was not attempted
  in this session (installing new system-level software felt like something
  to check with the project owner first, rather than a given for a spike);
  that remains the fastest way to get a true single-binary universal2 build
  and should be the first thing tried in CI.
- **Which Python builds the freezer matters a lot for the nested-signing
  surface — more than expected.** The arm64 build (Apple's own
  `Python3.framework`) has almost no vendored dylibs: `_ssl`/`_lzma` link
  against `/usr/lib/libssl.dylib` / `/usr/lib/liblzma.5.dylib` (system
  paths, confirmed via `otool -L`), not bundled copies. The x86_64 build
  (Homebrew Python) vendors its own `libssl.3.dylib`, `libcrypto.3.dylib`,
  `liblzma.5.dylib`, and `libmpdec.4.dylib` directly inside `_internal/`,
  each needing its own Developer ID signature. This resolves the open
  question in `nested-code-signing-inventory.md` — see that doc for the
  updated recommendation and the real (not Linux-proxy) file inventory for
  both architectures.
- **`Scripts/check-path-leakage.sh` had a false positive, now fixed.** The
  x86_64 build initially failed the check: it flagged `/Users/Barney` inside
  `base_library.zip` and the vendored `Python.framework` binary. That string
  is not a real build-machine path — it's CPython 3.12's own
  `ntpath.splitroot()` docstring (`'C:/Users/Barney'`, a fictional Windows
  example path), which PyInstaller always bundles as part of `os`'s
  cross-platform support regardless of target OS. Confirmed via `otool`/
  `strings` and by checking CPython's own `ntpath.py` source. The arm64
  build didn't trigger this because Python 3.9 doesn't have
  `ntpath.splitroot` (added in 3.12). Fixed with a narrow, exact-string
  allowlist in the script (not a positional/regex relaxation, since a real
  leak can legitimately sit right after a colon too — e.g. a baked-in
  colon-separated `$PATH`). Verified the fix still catches a planted
  colon-adjacent leak.
- Confirmed directly (`grep` across `backend/*.py`) that only `hashlib` is
  imported by this project's own code (via `legacy.py`, `settings.py`,
  `srp.py`); `bz2`/`lzma`/`xml` are pulled in transitively by other stdlib
  hooks, not by anything this app needs — consistent with the inventory
  doc's existing note that `--exclude-module` may be able to drop them.
- Confirmed `backend/*.py` runs correctly under Python 3.9 (older than the
  README's stated 3.10+ requirement) because every module using `X | Y`
  union-type syntax has `from __future__ import annotations` — so freezing
  with an older interpreter than the dev-flow minimum isn't itself a
  correctness risk, though it's not a reason to standardize on one.
- Bundle sizes on real macOS: arm64 ~10MB, x86_64 ~18MB (larger mainly due to
  the vendored OpenSSL/lzma/mpdecimal libraries above) — both still well
  under the full-framework option from ADR-0001.

## What was validated on the original Linux spike (x86_64, superseded above where overlapping)

- `backend/airport_backend.py` and its full import closure freeze cleanly
  with PyInstaller `--onedir`, with no spec-file customisation beyond adding
  the repo root to `--paths` so `from backend.acp import ...` resolves.
- The frozen executable runs `--help` correctly with `PATH` reduced to a
  nonexistent directory (`env -i PATH=/nonexistent ...`), i.e. with no
  `python3` reachable anywhere — proving the packaging technique removes the
  interpreter dependency in principle.
- The shipped `dist/airportbackend/` tree contains no absolute build-machine
  paths (verified with `Scripts/check-path-leakage.sh`). PyInstaller's
  intermediate `build/` bookkeeping (`.toc` files, `xref-*.html`) does
  contain the build path, but those files are never copied into `dist/` and
  would never ship inside `Resources/`.
- Bundle size for this backend (no third-party dependencies at all — see
  ADR-0001) is ~20MB for one architecture. A macOS build should be in a
  comparable range per architecture.
- `ctypes.CDLL(ctypes.util.find_library("System") or
  "/usr/lib/libSystem.B.dylib")` in `backend/acp.py` is unaffected by
  freezing, since it resolves by absolute fallback path rather than search.

## What this still does NOT prove

- **A true single-binary universal2 artifact.** Two independent arch-specific
  builds are now confirmed to work (see above), which is one of ADR-0001's
  two accepted paths, but no universal2 CPython was available on this machine
  to test PyInstaller's `--target-arch universal2` directly, and gluing two
  `--onedir` trees into one Gatekeeper-friendly bundle (via `lipo` for the
  single executable, plus reconciling the many single-arch `.so` files under
  `_internal/`) was not attempted. Installing python.org's universal2
  installer is the more direct route and should be tried first in CI, per
  ADR-0001.
- **Code signing and hardened runtime.** Deliberately out of scope for this
  pass (per ADR-0001, this is deferred until a Developer ID exists — see
  `docs/release/apple-credentials-needed.md`). `codesign`, entitlements, and
  Gatekeeper/notarisation behaviour still need verification with a real
  Developer ID. The nested-signing inventory now reflects the real macOS
  file lists for both architectures instead of the earlier Linux proxy — see
  `docs/architecture/nested-code-signing-inventory.md`.
- **Launch time on macOS**, antivirus/Gatekeeper heuristics for `--onedir`
  vs `--onefile`, and interaction with System Integrity Protection.
- **`ctypes.CDLL` resolution for `CommonCryptoAES` specifically.** This is a
  *lazy* call inside `CommonCryptoAES.__init__` (`backend/acp.py:123`), not
  exercised at import time — so the `--help` run in this session (which only
  imports the module) does not actually invoke it. Confirming the frozen
  executable can `dlopen` `/usr/lib/libSystem.B.dylib` and resolve its AES
  symbols still needs a real exercise of the ACP-encrypted code path, e.g. via
  the mock-mode tests mentioned below.
- **Behavioural parity with the existing Python test suite when frozen.** This
  session, like the Linux spike before it, only ran `--help`. Before this
  technique ships, the frozen executable should be exercised against (at
  minimum) the existing mock-mode paths that `Tests/BackendPythonTests`
  covers, invoked as a subprocess rather than imported, to catch anything
  PyInstaller's import analysis missed (this would also exercise the
  `ctypes` item above).

## Reproducing this spike

```sh
pip install pyinstaller   # in a venv; add --break-system-packages otherwise
./Prototype/self-contained-runtime/build-prototype.sh
```

Confirmed working end-to-end on real macOS with this exact invocation
(2026-08-22) — no changes to the script were needed to reproduce it for real.

## Recommended next step

Now that both `--onedir` builds and the `--help`-with-no-`python3` regression
test are confirmed working for real on macOS, the next step is a CI workflow
(`macos-latest` or matching Apple Silicon runner) that runs this on every
relevant change, on both architectures, before extending `build-app.sh` to
use this technique for real releases. Decide there whether to build with
python.org's universal2 installer (untested but likely the same
system-linked-library behaviour observed with Apple's own CLT Python, since
both are official framework builds) or keep Homebrew Python and accept its
larger vendored-library signing surface — see the updated
"Open question" section in `nested-code-signing-inventory.md`.
