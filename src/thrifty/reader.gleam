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
import gleam/list

import thrifty/container
import thrifty/field
import thrifty/types
import thrifty/varint
import thrifty/zigzag

/// Helpers for reading Compact Protocol values with an immutable `Reader`.
///
/// Public API contract (high level):
/// - from_bit_array/1: create a `Reader` positioned at the beginning of `data`.
/// - read_i8/read_i16/read_i32/read_i64: read the corresponding signed
///   integer and return Ok(#(value, reader)) or an Error(DecodeError).
/// - read_double: read IEEE-754 little-endian double returning Ok(#(float, reader)).
/// - read_binary/read_string: read a length-prefixed binary (varint length)
///   and return Ok(#(bytes, reader)) or Ok(#(string, reader)) for strings.
/// - read_struct: parse a struct returning the list of field headers and the
///   reader positioned after the struct payload.
/// - skip_value: skip a value of the given field type efficiently and return
///   the advanced reader.
///
/// All public readers return `Result(#(T, types.Reader), types.DecodeError)` to
/// make incremental parsing and error handling explicit. Examples and common
/// error cases are documented on specific functions below.
pub fn from_bit_array(data: BitArray) -> types.Reader {
  types.Reader(data, 0, types.default_reader_options)
}

pub fn with_options(
  data: BitArray,
  options: types.ReaderOptions,
) -> types.Reader {
  types.Reader(data, 0, options)
}

/// Current byte offset inside the reader.
pub fn position(reader: types.Reader) -> Int {
  let types.Reader(_, byte_pos, _) = reader
  byte_pos
}

