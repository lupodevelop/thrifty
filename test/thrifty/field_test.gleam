import gleeunit
import gleeunit/should

import thrifty/field
import thrifty/reader
import thrifty/types
import thrifty/varint

pub fn main() {
  gleeunit.main()
}

pub fn short_form_header_test() {
  // header: delta=1, type=I32 (5) -> 0x15
  let data = <<0x15:int-size(8)>>
  let reader0 = reader.from_bit_array(data)
  let assert Ok(#(hdr, r1)) = field.read_field_header(reader0, 0)
  case hdr {
    types.FieldHeader(field_id, ftype) -> {
      field_id |> should.equal(1)
      ftype |> should.equal(types.I32)
    }
  }
  reader.position(r1) |> should.equal(1)
}

pub fn long_form_header_test() {
  // header byte: delta=0, type=I32 (5) -> 0x05
  // field id: 32 (varint)
  let field_id_bits = varint.encode_varint(32)
  let data = <<0x05:int-size(8), field_id_bits:bits>>
  let reader0 = reader.from_bit_array(data)
  let assert Ok(#(hdr, r1)) = field.read_field_header(reader0, 16)
  case hdr {
    types.FieldHeader(field_id, ftype) -> {
      field_id |> should.equal(32)
      ftype |> should.equal(types.I32)
    }
  }
  // next pos should be header + varint length
  reader.position(r1) |> should.equal(2)
}

pub fn boolean_inline_header_test() {
  // delta=1, type=BOOL_TRUE(1) -> 0x11
  let data = <<0x11:int-size(8)>>
  let reader0 = reader.from_bit_array(data)
  let assert Ok(#(hdr, r1)) = field.read_field_header(reader0, 0)
  case hdr {
    types.FieldHeader(field_id, ftype) -> {
      field_id |> should.equal(1)
      ftype |> should.equal(types.BoolTrue)
    }
  }
  reader.position(r1) |> should.equal(1)
}

pub fn stop_field_test() {
  let data = <<0x00:int-size(8)>>
  let reader0 = reader.from_bit_array(data)
  let assert Ok(#(hdr, r1)) = field.read_field_header(reader0, 0)
  case hdr {
    types.FieldHeader(field_id, ftype) -> {
      field_id |> should.equal(0)
      ftype |> should.equal(types.Stop)
    }
  }
  reader.position(r1) |> should.equal(1)
}

pub fn truncated_header_test() {
  let data = <<>>
  let reader0 = reader.from_bit_array(data)
  let assert Error(e) = field.read_field_header(reader0, 0)
  case e {
    types.UnexpectedEndOfInput -> Nil
    _ -> panic as "Expected UnexpectedEndOfInput"
  }
}

pub fn unsupported_field_type_test() {
  // header: delta=1, type=13 (unsupported) -> header byte = 1*16 + 13 = 0x1D
  let data = <<0x1D:int-size(8)>>
  let reader0 = reader.from_bit_array(data)
  let assert Error(e) = field.read_field_header(reader0, 0)
  case e {
    types.UnsupportedType(n) -> n |> should.equal(13)
    _ -> panic as "Expected UnsupportedType(13)"
  }
}
