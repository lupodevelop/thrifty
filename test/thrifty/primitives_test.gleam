import gleeunit
import gleeunit/should
import thrifty/varint
import thrifty/zigzag

pub fn main() {
  gleeunit.main()
}

// Varint encode/decode roundtrip tests
pub fn varint_encode_zero_test() {
  let encoded = varint.encode_varint(0)
  let assert Ok(#(value, _)) = varint.decode_varint(encoded, 0)
  value |> should.equal(0)
}

pub fn varint_encode_one_test() {
  let encoded = varint.encode_varint(1)
  let assert Ok(#(value, _)) = varint.decode_varint(encoded, 0)
  value |> should.equal(1)
}

pub fn varint_encode_127_test() {
  let encoded = varint.encode_varint(127)
  let assert Ok(#(value, _)) = varint.decode_varint(encoded, 0)
  value |> should.equal(127)
}

pub fn varint_encode_128_test() {
  let encoded = varint.encode_varint(128)
  let assert Ok(#(value, _)) = varint.decode_varint(encoded, 0)
  value |> should.equal(128)
}

pub fn varint_encode_256_test() {
  let encoded = varint.encode_varint(256)
  let assert Ok(#(value, _)) = varint.decode_varint(encoded, 0)
  value |> should.equal(256)
}

pub fn varint_encode_large_test() {
  let encoded = varint.encode_varint(16_384)
  let assert Ok(#(value, _)) = varint.decode_varint(encoded, 0)
  value |> should.equal(16_384)
}

// ZigZag encode/decode roundtrip tests
pub fn zigzag_encode_zero_test() {
  let encoded = zigzag.encode_i32(0)
  let decoded = zigzag.decode_i32(encoded)
  decoded |> should.equal(0)
}

pub fn zigzag_encode_one_test() {
  let encoded = zigzag.encode_i32(1)
  let decoded = zigzag.decode_i32(encoded)
  decoded |> should.equal(1)
}

pub fn zigzag_encode_negative_one_test() {
  let encoded = zigzag.encode_i32(-1)
  let decoded = zigzag.decode_i32(encoded)
  decoded |> should.equal(-1)
}

pub fn zigzag_encode_negative_two_test() {
  let encoded = zigzag.encode_i32(-2)
  let decoded = zigzag.decode_i32(encoded)
  decoded |> should.equal(-2)
}

pub fn zigzag_encode_large_positive_test() {
  let encoded = zigzag.encode_i32(1000)
  let decoded = zigzag.decode_i32(encoded)
  decoded |> should.equal(1000)
}

pub fn zigzag_encode_large_negative_test() {
  let encoded = zigzag.encode_i32(-1000)
  let decoded = zigzag.decode_i32(encoded)
  decoded |> should.equal(-1000)
}

// ZigZag i64 roundtrip tests
pub fn zigzag_encode_i64_zero_test() {
  let encoded = zigzag.encode_i64(0)
  let decoded = zigzag.decode_i64(encoded)
  decoded |> should.equal(0)
}

pub fn zigzag_encode_i64_negative_one_test() {
  let encoded = zigzag.encode_i64(-1)
  let decoded = zigzag.decode_i64(encoded)
  decoded |> should.equal(-1)
}
