import gleam/bit_array
import gleeunit/should

import thrifty/container
import thrifty/reader as thrifty_reader
import thrifty/types
import thrifty/varint

// Truncated varint should return UnexpectedEndOfInput
pub fn truncated_varint_test() {
  let full = varint.encode_varint(0x123456)
  // Truncate last byte
  let truncated = bit_array.slice(full, 0, bit_array.byte_size(full) - 1)

  case truncated {
    Error(_) -> should.fail()
    Ok(bytes) -> {
      let reader =
        thrifty_reader.with_options(
          bytes,
          types.ReaderOptions(
            max_depth: 64,
            max_container_items: 1024,
            max_string_bytes: 1024,
            bool_element_policy: types.AcceptCanonicalOnly,
          ),
        )

      case thrifty_reader.read_varint(reader) {
        Ok(_) -> should.fail()
        Error(types.UnexpectedEndOfInput) -> True |> should.equal(True)
        Error(_) -> should.fail()
      }
    }
  }
}

// Excessively long varint (10 continuation bytes) should return InvalidVarint
pub fn varint_overflow_test() {
  // 10 bytes with MSB set will trigger the byte_count >= 10 guard
  let bytes = <<
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
    128:int-size(8),
  >>

  let reader =
    thrifty_reader.with_options(
      bytes,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 1024,
        max_string_bytes: 1024,
        bool_element_policy: types.AcceptCanonicalOnly,
      ),
    )

  case thrifty_reader.read_varint(reader) {
    Ok(_) -> should.fail()
    Error(types.InvalidVarint) -> True |> should.equal(True)
    Error(_) -> should.fail()
  }
}

// Large container header exceeding limits should return Exceeded container size limit
pub fn container_size_limit_fuzz_test() {
  // encode a list header for size 100
  let header = container.encode_list_header(100, container.I32Type)

  let reader =
    thrifty_reader.with_options(
      header,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 10,
        max_string_bytes: 1024,
        bool_element_policy: types.AcceptCanonicalOnly,
      ),
    )

  should.equal(
    Error(types.InvalidWireFormat("Exceeded container size limit")),
    thrifty_reader.skip_value(reader, types.List),
  )
}
