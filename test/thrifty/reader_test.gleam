import gleam/bit_array
import gleeunit
import gleeunit/should

import thrifty/container
import thrifty/reader
import thrifty/types
import thrifty/writer

pub fn main() {
  gleeunit.main()
}

pub fn read_primitives_test() {
  let r0 = reader.from_bit_array(writer.write_i32(-123))
  let assert Ok(#(value32, _)) = reader.read_i32(r0)
  value32 |> should.equal(-123)

  let r1 = reader.from_bit_array(writer.write_i16(42))
  let assert Ok(#(value16, _)) = reader.read_i16(r1)
  value16 |> should.equal(42)

  let r2 = reader.from_bit_array(writer.write_i64(99))
  let assert Ok(#(value64, _)) = reader.read_i64(r2)
  value64 |> should.equal(99)

  let r3 = reader.from_bit_array(writer.write_double(3.14))
  let assert Ok(#(value_d, _)) = reader.read_double(r3)
  value_d |> should.equal(3.14)

  let binary = writer.write_string("payload")
  let r4 = reader.from_bit_array(binary)
  let assert Ok(#(str, r5)) = reader.read_string(r4)
  str |> should.equal("payload")
  reader.position(r5) |> should.equal(bit_array.byte_size(binary))

  let bool_bits = writer.write_i8(1)
  let r6 = reader.from_bit_array(bool_bits)
  let assert Ok(#(flag, _)) = reader.read_bool_element(r6)
  flag |> should.equal(True)
}

pub fn skip_list_and_map_test() {
  let list_data =
    bit_array.concat([
      writer.write_list_header(2, container.I32Type),
      writer.write_i32(5),
      writer.write_i32(6),
    ])
  let list_reader = reader.from_bit_array(list_data)
  let assert Ok(list_after) = reader.skip_value(list_reader, types.List)
  reader.position(list_after) |> should.equal(bit_array.byte_size(list_data))

  let map_data =
    bit_array.concat([
      writer.write_map_header(1, container.I32Type, container.I32Type),
      writer.write_i32(7),
      writer.write_i32(8),
    ])
  let map_reader = reader.from_bit_array(map_data)
  let assert Ok(map_after) = reader.skip_value(map_reader, types.Map)
  reader.position(map_after) |> should.equal(bit_array.byte_size(map_data))
}

pub fn read_struct_test() {
  let buf0 = writer.buffer_new()
  let buf1 =
    writer.buffer_append(buf0, writer.write_field_header(1, types.I32, 0))
  let buf2 = writer.buffer_append(buf1, writer.write_i32(100))
  let buf3 =
    writer.buffer_append(buf2, writer.write_field_header(2, types.Binary, 1))
  let buf4 = writer.buffer_append(buf3, writer.write_string("struct"))
  let buf5 = writer.buffer_append(buf4, <<0:int-size(8)>>)
  let data = writer.buffer_to_bitarray(buf5)

  let struct_reader = reader.from_bit_array(data)
  let assert Ok(#(fields, after_struct)) = reader.read_struct(struct_reader)
  fields
  |> should.equal([
    types.FieldHeader(1, types.I32),
    types.FieldHeader(2, types.Binary),
  ])
  reader.position(after_struct) |> should.equal(bit_array.byte_size(data))
}
