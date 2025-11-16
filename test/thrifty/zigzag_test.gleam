import gleeunit
import gleeunit/should

import gleam/list
import thrifty/zigzag

pub fn main() {
  gleeunit.main()
}

pub fn zigzag_roundtrip_small_values_test() {
  // A few small values including negatives
  let vals = [-10, -1, 0, 1, 2, 10]
  list.map(vals, fn(v) {
    let enc = zigzag.encode_i32(v)
    let dec = zigzag.decode_i32(enc)
    dec |> should.equal(v)
    0
  })
}

pub fn zigzag_roundtrip_boundaries_test() {
  // 32-bit boundaries
  let min32 = -2_147_483_648
  let max32 = 2_147_483_647
  zigzag.decode_i32(zigzag.encode_i32(min32)) |> should.equal(min32)
  zigzag.decode_i32(zigzag.encode_i32(max32)) |> should.equal(max32)

  // A few 64-bit-ish values (Gleam ints are unbounded but we check common ranges)
  let vals64 = [
    -9_223_372_036_854_775_808,
    -1_000_000_000_000,
    0,
    1_000_000_000_000,
    9_223_372_036_854_775_807,
  ]
  list.map(vals64, fn(v) {
    let enc = zigzag.encode_i64(v)
    let dec = zigzag.decode_i64(enc)
    dec |> should.equal(v)
    0
  })
}

pub fn zigzag_out_of_range_test() {
  let assert Error(zigzag.ZigzagRangeError(_, 32)) =
    zigzag.encode_i32_checked(2_147_483_648)
  let assert Error(zigzag.ZigzagRangeError(_, 64)) =
    zigzag.encode_i64_checked(9_223_372_036_854_775_808)
}
