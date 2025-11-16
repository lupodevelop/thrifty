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

import gleam/bit_array
import gleam/int
import gleam/list

import thrifty/container
import thrifty/field
import thrifty/message
import thrifty/types
import thrifty/varint
import thrifty/zigzag

/// Encode a raw unsigned integer as varint bytes.
///
/// Inputs
/// - `value`: non-negative integer to encode.
///
/// Outputs
/// - Returns a `BitArray` containing 1..10 bytes of varint-encoded data.
pub fn write_varint(value: Int) -> BitArray {
  varint.encode_varint(value)
}

/// Encode an i32 using ZigZag followed by varint encoding.
///
/// Inputs
/// - `value`: signed integer expected to fit in 32-bit signed range.
///
/// Outputs
/// - Returns a `BitArray` containing the zigzag-then-varint encoding.
///
/// Error modes
/// - Panics if `value` does not fit in the i32 range. Prefer
///   `write_zigzag_i32_checked/1` to handle overflow explicitly.
pub fn write_zigzag_i32(value: Int) -> BitArray {
  case write_zigzag_i32_checked(value) {
    Ok(bits) -> bits
    Error(err) -> panic as zigzag_error_to_string(err)
  }
}

/// Checked i32 ZigZag encoder that returns the resulting bytes or an error.
///
/// Inputs
/// - `value`: signed integer to encode.
///
/// Outputs
/// - `Ok(BitArray)` containing the encoded bytes on success.
/// - `Error(ZigzagRangeError)` when `value` is out of the i32 range.
pub fn write_zigzag_i32_checked(
  value: Int,
) -> Result(BitArray, zigzag.ZigzagRangeError) {
  case zigzag.encode_i32_checked(value) {
    Error(err) -> Error(err)
    Ok(encoded) -> Ok(varint.encode_varint(encoded))
  }
}

/// Encode an i64 using ZigZag followed by varint encoding.
///
/// Inputs
/// - `value`: signed integer expected to fit in 64-bit signed range.
///
/// Outputs
/// - Returns a `BitArray` containing the zigzag-then-varint encoding.
///
/// Error modes
/// - Panics if `value` does not fit in the i64 range. Prefer
///   `write_zigzag_i64_checked/1` to handle overflow explicitly.
pub fn write_zigzag_i64(value: Int) -> BitArray {
  case write_zigzag_i64_checked(value) {
    Ok(bits) -> bits
    Error(err) -> panic as zigzag_error_to_string(err)
  }
}

/// Checked i64 ZigZag encoder that returns the resulting bytes or an error.
///
/// Inputs
/// - `value`: signed integer to encode.
///
/// Outputs
/// - `Ok(BitArray)` containing the encoded bytes on success.
/// - `Error(ZigzagRangeError)` when `value` is out of the i64 range.
pub fn write_zigzag_i64_checked(
  value: Int,
) -> Result(BitArray, zigzag.ZigzagRangeError) {
  case zigzag.encode_i64_checked(value) {
    Error(err) -> Error(err)
    Ok(encoded) -> Ok(varint.encode_varint(encoded))
  }
}

/// Write a single signed byte value.
///
/// Inputs
/// - `value`: integer in -128..127 that will be represented as a single byte.
///
/// Outputs
/// - Returns a `BitArray` of length 1 containing the byte.
pub fn write_i8(value: Int) -> BitArray {
  <<value:int-size(8)>>
}

/// Write an i16 value using zigzag encoding and varint bytes.
///
/// Inputs
/// - `value`: signed integer; caller should ensure it fits expected range.
///
/// Outputs
/// - Returns a `BitArray` with the encoded bytes (delegates to zigzag+varint).
pub fn write_i16(value: Int) -> BitArray {
  varint.encode_varint(zigzag.encode_i32(value))
}

/// Write an i32 value using zigzag encoding and varint bytes.
///
/// Inputs
/// - `value`: signed integer expected to fit in i32 range.
///
/// Outputs
/// - Returns a `BitArray` containing the encoded bytes or panics on overflow.
pub fn write_i32(value: Int) -> BitArray {
  case write_i32_checked(value) {
    Ok(bits) -> bits
    Error(err) -> panic as zigzag_error_to_string(err)
  }
}

/// Checked i32 writer that returns an error on overflow.
///
/// Inputs
/// - `value`: signed integer to write.
///
/// Outputs
/// - `Ok(BitArray)` with encoded bytes on success.
/// - `Error(ZigzagRangeError)` when the value is out of range.
pub fn write_i32_checked(
  value: Int,
) -> Result(BitArray, zigzag.ZigzagRangeError) {
  write_zigzag_i32_checked(value)
}

/// Write an i64 value using zigzag encoding and varint bytes.
///
/// Inputs
/// - `value`: signed integer expected to fit in i64 range.
///
/// Outputs
/// - Returns a `BitArray` with the encoded bytes or panics on overflow.
pub fn write_i64(value: Int) -> BitArray {
  case write_i64_checked(value) {
    Ok(bits) -> bits
    Error(err) -> panic as zigzag_error_to_string(err)
  }
}

