# Self-contained runtime prototype — what this does and does not prove

This directory holds a runtime-packaging spike for
[ADR-0001](../../docs/architecture/ADR-0001-self-contained-backend-runtime.md).
It was built and run inside a Linux cloud container, not on macOS, because
that is the only environment available to the agent that produced this
branch. Read this before trusting or extending it.

## What was validated here (Linux, x86_64)

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

## What this does NOT prove, and still needs a real Mac

- **Universal binary support.** PyInstaller does not cross-compile. Producing
  an arm64 + x86_64 artifact requires either two separate macOS build machines
  /runners (one per arch) with the outputs packaged side-by-side, or a
  universal2 CPython feeding PyInstaller's `--target-arch universal2`. Neither
  was exercised here.
- **Code signing and hardened runtime.** `codesign`, entitlements, and
  Gatekeeper/notarisation behaviour cannot be exercised outside macOS. See
  `docs/architecture/nested-code-signing-inventory.md` and
  `Packaging/entitlements-draft.plist` for the paper analysis this spike
  informed; both still need verification with a real Apple Developer ID.
- **Launch time on macOS**, antivirus/Gatekeeper heuristics for `--onedir`
  vs `--onefile`, and interaction with System Integrity Protection.
- **`ctypes` resolution inside a macOS-frozen interpreter specifically.** The
  Linux run above proves the *pattern* (absolute-path fallback bypasses
  library search) but the actual macOS dynamic loader behaviour under
  PyInstaller's bootloader needs a real run.
- **Behavioural parity with the existing Python test suite when frozen.** This
  spike ran `--help` only. Before this technique ships, the frozen executable
  should be exercised against (at minimum) the existing mock-mode paths that
  `Tests/BackendPythonTests` covers, invoked as a subprocess rather than
  imported, to catch anything PyInstaller's import analysis missed.

## Reproducing this spike

```sh
pip install pyinstaller --break-system-packages   # or use a venv
./Prototype/self-contained-runtime/build-prototype.sh
```

## Recommended next step

Run the equivalent of `build-prototype.sh` inside a `macos-latest` (or
matching Apple Silicon) GitHub Actions job as a new CI workflow, on both
architectures, before extending `build-app.sh` to use this technique for real
releases.
