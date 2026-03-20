import gleeunit/should

import thrifty/reader as thrifty_reader
import thrifty/types

// Direct read tests for boolean element bytes
pub fn read_bool_element_accepts_1_and_2_strict_test() {
  // bytes: 1 (True), 2 (False)
  let data = <<1:int-size(8), 2:int-size(8)>>

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

  case thrifty_reader.read_bool_element(reader) {
    Ok(#(v1, r1)) -> {
      v1 |> should.equal(True)
      case thrifty_reader.read_bool_element(r1) {
        Ok(#(v2, _)) -> v2 |> should.equal(False)
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn read_bool_element_accepts_1_and_2_permissive_test() {
  let data = <<1:int-size(8), 2:int-size(8)>>

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

  case thrifty_reader.read_bool_element(reader) {
    Ok(#(v1, r1)) -> {
      v1 |> should.equal(True)
      case thrifty_reader.read_bool_element(r1) {
        Ok(#(v2, _)) -> v2 |> should.equal(False)
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

// AcceptBoth must accept legacy byte 0 as False
pub fn permissive_bool_accepts_zero_as_false_test() {
  let data = <<0:int-size(8)>>

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

  case thrifty_reader.read_bool_element(reader) {
    Ok(#(v, _)) -> v |> should.equal(False)
    Error(_) -> should.fail()
  }
}

pub fn read_bool_element_rejects_other_bytes_test() {
  // byte 0 is invalid with AcceptCanonicalOnly
  let data = <<0:int-size(8)>>

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

  case thrifty_reader.read_bool_element(reader) {
    Ok(_) -> should.fail()
    Error(types.InvalidWireFormat(_)) -> True |> should.equal(True)
    Error(_) -> should.fail()
  }
}
