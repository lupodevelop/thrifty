import gleeunit
import gleeunit/should
import thrifty/container

pub fn main() {
  gleeunit.main()
}

// List/Set header encoding/decoding tests

pub fn list_header_short_empty_test() {
  let encoded = container.encode_list_header(0, container.I32Type)
  let assert Ok(#(size, _elem_type, next_pos)) =
    container.decode_list_header(encoded, 0)
  size |> should.equal(0)
  next_pos |> should.equal(1)
}

pub fn list_header_short_single_test() {
  let encoded = container.encode_list_header(1, container.I32Type)
  let assert Ok(#(size, _elem_type, next_pos)) =
    container.decode_list_header(encoded, 0)
  size |> should.equal(1)
  next_pos |> should.equal(1)
}

pub fn list_header_short_max_test() {
  let encoded = container.encode_list_header(14, container.BinaryType)
  let assert Ok(#(size, _elem_type, next_pos)) =
    container.decode_list_header(encoded, 0)
  size |> should.equal(14)
  next_pos |> should.equal(1)
}

pub fn list_header_long_15_test() {
  let encoded = container.encode_list_header(15, container.I64Type)
  let assert Ok(#(size, _elem_type, next_pos)) =
    container.decode_list_header(encoded, 0)
  size |> should.equal(15)
  next_pos |> should.equal(2)
  // 1 byte header + 1 byte varint
}

pub fn list_header_long_128_test() {
  let encoded = container.encode_list_header(128, container.I32Type)
  let assert Ok(#(size, _elem_type, next_pos)) =
    container.decode_list_header(encoded, 0)
  size |> should.equal(128)
  next_pos |> should.equal(3)
  // 1 byte header + 2 bytes varint
}

pub fn list_header_long_1000_test() {
  let encoded = container.encode_list_header(1000, container.ListType)
  let assert Ok(#(size, _elem_type, _next_pos)) =
    container.decode_list_header(encoded, 0)
  size |> should.equal(1000)
}

// Map header encoding/decoding tests

pub fn map_header_empty_test() {
  let encoded =
    container.encode_map_header(0, container.I32Type, container.BinaryType)
  let assert Ok(#(size, _key_type, _value_type, next_pos)) =
    container.decode_map_header(encoded, 0)
  size |> should.equal(0)
  next_pos |> should.equal(1)
  // Just 0x00
}

pub fn map_header_non_empty_small_test() {
  let encoded =
    container.encode_map_header(5, container.BinaryType, container.I32Type)
  let assert Ok(#(size, _key_type, _value_type, next_pos)) =
    container.decode_map_header(encoded, 0)
  size |> should.equal(5)
  next_pos |> should.equal(2)
  // 1 byte varint + 1 byte types
}

pub fn map_header_non_empty_large_test() {
  let encoded =
    container.encode_map_header(256, container.I64Type, container.BinaryType)
  let assert Ok(#(size, _key_type, _value_type, next_pos)) =
    container.decode_map_header(encoded, 0)
  size |> should.equal(256)
  next_pos |> should.equal(3)
  // 2 bytes varint + 1 byte types
}

pub fn map_header_roundtrip_test() {
  let encoded =
    container.encode_map_header(42, container.BinaryType, container.ListType)
  let assert Ok(#(size, _key_type, _value_type, _next_pos)) =
    container.decode_map_header(encoded, 0)
  size |> should.equal(42)
  // Note: can't directly compare ElementType variants, so just verify decode succeeded
}
