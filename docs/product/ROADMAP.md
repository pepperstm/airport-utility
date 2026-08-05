# AirPort Utility Powerhouse Roadmap

## Vision

Build a modern macOS management, diagnostics and monitoring suite for Apple AirPort base stations and Time Capsules.

The application should preserve the existing reverse-engineered management capabilities while adding safer configuration workflows, richer diagnostics and Time Capsule backup intelligence.

## Product principles

1. Read-only by default.
2. Configuration changes must be previewed before being applied.
3. Export a configuration snapshot before every write.
4. Destructive operations require explicit confirmation.
5. Failures must produce useful diagnostics rather than generic errors.
6. Maintain compatibility with the upstream project where practical.
7. Test initially against the A1470 AirPort Time Capsule.

## Phase 1: Foundation

- Conventional macOS app packaging
- Reliable development and release builds
- Structured logging
- Continuous integration
- Read-only dashboard shell
- Clear separation between reads and configuration writes
- Configuration snapshot service
- Human-readable error reporting

## Phase 2: Dashboard

- Base-station health
- Internet and network status
- Firmware status
- Connected-client overview
- Disk capacity
- Recent warnings
- Last refresh time

## Phase 3: Time Capsule Health

- Sparsebundle inventory
- Last backup time per Mac
- Backup age warnings
- Backup growth history
- SMB and AFP service tests
- Disk usage and throughput tests

## Phase 4: Diagnostics

- Gateway reachability
- DNS resolution
- Public Internet reachability
- Double-NAT detection
- Bonjour service browser
- Wi-Fi congestion analysis
- Channel recommendations
- Historical outage tracking

## Phase 5: Safe Administration

- Automatic pre-change backups
- Change previews
- Restart verification
- Configuration history
- One-click rollback
- Recovery assistant
