# Extended features roadmap

Tracks work on `feature/extended-features`, branched from the completed
navigation-shell modernisation. Unlike `ROADMAP.md` (delivered product
scope), this file covers new capability being evaluated for the first time,
brought in from other projects in the AirPort/Time Capsule hacking
community. Each item below stays in this file until it either ships (moves
to `ROADMAP.md`) or is explicitly rejected.

## Source projects being evaluated

| Project | License | Status | What it offers |
| --- | --- | --- | --- |
| [jamesyc/TimeCapsuleSMB](https://github.com/jamesyc/TimeCapsuleSMB) | GPL-3.0 | Active, 900+ stars | Replaces a Time Capsule's native Samba with a modern Samba 4 build via SSH, restoring SMB3/Time Machine connectivity now that macOS 27 dropped AFP entirely |
| [samuelthomas2774/node-acp](https://github.com/samuelthomas2774/node-acp) | MIT | Active | Node.js reimplementation of the same ACP protocol `backend/acp.py` already implements, plus firmware decrypt/extract tooling |
| [noname122021/airpyrt-tools-guide](https://github.com/noname122021/airpyrt-tools-guide) | MIT | Documentation hub | Root-SSH jailbreak guide: regional Wi-Fi lock removal, manual fan control, ACP property reference |

## 1. TimeCapsuleSMB integration (primary focus)

### Why this matters

macOS 27 removed AFP support outright, and Apple removed SMB1 support from
macOS years ago. Time Capsules only speak AFP and SMB1 natively. That means
**Time Machine backups to a Time Capsule are broken on current macOS**,
independent of anything airport-utility does — and this app's own
`TimeMachineBackup.swift`/`StorageHealth.swift`/health-history machinery,
which exists specifically to monitor Time Capsule backup health, is heading
toward monitoring a backup path that no longer works. This is the most
consequential thing in scope for this branch.

### Decision made (2026-08-24)

Orchestrate the fix in-app rather than just detecting the problem and
linking out to the external tool. This is a deliberate step beyond
airport-utility's current safety boundary: today the app only ever speaks
ACP (the same protocol Apple's own AirPort Utility used) and never touches
the device outside that protocol. TimeCapsuleSMB requires SSH access and
running a third-party prebuilt Samba 4 binary (built for NetBSD, the
Time Capsule's OS) on the device's own disk. Its own issue tracker records
devices resetting mid-deploy. This is a new risk category for the app, not
an extension of an existing one, and the UX has to make that boundary
obvious to the user rather than paper over it — closer to the Setup
Wizard's explicit recommend → review → apply → confirm flow than to a
routine settings change.

### Proposed phasing

1. **Detection (no SSH yet).** Identify a Time Capsule whose Time Machine
   path is AFP-only, and whether the connected Mac's macOS version has AFP
   client support (removed in macOS 27). Surface this as a new Dashboard
   condition, in the same place `RecoveryGuidance.swift`/the Recovery
   Dashboard section already surfaces other "something needs your
   attention, here's the guided next step" states. No device changes at
   this phase — pure read/detect, consistent with today's safety posture.
2. **Vendor the deploy logic.** `backend/` is already a self-contained,
   PyInstaller-frozen Python executable (see
   [ADR-0001](../architecture/ADR-0001-self-contained-backend-runtime.md));
   TimeCapsuleSMB's `src/` (Python) and `bin/` (prebuilt NetBSD `smbd`
   binaries for the 3 supported device generations) are a natural fit to
   vendor into a new `backend/samba_deploy/` package reusing that same
   packaging pipeline, rather than shelling out to a separately-installed
   copy of the tool. This needs its own licensing pass before any code
   lands: vendored third-party GPL-3.0 files get an
   `SPDX-License-Identifier: GPL-3.0-only` header same as
   [`NOTICE.md`](../../NOTICE.md)'s existing convention, but need a new,
   clearly separate attribution section there — this is incorporated
   third-party code, not new work by Graham Barber, so it doesn't belong
   in the existing git-blame-based Graham-vs-Jack split.

   **Binary-bundling decision (2026-08-24):** vendor the prebuilt `bin/`
   binaries verbatim to start — fastest path to a working feature, and
   consistent with how TimeCapsuleSMB itself ships and expects them to be
   used (its own README calls the checked-in binaries the normal workflow,
   not something users are expected to rebuild). Document a
   build-from-source path later, once a NetBSD build environment is
   available to this project — not blocking on it now.
3. **Guided in-app deploy flow.** A new sheet reusing the Setup Wizard's
   established pattern (recommendation screen, review-before-apply,
   progress, completion/failure with a clear rollback story) rather than a
   silent background action. Must cover: enabling SSH via the existing ACP
   client (TimeCapsuleSMB does this itself today — `configure` calls into
   the same Python ACP library this project's guide names as its source),
   deploying the payload, the NetBSD-4 boot-hook firmware patch step for
   older (Gen 1–4) devices, and a "Checkup"/doctor-equivalent verification
   step before declaring success.
4. **Ongoing health integration.** Once deployed, fold Samba/SMB3 reachability
   into the existing `StorageHealth`/health-notification machinery instead
   of it being a one-off installer — this is the actual point: Time Machine
   Backup health monitoring should reflect the modern stack once it's there.

### Resolved

- **License variant:** confirmed `GPL-3.0-only` directly from
  TimeCapsuleSMB's own `pyproject.toml` (`license = "GPL-3.0-only"`), not
  assumed — vendored files get an
  `SPDX-License-Identifier: GPL-3.0-only` header matching that exactly.
- **Binary bundling:** vendor prebuilt binaries verbatim; see the Phase 2
  decision above.

### Open questions to resolve before phase 2 starts

- How hard the app should gate this behind an explicit "Advanced" surface
  (e.g. a distinct confirmation step, possibly a Preferences opt-in to even
  show the feature) given the bricking risk is real and documented upstream,
  not hypothetical.

## 2. node-acp (secondary, reference-only for now)

No plan to depend on or vendor node-acp — `backend/acp.py` already
implements the same protocol. Two possible follow-ups, both lower priority
than TimeCapsuleSMB and not yet scheduled:

- A one-time audit diffing node-acp's known ACP property list against
  `backend/acp.py`'s for any properties or features this project's
  implementation is missing.
- Firmware decrypt/extract, mirroring node-acp's `airport-firmware`
  command, as a new Diagnostics-pane capability (inspecting a firmware
  image without installing it). Nice-to-have, not driven by a known user
  problem the way TimeCapsuleSMB is.

## 3. airpyrt-tools-guide (reference only, most of it out of scope)

This is a documentation hub, not a library — nothing to vendor directly.
Its ACP property reference is useful background reading for the node-acp
audit above. Its core subject matter (root SSH jailbreak, regional Wi-Fi
lock removal, manual fan control) is **not recommended for this project**:
region-unlocking bypasses regulatory (FCC) transmit-power limits, and fan
control carries a real hardware-damage risk by the guide's own disclaimer.
Both sit well outside this project's "safe reimplementation of Apple's own
tool" scope and its existing product rules (read-only by default, explicit
confirmation for destructive operations, no fabricated data). Flagging this
explicitly rather than silently dropping it — revisit only if the user
decides otherwise.
