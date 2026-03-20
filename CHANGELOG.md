# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] — 2026-03-20

### Fixed

#### Wire-format correctness (breaking for interoperability)

- **Field ID in long-form header not zigzag-encoded** (`field.gleam`)
  The Thrift Compact Protocol specification requires that field IDs in
  long-form headers (used when the delta from the previous field ID is
  outside `[1, 15]`) are encoded as a zigzag i16 followed by a varint.
  The encoder was writing a plain varint and the decoder was reading a
  plain varint, making payloads with long-form field headers
  incompatible with every other Thrift implementation.
  Fix: `encode_field_header` now applies `zigzag.encode_i32` before
  `varint.encode_varint`; `read_field_header` now applies
  `zigzag.decode_i32` after reading the varint.
  Affects any field whose delta from the previous field ID is `> 15`
  or `<= 0` (e.g. fields with ID > 15, or out-of-order fields).

- **`read_i8` decoded bytes as unsigned instead of signed** (`reader.gleam`)
  The bit-pattern `<<value:int-size(8)>>` matches unsigned (0–255).
  Negative i8 values such as `-1` (wire byte `0xFF`) were silently
  decoded as `255` instead of `-1`.
  Fix: changed to `<<value:int-signed-size(8)>>`.

- **`message.gleam` sequence ID broken for negative values**
  `encode_message_header` called `varint.encode_varint` directly on
  `sequence_id`. Because `encode_varint` requires a non-negative
  integer, negative sequence IDs produced corrupt output (or, after
  the `encode_varint` guard was added, a panic).
  The reference Java implementation encodes the sequence ID as its
  unsigned 32-bit two's-complement representation.
  Fix: encoder masks `sequence_id` to uint32 before encoding;
  decoder sign-extends values `> INT32_MAX` back to negative i32.

#### API correctness

- **`encode_varint` accepted negative integers silently** (`varint.gleam`)
  Passing a negative integer produced an invalid varint (the MSB
  continuation bit would be set on the last byte). Now panics with an
  explicit message including the offending value.

- **`write_i8` silently truncated out-of-range values** (`writer.gleam`)
  Values outside `[-128, 127]` were accepted and silently truncated by
  the bit-syntax, e.g. `write_i8(256)` produced `<<0>>`. Now panics
  with an explicit message, consistent with `write_i32` / `write_i64`.

- **`write_i16` accepted the full i32 range** (`writer.gleam`)
  `write_i16` delegated to `zigzag.encode_i32`, which allows values up
  to ±2 147 483 647. Now panics on values outside `[-32 768, 32 767]`.

- **`BoolElementPolicy::AcceptBoth` was identical to `AcceptCanonicalOnly`**
  (`reader.gleam`, `types.gleam`)
  Both policies executed the same code, making the distinction
  meaningless. `AcceptBoth` now also accepts byte value `0` as `False`,
  providing compatibility with older implementations that used the
  BinaryProtocol `0 = False / 1 = True` encoding.
  `AcceptCanonicalOnly` continues to accept only `1` (True) and `2`
  (False).

#### Documentation

- **Doc comments placed after function bodies** (`varint.gleam`,
  `zigzag.gleam`, `field.gleam`, `reader.gleam`, `writer.gleam`,
  `message.gleam`, `writer_highlevel.gleam`)
  Gleam attaches `///` doc comments to the next item in the file.
  Comments that appeared after a function body were silently associated
  with the wrong function in generated documentation. All misplaced
  comments have been moved to immediately precede the function they
  describe.

- **Duplicate Apache-2.0 license header** (`varint.gleam`, `field.gleam`)
  The license block appeared twice at the top of both files. The
  duplicate has been removed.

#### Dead code

- **`types.Writer` type was never used** (`types.gleam`)
  `pub type Writer { Writer(buffer: BitArray) }` was defined but never
  instantiated or referenced anywhere in the library. The actual writer
  uses `writer.Buffer`. The unused type has been removed.

### Tests added

- `read_i8_negative_roundtrip_test` — roundtrip for i8 values
  `-128, -42, -1, 0, 1, 127` via `write_i8` / `read_i8`.
- `i8_write_boundaries_test` — verifies the raw byte written for
  boundary values `127`, `-128`, `-1` (expected `0xFF`).
- `i16_write_boundaries_test` — roundtrip for `32 767`, `-32 768`, `-1`
  via `write_i16` / `read_i16`.
- `permissive_bool_accepts_zero_as_false_test` — verifies that
  `AcceptBoth` maps byte `0` to `False`.
- `message_negative_seqid_roundtrip_test` — roundtrip for sequence IDs
  `-1`, `-100`, `-2 147 483 648`.
- `long_form_negative_field_id_test` — verifies that a long-form field
  header with `field_id = -1` encodes and decodes correctly.
- `long_form_header_test` updated to use the correct wire bytes:
  `zigzag(32) = 64`, varint `<<0x40>>` instead of the previous
  (incorrect) plain varint `<<0x20>>`.
