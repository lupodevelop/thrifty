# Basic Encoding Example

Encode a Compact Protocol struct with Thrifty's writer helpers. This walkthrough covers:

- Building field headers with delta tracking
- Serialising primitive values
- Framing the payload with an RPC message header

## Writing a Struct Body

```gleam
import gleam/bit_array
import gleam/io
import gleam/int
import thrifty/message
import thrifty/types
import thrifty/writer

fn encode_user(name: String, age: Int) -> BitArray {
  let buffer = writer.buffer_new()

  // Field 1: required string `name`
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(1, types.Binary, 0),
  )
  let buffer = writer.buffer_append(buffer, writer.write_string(name))

  // Field 2: optional i32 `age`
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(2, types.I32, 1),
  )
  let buffer = writer.buffer_append(buffer, writer.write_i32(age))

  // Terminate the struct body with the STOP marker (field id ignored)
  let buffer = writer.buffer_append(
    buffer,
    writer.write_field_header(0, types.Stop, 2),
  )

  writer.buffer_to_bitarray(buffer)
}

pub fn main() {
  let user_body = encode_user("Ada", 37)
  io.debug("Encoded bytes: " <> int.to_string(bit_array.byte_size(user_body)))
}
```

### Notes

- `write_field_header` needs the current field id, its type, and the previous id to compute the Compact Protocol delta encoding. The first header uses `last_field_id = 0`.
- Strings are represented as `types.Binary` because the Compact Protocol treats them as length-prefixed UTF-8 binaries.
- Always append a STOP header once all fields are written so decoders know the struct body is complete.

## Framing a Client Call

Once you have the struct payload, prepend an RPC envelope so the message can traverse the wire:

```gleam
pub fn encode_request() -> BitArray {
  let header = writer.write_message_header(
    message.MessageHeader(
      name: "UserService::Create",
      message_type: message.Call,
      sequence_id: 7,
    ),
  )

  let body = encode_user("Ada", 37)

  bit_array.concat([header, body])
}
```

### Takeaways

- `write_message_header` emits the Compact Protocol framing (protocol id, version/type, sequence id, and method name).
- `bit_array.concat` joins the header and body without mutating either part.
- Reuse the `encode_user` helper to produce server replies (`message.Reply`) by swapping the message type and method name as needed.
