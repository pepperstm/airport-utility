# AirPort Utility Powerhouse roadmap

## Direction

Build a safe, modern macOS management and monitoring suite for Apple AirPort
base stations and Time Capsules while retaining compatibility with the
reverse-engineered backend.

## Product rules

1. Monitoring is read-only by default.
2. Configuration changes are previewed before application.
3. Destructive operations require explicit confirmation.
4. Credentials and client identity data do not belong in logs or health history.
5. Missing device data is reported as unknown, never estimated.
6. Failures produce actionable, exportable diagnostics.

## Delivered in 0.1.0 beta 1

- Standalone macOS packaging and continuous integration
- AirPort discovery, topology, startup selection, and configuration workflows
- Network, Internet, wireless, firmware, client, and warning dashboards
- Time Capsule capacity, SMART, SMB, and Time Machine backup health
- Local health notifications and bounded historical trend charts
- Structured redacted logging and diagnostics support bundles
- Gateway, DNS, public-Internet, and likely double-NAT diagnostics
- Removed the packaged app's external `python3` dependency — see
  [ADR-0001](../architecture/ADR-0001-self-contained-backend-runtime.md);
  `build-app.sh` now ships a self-contained backend and CI validates it on
  every push

## Next

- Expand real-hardware and legacy-model coverage (in development)
- Improve sparsebundle growth and backup-history analysis (delivered)
- Add Wi-Fi congestion analysis and channel recommendations (delivered)
- Strengthen pre-change snapshots, verification, history, and rollback (delivered)

## Not currently planned

- **Notarised distribution.** Requires a paid Apple Developer Program
  membership; decided against for a hobby-scale project (see
  [apple-credentials-needed.md](../release/apple-credentials-needed.md)).
  The app stays ad-hoc signed — Control-click → Open on first launch is the
  expected steady-state experience, not a temporary gap. Revisit only if
  that calculus changes (e.g. a co-maintainer covers the fee).

Features move into a release only after their data source, safety boundary,
failure behavior, privacy impact, and test coverage are documented.
