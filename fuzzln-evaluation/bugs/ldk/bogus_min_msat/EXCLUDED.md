# EXCLUDED

This bug is **not** part of the paper's final 17-bug ground-truth benchmark (5 CLN, 5 Eclair, 4 LND, 3 LDK).

**Reason:** a post-campaign audit found the diagnostic flag was misplaced.

`flag.patch` and `metadata.json` are left unmodified for transparency. See the paper's Methodology
section (Evaluation Architecture / Historical Bug Curation) for the audit process that led to this
exclusion, and [bugs/README.md](../../README.md) for the full accounting of all 20 candidate bugs
versus the 17 reported.
