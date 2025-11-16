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

import thrifty/types
import thrifty/varint

/// List and Set encoding/decoding for Thrift Compact Protocol.
///
/// Format:
/// - Short form (0-14 elements): 1 byte header (sssstttt)
/// - Long form (15+ elements): 1 byte header (1111tttt) + size varint
/// Element type values match field types from spec.
/// Element type codes (same as field types)
/// Note on boolean representation:
/// Historically there is a compatibility quirk in the Compact Protocol: boolean
/// element values inside containers (lists/sets/maps) have been encoded by
/// different implementations using either `1` or `2` as the element byte.
/// The inline boolean type nibble in field headers follows the spec mapping
/// (1 => TRUE, 2 => FALSE); container element bytes are interpreted using the
/// same mapping by this library (1 -> True, 2 -> False).
///
/// Policy in this library:
/// - The reader accepts element bytes `1` and `2` and maps them to booleans
///   as 1 => True, 2 => False.
/// - The `types.ReaderOptions.bool_element_policy` option controls whether to
///   reject bytes outside the set {1,2}. See `thrifty/types.gleam` for
///   available `BoolElementPolicy` values. The default policy enforces
///   canonical validation (accept only 1 or 2 and map 1->True, 2->False).
///
/// If you require an alternative policy (for example, accept a single numeric
/// value for legacy interop), add a thin pre-validation wrapper before
/// calling the reader, or request we add an explicit `bool_element_policy`
/// configuration to express that behaviour.
pub type ElementType {
  BoolType
  // 1 or 2 (reader accepts both)
  I8Type
  // 3
  I16Type
  // 4
  I32Type
  // 5
  I64Type
  // 6
  DoubleType
  // 7
  BinaryType
  // 8 (for string and binary)
  ListType
  // 9
  SetType
  // 10
  MapType
  // 11
  StructType
  // 12
  // note: codes > 12 are not part of the official Compact spec
}

/// Convert ElementType to compact protocol type code (4 bits).
///
/// Inputs
/// - `t`: the `ElementType` to convert.
///
/// Outputs
/// - Returns the 4-bit integer code used in Compact Protocol headers.
///
/// Complexity
/// - O(1)
pub fn element_type_to_code(t: ElementType) -> Int {
  case t {
    BoolType -> 2
    // Use 2 as default (spec original), reader accepts 1 too
    I8Type -> 3
    I16Type -> 4
    I32Type -> 5
    I64Type -> 6
    DoubleType -> 7
    BinaryType -> 8
    ListType -> 9
    SetType -> 10
    MapType -> 11
    StructType -> 12
    // no mapping for non-standard types
  }
}

/// Convert a compact protocol 4-bit type code to `ElementType`.
///
/// Inputs
/// - `code`: integer value extracted from a header nibble (0-15).
///
/// Outputs
/// - `Ok(ElementType)` when the code is recognized.
/// - `Error(types.UnsupportedType(code))` when the code is unknown.
///
/// Error modes
/// - Returns `types.UnsupportedType` for unknown codes.
pub fn code_to_element_type(code: Int) -> Result(ElementType, types.DecodeError) {
  case code {
    1 -> Ok(BoolType)
    // Accept both 1 and 2 for bool
    2 -> Ok(BoolType)
    3 -> Ok(I8Type)
    4 -> Ok(I16Type)
    5 -> Ok(I32Type)
    6 -> Ok(I64Type)
    7 -> Ok(DoubleType)
    8 -> Ok(BinaryType)
    9 -> Ok(ListType)
    10 -> Ok(SetType)
    11 -> Ok(MapType)
    12 -> Ok(StructType)
    _ -> Error(types.UnsupportedType(code))
  }
}

/// Encode a list/set header consisting of size and element type.
///
/// Inputs
/// - `size`: number of elements in the list/set (non-negative).
/// - `elem_type`: the `ElementType` of elements.
///
/// Outputs
/// - Returns a `BitArray` containing either the short-form header (1 byte)
///   when `size < 15` or the long-form header (1 byte + varint) otherwise.
///
/// Complexity
/// - O(1) (plus cost of varint encoding when required).
pub fn encode_list_header(size: Int, elem_type: ElementType) -> BitArray {
  let type_code = element_type_to_code(elem_type)
  case size < 15 {
    True -> {
      // Short form: sssstttt (1 byte)
      let header_byte = size * 16 + type_code
      <<header_byte:int-size(8)>>
    }
    False -> {
      // Long form: 1111tttt + size varint
      let header_byte = 15 * 16 + type_code
      // 0xF0 | type_code
      let size_varint = varint.encode_varint(size)
      <<header_byte:int-size(8), size_varint:bits>>
    }
  }
}

