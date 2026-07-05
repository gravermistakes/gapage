# APKre - Pure GPL Android Reverse Engineering Toolkit

**Proof that copyleft can replace corporate Android tooling**

## What This Is

100% GPLv3.0 APK analysis toolkit built in 263 lines of Perl/Bash. Zero Apache 2.0 dependencies.

Replaces:
- ✗ apktool (Apache 2.0) → Our BinaryXMLParser.pm
- ✗ aapt (Apache 2.0) → Our format parsers
- ✓ Uses only GPL tools: unzip, perl, bash

## Installation

```bash
chmod +x bin/*
export PATH="$PWD/bin:$PATH"
```

## Quick Start

```bash
# Full analysis
apkre.pl analyze app.apk

# Security audit
apkre.pl audit app.apk

# Just unpack
apkre.pl unpack app.apk output_dir
```

## Individual Tools

```bash
# Parse manifest only
manifest-analyzer.pl app.apk

# Analyze DEX bytecode
dex-analyzer.pl app.apk

# Security scan
security-auditor.pl app.apk

# Extract resources
resource-extractor.sh app.apk resources/
```

## What It Detects

**Security Issues:**
- Hardcoded API keys (Google, AWS, Stripe, Firebase)
- Hardcoded passwords
- Debuggable flag in production
- HTTP endpoints (should be HTTPS)
- Backup allowance vulnerabilities

**APK Structure:**
- Package name, version
- Permissions (count + list)
- Activities, services, receivers
- Class count, method count
- Resource files

## License

**GPLv3.0** - All code, all components

This ensures:
- Freedom to use, modify, distribute
- Inheritance: derivatives must also be GPL
- Independence from corporate control

## Build Info

Built using swarm orchestration with dependency-ordered execution:
- 4 foundation parsers (parallel)
- 3 analysis tools (depend on parsers)
- 1 security layer (depends on tools)
- 1 master CLI (depends on all)

See BUILD_REPORT.md for full details.

## Philosophy

Corporate Android tooling creates dependency lock-in. By rebuilding from GPL primitives, we prove copyleft completeness and technical sovereignty.

If tech can move without corporate oligarchs, it starts with tools like this.
