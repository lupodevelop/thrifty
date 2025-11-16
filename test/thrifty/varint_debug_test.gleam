import gleam/io
import thrifty/varint

pub fn debug_encode_zero() {
  let encoded = varint.encode_varint(0)
  io.println("Encoded 0: " <> debug_bitarray(encoded))
  Nil
}

pub fn debug_encode_one() {
  let encoded = varint.encode_varint(1)
  io.println("Encoded 1: " <> debug_bitarray(encoded))
  Nil
}

pub fn debug_encode_127() {
  let encoded = varint.encode_varint(127)
  io.println("Encoded 127: " <> debug_bitarray(encoded))
  Nil
}

pub fn debug_encode_128() {
  let encoded = varint.encode_varint(128)
  io.println("Encoded 128: " <> debug_bitarray(encoded))
  Nil
}

fn debug_bitarray(ba: BitArray) -> String {
  case ba {
    <<>> -> "<<>>"
    <<b:int>> -> "<<" <> int_to_hex(b) <> ">>"
    <<b1:int, b2:int>> ->
      "<<" <> int_to_hex(b1) <> " " <> int_to_hex(b2) <> ">>"
    <<b1:int, b2:int, b3:int>> ->
      "<<"
      <> int_to_hex(b1)
      <> " "
      <> int_to_hex(b2)
      <> " "
      <> int_to_hex(b3)
      <> ">>"
    _ -> "<<...>>"
  }
}

fn int_to_hex(i: Int) -> String {
  case i {
    0 -> "00"
    1 -> "01"
    127 -> "7F"
    128 -> "80"
    129 -> "81"
    255 -> "FF"
    _ -> "??"
  }
}
