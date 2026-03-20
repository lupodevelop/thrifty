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
import thrifty/zigzag

/// Read a field header from the reader and advance the reader.
///
/// Inputs
/// - `reader`: a `types.Reader` positioned at the start of a field header.
/// - `last_field_id`: the previous field id used to decode delta-encoded ids.
///
/// Outputs
/// - `Ok(#(types.FieldHeader, types.Reader))` on success where the returned
///   `types.Reader` is advanced past the header.
/// - `Error(types.DecodeError)` for truncated input or invalid header bytes.
///
/// Semantics
/// - Supports the compact protocol short and long forms: short form encodes
///   small deltas in the header byte; long form encodes an absolute field id
///   as a following varint.
pub fn read_field_header(
  reader: types.Reader,
  last_field_id: Int,
) -> Result(#(types.FieldHeader, types.Reader), types.DecodeError) {
  let types.Reader(data, byte_pos, options) = reader
  case bit_array.slice(data, byte_pos, 1) {
    Error(_) -> Error(types.UnexpectedEndOfInput)
    Ok(<<header_byte:int-size(8)>>) ->
      case header_byte == 0 {
        True ->
          Ok(#(
            types.FieldHeader(0, types.Stop),
            set_position(reader, byte_pos + 1, options),
          ))
        False -> {
          let type_value = header_byte % 16
          let delta = header_byte / 16
          case delta == 0 {
            True ->
              // Long form: field id encoded as zigzag i16 + varint (per spec).
              case varint.decode_varint(data, byte_pos + 1) {
                Error(e) -> Error(e)
                Ok(#(field_id_raw, next_pos)) -> {
                  let field_id = zigzag.decode_i32(field_id_raw)
                  case int_to_field_type(type_value) {
                    Error(e) -> Error(e)
                    Ok(field_type) ->
                      Ok(#(
                        types.FieldHeader(field_id, field_type),
                        set_position(reader, next_pos, options),
                      ))
                  }
                }
              }
            False -> {
              // Short form: field id = last_field_id + delta
              let field_id = last_field_id + delta
              case int_to_field_type(type_value) {
                Error(e) -> Error(e)
                Ok(field_type) ->
                  Ok(#(
                    types.FieldHeader(field_id, field_type),
                    set_position(reader, byte_pos + 1, options),
                  ))
              }
            }
          }
        }
      }

    Ok(_) -> Error(types.InvalidWireFormat("Invalid header byte"))
  }
}

/// Encode a field header into a `BitArray` using compact delta encoding.
///
/// Inputs
/// - `field_id`: absolute field identifier.
/// - `field_type`: the `types.FieldType` describing the field payload.
/// - `last_field_id`: previous field id for delta calculation.
///
/// Outputs
/// - Returns a `BitArray` containing either a single header byte (short form)
///   or a header byte followed by a varint-encoded absolute field id (long form).
///
/// Semantics
/// - Short form is used when `1 <= delta <= 15` where `delta = field_id - last_field_id`.
/// - Boolean fields use inline header encodings and follow the same delta rules.
pub fn encode_field_header(
  field_id: Int,
  field_type: types.FieldType,
  last_field_id: Int,
) -> BitArray {
  let delta = field_id - last_field_id
  case field_type {
    types.Stop -> <<0:int-size(8)>>
    types.BoolTrue | types.BoolFalse -> {
      case delta > 0 && delta <= 15 {
        True -> {
          let type_nibble = field_type_to_int(field_type)
          let header_byte = { delta * 16 } + type_nibble
          <<header_byte:int-size(8)>>
        }
        False -> {
          // Long form: field id as zigzag i16 + varint (per spec).
          let varint_bytes = varint.encode_varint(zigzag.encode_i32(field_id))
          let type_nibble = field_type_to_int(field_type)
          let header_byte = type_nibble
          bit_array.concat([<<header_byte:int-size(8)>>, varint_bytes])
        }
      }
    }
    _ -> {
      case delta > 0 && delta <= 15 {
        True -> {
          let type_nibble = field_type_to_int(field_type)
          let header_byte = { delta * 16 } + type_nibble
          <<header_byte:int-size(8)>>
        }
        False -> {
          // Long form: field id as zigzag i16 + varint (per spec).
          let varint_bytes = varint.encode_varint(zigzag.encode_i32(field_id))
          let type_nibble = field_type_to_int(field_type)
          let header_byte = type_nibble
          bit_array.concat([<<header_byte:int-size(8)>>, varint_bytes])
        }
      }
    }
  }
}

/// Convert a `types.FieldType` to its compact protocol integer nibble.
///
/// Inputs
/// - `ft`: field type to convert.
///
/// Outputs
/// - Integer value per Compact Protocol mapping used in header bytes.
fn field_type_to_int(ft: types.FieldType) -> Int {
  case ft {
    types.Stop -> 0
    types.BoolTrue -> 1
    types.BoolFalse -> 2
    types.Byte -> 3
    types.I16 -> 4
    types.I32 -> 5
    types.I64 -> 6
    types.Double -> 7
    types.Binary -> 8
    types.List -> 9
    types.Set -> 10
    types.Map -> 11
    types.Struct -> 12
  }
}

/// Convert an integer nibble to `types.FieldType`.
///
/// Inputs
/// - `n`: integer nibble from a header byte.
///
/// Outputs
/// - `Ok(FieldType)` when the nibble maps to a known type.
/// - `Error(types.UnsupportedType(n))` for unknown nibble values.
fn int_to_field_type(n: Int) -> Result(types.FieldType, types.DecodeError) {
  case n {
    0 -> Ok(types.Stop)
    1 -> Ok(types.BoolTrue)
    2 -> Ok(types.BoolFalse)
    3 -> Ok(types.Byte)
    4 -> Ok(types.I16)
    5 -> Ok(types.I32)
    6 -> Ok(types.I64)
    7 -> Ok(types.Double)
    8 -> Ok(types.Binary)
    9 -> Ok(types.List)
    10 -> Ok(types.Set)
    11 -> Ok(types.Map)
    12 -> Ok(types.Struct)
    _ -> Error(types.UnsupportedType(n))
  }
}

/// Return a new `types.Reader` with updated byte position and options.
///
/// Inputs
/// - `reader`: existing `types.Reader`.
/// - `byte_pos`: new byte offset.
/// - `options`: reader options to attach.
///
/// Outputs
/// - `types.Reader` referencing the same `data` with updated state.
fn set_position(
  reader: types.Reader,
  byte_pos: Int,
  options: types.ReaderOptions,
) -> types.Reader {
  let types.Reader(data, _, _) = reader
  types.Reader(data, byte_pos, options)
}
