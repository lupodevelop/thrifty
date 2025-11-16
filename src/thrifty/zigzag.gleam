import gleam/int

/// ZigZag encode/decode for signed integers.
///
/// Maps signed integers to unsigned so small-magnitude negative numbers
/// become small positive integers for efficient varint encoding.
const min_i32 = -2_147_483_648

const max_i32 = 2_147_483_647

const min_i64 = -9_223_372_036_854_775_808

const max_i64 = 9_223_372_036_854_775_807

const uint32_mod = 4_294_967_296

const uint64_mod = 18_446_744_073_709_551_616

/// Error type returned by checked ZigZag encoders when a value exceeds the
/// allowed range.
pub type ZigzagRangeError {
  ZigzagRangeError(value: Int, bits: Int)
}

/// Encode a signed 32-bit integer into an unsigned integer using ZigZag.
///
/// Inputs
/// - `n`: signed integer expected to fit in 32-bit signed range.
///
/// Outputs
/// - Returns the ZigZag-encoded unsigned integer.
///
/// Error modes
/// - Panics when `n` is outside the supported i32 range. Use
///   `encode_i32_checked/1` to receive an explicit error instead of panicking.
pub fn encode_i32(n: Int) -> Int {
  case encode_i32_checked(n) {
    Ok(value) -> value
    Error(err) -> panic as zigzag_range_error_to_string(err)
  }
}

/// Checked version of `encode_i32/1` returning an explicit error for out-of-range inputs.
///
/// Inputs
/// - `n`: signed integer to encode.
///
/// Outputs
/// - `Ok(Int)` with the ZigZag-encoded unsigned integer when `n` fits in i32.
/// - `Error(ZigzagRangeError)` when `n` is outside the i32 representable range.
pub fn encode_i32_checked(n: Int) -> Result(Int, ZigzagRangeError) {
  case check_range(n, min_i32, max_i32, 32) {
    Error(e) -> Error(e)
    Ok(value) -> Ok(mask_uint(zigzag_encode_formula(value), uint32_mod))
  }
}

/// Decode a ZigZag-encoded unsigned integer back to signed i32.
///
/// Inputs
/// - `z`: ZigZag-encoded unsigned integer.
///
/// Outputs
/// - Returns the decoded signed integer.
pub fn decode_i32(z: Int) -> Int {
  case z % 2 == 0 {
    True -> z / 2
    False -> 0 - z / 2 - 1
  }
}

/// Encode a signed 64-bit integer into an unsigned integer using ZigZag.
///
/// Inputs
/// - `n`: signed integer expected to fit in 64-bit signed range.
///
/// Outputs
/// - Returns the ZigZag-encoded unsigned integer.
///
/// Error modes
/// - Panics when `n` is outside the supported i64 range. Use
///   `encode_i64_checked/1` to receive an explicit error instead of panicking.
pub fn encode_i64(n: Int) -> Int {
  case encode_i64_checked(n) {
    Ok(value) -> value
    Error(err) -> panic as zigzag_range_error_to_string(err)
  }
}

/// Checked version of `encode_i64/1` returning an explicit error for out-of-range inputs.
///
/// Inputs
/// - `n`: signed integer to encode.
///
/// Outputs
/// - `Ok(Int)` with the ZigZag-encoded unsigned integer when `n` fits in i64.
/// - `Error(ZigzagRangeError)` when `n` is outside the i64 representable range.
pub fn encode_i64_checked(n: Int) -> Result(Int, ZigzagRangeError) {
  case check_range(n, min_i64, max_i64, 64) {
    Error(e) -> Error(e)
    Ok(value) -> Ok(mask_uint(zigzag_encode_formula(value), uint64_mod))
  }
}

/// Decode a ZigZag-encoded unsigned integer back to signed i64.
///
/// Inputs
/// - `z`: ZigZag-encoded unsigned integer.
///
/// Outputs
/// - Returns the decoded signed integer.
pub fn decode_i64(z: Int) -> Int {
  case z % 2 == 0 {
    True -> z / 2
    False -> 0 - z / 2 - 1
  }
}

fn check_range(
  value: Int,
  min: Int,
  max: Int,
  bits: Int,
) -> Result(Int, ZigzagRangeError) {
  case value < min || value > max {
    True -> Error(ZigzagRangeError(value, bits))
    False -> Ok(value)
  }
}

/// Validate that `value` falls within `[min, max]` inclusive and return an
/// explicit `ZigzagRangeError` when it does not.
///
/// Inputs
/// - `value`: integer to validate.
/// - `min`, `max`: inclusive bounds.
/// - `bits`: bit-width used for error reporting.
///
/// Outputs
/// - `Ok(value)` when within range.
/// - `Error(ZigzagRangeError)` when out of range.
fn mask_uint(value: Int, modulus: Int) -> Int {
  let remainder = value % modulus
  case remainder < 0 {
    True -> remainder + modulus
    False -> remainder
  }
}

/// Ensure an integer is represented as a non-negative residue modulo `modulus`.
///
/// Inputs
/// - `value`: integer to reduce.
/// - `modulus`: modulus used for reduction (e.g., 2^32, 2^64).
///
/// Outputs
/// - Non-negative integer in 0..modulus-1 representing `value mod modulus`.
fn zigzag_encode_formula(n: Int) -> Int {
  case n >= 0 {
    True -> n * 2
    False -> n * -2 - 1
  }
}

/// Core zigzag mapping formula: maps signed integers to unsigned integers
/// such that small-magnitude signed values map to small unsigned values.
///
/// Inputs
/// - `n`: signed integer.
///
/// Outputs
/// - ZigZag-mapped integer (unsigned representation prior to masking).
fn zigzag_range_error_to_string(err: ZigzagRangeError) -> String {
  case err {
    ZigzagRangeError(value, bits) ->
      "Value "
      <> int.to_string(value)
      <> " is outside the supported i"
      <> int.to_string(bits)
      <> " range"
  }
}
/// Format a `ZigzagRangeError` for logging or panic messages.