/// Checked i64 writer that returns an error on overflow.
///
/// Inputs
/// - `value`: signed integer to write.
///
/// Outputs
/// - `Ok(BitArray)` with encoded bytes on success.
/// - `Error(ZigzagRangeError)` when the value is out of range.
pub fn write_i64_checked(
  value: Int,
) -> Result(BitArray, zigzag.ZigzagRangeError) {
  write_zigzag_i64_checked(value)
}

/// Write a 64-bit little-endian IEEE‑754 float value.
///
/// Inputs
/// - `value`: floating point number to encode.
///
/// Outputs
/// - `BitArray` of 8 bytes containing the IEEE‑754 little-endian encoding.
pub fn write_double(value: Float) -> BitArray {
  <<value:float-little-size(64)>>
}

/// Encode a field header with compact delta encoding logic.
pub fn write_field_header(
  field_id: Int,
  field_type: types.FieldType,
  last_field_id: Int,
) -> BitArray {
  field.encode_field_header(field_id, field_type, last_field_id)
}

/// Encode a message header.
pub fn write_message_header(header: message.MessageHeader) -> BitArray {
  message.encode_message_header(header)
}

/// Write a length-prefixed binary blob.
pub fn write_binary(bytes: BitArray) -> BitArray {
  let length = bit_array.byte_size(bytes)
  concat_many([varint.encode_varint(length), bytes])
}

/// Write a UTF-8 string as length-prefixed binary.
pub fn write_string(value: String) -> BitArray {
  write_binary(<<value:utf8>>)
}

/// Encode a list header.
pub fn write_list_header(
  size: Int,
  element_type: container.ElementType,
) -> BitArray {
  container.encode_list_header(size, element_type)
}

/// Encode a map header.
pub fn write_map_header(
  size: Int,
  key_type: container.ElementType,
  value_type: container.ElementType,
) -> BitArray {
  container.encode_map_header(size, key_type, value_type)
}

/// Encode a list by combining its header and payload.
pub fn write_list(
  size: Int,
  element_type: container.ElementType,
  payload: BitArray,
) -> BitArray {
  concat_many([write_list_header(size, element_type), payload])
}

/// Encode a map by combining its header and payload.
pub fn write_map(
  size: Int,
  key_type: container.ElementType,
  value_type: container.ElementType,
  payload: BitArray,
) -> BitArray {
  concat_many([write_map_header(size, key_type, value_type), payload])
}

/// Concatenate a list of bitarrays in order.
fn concat_many(parts: List(BitArray)) -> BitArray {
  list.fold(parts, <<>>, fn(acc, part) { bit_array.concat([acc, part]) })
}

/// Concatenate a list of `BitArray` parts into a single contiguous `BitArray`.
///
/// Inputs
/// - `parts`: list of `BitArray` values to concatenate in order.
///
/// Outputs
/// - A single `BitArray` containing the concatenated bytes.
/// Buffer accumulator used by the high-level writer for struct assembly.
pub type Buffer {
  Buffer(parts: List(BitArray))
}

/// Create an empty buffer accumulator.
pub fn buffer_new() -> Buffer {
  Buffer([])
}

/// Create a new empty buffer accumulator for high-level writer assembly.
/// Append a new part to the buffer.
pub fn buffer_append(buffer: Buffer, part: BitArray) -> Buffer {
  case buffer {
    Buffer(parts) -> Buffer([part, ..parts])
  }
}

/// Append a part to an existing `Buffer` accumulator.
///
/// Inputs
/// - `buffer`: existing `Buffer`.
/// - `part`: `BitArray` to append.
///
/// Outputs
/// - New `Buffer` with `part` added to the internal list.
/// Convert an accumulated buffer into a contiguous bitarray.
pub fn buffer_to_bitarray(buffer: Buffer) -> BitArray {
  case buffer {
    Buffer(parts) -> concat_many(list.reverse(parts))
  }
}

/// Convert an accumulated `Buffer` into a contiguous `BitArray`.
///
/// Outputs
/// - Concatenated `BitArray` in original append order.
/// Write a boolean field using the inline field header encoding.
pub fn write_bool(field_id: Int, value: Bool, last_field_id: Int) -> BitArray {
  write_bool_inline(field_id, value, last_field_id)
}

/// Write a boolean field using the inline header helper.
pub fn write_bool_inline(
  field_id: Int,
  value: Bool,
  last_field_id: Int,
) -> BitArray {
  let field_type = case value {
    True -> types.BoolTrue
    False -> types.BoolFalse
  }
  write_field_header(field_id, field_type, last_field_id)
}

fn zigzag_error_to_string(err: zigzag.ZigzagRangeError) -> String {
  case err {
    zigzag.ZigzagRangeError(value, bits) ->
      "Value " <> int.to_string(value) <> " overflows i" <> int.to_string(bits)
  }
}
/// Format a `ZigzagRangeError` into a human readable string for panics/logs.
