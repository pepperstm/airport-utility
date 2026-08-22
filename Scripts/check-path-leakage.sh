#!/bin/sh
# Fails if any file under the given path(s) contains an absolute path that
# only makes sense on the machine that built it. Intended to run against the
# *shipped* output of a build (a packaged .app, or a frozen backend's dist/
# directory) — never against intermediate build/ bookkeeping, which is
# expected to contain build-machine paths and is discarded before packaging.
#
# Usage:
#   Scripts/check-path-leakage.sh "<path-to-app-or-dist>" [more paths...]
#
# Exit status is 0 if clean, 1 if any leak is found (with the matching files
# and lines printed to stderr), 2 on usage error.
#
# Known caveat (unverified on macOS as of this writing): release-mode Mach-O
# binaries can still carry absolute source paths in their DWARF debug-info
# sections even when the source itself never embeds a path (Swift's default
# `#file` has aliased the short `#fileID` form since Swift 5.3, so this is
# unlikely but not proven for this project's release build). If this check
# ever fails against Sources/AirPortUtilityApp's compiled binary rather than
# against the Python/backend payload, first confirm the match is in debug
# info (e.g. via `dwarfdump` or `nm`) before treating it as a real leak, and
# consider stripping debug symbols from the release build (`strip -S`) as the
# fix rather than relaxing this script's patterns.

set -eu

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <path-to-app-or-dist> [more paths...]" >&2
  exit 2
fi

# Patterns that indicate a developer- or build-machine-specific absolute
# path baked into a shipped artifact. Extend this list as new build hosts or
# home-directory conventions are used (e.g. CI runner home directories).
PATTERNS='/Users/[A-Za-z0-9_.-]+|/home/[A-Za-z0-9_.-]+|/root/[A-Za-z0-9_./-]+|/private/var/folders/'

FOUND=0
for TARGET in "$@"; do
  if [ ! -e "$TARGET" ]; then
    echo "warning: $TARGET does not exist, skipping" >&2
    continue
  fi
  MATCHES=$(grep -rlaE "$PATTERNS" "$TARGET" 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    FOUND=1
    echo "Absolute build-machine paths found under $TARGET:" >&2
    printf '%s\n' "$MATCHES" | while IFS= read -r FILE; do
      echo "  $FILE" >&2
      grep -aoE "$PATTERNS" "$FILE" 2>/dev/null | sort -u | sed 's/^/    -> /' >&2
    done
  fi
done

if [ "$FOUND" -ne 0 ]; then
  echo "" >&2
  echo "FAIL: shipped artifact leaks an absolute developer/build-machine path." >&2
  echo "This can break on another machine and can reveal the packager's" >&2
  echo "username. Check for hardcoded paths, unresolved template variables," >&2
  echo "or a freezer/bundler emitting debug metadata into the shipped tree" >&2
  echo "instead of its intermediate build directory." >&2
  exit 1
fi

echo "OK: no absolute build-machine paths found under: $*"
