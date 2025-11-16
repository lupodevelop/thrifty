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

/// Replace the byte at position `pos` with the provided `value`.
///
/// Inputs
/// - `data`: the source `BitArray` to mutate.
/// - `pos`: zero-based byte index to replace.
/// - `value`: integer 0..255 to write at `pos`.
///
/// Outputs
/// - Returns a new `BitArray` with the replaced byte when `pos` is in range.
/// - Returns the original `data` unchanged if `pos` is out of range or on
///   unexpected slicing errors.
pub fn mutate_byte(data: BitArray, pos: Int, value: Int) -> BitArray {
  let size = bit_array.byte_size(data)
  case pos < 0 || pos >= size {
    True -> data
    False ->
      case bit_array.slice(data, 0, pos) {
        Error(_) -> data
        Ok(prefix) -> {
          let suffix_len = size - pos - 1
          case bit_array.slice(data, pos + 1, suffix_len) {
            Error(_) -> bit_array.concat([prefix, <<value:int-size(8)>>])
            Ok(suffix) ->
              bit_array.concat([prefix, <<value:int-size(8)>>, suffix])
          }
        }
      }
  }
}

/// Flip a single bit in the byte at `pos`.
///
/// Inputs
/// - `data`: source `BitArray`.
/// - `pos`: byte index to modify.
/// - `bit_index`: 0..7 bit to flip (0 is LSB).
///
/// Outputs
/// - `BitArray` with the selected bit flipped, or original data if out of range.
pub fn mutate_bit_flip(data: BitArray, pos: Int, bit_index: Int) -> BitArray {
  let size = bit_array.byte_size(data)
  case pos < 0 || pos >= size || bit_index < 0 || bit_index > 7 {
    True -> data
    False ->
      case bit_array.slice(data, pos, 1) {
        Error(_) -> data
        Ok(bits) ->
          case bits {
            <<b:int-size(8)>> -> {
              let mask = pow2(bit_index)
              let div = b / mask
              let has_bit = div % 2 == 1
              let new_byte = case has_bit {
                True -> b - mask
                False -> b + mask
              }
              mutate_byte(data, pos, new_byte)
            }
            _ -> data
          }
      }
  }
}

/// Insert a single byte at position `pos` shifting the remainder to the right.
pub fn mutate_insert_byte(data: BitArray, pos: Int, value: Int) -> BitArray {
  let size = bit_array.byte_size(data)
  case pos < 0 || pos > size {
    True -> data
    False ->
      case bit_array.slice(data, 0, pos) {
        Error(_) -> data
        Ok(prefix) ->
          case bit_array.slice(data, pos, size - pos) {
            Error(_) -> bit_array.concat([prefix, <<value:int-size(8)>>])
            Ok(suffix) ->
              bit_array.concat([prefix, <<value:int-size(8)>>, suffix])
          }
      }
  }
}

/// Delete a single byte at position `pos`.
pub fn mutate_delete_byte(data: BitArray, pos: Int) -> BitArray {
  let size = bit_array.byte_size(data)
  case pos < 0 || pos >= size {
    True -> data
    False ->
      case bit_array.slice(data, 0, pos) {
        Error(_) -> data
        Ok(prefix) ->
          case bit_array.slice(data, pos + 1, size - pos - 1) {
            Error(_) -> prefix
            Ok(suffix) -> bit_array.concat([prefix, suffix])
          }
      }
  }
}

/// Overwrite `len` bytes starting at `pos` with repeated `value` bytes.
pub fn mutate_multi_byte(
  data: BitArray,
  pos: Int,
  len: Int,
  value: Int,
) -> BitArray {
  let size = bit_array.byte_size(data)
  case pos < 0 || pos >= size || len <= 0 {
    True -> data
    False -> {
      let write_len = case pos + len > size {
        True -> size - pos
        False -> len
      }
      case bit_array.slice(data, 0, pos) {
        Error(_) -> data
        Ok(prefix) -> {
          let repeated = gen_bytes(write_len, value)
          case bit_array.slice(data, pos + write_len, size - pos - write_len) {
            Error(_) -> bit_array.concat([prefix, repeated])
            Ok(suffix) -> bit_array.concat([prefix, repeated, suffix])
          }
        }
      }
    }
  }
}

fn gen_bytes(count: Int, value: Int) -> BitArray {
  case count <= 0 {
    True -> <<>>
    False -> {
      let tail = gen_bytes(count - 1, value)
      <<value:int-size(8), tail:bits>>
    }
  }
}

fn pow2(exp: Int) -> Int {
  case exp <= 0 {
    True -> 1
    False -> 2 * pow2(exp - 1)
  }
}
