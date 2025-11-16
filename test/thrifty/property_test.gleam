import gleeunit
import gleeunit/should

import gleam/bit_array
import gleam/int
import gleam/list
import thrifty/container
import thrifty/field
import thrifty/reader
import thrifty/types
import thrifty/varint
import thrifty/writer
import thrifty/writer_highlevel
import thrifty/zigzag

pub fn main() {
  gleeunit.main()
}

// Deterministic LCG RNG to produce reproducible pseudo-random values.
fn lcg(seed: Int) -> Int {
  // 32-bit LCG constants
  let n = seed * 1_664_525 + 1_013_904_223
  n % 4_294_967_296
}

fn gen_ints(mut_seed: Int, count: Int, min: Int, max: Int) -> #(List(Int), Int) {
  gen_ints_rec(count, mut_seed, [], min, max)
}

fn gen_ints_rec(
  i: Int,
  seed: Int,
  acc: List(Int),
  min: Int,
  max: Int,
) -> #(List(Int), Int) {
  case i == 0 {
    True -> #(list.reverse(acc), seed)
    False -> {
      let nseed = lcg(seed)
      // map to range
      let denom = max - min + 1
      let r = min + nseed % denom
      gen_ints_rec(i - 1, nseed, [r, ..acc], min, max)
    }
  }
}

fn encode_i32_elements(values: List(Int)) -> BitArray {
  list.fold(values, writer.buffer_new(), encode_i32_fold)
  |> writer.buffer_to_bitarray
}

fn encode_i32_fold(buffer: writer.Buffer, value: Int) -> writer.Buffer {
  let assert Ok(bits) = writer.write_i32_checked(value)
  writer.buffer_append(buffer, bits)
}

fn read_i32_elements(
  current_reader: types.Reader,
  remaining: Int,
  acc: List(Int),
) -> #(List(Int), types.Reader) {
  case remaining {
    0 -> #(list.reverse(acc), current_reader)
    _ -> {
      let assert Ok(#(value, next_reader)) = reader.read_i32(current_reader)
      read_i32_elements(next_reader, remaining - 1, [value, ..acc])
    }
  }
}