/// Decode a list/set header from a `BitArray` at `byte_position`.
///
/// Inputs
/// - `data`: the `BitArray` containing the encoded header and payload.
/// - `byte_position`: byte offset where the header begins.
///
/// Outputs
/// - `Ok(#(size, element_type, next_byte_position))` on success where
///   `next_byte_position` is the byte index immediately after the header.
/// - `Error(types.DecodeError)` on malformed input or unexpected end.
pub fn decode_list_header(
  data: BitArray,
  byte_position: Int,
) -> Result(#(Int, ElementType, Int), types.DecodeError) {
  case bit_array.slice(data, byte_position, 1) {
    Error(_) -> Error(types.UnexpectedEndOfInput)
    Ok(header_bits) -> {
      case header_bits {
        <<header_byte:int-size(8)>> -> {
          let size_nibble = header_byte / 16
          let type_nibble = header_byte % 16

          case code_to_element_type(type_nibble) {
            Error(e) -> Error(e)
            Ok(elem_type) -> {
              case size_nibble == 15 {
                True -> {
                  // Long form: read size varint
                  case varint.decode_varint(data, byte_position + 1) {
                    Error(e) -> Error(e)
                    Ok(#(size, next_pos)) -> Ok(#(size, elem_type, next_pos))
                  }
                }
                False -> {
                  // Short form: size is in nibble
                  Ok(#(size_nibble, elem_type, byte_position + 1))
                }
              }
            }
          }
        }
        _ -> Error(types.InvalidWireFormat("Invalid list header byte"))
      }
    }
  }
}

/// Encode a map header (size + key type + value type).
///
/// Inputs
/// - `size`: number of entries in the map (non-negative).
/// - `key_type`: the `ElementType` used for keys.
/// - `value_type`: the `ElementType` used for values.
///
/// Outputs
/// - For empty maps returns a single zero byte.
/// - For non-empty maps returns varint(size) followed by a single types byte
///   where the high nibble is key type and the low nibble is value type.
pub fn encode_map_header(
  size: Int,
  key_type: ElementType,
  value_type: ElementType,
) -> BitArray {
  case size == 0 {
    True -> <<0:int-size(8)>>
    False -> {
      let size_varint = varint.encode_varint(size)
      let key_code = element_type_to_code(key_type)
      let value_code = element_type_to_code(value_type)
      let types_byte = key_code * 16 + value_code
      <<size_varint:bits, types_byte:int-size(8)>>
    }
  }
}

/// Decode a map header from `data` at `byte_position`.
///
/// Inputs
/// - `data`: the `BitArray` containing the encoded header and payload.
/// - `byte_position`: byte offset where the header begins.
///
/// Outputs
/// - `Ok(#(size, key_type, value_type, next_byte_position))` where `next_byte_position`
///   points after the types byte (or after the varint for empty maps).
/// - `Error(types.DecodeError)` on malformed input or unexpected end.
pub fn decode_map_header(
  data: BitArray,
  byte_position: Int,
) -> Result(#(Int, ElementType, ElementType, Int), types.DecodeError) {
  // First, try to read size varint (could be 0 for empty map)
  case varint.decode_varint(data, byte_position) {
    Error(e) -> Error(e)
    Ok(#(size, next_pos)) -> {
      case size == 0 {
        True -> {
          // Empty map: no types byte
          // Return dummy types (won't be used)
          Ok(#(0, I32Type, I32Type, next_pos))
        }
        False -> {
          // Non-empty map: read types byte
          case bit_array.slice(data, next_pos, 1) {
            Error(_) -> Error(types.UnexpectedEndOfInput)
            Ok(types_bits) -> {
              case types_bits {
                <<types_byte:int-size(8)>> -> {
                  let key_code = types_byte / 16
                  let value_code = types_byte % 16

                  case code_to_element_type(key_code) {
                    Error(e) -> Error(e)
                    Ok(key_type) -> {
                      case code_to_element_type(value_code) {
                        Error(e) -> Error(e)
                        Ok(value_type) -> {
                          Ok(#(size, key_type, value_type, next_pos + 1))
                        }
                      }
                    }
                  }
                }
                _ -> Error(types.InvalidWireFormat("Invalid map types byte"))
              }
            }
          }
        }
      }
    }
  }
}
