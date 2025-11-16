# Basic Decoding Example

Learn how to decode a Compact Protocol payload using Thrifty's reader API. This example shows how to:

- Create a reader backed by a `BitArray`
- Read primitives and fields from a struct
- Handle decoding errors gracefully

## Setup

```gleam
import gleam/bit_array
import gleam/io
import thrifty/reader
import thrifty/types

pub fn main() {
  // Raw Compact Protocol payload (replace with your own bytes)
  let payload = <<12, 16, 130, 1, 5, 72, 101, 108, 108, 111, 0>>
  let bitstring = bit_array.from_bytes(payload)

  let reader = reader.with_options(
    bitstring,
    types.ReaderOptions(
      max_depth: 32,
      max_container_items: 1024,
      max_string_bytes: 65_536,
      bool_element_policy: types.AcceptCanonicalOnly,
    ),
  )

  case reader.read_struct(reader) {
    Ok(#(fields, _next_reader)) -> io.debug(fields)
    Error(err) -> io.debug("Decode error: " <> types.decode_error_to_string(err))
  }
}
```

## Explanation

- `reader.with_options` constructs an immutable reader with safety limits.
- `read_struct` returns a list of field headers and the reader positioned after the struct body.
- Always inspect the result via pattern matching; decoding may fail because of malformed input or policy violations.
