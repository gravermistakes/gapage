# Kerebral – Strategic Executive Interface

This directory is the executive brain of AVRS v3.0 Cybernetic.
the operator reads pipeline outputs from `../data/` and writes strategic
overrides here. The Ada core loop checks these files before executing
Phases 8 (Primitive Extract), 9 (Payload Synth), and 11 (Feedback).

## Files the operator May Write

### `hypothesis.txt` → overrides Phase 8
Vulnerability class, offset, and return address. Example:
```
type=stack_overflow
offset=136
ret_addr=0x401234
```

### `exploit_override.pl` → overrides Phase 9
Valid Perl PoC script. Copied to `action/exploit_synthesis/payload.pl`.
Must accept target path as `$ARGV[0]` and feed payload to it.

### `retrain_decision.txt` → overrides Phase 11
One of:
- `RETRY offset +8` — adjust offset and redo primitive extraction
- `RETRY payload` — redo payload synthesis only
- `ESCALATE` — mark unexploitable, proceed to seal
- `CONTINUE` — accept current result, proceed to seal

### `after_action_report.txt` → appended to final report
Free-text assessment: target architecture, vulnerability class,
exploitation reliability, disclosure recommendation.

## Protocol

The Ada core checks file modification time. If your file is newer
than the automated output, your version wins.

When the core is waiting: `[AVRS] ⏸ Awaiting the operator...`
Write the appropriate file, then press Enter to unblock.
