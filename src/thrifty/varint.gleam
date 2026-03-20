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

import thrifty/types

/// Encode an unsigned integer as a varint BitArray.
/// Returns a BitArray of 1-10 bytes (for i64).
///
/// Varint encoding: 7 bits per byte, MSB as continuation bit.
/// Bytes are emitted LSB first.
///
/// Panics if `n` is negative. Use callers that guarantee non-negative input
/// (e.g. ZigZag-encode signed integers before calling this function).
pub fn encode_varint(n: Int) -> BitArray {
  case n < 0 {
    True ->
      panic as {
        "encode_varint requires a non-negative integer, got "
        <> int.to_string(n)
      }
    False ->
      encode_varint_loop(n, [])
      |> list.reverse
      |> list_to_bitarray
  }
}

/// Internal loop that emits varint bytes (LSB-first) into an accumulator.
///
/// Inputs
/// - `n`: remaining unsigned integer to encode.
/// - `acc`: accumulator list of emitted bytes (in reverse order).
///
/// Outputs
/// - List of byte integers representing the varint, in emission order when
///   reversed by the caller.
fn encode_varint_loop(n: Int, acc: List(Int)) -> List(Int) {
  let low7 = n % 128
  let rest = n / 128
  case rest > 0 {
    True -> {
      // More bytes to come: set MSB
      let byte = low7 + 128
      encode_varint_loop(rest, [byte, ..acc])
    }
    False -> {
      // Last byte: MSB clear
      [low7, ..acc]
    }
  }
}

/// Convert a list of byte integers to a `BitArray` by serial concatenation.
///
/// Inputs
/// - `bytes`: list of integers each 0..255.
///
/// Outputs
/// - `BitArray` concatenating the provided bytes.
fn list_to_bitarray(bytes: List(Int)) -> BitArray {
  case bytes {
    [] -> <<>>
    [h, ..t] -> {
      let rest_bits = list_to_bitarray(t)
      <<h:int-size(8), rest_bits:bits>>
    }
  }
}

/// Decode a varint from a BitArray starting at a given byte position.
/// Returns Ok(#(value, next_byte_position)) on success, or Error on failure.
///
/// Max length: 10 bytes for i64, 5 bytes for i32.
/// Reads bytes LSB first, accumulating 7-bit groups.
pub fn decode_varint(
  data: BitArray,
  byte_position: Int,
) -> Result(#(Int, Int), types.DecodeError) {
  decode_varint_loop(data, byte_position, 0, 1, 0)
}

/// Recursive helper that decodes varint bytes accumulating the result.
///
/// Inputs
/// - `data`: source `BitArray`.
/// - `byte_pos`: current byte offset to read.
/// - `value`: accumulated integer value so far.
/// - `multiplier`: current multiplier (powers of 128) for incoming 7-bit groups.
/// - `byte_count`: number of bytes consumed so far (used to bound length).
///
/// Outputs
/// - `Ok(#(value, next_byte_pos))` on successful termination.
/// - `Error(types.InvalidVarint)` when maximum byte length is exceeded.
/// - `Error(types.UnexpectedEndOfInput)` when data runs out mid-varint.
fn decode_varint_loop(
  data: BitArray,
  byte_pos: Int,
  value: Int,
  multiplier: Int,
  byte_count: Int,
) -> Result(#(Int, Int), types.DecodeError) {
  case byte_count >= 10 {
    True -> Error(types.InvalidVarint)
    False -> {
      // bit_array.slice takes byte offset and byte length
      case bit_array.slice(data, byte_pos, 1) {
        Error(_) -> Error(types.UnexpectedEndOfInput)
        Ok(byte_bits) -> {
          case byte_bits {
            <<b:int-size(8)>> -> {
              let low7 = b % 128
              let new_value = value + low7 * multiplier
              let has_more = b >= 128
              case has_more {
                True ->
                  decode_varint_loop(
                    data,
                    byte_pos + 1,
                    new_value,
                    multiplier * 128,
                    byte_count + 1,
                  )
                False -> {
                  let next_byte_pos = byte_pos + 1
                  Ok(#(new_value, next_byte_pos))
                }
              }
            }
            _ -> Error(types.InvalidWireFormat("Invalid byte in varint"))
          }
        }
      }
    }
  }
}