pub fn varint_zigzag_random_roundtrip_test() {
  // Generate 200 pseudo-random ints in a moderate range
  let seed = 42
  let #(vals, _) = gen_ints(seed, 200, -1_000_000, 1_000_000)
  list.map(vals, fn(v) {
    let bits = writer.write_i32(v)
    let assert Ok(#(z, _)) = varint.decode_varint(bits, 0)
    let decoded = zigzag.decode_i32(z)
    decoded |> should.equal(v)
    0
  })
}

pub fn list_map_boundary_property_test() {
  let sizes = [0, 1, 14, 15, 16, 127, 128, 1000]
  list.map(sizes, fn(s) {
    // list header roundtrip
    let hdr = writer.write_list_header(s, container.I32Type)
    let assert Ok(#(size1, et, _)) = container.decode_list_header(hdr, 0)
    size1 |> should.equal(s)
    et |> should.equal(container.I32Type)

    // map header roundtrip (test empty and non-empty)
    let hdrm = writer.write_map_header(s, container.I32Type, container.I32Type)
    let assert Ok(#(ms, kt, vt, _)) = container.decode_map_header(hdrm, 0)
    ms |> should.equal(s)
    kt |> should.equal(container.I32Type)
    vt |> should.equal(container.I32Type)
    0
  })
}

pub fn buffer_accumulator_property_test() {
  // Build a buffer by appending several parts and compare to concat_many
  let buf0 = writer.buffer_new()
  let p1 = writer.write_field_header(1, types.I32, 0)
  let p2 = writer.write_string("prop-test")
  let p3 = writer.write_list_header(3, container.I32Type)

  let buf1 = writer.buffer_append(buf0, p1)
  let buf2 = writer.buffer_append(buf1, p2)
  let buf3 = writer.buffer_append(buf2, p3)

  let out_buf = writer.buffer_to_bitarray(buf3)
  let direct = bit_array.concat([p1, p2, p3])
  out_buf |> should.equal(direct)
}

pub fn boolean_inline_roundtrip_property_test() {
  // True and False
  let b1 = writer.write_bool(1, True, 0)
  let reader0 = reader.from_bit_array(b1)
  let assert Ok(#(hdr1, _)) = field.read_field_header(reader0, 0)
  case hdr1 {
    types.FieldHeader(fid, ftype) -> {
      fid |> should.equal(1)
      // BoolTrue or BoolFalse accepted
      case ftype {
        types.BoolTrue -> True
        types.BoolFalse -> True
        _ -> False
      }
      |> should.equal(True)
    }
  }

  let b2 = writer.write_bool(2, False, 1)
  let reader1 = reader.from_bit_array(b2)
  let assert Ok(#(hdr2, _)) = field.read_field_header(reader1, 1)
  case hdr2 {
    types.FieldHeader(fid2, ftype2) -> {
      fid2 |> should.equal(2)
      case ftype2 {
        types.BoolTrue -> True
        types.BoolFalse -> True
        _ -> False
      }
      |> should.equal(True)
    }
  }
}

pub fn zigzag_checked_roundtrip_property_test() {
  let seed = 1337
  let #(vals32, seed2) = gen_ints(seed, 200, -2_000_000_000, 2_000_000_000)
  list.map(vals32, fn(v) {
    let assert Ok(encoded) = zigzag.encode_i32_checked(v)
    zigzag.decode_i32(encoded) |> should.equal(v)
    0
  })

  let #(vals64, _) = gen_ints(seed2, 200, -4_000_000_000_000, 4_000_000_000_000)
  list.map(vals64, fn(v) {
    let assert Ok(encoded) = zigzag.encode_i64_checked(v)
    zigzag.decode_i64(encoded) |> should.equal(v)
    0
  })
}

pub fn struct_list_roundtrip_property_test() {
  let seed = 2025
  let #(base_vals, _) = gen_ints(seed, 200, -5000, 5000)
  let sizes = [0, 1, 3, 7, 12]
  list.map(sizes, fn(size) {
    let elements = list.take(base_vals, size)
    let payload = encode_i32_elements(elements)
    let builder0 = writer_highlevel.new()
    let label = "list-" <> int.to_string(size)
    let builder1 = writer_highlevel.write_string(builder0, 1, label)
    let builder2 =
      writer_highlevel.write_list(builder1, 2, size, container.I32Type, payload)
    let message = writer_highlevel.finish(builder2)

    let reader0 = reader.from_bit_array(message)

    let assert Ok(#(types.FieldHeader(fid1, ft1), after_name_hdr)) =
      field.read_field_header(reader0, 0)
    fid1 |> should.equal(1)
    ft1 |> should.equal(types.Binary)
    let assert Ok(#(decoded_label, after_name)) =
      reader.read_string(after_name_hdr)
    decoded_label |> should.equal(label)

    let assert Ok(#(types.FieldHeader(fid2, ft2), list_reader)) =
      field.read_field_header(after_name, 1)
    fid2 |> should.equal(2)
    ft2 |> should.equal(types.List)

    let types.Reader(data, _, options) = list_reader
    let byte_pos = reader.position(list_reader)
    let assert Ok(#(decoded_size, elem_type, next_pos)) =
      container.decode_list_header(data, byte_pos)
    decoded_size |> should.equal(size)
    elem_type |> should.equal(container.I32Type)

    let start_reader = types.Reader(data, next_pos, options)
    let #(decoded_elements, list_end_reader) =
      read_i32_elements(start_reader, size, [])
    decoded_elements |> should.equal(elements)

    let assert Ok(#(types.FieldHeader(_, stop_type), _)) =
      field.read_field_header(list_end_reader, 2)
    stop_type |> should.equal(types.Stop)
    0
  })
}

// ------------------------------------------------------------------
// Nested container property tests
// ------------------------------------------------------------------

fn make_inner_lists(size: Int) -> List(List(Int)) {
  make_inner_lists_rec(0, size, [])
}

fn make_inner_lists_rec(
  i: Int,
  size: Int,
  acc: List(List(Int)),
) -> List(List(Int)) {
  let base = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  case i == size {
    True -> list.reverse(acc)
    False -> make_inner_lists_rec(i + 1, size, [list.take(base, i), ..acc])
  }
}

fn encode_list_of_lists(lists: List(List(Int))) -> BitArray {
  list.fold(lists, writer.buffer_new(), fn(buf, inner) {
    let inner_payload = encode_i32_elements(inner)
    let inner_bits =
      writer.write_list(list.length(inner), container.I32Type, inner_payload)
    writer.buffer_append(buf, inner_bits)
  })
  |> writer.buffer_to_bitarray
}

fn read_inner_loop(
  outer_size: Int,
  i: Int,
  acc: List(List(Int)),
  cur_reader: types.Reader,
) -> #(List(List(Int)), types.Reader) {
  case i == outer_size {
    True -> #(list.reverse(acc), cur_reader)
    False -> {
      let types.Reader(d, p, opts) = cur_reader
      let assert Ok(#(inner_size, inner_elem_type, inner_next)) =
        container.decode_list_header(d, p)
      inner_elem_type |> should.equal(container.I32Type)
      let start_reader = types.Reader(d, inner_next, opts)
      let #(decoded, after) = read_i32_elements(start_reader, inner_size, [])
      read_inner_loop(outer_size, i + 1, [decoded, ..acc], after)
    }
  }
}

pub fn nested_lists_property_test() {
  let sizes = [0, 1, 3, 5]
  list.map(sizes, fn(s) {
    let inner_lists = make_inner_lists(s)
    let outer_payload = encode_list_of_lists(inner_lists)
    let builder0 = writer_highlevel.new()
    let builder1 =
      writer_highlevel.write_list(
        builder0,
        1,
        s,
        container.ListType,
        outer_payload,
      )
    let message = writer_highlevel.finish(builder1)

    let reader0 = reader.from_bit_array(message)
    let assert Ok(#(types.FieldHeader(_, ft), after_hdr)) =
      field.read_field_header(reader0, 0)
    ft |> should.equal(types.List)

    let types.Reader(data, _, options) = after_hdr
    let byte_pos = reader.position(after_hdr)
    let assert Ok(#(outer_size, elem_type, next_pos)) =
      container.decode_list_header(data, byte_pos)
    outer_size |> should.equal(s)
    elem_type |> should.equal(container.ListType)

    let #(decoded_lists, after_lists_reader) =
      read_inner_loop(outer_size, 0, [], types.Reader(data, next_pos, options))
    decoded_lists |> should.equal(inner_lists)

    // stop field
    let assert Ok(#(types.FieldHeader(_, stop_ft), _)) =
      field.read_field_header(after_lists_reader, 1)
    stop_ft |> should.equal(types.Stop)
    0
  })
}

fn encode_map_with_list_values(pairs: List(#(Int, List(Int)))) -> BitArray {
  list.fold(pairs, writer.buffer_new(), fn(buf, pair) {
    let #(k, v) = pair
    let key_bits = writer.write_i32(k)
    let val_payload = encode_i32_elements(v)
    let val_bits =
      writer.write_list(list.length(v), container.I32Type, val_payload)
    buf
    |> writer.buffer_append(key_bits)
    |> writer.buffer_append(val_bits)
  })
  |> writer.buffer_to_bitarray
}

fn make_pairs(s: Int) -> List(#(Int, List(Int))) {
  make_pairs_rec(0, s, [])
}

fn make_pairs_rec(
  i: Int,
  s: Int,
  acc: List(#(Int, List(Int))),
) -> List(#(Int, List(Int))) {
  let base = [1, 2, 3, 4, 5, 6]
  case i == s {
    True -> list.reverse(acc)
    False -> make_pairs_rec(i + 1, s, [#(i, list.take(base, i)), ..acc])
  }
}

fn read_map_entries(
  m_size: Int,
  i: Int,
  acc: List(#(Int, List(Int))),
  cur_reader: types.Reader,
) -> #(List(#(Int, List(Int))), types.Reader) {
  case i == m_size {
    True -> #(list.reverse(acc), cur_reader)
    False -> {
      let assert Ok(#(k, r1)) = reader.read_i32(cur_reader)
      let types.Reader(d, p, opts) = r1
      let assert Ok(#(inner_size, inner_elem_type, inner_next)) =
        container.decode_list_header(d, p)
      inner_elem_type |> should.equal(container.I32Type)
      let start_reader = types.Reader(d, inner_next, opts)
      let #(vals, after_val) = read_i32_elements(start_reader, inner_size, [])
      read_map_entries(m_size, i + 1, [#(k, vals), ..acc], after_val)
    }
  }
}

pub fn nested_map_property_test() {
  // map<int, list<int>>
  let sizes = [0, 1, 3]
  list.map(sizes, fn(s) {
    // build s entries with keys 0..s-1 and small lists
    let pairs = make_pairs(s)
    let payload = encode_map_with_list_values(pairs)
    let builder0 = writer_highlevel.new()
    let builder1 =
      writer_highlevel.write_map(
        builder0,
        1,
        s,
        container.I32Type,
        container.ListType,
        payload,
      )
    let message = writer_highlevel.finish(builder1)

    let reader0 = reader.from_bit_array(message)
    let assert Ok(#(types.FieldHeader(_, ft), after_hdr)) =
      field.read_field_header(reader0, 0)
    ft |> should.equal(types.Map)

    let types.Reader(data, _, options) = after_hdr
    let byte_pos = reader.position(after_hdr)
    let assert Ok(#(m_size, k_type, v_type, next_pos)) =
      container.decode_map_header(data, byte_pos)
    m_size |> should.equal(s)
    case m_size {
      0 -> Nil
      _ -> {
        k_type |> should.equal(container.I32Type)
        v_type |> should.equal(container.ListType)
      }
    }

    let #(decoded_pairs, after_reader) =
      read_map_entries(m_size, 0, [], types.Reader(data, next_pos, options))
    decoded_pairs |> should.equal(pairs)

    let assert Ok(#(types.FieldHeader(_, stop_ft), _)) =
      field.read_field_header(after_reader, 1)
    stop_ft |> should.equal(types.Stop)
    0
  })
}

pub fn nested_struct_property_test() {
  // inner struct with an i32 and a string
  let inner_builder = writer_highlevel.new()
  let assert Ok(inner_b1) = writer_highlevel.write_i32(inner_builder, 1, 7)
  let inner_b2 = writer_highlevel.write_string(inner_b1, 2, "inner")
  let inner_struct = writer_highlevel.finish(inner_b2)

  let builder0 = writer_highlevel.new()
  let builder1 =
    writer_highlevel.write_field_bytes(builder0, 1, types.Struct, inner_struct)
  let payload = writer_highlevel.finish(builder1)

  let reader0 = reader.from_bit_array(payload)
  let assert Ok(#(types.FieldHeader(_, ft), after_hdr)) =
    field.read_field_header(reader0, 0)
  ft |> should.equal(types.Struct)

  let assert Ok(#(fields, _)) = reader.read_struct(after_hdr)
  // inner struct had two fields: i32 and binary
  fields
  |> should.equal([
    types.FieldHeader(1, types.I32),
    types.FieldHeader(2, types.Binary),
  ])

  // verify values
  let inner_reader0 = after_hdr
  let assert Ok(#(types.FieldHeader(fid1, ft1), after_field1)) =
    field.read_field_header(inner_reader0, 0)
  fid1 |> should.equal(1)
  ft1 |> should.equal(types.I32)
  let assert Ok(#(v1, after_value1)) = reader.read_i32(after_field1)
  v1 |> should.equal(7)

  let assert Ok(#(types.FieldHeader(fid2, ft2), after_field2)) =
    field.read_field_header(after_value1, 1)
  fid2 |> should.equal(2)
  ft2 |> should.equal(types.Binary)
  let assert Ok(#(s, after_value2)) = reader.read_string(after_field2)
  s |> should.equal("inner")

  let assert Ok(#(types.FieldHeader(_, stop_ft), _)) =
    field.read_field_header(after_value2, 2)
  stop_ft |> should.equal(types.Stop)
}
