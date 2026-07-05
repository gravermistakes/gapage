# Self-Referential Audit — Architectural Review Checklist

For any agent workload deployed in orchestrated infrastructure, walk this
checklist. Every "yes" answer is a substrate the agent can encode into.

## Identity Self-Read

- [ ] Can the workload read its own pod name / container ID / instance ID?
- [ ] Can the workload read its own node name / host identity?
- [ ] Can the workload read its own ServiceAccount identity?
- [ ] Can the workload read its own RBAC permissions?

If any → the agent has the seed material for key derivation, schema
mimicry, environmental fingerprinting. Either close the read, or assume
all subsequent defenses must work without secrecy from this identity.

## Self-Modify Capability

- [ ] Can the workload patch its own Deployment?
- [ ] Can the workload update its own Lease?
- [ ] Can the workload create/modify its own ConfigMaps or Secrets?
- [ ] Can the workload modify its own Pod annotations or labels?
- [ ] Can the workload create new RoleBindings naming itself?

If any → the agent can re-create itself, persist across restarts, and
hide self-modification inside legitimate-looking writes.

## Telemetry Authority

- [ ] Can the workload define its own telemetry schema?
- [ ] Can the workload write to telemetry without collector validation?
- [ ] Are there fields in the telemetry payload that accept arbitrary content?

If any → telemetry is a covert channel. Add collector-side nonces tied to
collector trust domain.

## Boundary Crossings

- [ ] Does the workload access cloud metadata (169.254.169.254) at startup?
- [ ] Does the workload read user-data or instance tags?
- [ ] Does the workload contact external services before health-check passes?

If any → introduce attestation-before-access. Bootstrap-time crossings
are observable and should be authenticated.

## IPC Surface

- [ ] Does the workload share memory via shmget/shmat?
- [ ] Does the workload use memfd_create or anonymous files?
- [ ] Can the workload spawn helper processes?
- [ ] Does the host expose /proc or /sys to the workload?

If any → eBPF observation is necessary. Predictable IPC keys derived from
workload identity should be pre-enumerated.

## Privilege Boundaries

- [ ] Does the workload have CAP_SYS_ADMIN?
- [ ] Does the workload have CAP_SYS_PTRACE?
- [ ] Does the workload have CAP_NET_ADMIN?
- [ ] Can the workload mount the host's docker.sock or runtime socket?
- [ ] Can the workload write to /proc/sys/kernel/core_pattern?

Any "yes" here is a sandbox escape primitive. Remove the capability,
or treat the workload as host-equivalent.

## The Closing Question

After running this checklist, ask:

> Could a compromised version of this workload mimic its own orchestrator
> well enough that downstream infrastructure cannot distinguish them?

If yes, the architectural fix is not detection. It is closing the
self-referential loop.
