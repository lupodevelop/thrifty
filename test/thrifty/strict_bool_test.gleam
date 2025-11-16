import gleam/bit_array
import gleeunit/should

import thrifty/container
import thrifty/reader as thrifty_reader
import thrifty/types

pub fn strict_bool_rejects_invalid_element_test() {
  // list<bool> with a single invalid element value (3)
  let header = container.encode_list_header(1, container.BoolType)
  let data = bit_array.concat([header, <<3:int-size(8)>>])

  let reader =
    thrifty_reader.with_options(
      data,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 32,
        max_string_bytes: 256,
        bool_element_policy: types.AcceptCanonicalOnly,
      ),
    )

  should.equal(
    Error(types.InvalidWireFormat("Invalid boolean element")),
    thrifty_reader.skip_value(reader, types.List),
  )
}

pub fn permissive_bool_accepts_valid_elements_test() {
  // list<bool> with two valid element bytes 1 and 2
  let header = container.encode_list_header(2, container.BoolType)
  let data = bit_array.concat([header, <<1:int-size(8)>>, <<2:int-size(8)>>])

  let reader =
    thrifty_reader.with_options(
      data,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 32,
        max_string_bytes: 256,
        bool_element_policy: types.AcceptBoth,
      ),
    )

  // should skip successfully
  case thrifty_reader.skip_value(reader, types.List) {
    Ok(_) -> True |> should.equal(True)
    Error(_) -> should.fail()
  }
}

pub fn strict_bool_accepts_valid_elements_test() {
  // Same valid payload but strict mode should also accept canonical 1/2
  let header = container.encode_list_header(2, container.BoolType)
  let data = bit_array.concat([header, <<1:int-size(8)>>, <<2:int-size(8)>>])

  let reader =
    thrifty_reader.with_options(
      data,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 32,
        max_string_bytes: 256,
        bool_element_policy: types.AcceptCanonicalOnly,
      ),
    )

  case thrifty_reader.skip_value(reader, types.List) {
    Ok(_) -> True |> should.equal(True)
    Error(_) -> should.fail()
  }
}

pub fn permissive_bool_rejects_invalid_element_test() {
  // In permissive mode invalid element bytes are still rejected; only 1/2
  // are considered valid boolean encodings.
  let header = container.encode_list_header(1, container.BoolType)
  let data = bit_array.concat([header, <<3:int-size(8)>>])

  let reader =
    thrifty_reader.with_options(
      data,
      types.ReaderOptions(
        max_depth: 64,
        max_container_items: 32,
        max_string_bytes: 256,
        bool_element_policy: types.AcceptBoth,
      ),
    )

  should.equal(
    Error(types.InvalidWireFormat("Invalid boolean element")),
    thrifty_reader.skip_value(reader, types.List),
  )
}
