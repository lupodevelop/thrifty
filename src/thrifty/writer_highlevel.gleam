import gleam/bit_array

import thrifty/container
import thrifty/types
import thrifty/writer as low_writer
import thrifty/zigzag

/// Immutable builder for encoding Thrift Compact structs.
///
/// The writer keeps track of the last emitted field id so that
/// subsequent field headers can use the compact delta encoding.
pub type StructWriter {
  StructWriter(last_field_id: Int, buffer: low_writer.Buffer)
}

/// Create a new empty `StructWriter`.
///
/// Outputs
/// - A `StructWriter` initialised with last field id `0` and an empty buffer.
///
/// Semantics
/// - The writer tracks `last_field_id` to emit compact delta-encoded headers.
pub fn new() -> StructWriter {
  StructWriter(0, low_writer.buffer_new())
}

/// Append a boolean field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `value`: boolean value to encode.
///
/// Outputs
/// - Returns an updated `StructWriter` with the boolean field header appended.
///
/// Semantics
/// - The boolean is encoded inline in the field header; no payload bytes are
///   appended beyond the header itself.
pub fn write_bool(
  builder: StructWriter,
  field_id: Int,
  value: Bool,
) -> StructWriter {
  let field_type = case value {
    True -> types.BoolTrue
    False -> types.BoolFalse
  }
  append_field(builder, field_id, field_type, <<>>)
}

/// Append an i8 field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `value`: 8-bit signed integer to encode.
///
/// Outputs
/// - Returns an updated `StructWriter` with the field header and payload appended.
pub fn write_i8(
  builder: StructWriter,
  field_id: Int,
  value: Int,
) -> StructWriter {
  let payload = low_writer.write_i8(value)
  append_field(builder, field_id, types.Byte, payload)
}

/// Append an i16 field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `value`: signed integer to encode as i16 (via zigzag + varint semantics).
///
/// Outputs
/// - Returns an updated `StructWriter` with header and encoded payload appended.
pub fn write_i16(
  builder: StructWriter,
  field_id: Int,
  value: Int,
) -> StructWriter {
  let payload = low_writer.write_i16(value)
  append_field(builder, field_id, types.I16, payload)
}

/// Append an i32 field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `value`: signed integer to encode as i32.
///
/// Outputs
/// - `Ok(StructWriter)` with the new state on success.
/// - `Error(ZigzagRangeError)` when `value` does not fit in i32 range.
pub fn write_i32(
  builder: StructWriter,
  field_id: Int,
  value: Int,
) -> Result(StructWriter, zigzag.ZigzagRangeError) {
  case low_writer.write_i32_checked(value) {
    Error(err) -> Error(err)
    Ok(payload) -> Ok(append_field(builder, field_id, types.I32, payload))
  }
}

/// Append an i64 field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `value`: signed integer to encode as i64.
///
/// Outputs
/// - `Ok(StructWriter)` with the new state on success.
/// - `Error(ZigzagRangeError)` when `value` does not fit in i64 range.
pub fn write_i64(
  builder: StructWriter,
  field_id: Int,
  value: Int,
) -> Result(StructWriter, zigzag.ZigzagRangeError) {
  case low_writer.write_i64_checked(value) {
    Error(err) -> Error(err)
    Ok(payload) -> Ok(append_field(builder, field_id, types.I64, payload))
  }
}

/// Append a double (64-bit float) field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `value`: floating point value to store.
///
/// Outputs
/// - Returns an updated `StructWriter` with the encoded field appended.
pub fn write_double(
  builder: StructWriter,
  field_id: Int,
  value: Float,
) -> StructWriter {
  let payload = low_writer.write_double(value)
  append_field(builder, field_id, types.Double, payload)
}

/// Append a binary/blob field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `bytes`: raw payload as `BitArray`.
///
/// Outputs
/// - Returns an updated `StructWriter` with header and length-prefixed payload appended.
pub fn write_binary(
  builder: StructWriter,
  field_id: Int,
  bytes: BitArray,
) -> StructWriter {
  let payload = low_writer.write_binary(bytes)
  append_field(builder, field_id, types.Binary, payload)
}

/// Append a UTF-8 string field to the struct under construction.
///
/// Inputs
/// - `builder`: current `StructWriter` state.
/// - `field_id`: field identifier.
/// - `value`: UTF-8 string to encode.
///
/// Outputs
/// - Returns an updated `StructWriter` with the encoded string appended.
pub fn write_string(
  builder: StructWriter,
  field_id: Int,
  value: String,
) -> StructWriter {
  let payload = low_writer.write_string(value)
  append_field(builder, field_id, types.Binary, payload)
}

/// Write a list field using a pre-encoded payload of elements.
///
/// The payload must contain the concatenated element encodings. The size is used
/// to emit the list header with the correct short/long encoding.
pub fn write_list(
  builder: StructWriter,
  field_id: Int,
  size: Int,
  element_type: container.ElementType,
  payload: BitArray,
) -> StructWriter {
  let body = low_writer.write_list(size, element_type, payload)
  append_field(builder, field_id, types.List, body)
}

/// Write a map field using a pre-encoded payload of key/value pairs.
///
/// The payload must contain the concatenated encodings for keys and values in
/// sequence.
pub fn write_map(
  builder: StructWriter,
  field_id: Int,
  size: Int,
  key_type: container.ElementType,
  value_type: container.ElementType,
  payload: BitArray,
) -> StructWriter {
  let body = low_writer.write_map(size, key_type, value_type, payload)
  append_field(builder, field_id, types.Map, body)
}

/// Write an arbitrary field by supplying the field type and the payload bytes.
///
/// This is useful for struct fields encoded by custom logic (e.g. nested
/// structs) while still benefiting from automatic delta handling.
pub fn write_field_bytes(
  builder: StructWriter,
  field_id: Int,
  field_type: types.FieldType,
  payload: BitArray,
) -> StructWriter {
  append_field(builder, field_id, field_type, payload)
}

/// Finalise the `StructWriter` returning a compact protocol encoded `BitArray`.
///
/// Outputs
/// - A `BitArray` containing the concatenated headers and payloads for the
///   struct, with a stop field appended automatically.
pub fn finish(builder: StructWriter) -> BitArray {
  let StructWriter(last_field_id, buffer) = builder
  let stop = low_writer.write_field_header(0, types.Stop, last_field_id)
  low_writer.buffer_append(buffer, stop)
  |> low_writer.buffer_to_bitarray
}

/// Internal helper that appends a field header and optional payload to the
/// builder's buffer and returns the updated `StructWriter`.
///
/// Inputs
/// - `struct_writer`: current `StructWriter` state.
/// - `field_id`: identifier for the field being appended.
/// - `field_type`: type of the field.
/// - `payload`: pre-encoded payload bytes for the field (may be empty).
///
/// Outputs
/// - `StructWriter` updated with the appended header/payload and the new
///   last_field_id set to `field_id`.
fn append_field(
  struct_writer: StructWriter,
  field_id: Int,
  field_type: types.FieldType,
  payload: BitArray,
) -> StructWriter {
  let StructWriter(last_field_id, buffer) = struct_writer
  let header =
    low_writer.write_field_header(field_id, field_type, last_field_id)
  let buffer_with_header = low_writer.buffer_append(buffer, header)
  let buffer_with_payload = case bit_array.byte_size(payload) {
    0 -> buffer_with_header
    _ -> low_writer.buffer_append(buffer_with_header, payload)
  }
  StructWriter(field_id, buffer_with_payload)
}
