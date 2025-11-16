import gleam/bit_array
import gleam/int
import gleam/list
import gleeunit
import gleeunit/should

import thrifty/container
import thrifty/field
import thrifty/file_io
import thrifty/message
import thrifty/reader
import thrifty/types

pub fn main() {
  gleeunit.main()
}

pub fn user_profile_struct_golden_test() {
  let assert Ok(data) = file_io.read_binary("artifact/golden/user_profile.bin")
  let reader0 = reader.from_bit_array(data)

  // field 1: name (string)
  let assert Ok(#(types.FieldHeader(fid1, ftype1), r1)) =
    field.read_field_header(reader0, 0)
  fid1 |> should.equal(1)
  ftype1 |> should.equal(types.Binary)
  let assert Ok(#(name, r_name)) = reader.read_string(r1)
  name |> should.equal("Ada")

  // field 2: user_id (i32)
  let assert Ok(#(types.FieldHeader(fid2, ftype2), r2)) =
    field.read_field_header(r_name, 1)
  fid2 |> should.equal(2)
  ftype2 |> should.equal(types.I32)
  let assert Ok(#(user_id, r_id)) = reader.read_i32(r2)
  user_id |> should.equal(42)

  // field 3: is_active (bool inline)
  let assert Ok(#(types.FieldHeader(fid3, ftype3), r3)) =
    field.read_field_header(r_id, 2)
  fid3 |> should.equal(3)
  case ftype3 {
    types.BoolTrue -> True
    _ -> False
  }
  |> should.equal(True)

  // field 4: reputation (i64)
  let assert Ok(#(types.FieldHeader(fid4, ftype4), r4)) =
    field.read_field_header(r3, 3)
  fid4 |> should.equal(4)
  ftype4 |> should.equal(types.I64)
  let assert Ok(#(reputation, r_rep)) = reader.read_i64(r4)
  reputation |> should.equal(9000)

  // stop field
  let assert Ok(#(types.FieldHeader(fid_stop, ftype_stop), _)) =
    field.read_field_header(r_rep, 4)
  fid_stop |> should.equal(0)
  ftype_stop |> should.equal(types.Stop)
}

pub fn ping_message_golden_test() {
  let assert Ok(data) = file_io.read_binary("artifact/golden/ping_message.bin")

  let assert Ok(#(header, body_pos)) = message.decode_message_header(data, 0)
  header.name |> should.equal("Ping")
  header.message_type |> should.equal(message.Call)
  header.sequence_id |> should.equal(1)

  let total_bytes = bit_array.byte_size(data)
  let body_length = total_bytes - body_pos
  let assert Ok(body_bits) = bit_array.slice(data, body_pos, body_length)
  let reader0 = reader.from_bit_array(body_bits)

  // field 1: name (string)
  let assert Ok(#(types.FieldHeader(fid1, ftype1), r1)) =
    field.read_field_header(reader0, 0)
  fid1 |> should.equal(1)
  ftype1 |> should.equal(types.Binary)
  let assert Ok(#(name, r_name)) = reader.read_string(r1)
  name |> should.equal("Ada")

  // field 2: user_id (i32)
  let assert Ok(#(types.FieldHeader(fid2, ftype2), r2)) =
    field.read_field_header(r_name, 1)
  fid2 |> should.equal(2)
  ftype2 |> should.equal(types.I32)
  let assert Ok(#(user_id, r_id)) = reader.read_i32(r2)
  user_id |> should.equal(42)

  // field 3: is_active (bool inline true)
  let assert Ok(#(types.FieldHeader(fid3, ftype3), r3)) =
    field.read_field_header(r_id, 2)
  fid3 |> should.equal(3)
  case ftype3 {
    types.BoolTrue -> True
    _ -> False
  }
  |> should.equal(True)

  // field 4: reputation (i64)
  let assert Ok(#(types.FieldHeader(fid4, ftype4), r4)) =
    field.read_field_header(r3, 3)
  fid4 |> should.equal(4)
  ftype4 |> should.equal(types.I64)
  let assert Ok(#(reputation, r_rep)) = reader.read_i64(r4)
  reputation |> should.equal(9000)

  // stop field
  let assert Ok(#(types.FieldHeader(fid_stop, ftype_stop), _)) =
    field.read_field_header(r_rep, 4)
  fid_stop |> should.equal(0)
  ftype_stop |> should.equal(types.Stop)
}

pub fn complex_struct_golden_test() {
  let assert Ok(data) =
    file_io.read_binary("artifact/golden/complex_struct.bin")
  let reader0 = reader.from_bit_array(data)

  let assert Ok(#(types.FieldHeader(fid1, ft1), after_map_field)) =
    field.read_field_header(reader0, 0)
  fid1 |> should.equal(1)
  ft1 |> should.equal(types.Map)

  let #(map_entries, after_map_reader) =
    decode_map_of_inner_lists(after_map_field)
  map_entries
  |> should.equal([
    #(1, [#(1, "a"), #(2, "b")]),
    #(2, []),
  ])

  let assert Ok(#(types.FieldHeader(fid2, ft2), after_list_field)) =
    field.read_field_header(after_map_reader, 1)
  fid2 |> should.equal(2)
  ft2 |> should.equal(types.List)

  let #(list_map_set, after_list_reader) =
    decode_list_map_of_sets(after_list_field)
  list_map_set
  |> should.equal([
    [#("k1", [1, 2, 3])],
    [#("k2", [])],
  ])

  let assert Ok(#(types.FieldHeader(fid3, ft3), after_i32_field)) =
    field.read_field_header(after_list_reader, 2)
  fid3 |> should.equal(3)
  ft3 |> should.equal(types.I32)
  let assert Ok(#(edge_i32, after_i32_value)) = reader.read_i32(after_i32_field)
  edge_i32 |> should.equal(2_147_483_647)

  let assert Ok(#(types.FieldHeader(fid4, ft4), after_i64_field)) =
    field.read_field_header(after_i32_value, 3)
  fid4 |> should.equal(4)
  ft4 |> should.equal(types.I64)
  let assert Ok(#(edge_i64, after_i64_value)) = reader.read_i64(after_i64_field)
  edge_i64 |> should.equal(9_223_372_036_854_775_807)

  let assert Ok(#(types.FieldHeader(fid5, ft5), after_flag_field)) =
    field.read_field_header(after_i64_value, 4)
  fid5 |> should.equal(5)
  ft5 |> should.equal(types.BoolFalse)

  let assert Ok(#(types.FieldHeader(fid_stop, ft_stop), _)) =
    field.read_field_header(after_flag_field, 5)
  should.equal(fid_stop, 0)
  should.equal(ft_stop, types.Stop)
}

pub fn bool_list_struct_golden_test() {
  let assert Ok(data) = file_io.read_binary("artifact/golden/bool_list.bin")
  let reader0 = reader.from_bit_array(data)

  let assert Ok(#(types.FieldHeader(fid1, ft1), after_list_field)) =
    field.read_field_header(reader0, 0)
  fid1 |> should.equal(1)
  ft1 |> should.equal(types.List)

  let #(values, after_values_reader) = decode_bool_list(after_list_field)
  values |> should.equal([True, False, True, False])

  let assert Ok(#(types.FieldHeader(fid_stop, ft_stop), _)) =
    field.read_field_header(after_values_reader, 1)
  fid_stop |> should.equal(0)
  ft_stop |> should.equal(types.Stop)
}

pub fn truncated_struct_failure_golden_test() {
  let assert Ok(data) =
    file_io.read_binary("artifact/golden/user_profile_truncated.bin")
  let reader0 = reader.from_bit_array(data)

  // field 1: name (string) should still decode correctly
  let assert Ok(#(name_header, after_name_field)) =
    field.read_field_header(reader0, 0)
  let types.FieldHeader(fid1, ft1) = name_header
  fid1 |> should.equal(1)
  ft1 |> should.equal(types.Binary)
  let assert Ok(#(_, after_name_value)) = reader.read_string(after_name_field)

  // field 2: user_id (i32)
  let assert Ok(#(id_header, after_id_field)) =
    field.read_field_header(after_name_value, 1)
  let types.FieldHeader(fid2, ft2) = id_header
  fid2 |> should.equal(2)
  ft2 |> should.equal(types.I32)
  let assert Ok(#(_, after_id_value)) = reader.read_i32(after_id_field)

  // field 3: is_active (bool inline)
  let assert Ok(#(flag_header, after_flag_field)) =
    field.read_field_header(after_id_value, 2)
  let types.FieldHeader(fid3, ft3) = flag_header
  fid3 |> should.equal(3)
  case ft3 {
    types.BoolTrue -> Nil
    types.BoolFalse -> Nil
    _ -> panic as "Expected inline bool"
  }

  // field 4: reputation (i64) value is truncated in payload
  let assert Ok(#(rep_header, after_rep_field)) =
    field.read_field_header(after_flag_field, 3)
  let types.FieldHeader(fid4, ft4) = rep_header
  fid4 |> should.equal(4)
  ft4 |> should.equal(types.I64)

  case reader.read_i64(after_rep_field) {
    Error(types.UnexpectedEndOfInput) -> Nil
    Error(other) -> {
      let message = "Expected UnexpectedEndOfInput, got " <> debug_error(other)
      panic as message
    }
    Ok(_) -> panic as "Truncated payload should not decode successfully"
  }
}

fn decode_map_of_inner_lists(
  reader0: types.Reader,
) -> #(List(#(Int, List(#(Int, String)))), types.Reader) {
  let types.Reader(data, _, options) = reader0
  let start_pos = reader.position(reader0)
  let assert Ok(#(size, key_type, value_type, next_pos)) =
    container.decode_map_header(data, start_pos)
  key_type |> should.equal(container.I32Type)
  value_type |> should.equal(container.ListType)

  read_map_inner_entries(size, types.Reader(data, next_pos, options), [])
}

fn read_map_inner_entries(
  remaining: Int,
  current: types.Reader,
  acc: List(#(Int, List(#(Int, String)))),
) -> #(List(#(Int, List(#(Int, String)))), types.Reader) {
  case remaining {
    0 -> #(list.reverse(acc), current)
    _ -> {
      let #(key, after_key) = expect_i32(reader.read_i32(current))
      let #(inners, after_list) = decode_inner_struct_list(after_key)
      read_map_inner_entries(remaining - 1, after_list, [#(key, inners), ..acc])
    }
  }
}

fn decode_inner_struct_list(
  reader0: types.Reader,
) -> #(List(#(Int, String)), types.Reader) {
  let types.Reader(data, _, options) = reader0
  let start_pos = reader.position(reader0)
  let assert Ok(#(size, elem_type, next_pos)) =
    container.decode_list_header(data, start_pos)
  elem_type |> should.equal(container.StructType)
  read_inner_structs(size, types.Reader(data, next_pos, options), [])
}

fn read_inner_structs(
  remaining: Int,
  current: types.Reader,
  acc: List(#(Int, String)),
) -> #(List(#(Int, String)), types.Reader) {
  case remaining {
    0 -> #(list.reverse(acc), current)
    _ -> {
      let #(inner, after_struct) = decode_inner_struct(current)
      read_inner_structs(remaining - 1, after_struct, [inner, ..acc])
    }
  }
}

fn decode_inner_struct(reader0: types.Reader) -> #(#(Int, String), types.Reader) {
  let #(header1, after_id_field) =
    expect_field_header(field.read_field_header(reader0, 0))
  let types.FieldHeader(fid1, ft1) = header1
  fid1 |> should.equal(1)
  ft1 |> should.equal(types.I32)

  let #(id_value, after_id_value) = expect_i32(reader.read_i32(after_id_field))

  let #(header2, after_name_field) =
    expect_field_header(field.read_field_header(after_id_value, 1))
  let types.FieldHeader(fid2, ft2) = header2
  fid2 |> should.equal(2)
  ft2 |> should.equal(types.Binary)

  let #(name_value, after_name_value) =
    expect_string(reader.read_string(after_name_field))

  let #(header_stop, after_stop) =
    expect_field_header(field.read_field_header(after_name_value, 2))
  case header_stop {
    types.FieldHeader(0, types.Stop) -> #(#(id_value, name_value), after_stop)
    _ -> panic as "Expected stop field header"
  }
}

fn decode_list_map_of_sets(
  reader0: types.Reader,
) -> #(List(List(#(String, List(Int)))), types.Reader) {
  let types.Reader(data, _, options) = reader0
  let start_pos = reader.position(reader0)
  let assert Ok(#(size, elem_type, next_pos)) =
    container.decode_list_header(data, start_pos)
  elem_type |> should.equal(container.MapType)
  read_list_map_entries(size, types.Reader(data, next_pos, options), [])
}

fn read_list_map_entries(
  remaining: Int,
  current: types.Reader,
  acc: List(List(#(String, List(Int)))),
) -> #(List(List(#(String, List(Int)))), types.Reader) {
  case remaining {
    0 -> #(list.reverse(acc), current)
    _ -> {
      let #(pairs, after_map) = decode_string_set_map(current)
      read_list_map_entries(remaining - 1, after_map, [pairs, ..acc])
    }
  }
}

fn decode_string_set_map(
  reader0: types.Reader,
) -> #(List(#(String, List(Int))), types.Reader) {
  let types.Reader(data, _, options) = reader0
  let start_pos = reader.position(reader0)
  let assert Ok(#(size, key_type, value_type, next_pos)) =
    container.decode_map_header(data, start_pos)
  key_type |> should.equal(container.BinaryType)
  value_type |> should.equal(container.SetType)
  read_string_set_pairs(size, types.Reader(data, next_pos, options), [])
}

fn read_string_set_pairs(
  remaining: Int,
  current: types.Reader,
  acc: List(#(String, List(Int))),
) -> #(List(#(String, List(Int))), types.Reader) {
  case remaining {
    0 -> #(list.reverse(acc), current)
    _ -> {
      let #(key, after_key) = expect_string(reader.read_string(current))
      let #(values, after_set) = decode_i32_set(after_key)
      read_string_set_pairs(remaining - 1, after_set, [#(key, values), ..acc])
    }
  }
}

fn decode_i32_set(reader0: types.Reader) -> #(List(Int), types.Reader) {
  let types.Reader(data, _, options) = reader0
  let start_pos = reader.position(reader0)
  let assert Ok(#(size, elem_type, next_pos)) =
    container.decode_list_header(data, start_pos)
  elem_type |> should.equal(container.I32Type)
  read_i32_values(size, types.Reader(data, next_pos, options), [])
}

fn read_i32_values(
  remaining: Int,
  current: types.Reader,
  acc: List(Int),
) -> #(List(Int), types.Reader) {
  case remaining {
    0 -> #(list.reverse(acc), current)
    _ -> {
      let #(value, after_value) = expect_i32(reader.read_i32(current))
      read_i32_values(remaining - 1, after_value, [value, ..acc])
    }
  }
}

fn decode_bool_list(reader0: types.Reader) -> #(List(Bool), types.Reader) {
  let types.Reader(data, _, options) = reader0
  let start_pos = reader.position(reader0)
  let assert Ok(#(size, elem_type, next_pos)) =
    container.decode_list_header(data, start_pos)
  elem_type |> should.equal(container.BoolType)
  read_bool_values(size, types.Reader(data, next_pos, options), [])
}

fn read_bool_values(
  remaining: Int,
  current: types.Reader,
  acc: List(Bool),
) -> #(List(Bool), types.Reader) {
  case remaining {
    0 -> #(list.reverse(acc), current)
    _ -> {
      let #(value, after_value) = expect_bool(reader.read_bool_element(current))
      read_bool_values(remaining - 1, after_value, [value, ..acc])
    }
  }
}

fn debug_error(error: types.DecodeError) -> String {
  case error {
    types.UnexpectedEndOfInput -> "UnexpectedEndOfInput"
    types.InvalidVarint -> "InvalidVarint"
    types.InvalidFieldType(expected, got) ->
      "InvalidFieldType("
      <> int.to_string(expected)
      <> ","
      <> int.to_string(got)
      <> ")"
    types.UnsupportedType(code) ->
      "UnsupportedType(" <> int.to_string(code) <> ")"
    types.InvalidWireFormat(message) -> "InvalidWireFormat(" <> message <> ")"
  }
}

fn expect_field_header(
  result: Result(#(types.FieldHeader, types.Reader), types.DecodeError),
) -> #(types.FieldHeader, types.Reader) {
  case result {
    Ok(value) -> value
    Error(error) -> {
      let message = "Decode error: " <> debug_error(error)
      panic as message
    }
  }
}

fn expect_i32(
  result: Result(#(Int, types.Reader), types.DecodeError),
) -> #(Int, types.Reader) {
  case result {
    Ok(value) -> value
    Error(error) -> {
      let message = "Decode error: " <> debug_error(error)
      panic as message
    }
  }
}

fn expect_string(
  result: Result(#(String, types.Reader), types.DecodeError),
) -> #(String, types.Reader) {
  case result {
    Ok(value) -> value
    Error(error) -> {
      let message = "Decode error: " <> debug_error(error)
      panic as message
    }
  }
}

fn expect_bool(
  result: Result(#(Bool, types.Reader), types.DecodeError),
) -> #(Bool, types.Reader) {
  case result {
    Ok(value) -> value
    Error(error) -> {
      let message = "Decode error: " <> debug_error(error)
      panic as message
    }
  }
}
