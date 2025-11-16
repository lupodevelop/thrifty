
# Thrifty -  a Gleamourous Apache Thrift Compact Protocol Library.

[![CI](https://github.com/lupodevelop/thrifty/actions/workflows/run-tests.yml/badge.svg?branch=main)](https://github.com/lupodevelop/thrifty/actions/workflows/run-tests.yml)[![Hex](https://img.shields.io/hexpm/v/thrifty.svg)](https://hex.pm/packages/thrifty) [![License](https://img.shields.io/badge/license-Apache%202.0-yellow.svg)](LICENSE) [![Built with Gleam](https://img.shields.io/badge/Built%20with-Gleam-ffaff3)](https://gleam.run) [![Gleam Version](https://img.shields.io/badge/gleam-%3E%3D1.13.0-ffaff3)](https://gleam.run)



Thrifty is a pure Gleam implementation of the [Apache Thrift Compact Protocol](https://thrift.apache.org/docs/compact-protocol). It targets predictable behaviour, strict boolean semantics, and interoperability with golden payloads produced by official Thrift stacks.

| Use case | What Thrifty provides |
| --- | --- |
| Runtime decoding | Immutable reader with configurable limits, compatibility with legacy booleans, schema-agnostic skip support |
| Encoding | Writer helpers for primitives, containers, and struct headers |
| Testing harness | Deterministic fuzzing CLI, property tests, and golden vector validation |

## Features

- Compact Protocol reader/writer covering integers, doubles, strings/binaries, and containers
- ZigZag and VarInt helpers with boundary checks and clear error reporting
- Field header decoding (short and long delta) with inline boolean handling
- Strict boolean policy (`AcceptCanonicalOnly`) enforced across container element reads and skips
- Reader options for depth, container size, and string length limits to guard untrusted payloads
- Deterministic fuzz harness with optional persistence of failing mutations under `artifact/fuzz-failures/`
- Extensive test suite: golden vectors, structural property tests, and targeted regression cases

## Getting Started

### Prerequisites

- Gleam ≥ 1.13.0
- Erlang/OTP ≥ 28 (tested with 28.1)
- rebar3 ≥ 3.25.1 (for Hex packaging and publishing)

### Installation (Hex)

Add Thrifty as a dependency once published:

```gleam
// gleam.toml
[dependencies]
thrifty = "~> 1.0"
```

### Local Development

```bash
gleam deps download
gleam test           # run unit, property, and golden tests
gleam run -m thrifty # execute example entrypoint (if configured)
```

Golden payloads live under `artifact/golden/`; tests read directly from this directory. If you regenerate payloads out of band, keep filenames stable so golden tests discover them automatically.

Explore hands-on guides under `docs/examples/` for decoding, encoding, skipping unknown fields, strict-boolean enforcement, and fuzz harness walkthroughs.

## Project Layout

```text
artifact/
  golden/              # canonical Compact Protocol payloads used in tests
  fuzz-failures/       # failing fuzz cases (enabled on demand)
src/                   # library implementation modules
test/                  # gleeunit test suites (unit, property, golden)
.github/workflows/     # GitHub Actions CI pipelines
```

### Key Modules

- `thrifty/reader.gleam`: public reader API (`read_struct`, `skip_value`, primitives)
- `thrifty/writer.gleam`: writer helpers for Compact Protocol encoding
- `thrifty/field.gleam`, `thrifty/container.gleam`: header and container decoding logic
- `thrifty/fuzz_cli.gleam`: deterministic fuzz harness with optional persistence
- `thrifty/fuzz_persistence.gleam`: helper used by the harness to persist failing inputs

## Fuzz Harness & Failure Persistence

The fuzz CLI mutates golden payloads deterministically. Set the internal toggle or expose a CLI flag to enable persistence:

```gleam
const save_failures_enabled = True
const save_failures_dir = "artifact/fuzz-failures"
```

When enabled, failing payloads and slim metadata (`seed`, `iteration`, `reason`) are written to the target directory for later triage. Tests under `test/thrifty/fuzz_persistence_test.gleam` exercise this pipeline.

For long-running fuzz jobs in CI, upload `artifact/fuzz-failures/` as a build artifact so failures can be replayed locally.

## Testing & Tooling

- `gleam test` covers all suites and currently exercises 79 assertions.
- GitHub Actions workflows:
  - `run-tests.yml`: primary CI (`gleam test`).
  - `validate-goldens.yml`: ensures golden vectors are up to date.
  - `fuzz-long.yml`: optional longer fuzz runs.
  - `publish-on-ci-main.yml`: gated Hex publish upon release once secrets are configured.
- Packaging checks: `rebar3 hex build` verifies Hex metadata and produces the `.tar` artifact under `_build/default/lib/thrifty/hex/`.

## Regenerating Golden Payloads

Golden payloads are sourced from reference implementations (e.g., thriftpy2 or Apache Thrift Java). A typical workflow is:

1. Produce binaries with the upstream tool of choice (store generator scripts alongside other tooling if you add them).
2. Copy the resulting Compact payloads into `artifact/golden/`.
3. Extend `test/thrifty/golden_test.gleam` or other suites to assert the expected decoding behaviour.
4. Run `gleam test` to validate compatibility.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).