/// Read an i8 value.
pub fn read_i8(
  reader: types.Reader,
) -> Result(#(Int, types.Reader), types.DecodeError) {
  let types.Reader(data, byte_pos, options) = reader
  case bit_array.slice(data, byte_pos, 1) {
    Error(_) -> Error(types.UnexpectedEndOfInput)
    Ok(bits) ->
      case bits {
        <<value:int-size(8)>> ->
          Ok(#(value, set_position(reader, byte_pos + 1, options)))
        _ -> Error(types.InvalidWireFormat("Invalid byte"))
      }
  }
}

/// Read a zigzag-encoded i16/i32/i64 depending on the helper used. Returns
/// Ok(#(value, reader)) on success or Error(types.DecodeError) on failure.
pub fn read_i16(
  reader: types.Reader,
) -> Result(#(Int, types.Reader), types.DecodeError) {
  read_zigzag_integer(reader, zigzag.decode_i32)
}

pub fn read_i32(
  reader: types.Reader,
) -> Result(#(Int, types.Reader), types.DecodeError) {
  read_zigzag_integer(reader, zigzag.decode_i32)
}

pub fn read_i64(
  reader: types.Reader,
) -> Result(#(Int, types.Reader), types.DecodeError) {
  read_zigzag_integer(reader, zigzag.decode_i64)
}

pub fn read_double(
  reader: types.Reader,
) -> Result(#(Float, types.Reader), types.DecodeError) {
  let types.Reader(data, byte_pos, options) = reader
  case bit_array.slice(data, byte_pos, 8) {
    Error(_) -> Error(types.UnexpectedEndOfInput)
    Ok(bits) ->
      case bits {
        <<value:float-little-size(64)>> ->
          Ok(#(value, set_position(reader, byte_pos + 8, options)))
        _ -> Error(types.InvalidWireFormat("Invalid double"))
      }
  }
}

pub fn read_varint(
  reader: types.Reader,
) -> Result(#(Int, types.Reader), types.DecodeError) {
  let types.Reader(data, byte_pos, options) = reader
  case varint.decode_varint(data, byte_pos) {
    Error(e) -> Error(e)
    Ok(#(value, next_pos)) ->
      Ok(#(value, set_position(reader, next_pos, options)))
  }
}

pub fn read_binary(
  reader: types.Reader,
) -> Result(#(BitArray, types.Reader), types.DecodeError) {
  let types.Reader(data, byte_pos, options) = reader
  case varint.decode_varint(data, byte_pos) {
    Error(e) -> Error(e)
    Ok(#(length, next_pos)) -> {
      case
        ensure_limit(
          length,
          options.max_string_bytes,
          "Binary length exceeds max_string_bytes",
        )
      {
        Error(e) -> Error(e)
        Ok(Nil) ->
          case bit_array.slice(data, next_pos, length) {
            Error(_) -> Error(types.UnexpectedEndOfInput)
            Ok(bytes) ->
              Ok(#(bytes, set_position(reader, next_pos + length, options)))
          }
      }
    }
  }
}

/// Read a UTF-8 string. This uses `read_binary/1` and then converts to a
/// Gleam `String`. Returns Error(types.InvalidWireFormat) if bytes are not valid
/// UTF-8. Example:
///
/// let r0 = reader.from_bit_array(writer.write_string("hello"))
/// let Ok(#(s, r1)) = reader.read_string(r0)
/// s |> should.equal("hello")
pub fn read_string(
  reader: types.Reader,
) -> Result(#(String, types.Reader), types.DecodeError) {
  case read_binary(reader) {
    Error(e) -> Error(e)
    Ok(#(bytes, next_reader)) ->
      case bit_array.to_string(bytes) {
        Error(_) -> Error(types.InvalidWireFormat("Invalid UTF-8 string"))
        Ok(value) -> Ok(#(value, next_reader))
      }
  }
}

/// Read a boolean element stored as a single byte (used for boolean values
/// inside containers such as list<bool> / set<bool> / map values).
///
/// Encoding & canonical mapping:
/// - Valid element bytes are `1` and `2`. This library interprets them as
///   `1 -> True` and `2 -> False` (matching the inline boolean type nibble
///   mapping used in field headers).
///
/// Validation behaviour:
/// - `types.ReaderOptions.bool_element_policy` controls validation. See
///   `thrifty/types.gleam` for the available `BoolElementPolicy` values.
///
/// This function returns Ok(#(Bool, Reader)) on success, advancing the
/// reader past the element byte, or Error(types.DecodeError) on invalid or
/// truncated input.
pub fn read_bool_element(
  reader: types.Reader,
) -> Result(#(Bool, types.Reader), types.DecodeError) {
  let types.Reader(data, byte_pos, options) = reader
  case bit_array.slice(data, byte_pos, 1) {
    Error(_) -> Error(types.UnexpectedEndOfInput)
    Ok(bits) ->
      case bits {
        <<value:int-size(8)>> ->
          // Consult reader options to determine policy.
          case options.bool_element_policy {
            types.AcceptCanonicalOnly ->
              // Enforce canonical encodings (1 => True, 2 => False)
              case value {
                1 -> Ok(#(True, set_position(reader, byte_pos + 1, options)))
                2 -> Ok(#(False, set_position(reader, byte_pos + 1, options)))
                _ -> Error(types.InvalidWireFormat("Invalid boolean element"))
              }
            types.AcceptBoth ->
              // Accept either common encoding 1 or 2 and map to booleans.
              case value {
                1 -> Ok(#(True, set_position(reader, byte_pos + 1, options)))
                2 -> Ok(#(False, set_position(reader, byte_pos + 1, options)))
                _ -> Error(types.InvalidWireFormat("Invalid boolean element"))
              }
          }
        _ -> Error(types.InvalidWireFormat("Invalid boolean element"))
      }
  }
}

/// Skip a value of the given `field_type`. Useful when parsing structs and
/// encountering unknown/ignored fields. This function enforces depth/size
/// limits configured in `ReaderOptions` and returns the advanced reader or an
/// error. Example:
///
/// let r0 = reader.from_bit_array(some_encoded_list)
/// let Ok(r1) = reader.skip_value(r0, types.List)
pub fn skip_value(
  reader: types.Reader,
  field_type: types.FieldType,
) -> Result(types.Reader, types.DecodeError) {
  skip_value_at_depth(reader, field_type, 1)
}

pub fn read_struct(
  reader: types.Reader,
) -> Result(#(List(types.FieldHeader), types.Reader), types.DecodeError) {
  read_struct_at_depth(reader, 1)
}

fn read_struct_at_depth(
  reader: types.Reader,
  depth: Int,
) -> Result(#(List(types.FieldHeader), types.Reader), types.DecodeError) {
  case ensure_depth(reader, depth) {
    Error(e) -> Error(e)
    Ok(Nil) -> read_struct_loop(reader, depth, 0, [])
  }
}

fn read_struct_loop(
  reader: types.Reader,
  depth: Int,
  last_field_id: Int,
  acc: List(types.FieldHeader),
) -> Result(#(List(types.FieldHeader), types.Reader), types.DecodeError) {
  case field.read_field_header(reader, last_field_id) {
    Error(e) -> Error(e)
    Ok(#(types.FieldHeader(field_id, field_type), after_header)) ->
      case field_type {
        types.Stop -> Ok(#(list.reverse(acc), after_header))
        _ ->
          case skip_value_at_depth(after_header, field_type, depth + 1) {
            Error(e) -> Error(e)
            Ok(after_value) ->
              read_struct_loop(after_value, depth, field_id, [
                types.FieldHeader(field_id, field_type),
                ..acc
              ])
          }
      }
  }
}

fn skip_value_at_depth(
  reader: types.Reader,
  field_type: types.FieldType,
  depth: Int,
) -> Result(types.Reader, types.DecodeError) {
  case ensure_depth(reader, depth) {
    Error(e) -> Error(e)
    Ok(Nil) ->
      case field_type {
        types.BoolTrue -> Ok(reader)
        types.BoolFalse -> Ok(reader)
        types.Stop -> Ok(reader)
        types.Byte -> skip_bytes(reader, 1)
        types.I16 -> map_reader(read_i16(reader))
        types.I32 -> map_reader(read_i32(reader))
        types.I64 -> map_reader(read_i64(reader))
        types.Double -> map_reader(read_double(reader))
        types.Binary -> map_reader(read_binary(reader))
        types.List -> skip_list_or_set(reader, depth)
        types.Set -> skip_list_or_set(reader, depth)
        types.Map -> skip_map(reader, depth)
        types.Struct -> map_reader(read_struct_at_depth(reader, depth))
      }
  }
}

fn skip_list_or_set(
  reader: types.Reader,
  depth: Int,
) -> Result(types.Reader, types.DecodeError) {
  case ensure_depth(reader, depth) {
    Error(e) -> Error(e)
    Ok(Nil) -> {
      let types.Reader(data, byte_pos, options) = reader
      case container.decode_list_header(data, byte_pos) {
        Error(e) -> Error(e)
        Ok(#(size, elem_type, next_pos)) ->
          case
            ensure_limit(
              size,
              options.max_container_items,
              "Exceeded container size limit",
            )
          {
            Error(e) -> Error(e)
            Ok(Nil) ->
              skip_elements(
                size,
                elem_type,
                set_position(reader, next_pos, options),
                depth + 1,
              )
          }
      }
    }
  }
}

/// Skip a list or set container: decode its header, enforce container limits,
/// and skip all contained elements recursively.
///
/// Inputs
/// - `reader`: current `types.Reader` positioned at a list/set header.
/// - `depth`: current recursion depth.
///
/// Outputs
/// - `Ok(types.Reader)` with the reader positioned after the container on success.
/// - `Error(types.DecodeError)` on header decode failures, unexpected end, or if
///   container limits are exceeded.
fn skip_map(
  reader: types.Reader,
  depth: Int,
) -> Result(types.Reader, types.DecodeError) {
  case ensure_depth(reader, depth) {
    Error(e) -> Error(e)
    Ok(Nil) -> {
      let types.Reader(data, byte_pos, options) = reader
      case container.decode_map_header(data, byte_pos) {
        Error(e) -> Error(e)
        Ok(#(size, key_type, value_type, next_pos)) ->
          case
            ensure_limit(
              size,
              options.max_container_items,
              "Exceeded container size limit",
            )
          {
            Error(e) -> Error(e)
            Ok(Nil) ->
              skip_map_entries(
                size,
                key_type,
                value_type,
                set_position(reader, next_pos, options),
                depth + 1,
              )
          }
      }
    }
  }
}

/// Skip a map container: decode its header, enforce limits, and skip all
/// key/value pairs recursively.
///
/// Inputs
/// - `reader`: current `types.Reader` positioned at a map header.
/// - `depth`: current recursion depth.
///
/// Outputs
/// - `Ok(types.Reader)` with the reader positioned after the map on success.
/// - `Error(types.DecodeError)` on malformed input or if configured limits are exceeded.
fn skip_elements(
  count: Int,
  elem_type: container.ElementType,
  reader: types.Reader,
  depth: Int,
) -> Result(types.Reader, types.DecodeError) {
  case count {
    0 -> Ok(reader)
    _ ->
      case skip_element(reader, elem_type, depth) {
        Error(e) -> Error(e)
        Ok(next_reader) ->
          skip_elements(count - 1, elem_type, next_reader, depth)
      }
  }
}

/// Skip `count` elements of `elem_type`, returning the reader advanced past
/// all elements or an error if any element skip fails.
///
/// Inputs
/// - `count`: number of elements to skip.
/// - `elem_type`: element type descriptor.
/// - `reader`: current `types.Reader` positioned at the first element.
/// - `depth`: current recursion depth.
///
/// Outputs
/// - `Ok(types.Reader)` positioned after the skipped elements.
/// - `Error(types.DecodeError)` when an element cannot be skipped or limits are exceeded.
fn skip_map_entries(
  count: Int,
  key_type: container.ElementType,
  value_type: container.ElementType,
  reader: types.Reader,
  depth: Int,
) -> Result(types.Reader, types.DecodeError) {
  case count {
    0 -> Ok(reader)
    _ ->
      case skip_element(reader, key_type, depth) {
        Error(e) -> Error(e)
        Ok(after_key) ->
          case skip_element(after_key, value_type, depth) {
            Error(e) -> Error(e)
            Ok(after_value) ->
              skip_map_entries(
                count - 1,
                key_type,
                value_type,
                after_value,
                depth,
              )
          }
      }
  }
}

/// Skip `count` map entries (key followed by value), returning the reader
/// advanced after all entries or an error.
///
/// Inputs
/// - `count`: number of key/value pairs to skip.
/// - `key_type`, `value_type`: element types for keys and values.
/// - `reader`: current `types.Reader` positioned at the first key.
/// - `depth`: current recursion depth.
///
/// Outputs
/// - `Ok(types.Reader)` after all entries are skipped.
/// - `Error(types.DecodeError)` if any entry fails to skip.
fn skip_element(
  reader: types.Reader,
  elem_type: container.ElementType,
  depth: Int,
) -> Result(types.Reader, types.DecodeError) {
  case elem_type {
    // Enforce boolean-element decoding rules when skipping boolean
    // elements so `bool_element_policy` applies consistently whether the
    // caller reads values or skips them.
    container.BoolType -> map_reader(read_bool_element(reader))
    container.I8Type -> skip_bytes(reader, 1)
    container.I16Type -> map_reader(read_i16(reader))
    container.I32Type -> map_reader(read_i32(reader))
    container.I64Type -> map_reader(read_i64(reader))
    container.DoubleType -> map_reader(read_double(reader))
    container.BinaryType -> map_reader(read_binary(reader))
    container.ListType -> skip_list_or_set(reader, depth + 1)
    container.SetType -> skip_list_or_set(reader, depth + 1)
    container.MapType -> skip_map(reader, depth + 1)
    container.StructType -> map_reader(read_struct_at_depth(reader, depth + 1))
  }
}

/// Skip a single element of type `elem_type`.
///
/// Inputs
/// - `reader`: current `types.Reader` positioned at the element.
/// - `elem_type`: element type descriptor.
/// - `depth`: current recursion depth.
///
/// Outputs
/// - `Ok(types.Reader)` positioned after the element on success.
/// - `Error(types.DecodeError)` if the element is malformed or limits are exceeded.
fn skip_bytes(
  reader: types.Reader,
  count: Int,
) -> Result(types.Reader, types.DecodeError) {
  let types.Reader(data, byte_pos, options) = reader
  case bit_array.slice(data, byte_pos, count) {
    Error(_) -> Error(types.UnexpectedEndOfInput)
    Ok(_) -> Ok(set_position(reader, byte_pos + count, options))
  }
}

/// Skip `count` bytes in the reader, returning an advanced reader.
///
/// Inputs
/// - `reader`: current `types.Reader`.
/// - `count`: number of bytes to skip.
///
/// Outputs
/// - `Ok(types.Reader)` advanced `count` bytes on success.
/// - `Error(types.UnexpectedEndOfInput)` when there are not enough bytes.
fn read_zigzag_integer(
  reader: types.Reader,
  decode: fn(Int) -> Int,
) -> Result(#(Int, types.Reader), types.DecodeError) {
  case read_varint(reader) {
    Error(e) -> Error(e)
    Ok(#(bits, next_reader)) -> Ok(#(decode(bits), next_reader))
  }
}

/// Map a Result containing a value and a reader to a Result containing only
/// the reader. Utility used by skip helpers to ignore parsed values while
/// preserving the updated reader or propagating errors.
fn map_reader(
  result: Result(#(_, types.Reader), types.DecodeError),
) -> Result(types.Reader, types.DecodeError) {
  case result {
    Error(e) -> Error(e)
    Ok(#(_, reader)) -> Ok(reader)
  }
}

fn set_position(
  reader: types.Reader,
  byte_pos: Int,
  options: types.ReaderOptions,
) -> types.Reader {
  let types.Reader(data, _, _) = reader
  types.Reader(data, byte_pos, options)
}

/// Set the reader's byte position and options, returning a new immutable reader.
///
/// Inputs
/// - `reader`: existing `types.Reader` instance.
/// - `byte_pos`: new byte offset to set.
/// - `options`: `types.ReaderOptions` to attach to the new reader.
///
/// Outputs
/// - A `types.Reader` referencing the same underlying data with updated
///   position and options.
fn ensure_depth(
  reader: types.Reader,
  depth: Int,
) -> Result(Nil, types.DecodeError) {
  let types.Reader(_, _, options) = reader
  case depth > options.max_depth {
    True -> Error(types.InvalidWireFormat("Exceeded maximum depth"))
    False -> Ok(Nil)
  }
}

fn ensure_limit(
  value: Int,
  limit: Int,
  message: String,
) -> Result(Nil, types.DecodeError) {
  case value > limit {
    True -> Error(types.InvalidWireFormat(message))
    False -> Ok(Nil)
  }
}
/// Ensure the current recursion `depth` does not exceed configured limits.
///
/// Inputs
/// - `reader`: the current `types.Reader` containing configured options.
/// - `depth`: current recursion depth to validate.
///
/// Outputs
/// - `Ok(Nil)` when within limits.
/// - `Error(types.InvalidWireFormat("Exceeded maximum depth"))` when the depth
///   exceeds `options.max_depth`.
/// Ensure a numeric `value` does not exceed a configured `limit`.
///
/// Inputs
/// - `value`: measured quantity (for example container size).
/// - `limit`: configured maximum allowed value.
/// - `message`: error message to use when the limit is exceeded.
///
/// Outputs
/// - `Ok(Nil)` when `value <= limit`.
/// - `Error(types.InvalidWireFormat(message))` when `value > limit`.
