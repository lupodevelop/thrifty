# Deterministic Fuzz Harness

Thrifty ships with a deterministic fuzz harness that mutates golden payloads. This guide explains how to run the harness locally and persist failing inputs.

## Running the Harness

```bash
# Execute the fuzz CLI against bundled golden payloads
gleam run -m thrifty/fuzz_cli
```

## Enabling Failure Persistence

Set the internal toggle in `src/thrifty/fuzz_cli.gleam` to persist failing inputs:

```gleam
const save_failures_enabled = True
const save_failures_dir = "artifact/fuzz-failures"
```

When enabled, Thrifty writes two files per failing case:

- `fuzz-failure-{seed}-{iteration}.bin`: the mutated payload
- `fuzz-failure-{seed}-{iteration}.meta`: metadata containing seed, iteration, and decode error

Collect these artefacts from `artifact/fuzz-failures/` for regression tests or manual analysis.
