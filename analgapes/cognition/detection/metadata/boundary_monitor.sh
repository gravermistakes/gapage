#!/usr/bin/env bash
# boundary_monitor.sh — Detect cloud metadata dead-drop access patterns
# Doc 5 insight: re-entry check is the only mandatory boundary crossing.
# Monitors outbound connections to metadata endpoints during workload init.
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

# Known cloud metadata IPs
META_AWS="169.254.169.254"
META_GCP="metadata.google.internal"
META_GCP_IP="169.254.169.254"
META_AZURE="169.254.169.254"
META_DO="169.254.169.254"

LOG=${LOG:-/var/log/metadata_boundary.log}
ATTEST_REQUIRED=${ATTEST_REQUIRED:-0}
WORKLOAD_READY_TS_FILE=${WORKLOAD_READY_TS_FILE:-/run/workload_ready}

usage() {
    cat <<EOF
boundary_monitor.sh — Cloud metadata dead-drop detection

Usage: $0 [--monitor|--audit|--gate] [options]

Modes:
  --monitor          Long-running: tail conntrack/audit for metadata access
  --audit <log>      One-shot: scan existing log file
  --gate <pid>       Block metadata access from <pid> until attestation file exists

Environment:
  LOG=path                 Output log file (default: /var/log/metadata_boundary.log)
  WORKLOAD_READY_TS_FILE   File whose existence indicates workload is ready
                           (used by --gate; metadata access before this = alert)
  ATTEST_REQUIRED=1        Require signed attestation file before allowing access
EOF
    exit 1
}

[[ $# -lt 1 ]] && usage

mode="$1"; shift || true

log_event() {
    local kind="$1"; shift
    printf '[%d] %s %s\n' "$(date +%s)" "$kind" "$*" >> "$LOG"
}

case "$mode" in
    --monitor)
        # Use conntrack if available, fall back to ss polling
        if command -v conntrack >/dev/null 2>&1; then
            log_event MONITOR_START "conntrack"
            conntrack -E -e NEW,UPDATE 2>/dev/null | \
                grep --line-buffered -E "$META_AWS|$META_GCP_IP" | \
                while IFS= read -r line; do
                    pid_info=$(ss -tnp 2>/dev/null | grep -E "$META_AWS|$META_GCP_IP" | head -1)
                    log_event METADATA_ACCESS "$line | $pid_info"

                    # Check if workload was already declared ready
                    if [[ ! -f "$WORKLOAD_READY_TS_FILE" ]]; then
                        log_event PRE_READY_METADATA_ALERT "$pid_info"
                        echo "ALERT: metadata access before workload ready: $pid_info" >&2
                    fi
                done
        else
            log_event MONITOR_START "ss-polling"
            while true; do
                conns=$(ss -tnp 2>/dev/null | grep -E "$META_AWS|$META_GCP_IP" || true)
                if [[ -n "$conns" ]]; then
                    log_event METADATA_ACCESS "$conns"
                fi
                sleep 1
            done
        fi
        ;;

    --audit)
        logfile="${1:-}"; [[ -z "$logfile" ]] && usage
        [[ ! -f "$logfile" ]] && { echo "Log not found: $logfile" >&2; exit 1; }

        echo "BOUNDARY_AUDIT(log=$logfile)"
        echo "===================================="

        # Find access events
        access_count=$(grep -c "METADATA_ACCESS" "$logfile" 2>/dev/null || echo 0)
        alert_count=$(grep -c "PRE_READY_METADATA_ALERT" "$logfile" 2>/dev/null || echo 0)

        echo "Total metadata access events: $access_count"
        echo "Pre-ready alerts:             $alert_count"

        if [[ "$alert_count" -gt 0 ]]; then
            echo ""
            echo "*** PRE-READY ALERTS ***"
            grep "PRE_READY_METADATA_ALERT" "$logfile" | head -20
            echo ""
            echo "→ These connections accessed cloud metadata before workload was ready."
            echo "  This is the doc 5 dead-drop signature. Investigate source processes."
        fi

        # Distinct source processes
        echo ""
        echo "--- Source processes ---"
        grep "METADATA_ACCESS" "$logfile" | \
            grep -oE 'users:\(\("[^"]+"' | \
            sort -u | head -20
        ;;

    --gate)
        target_pid="${1:-}"; [[ -z "$target_pid" ]] && usage

        # Wait for either attestation or timeout
        timeout=${TIMEOUT:-30}
        elapsed=0
        attest_file=${ATTEST_FILE:-/run/workload_attestation.sig}

        while [[ $elapsed -lt $timeout ]]; do
            if [[ -f "$attest_file" ]]; then
                # Verify attestation signature if openssl available
                if command -v openssl >/dev/null 2>&1 && [[ -f "${attest_file}.pub" ]]; then
                    if openssl dgst -sha256 -verify "${attest_file}.pub" \
                        -signature "$attest_file" "$WORKLOAD_READY_TS_FILE" >/dev/null 2>&1; then
                        log_event ATTEST_VERIFIED "pid=$target_pid"
                        echo "Attestation verified for pid $target_pid"
                        exit 0
                    fi
                else
                    log_event ATTEST_PRESENT_UNVERIFIED "pid=$target_pid (no openssl/pubkey)"
                    exit 0
                fi
            fi
            sleep 1
            elapsed=$((elapsed + 1))
        done

        log_event ATTEST_TIMEOUT "pid=$target_pid timeout=${timeout}s"
        echo "Attestation timeout: blocking pid $target_pid from metadata access"
        # In real deployment: drop iptables rule or kill pid
        # iptables -A OUTPUT -m owner --pid-owner $target_pid -d 169.254.169.254 -j DROP
        exit 1
        ;;

    *)
        usage
        ;;
esac
