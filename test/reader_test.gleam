import gleam/bit_array
import gleeunit/should

import thrifty/container
import thrifty/field
import thrifty/reader as thrifty_reader
import thrifty/types
import thrifty/varint

pub fn binary_limit_test() {
  let data =
    bit_array.concat([
      varint.encode_varint(5),
      <<"hello":utf8>>,
    ])

  let reader =
    thrifty_reader.with_options(
      data,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 128,
        max_string_bytes: 4,
        bool_element_policy: types.AcceptCanonicalOnly,
      ),
    )

  should.equal(
    Error(types.InvalidWireFormat("Binary length exceeds max_string_bytes")),
    thrifty_reader.read_binary(reader),
  )
}

pub fn list_limit_test() {
  let header = container.encode_list_header(20, container.I32Type)

  let reader =
    thrifty_reader.with_options(
      header,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 5,
        max_string_bytes: 256,
        bool_element_policy: types.AcceptCanonicalOnly,
      ),
    )

  should.equal(
    Error(types.InvalidWireFormat("Exceeded container size limit")),
    thrifty_reader.skip_value(reader, types.List),
  )
}

pub fn struct_depth_limit_test() {
  let header = field.encode_field_header(1, types.I32, 0)
  let value = varint.encode_varint(1)
  let stop = <<0:int-size(8)>>

  let data = bit_array.concat([header, value, stop])

  let reader =
    thrifty_reader.with_options(
      data,
      types.ReaderOptions(
        max_depth: 1,
        max_container_items: 32,
        max_string_bytes: 256,
        bool_element_policy: types.AcceptCanonicalOnly,
      ),
    )

  should.equal(
    Error(types.InvalidWireFormat("Exceeded maximum depth")),
    thrifty_reader.read_struct(reader),
  )
}
