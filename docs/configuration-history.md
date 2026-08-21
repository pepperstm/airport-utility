# Configuration snapshots, history, and reviewed rollback

Before a normal settings write, AirPort Utility saves the currently loaded
configuration locally. If the snapshot cannot be written, the configuration
change is blocked. The history then records whether the write completed and
whether the AirPort became reachable and returned readable settings afterward.

Snapshots are stored under:

```text
~/Library/Application Support/AirPort Utility Powerhouse/Configuration History/
```

The newest 50 records are retained. Passwords, RADIUS secrets, and opaque
advanced ACP data are omitted before the snapshot reaches disk. History is
local and is not included automatically in support bundles.

## Rollback safety

**Prepare Rollback** loads the selected pre-change snapshot into the normal
configuration editor. Sensitive fields are preserved from the currently loaded
configuration because they are not present in history. The user must review the
result, run the existing preview, and explicitly apply it. Nothing is rolled
back automatically.

The current verification state confirms that the AirPort became reachable and
its configuration could be read after the write. It does not yet claim a
field-by-field match, because older models and firmware can normalize or omit
values when returning them.
