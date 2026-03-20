import gleeunit
import gleeunit/should

import thrifty/field
import thrifty/reader
import thrifty/types
import thrifty/varint
import thrifty/zigzag

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
  // Long-form header per spec: header byte = 0x00 | type_nibble,
  // followed by zigzag(field_id) encoded as varint.
  // field_id=32 -> zigzag(32)=64 -> varint(64) = <<0x40>>
  let field_id_bits = varint.encode_varint(zigzag.encode_i32(32))
  let data = <<0x05:int-size(8), field_id_bits:bits>>
  let reader0 = reader.from_bit_array(data)
  let assert Ok(#(hdr, r1)) = field.read_field_header(reader0, 16)
  case hdr {
    types.FieldHeader(field_id, ftype) -> {
      field_id |> should.equal(32)
      ftype |> should.equal(types.I32)
    }
  }
  // next pos should be header byte + 1 varint byte (64 fits in 1 byte)
  reader.position(r1) |> should.equal(2)
}

pub fn long_form_negative_field_id_test() {
  // Negative field IDs are unusual but valid i16 per spec.
  // field_id=-1 -> zigzag(-1)=1 -> varint(1) = <<0x01>>
  let field_id_bits = varint.encode_varint(zigzag.encode_i32(-1))
  let data = <<0x05:int-size(8), field_id_bits:bits>>
  let reader0 = reader.from_bit_array(data)
  let assert Ok(#(hdr, _)) = field.read_field_header(reader0, 100)
  case hdr {
    types.FieldHeader(field_id, ftype) -> {
      field_id |> should.equal(-1)
      ftype |> should.equal(types.I32)
    }
  }
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
