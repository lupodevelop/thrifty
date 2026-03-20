import gleeunit
import gleeunit/should

import gleam/bit_array

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

pub fn zigzag_i32_roundtrip_test() {
  let values = [0, 1, -1, 127, -128, 1000]
  list.map(values, fn(value) {
    let bits = writer.write_i32(value)
    // decode varint from bits
    let assert Ok(#(z, _)) = varint.decode_varint(bits, 0)
    let decoded = zigzag.decode_i32(z)
    decoded |> should.equal(value)
    0
  })
}

pub fn i8_write_test() {
  let b = writer.write_i8(42)
  let assert Ok(<<v:int-size(8)>>) = bit_array.slice(b, 0, 1)
  v |> should.equal(42)
}

// write_i8: boundary values and roundtrip with negative values
pub fn i8_write_boundaries_test() {
  // max positive i8
  let b_max = writer.write_i8(127)
  let assert Ok(<<v_max:int-signed-size(8)>>) = bit_array.slice(b_max, 0, 1)
  v_max |> should.equal(127)

  // min negative i8
  let b_min = writer.write_i8(-128)
  let assert Ok(<<v_min:int-signed-size(8)>>) = bit_array.slice(b_min, 0, 1)
  v_min |> should.equal(-128)

  // -1 encodes as 0xFF
  let b_neg1 = writer.write_i8(-1)
  let assert Ok(<<raw:int-size(8)>>) = bit_array.slice(b_neg1, 0, 1)
  raw |> should.equal(255)
}

// write_i16: boundary values roundtrip via read_i16
pub fn i16_write_boundaries_test() {
  let r_max = reader.from_bit_array(writer.write_i16(32_767))
  let assert Ok(#(v_max, _)) = reader.read_i16(r_max)
  v_max |> should.equal(32_767)

  let r_min = reader.from_bit_array(writer.write_i16(-32_768))
  let assert Ok(#(v_min, _)) = reader.read_i16(r_min)
  v_min |> should.equal(-32_768)

  let r_neg = reader.from_bit_array(writer.write_i16(-1))
  let assert Ok(#(v_neg, _)) = reader.read_i16(r_neg)
  v_neg |> should.equal(-1)
}

pub fn list_header_roundtrip_test() {
  // short form
  let hdr = writer.write_list_header(14, container.I32Type)
  let assert Ok(#(size, elem, _)) = container.decode_list_header(hdr, 0)
  size |> should.equal(14)
  elem |> should.equal(container.I32Type)

  // long form
  let hdr2 = writer.write_list_header(32, container.I32Type)
  let assert Ok(#(size2, elem2, _)) = container.decode_list_header(hdr2, 0)
  size2 |> should.equal(32)
  elem2 |> should.equal(container.I32Type)
}

pub fn map_header_roundtrip_test() {
  let hdr = writer.write_map_header(0, container.I32Type, container.I32Type)
  let assert Ok(#(size, _, _, _)) = container.decode_map_header(hdr, 0)
  size |> should.equal(0)

  let hdr2 = writer.write_map_header(3, container.I32Type, container.I32Type)
  let assert Ok(#(size2, kt, vt, _)) = container.decode_map_header(hdr2, 0)
  size2 |> should.equal(3)
  kt |> should.equal(container.I32Type)
  vt |> should.equal(container.I32Type)
}

pub fn string_write_roundtrip_test() {
  let s = "hello"
  let bits = writer.write_string(s)
  // read length varint
  let assert Ok(#(len, pos)) = varint.decode_varint(bits, 0)
  let assert Ok(bytes) = bit_array.slice(bits, pos, len)
  let assert Ok(out) = bit_array.to_string(bytes)
  out |> should.equal(s)
}

pub fn struct_writer_roundtrip_test() {
  let builder0 = writer_highlevel.new()
  let builder1 = writer_highlevel.write_string(builder0, 1, "Ada")
  let assert Ok(builder2) = writer_highlevel.write_i32(builder1, 2, 42)
  let builder3 = writer_highlevel.write_bool(builder2, 3, True)
  let assert Ok(builder4) = writer_highlevel.write_i64(builder3, 4, 9000)
  let payload = writer_highlevel.finish(builder4)

  let reader0 = reader.from_bit_array(payload)

  let assert Ok(#(types.FieldHeader(fid1, ft1), r1)) =
    field.read_field_header(reader0, 0)
  fid1 |> should.equal(1)
  ft1 |> should.equal(types.Binary)
  let assert Ok(#(name, r_name)) = reader.read_string(r1)
  name |> should.equal("Ada")

  let assert Ok(#(types.FieldHeader(fid2, ft2), r2)) =
    field.read_field_header(r_name, 1)
  fid2 |> should.equal(2)
  ft2 |> should.equal(types.I32)
  let assert Ok(#(id, r_id)) = reader.read_i32(r2)
  id |> should.equal(42)

  let assert Ok(#(types.FieldHeader(fid3, ft3), r3)) =
    field.read_field_header(r_id, 2)
  fid3 |> should.equal(3)
  case ft3 {
    types.BoolTrue -> True
    _ -> False
  }
  |> should.equal(True)

  let assert Ok(#(types.FieldHeader(fid4, ft4), r4)) =
    field.read_field_header(r3, 3)
  fid4 |> should.equal(4)
  ft4 |> should.equal(types.I64)
  let assert Ok(#(rep, r_rep)) = reader.read_i64(r4)
  rep |> should.equal(9000)

  let assert Ok(#(types.FieldHeader(fid_stop, ft_stop), _)) =
    field.read_field_header(r_rep, 4)
  fid_stop |> should.equal(0)
  ft_stop |> should.equal(types.Stop)
}

pub fn struct_writer_long_header_test() {
  let builder0 = writer_highlevel.new()
  let assert Ok(builder1) = writer_highlevel.write_i32(builder0, 1, 7)
  let assert Ok(builder2) = writer_highlevel.write_i32(builder1, 18, 300)
  let assert Ok(builder3) = writer_highlevel.write_i32(builder2, 2, -12)
  let payload = writer_highlevel.finish(builder3)

  let reader0 = reader.from_bit_array(payload)

  let assert Ok(#(types.FieldHeader(fid1, _), r1)) =
    field.read_field_header(reader0, 0)
  fid1 |> should.equal(1)
  let assert Ok(#(_, r_after1)) = reader.read_i32(r1)

  let assert Ok(#(types.FieldHeader(fid2, _), r2)) =
    field.read_field_header(r_after1, 1)
  fid2 |> should.equal(18)
  let assert Ok(#(v2, r_after2)) = reader.read_i32(r2)
  v2 |> should.equal(300)

  let assert Ok(#(types.FieldHeader(fid3, _), r3)) =
    field.read_field_header(r_after2, 18)
  fid3 |> should.equal(2)
  let assert Ok(#(v3, r_after3)) = reader.read_i32(r3)
  v3 |> should.equal(-12)

  let assert Ok(#(types.FieldHeader(_, ft_stop), _)) =
    field.read_field_header(r_after3, 2)
  ft_stop |> should.equal(types.Stop)
}
