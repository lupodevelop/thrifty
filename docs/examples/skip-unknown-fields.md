# Skipping Unknown Fields

Forward-compatible decoders should ignore fields they do not understand. Thrifty's `reader.skip_value` helper makes this easy while still enforcing depth and container limits.

## Payload Setup

The sample payload encodes a struct with two known fields, an inline boolean, and a nested struct that we will ignore:

```gleam
import gleam/bit_array
import thrifty/types
import thrifty/writer

fn sample_payload() -> BitArray {
  let buffer = writer.buffer_new()

  // Known field 1: name (string)
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(1, types.Binary, 0),
  )
  let buffer = writer.buffer_append(buffer, writer.write_string("Ada"))

  // Known field 2: age (i32)
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(2, types.I32, 1),
  )
  let buffer = writer.buffer_append(buffer, writer.write_i32(37))

  // Unknown field 4: active flag encoded inline
  let buffer = writer.buffer_append(buffer, writer.write_bool(4, True, 2))

  // Unknown field 7: nested struct with its own STOP marker
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(7, types.Struct, 4),
  )
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(1, types.I32, 0),
  )
  let buffer = writer.buffer_append(buffer, writer.write_i32(123))
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(0, types.Stop, 1),
  )

  // Close the outer struct
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(0, types.Stop, 7),
  )

  writer.buffer_to_bitarray(buffer)
}
```

## Selective Decoding

We iterate over field headers, read the values we care about, and skip everything else:

```gleam
import gleam/bit_array
import gleam/io
import gleam/int
import thrifty/field
import thrifty/reader
import thrifty/types

fn consume_known_fields(
  reader: types.Reader,
  last_field_id: Int,
) -> Result(types.Reader, types.DecodeError) {
  case field.read_field_header(reader, last_field_id) {
    Error(err) -> Error(err)
    Ok(#(types.FieldHeader(_, types.Stop), after_stop)) -> Ok(after_stop)
    Ok(#(types.FieldHeader(field_id, field_type), after_header)) -> {
      case field_id {
        1 ->
          case reader.read_string(after_header) {
            Error(err) -> Error(err)
            Ok(#(name, after_value)) -> {
              io.debug("name: " <> name)
              consume_known_fields(after_value, field_id)
            }
          }
        2 ->
          case reader.read_i32(after_header) {
            Error(err) -> Error(err)
            Ok(#(age, after_value)) -> {
              io.debug("age: " <> int.to_string(age))
              consume_known_fields(after_value, field_id)
            }
          }
        _ -> {
          io.debug("Skipping field " <> int.to_string(field_id))
          case reader.skip_value(after_header, field_type) {
            Error(err) -> Error(err)
            Ok(next_reader) -> consume_known_fields(next_reader, field_id)
          }
        }
      }
    }
  }
}

pub fn main() {
  let payload = sample_payload()
  let start_reader = reader.from_bit_array(payload)

  case consume_known_fields(start_reader, 0) {
    Ok(_next_reader) -> Nil
    Error(err) ->
      io.debug("Decode error: " <> types.decode_error_to_string(err))
  }
}
```

## Takeaways

- `field.read_field_header` exposes both the field id and the Compact Protocol type, making it straightforward to decide whether to parse or skip.
- `reader.skip_value` handles inline booleans, containers, and nested structs, so unknown fields do not compromise forward compatibility.
- Continue passing the current field id into each recursive call so delta-encoded headers remain valid.

