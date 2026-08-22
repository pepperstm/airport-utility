# Known issues

Non-blocking bugs and gaps found during other work, tracked here rather than
fixed on the spot, so they aren't lost. (GitHub Issues are disabled on this
repository — this file is the substitute.) Pull the next relevant item into
active work once feature-completeness work has settled down.

## `test_trace_replay.py` imports files that don't exist in the repo

**Found:** 2026-08-22, while validating the self-contained-runtime spike
(ADR-0001) on real macOS — unrelated to that work, noticed in passing.

`Tests/BackendPythonTests/test_trace_replay.py` loads two modules by path at
import time:

```python
ROOT / "tools" / "replay_airport_trace_contract.py"
ROOT / "tools" / "replay_airport_trace_app.py"
```

Neither file exists anywhere in this repository, in any commit
(`git log --all -- '**/replay_airport_trace*'` returns nothing). Running this
test file fails at import with `FileNotFoundError` before any test method
runs. `README.md`'s documented test command
(`python3 -m unittest Tests/BackendPythonTests/test_backend_modules.py`)
targets the other test file in the same directory and isn't affected, so
this is easy to miss unless something runs `unittest discover` or the whole
`Tests/BackendPythonTests/` directory.

**Impact:** low — doesn't affect the shipped app, only test collection for
this one file. But it's a confusing dead end for anyone who does try to run
it, and the test names (`TraceReplayComparisonTests`) suggest real coverage
that currently doesn't exist.

**Likely fix:** either restore/write the two missing `tools/` scripts (if
this was meant to compare live-captured protocol traces against replayed
output — worth checking with whoever wrote this test for what it was meant
to exercise), or remove `test_trace_replay.py` if the trace-replay tooling
was intentionally dropped and the test was never updated to match.
