/// Types and errors for the Thrift Compact Protocol library.
import gleam/int

pub type Reader {
  Reader(data: BitArray, position: Int, options: ReaderOptions)
}

pub type Writer {
  Writer(buffer: BitArray)
}

pub type FieldType {
  BoolTrue
  BoolFalse
  Byte
  I16
  I32
  I64
  Double
  Binary
  List
  Set
  Map
  Struct
  Stop
}

pub type FieldHeader {
  FieldHeader(field_id: Int, field_type: FieldType)
}

pub type DecodeError {
  UnexpectedEndOfInput
  InvalidVarint
  InvalidFieldType(expected: Int, got: Int)
  UnsupportedType(Int)
  InvalidWireFormat(String)
}

pub type ReaderOptions {
  ReaderOptions(
    max_depth: Int,
    max_container_items: Int,
    max_string_bytes: Int,
    // Policy for boolean elements inside containers. See `BoolElementPolicy`
    // below for the available options and behaviours.
    bool_element_policy: BoolElementPolicy,
  )
}

/// How boolean elements (bytes inside list/set/map representing booleans)
/// are interpreted and validated by the reader.
pub type BoolElementPolicy {
  // Accept both byte encodings 1 and 2 and map them to booleans as
  // 1 => True, 2 => False. This is the default and maximally compatible
  // behaviour.
  AcceptBoth

  // Enforce canonical validation: accept only the canonical spec encodings
  // (1 => True, 2 => False) and reject any other byte with
  // `InvalidWireFormat("Invalid boolean element")`.
  // (Functionally equivalent to AcceptBoth today but provided to make the
  // intent explicit and to allow future divergence if needed.)
  AcceptCanonicalOnly
}

pub const default_reader_options = ReaderOptions(
  max_depth: 64,
  max_container_items: 65_536,
  max_string_bytes: 8_388_608,
  bool_element_policy: AcceptCanonicalOnly,
)

/// Convert a `DecodeError` into a human readable string for logging or
/// metadata files.
pub fn decode_error_to_string(err: DecodeError) -> String {
  case err {
    UnexpectedEndOfInput -> "UnexpectedEndOfInput"
    InvalidVarint -> "InvalidVarint"
    InvalidFieldType(expected, got) ->
      "InvalidFieldType("
      <> int.to_string(expected)
      <> ","
      <> int.to_string(got)
      <> ")"
    UnsupportedType(code) -> "UnsupportedType(" <> int.to_string(code) <> ")"
    InvalidWireFormat(msg) -> "InvalidWireFormat(" <> msg <> ")"
  }
}
