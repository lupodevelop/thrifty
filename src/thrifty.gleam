// Copyright 2025 The thrifty contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import gleam/io

import thrifty/reader
import thrifty/types
import thrifty/writer_highlevel as high_writer

/// Convenience top-level API for small projects that `import thrifty`
///
/// This module exposes a tiny, curated surface so consumers that import
/// `thrifty` have quick access to common reader/writer helpers without
/// importing internal submodules. For advanced usage prefer importing
/// `thrifty/reader` or `thrifty/writer` directly.
/// CLI entry used for quick manual checks during development.
///
/// This module is primarily a library: consumers should `import thrifty`
/// and use the provided helpers (for example `from_bit_array`,
/// `with_options`, `new_struct_writer`). The `main` here is a small,
/// non-invasive convenience that prints a short message when the package
/// is run directly. It is intentionally minimal and not a replacement for
/// a proper CLI or integration in a production project.
pub fn main() -> Nil {
  io.println(
    "thrifty: library — import `thrifty` and use the helpers (this main is a tiny smoke-test, not a production CLI)",
  )
}

/// Construct a reader from a low-level BitArray containing a compact-encoded
/// Thrift payload.
///
/// Inputs
/// - `data`: the `BitArray` which contains the bytes of a compact-encoded
///   Thrift message. The function does not copy `data`; the returned reader
///   references it immutably.
///
/// Outputs
/// - Returns a `types.Reader` positioned at the start of `data` suitable for
///   subsequent `read_*` operations.
///
/// Error modes / guarantees
/// - This constructor does not perform parsing or validation beyond creating
///   the reader. Errors from malformed payloads appear when read operations
///   are invoked (for example `read_i32` or `read_string`).
pub fn from_bit_array(data: BitArray) -> types.Reader {
  reader.from_bit_array(data)
}

/// Construct a reader with explicit runtime limits and decoding options.
///
/// Inputs
/// - `data`: the `BitArray` containing the compact-encoded payload.
/// - `options`: a `types.ReaderOptions` record controlling limits such as
///   maximum container items, maximum recursion depth, maximum string bytes,
///   and the boolean element policy.
///
/// Outputs
/// - Returns a `types.Reader` configured with the provided `options`.
///
/// Semantics and safety
/// - Options are enforced during subsequent read operations; when a limit is
///   exceeded the reader will return a `types.DecodeError` rather than crash.
/// - Use this constructor when parsing untrusted data or when you need to
///   enforce resource bounds in library consumers.
pub fn with_options(
  data: BitArray,
  options: types.ReaderOptions,
) -> types.Reader {
  reader.with_options(data, options)
}

/// Read a compact-encoded string from the provided reader.
///
/// Inputs
/// - `r`: the `types.Reader` positioned at the start of a string field.
///
/// Outputs
/// - On success returns `Ok((value, reader'))` where `value` is the decoded
///   UTF-8 string and `reader'` is the reader advanced past the string bytes.
/// - On failure returns `Error(types.DecodeError)` describing the problem
///   (for example truncated data, invalid UTF-8, or exceeding configured
///   `max_string_bytes`).
pub fn read_string(
  r: types.Reader,
) -> Result(#(String, types.Reader), types.DecodeError) {
  reader.read_string(r)
}

/// Read a 32-bit signed integer encoded with Thrift compact varint/zigzag
/// encoding.
///
/// Inputs
/// - `r`: a `types.Reader` positioned at an integer field.
///
/// Outputs
/// - On success returns `Ok((value, reader'))` where `value` is the decoded
///   integer and `reader'` is the reader advanced past the integer encoding.
/// - On failure returns `Error(types.DecodeError)`, typically for truncated
///   varint encodings or if the encoded value would cause an overflow.
pub fn read_i32(
  r: types.Reader,
) -> Result(#(Int, types.Reader), types.DecodeError) {
  reader.read_i32(r)
}

/// Read a boolean value when encoded as a field element in the compact
/// protocol.
///
/// Background
/// - In Thrift Compact, boolean fields may be encoded either inline in the
///   field header (canonical) or as a separate byte depending on the writer
///   and field position. The reader's behavior may be controlled by the
///   `bool_element_policy` option in `types.ReaderOptions`.
///
/// Inputs
/// - `r`: the `types.Reader` positioned at a boolean field.
///
/// Outputs
/// - Returns `Ok((value, reader'))` with the boolean `value` and an advanced
///   reader on success.
/// - Returns `Error(types.DecodeError)` for malformed encodings or when the
///   reader policy rejects non-canonical boolean encodings if the policy
///   requires canonical-only booleans.
pub fn read_bool_element(
  r: types.Reader,
) -> Result(#(Bool, types.Reader), types.DecodeError) {
  reader.read_bool_element(r)
}

/// Skip over a value of the specified Thrift `FieldType`.
///
/// Inputs
/// - `r`: the `types.Reader` positioned at the start of a value.
/// - `t`: the `types.FieldType` describing the encoded type to skip.
///
/// Outputs
/// - Returns `Ok(reader')` with `reader'` advanced past the encoded value on
///   success.
/// - Returns `Error(types.DecodeError)` when the encoded value is truncated,
///   when a container exceeds configured limits, or on other decoding errors.
///
/// Notes
/// - This helper is useful when the caller is only interested in selected
///   fields and wants to ignore others while still enforcing resource bounds.
pub fn skip_value(
  r: types.Reader,
  t: types.FieldType,
) -> Result(types.Reader, types.DecodeError) {
  reader.skip_value(r, t)
}

/// Return the default `types.ReaderOptions` used by convenience constructors.
///
/// Outputs
/// - A `types.ReaderOptions` record populated with conservative defaults for
///   maximum recursion depth, maximum container items, maximum string
///   length, and the boolean element policy. These defaults are chosen to be
///   safe for typical server workloads but can be overridden with
///   `with_options` for more restrictive or permissive policies.
pub fn default_reader_options() -> types.ReaderOptions {
  types.default_reader_options
}

/// Create a new high-level struct writer for building compact-encoded
/// Thrift messages.
///
/// Outputs
/// - Returns a `high_writer.StructWriter` initially empty. The writer exposes
///   composable helpers to append fields and then produce a compact-encoded
///   `BitArray`.
///
/// Semantics
/// - The high-level writer is intended for small-to-medium sized payloads and
///   convenience usage. For maximum performance consider using a lower-level
///   writer if micro-optimizations are required.
pub fn new_struct_writer() -> high_writer.StructWriter {
  high_writer.new()
}
