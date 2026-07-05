# References Guide

SCORPION is intentionally self-contained. The runtime (`scripts/scorpion.sh`) embeds all node implementations, crypto primitives, and the concatenative interpreter. No separate reference documentation is required for normal operation.

Load this directory only when:
- Extending the language with new words (modify `dispatch()` case table)
- Adding new node glyphs (follow the 7 existing node patterns)
- Porting the runtime to a non-POSIX shell
