# Strict Boolean Policy

Thrifty enforces a strict interpretation of boolean container elements when configured via `ReaderOptions.bool_element_policy`. This guide illustrates the behaviour and how to surface validation failures.

## Example

```gleam
import gleam/bit_array
import gleam/io
import thrifty/reader
import thrifty/types

fn decode_list(bytes: BitArray) {
  let options = types.ReaderOptions(
    max_depth: 4,
    max_container_items: 64,
    max_string_bytes: 1_048_576,
    bool_element_policy: types.AcceptCanonicalOnly,
  )

  let list_reader = reader.with_options(bytes, options)
  case reader.read_struct(list_reader) {
    Ok(result) -> io.debug(result)
    Error(err) -> io.debug("Invalid payload: " <> types.decode_error_to_string(err))
  }
}

pub fn main() {
  // Byte sequence containing a list<bool> with a non-canonical element (value 3)
  let payload = <<6, 9, 3, 0>>
  let bytes = bit_array.from_bytes(payload)
  decode_list(bytes)
}
```

## Takeaways

- Setting `bool_element_policy: AcceptCanonicalOnly` requires elements encoded as `1` (True) or `2` (False).
- Unexpected values produce an `InvalidWireFormat("Invalid boolean element")` error, preventing ambiguous decoding.
- Use alternative policies (e.g., `AcceptBoth`) when you must interoperate with legacy payloads.
