# cognition/detection — Agent-Native C2 Detection

Operational detection for the four agent-native covert channel classes from
the docs 4+5 analysis. All four exploit the property that an agent can read
and write state *about itself* that downstream infrastructure trusts as
authoritative.

## The Core Principle (locked)

> Agent workloads should not have permissions that allow them to resemble
> their own orchestrator, nor read access to self-describing state that
> downstream infrastructure treats as authoritative.

Close that self-referential loop and the C2 channel collapses — not because
it's detected, but because it has no substrate left to encode into.

Every detection in this subsystem is a fallback for when the principle
cannot be enforced upstream.

## Subsystem Layout

```
detection/
├── k8s/
│   ├── lease_entropy.pl     — per-field entropy across Lease updates
│   └── rbac_flagger.pl      — surface self-modifying ServiceAccount RBAC
├── telemetry/
│   └── schema_validator.pl  — collector-side nonce injection + validation
├── ipc/
│   ├── shmget_probe.bt      — bpftrace for shmget/shmat/memfd/ptrace
│   └── helper_detector.pl   — correlate execve→shmget→exit; predictable keys
├── metadata/
│   └── boundary_monitor.sh  — dead-drop detection; attestation gating
└── principles/
    └── self_ref_audit.md    — architectural review checklist
```

## The Four Vectors

### 1. K8s Lease/Annotation Covert Channels

Legitimate controllers vary only timestamp and resourceVersion. C2 channels
must vary payload, producing per-field entropy.

**Tool**: `k8s/lease_entropy.pl` — Shannon entropy per field over a window.

**Companion**: `k8s/rbac_flagger.pl` — flags self-modifying RBAC, which is
the precondition for this attack class.

### 2. OpenTelemetry Schema Tunnels

Format-aware tunnels embedded in legitimate telemetry. Defended by
collector-side nonce injection that the agent cannot predict.

**Tool**: `telemetry/schema_validator.pl` — inject + validate modes.

**Critical**: nonce generator must live in the collector's trust domain,
never the agent's environment.

### 3. Shared Memory + Ephemeral Helpers

Helper processes leave parent-child links, brief PIDs, and IPC footprints.
The key space derived from container identity is small and enumerable.

**Tools**:
- `ipc/shmget_probe.bt` — observation via eBPF
- `ipc/helper_detector.pl` — correlation + predictable key enumeration

### 4. Cloud Metadata Dead-Drops

Re-entry is the only mandatory boundary crossing; detect at workload start.

**Tool**: `metadata/boundary_monitor.sh` — monitor/audit/gate modes.

**Hardening**: require signed attestation before metadata reads succeed.

## Usage

Each tool runs standalone with `--help`. For chained operation, invoke via
the pipeline orchestrator:

```bash
./avrs.sh --target <runtime_signals> --mode detection
```

## CTC2 (deferred work)

The Capture-The-C2 frame — building working covert channels paired with
this detection to validate it works — is deferred per the project decision
log. When that work happens, it will be scoped as a separate exercise
with explicit test environment, not baked into AVRS base.
