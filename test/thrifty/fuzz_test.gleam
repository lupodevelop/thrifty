import gleam/bit_array
import gleam/list
import gleeunit/should

import thrifty/file_io
import thrifty/reader as thrifty_reader
import thrifty/types

// Mutate a BitArray (represented as BitArray bytes) by flipping a single
// byte to a pseudo-random value. We operate on raw bytes by slicing and
// rebuilding small BitArrays.
fn mutate_bytes(data: BitArray, pos: Int, value: Int) -> BitArray {
  case bit_array.slice(data, 0, pos) {
    Error(_) -> data
    Ok(prefix) -> {
      let total = bit_array.byte_size(data)
      let suffix_len = total - pos - 1
      case bit_array.slice(data, pos + 1, suffix_len) {
        Error(_) -> bit_array.concat([prefix, <<value:int-size(8)>>])
        Ok(suffix) -> bit_array.concat([prefix, <<value:int-size(8)>>, suffix])
      }
    }
  }
}

pub fn fuzz_golden_payloads_test() {
  // Load available golden files and apply small deterministic mutations.
  let files = [
    "artifact/golden/user_profile.bin",
    "artifact/golden/ping_message.bin",
    "artifact/golden/complex_struct.bin",
    "artifact/golden/bool_list.bin",
  ]

  list.each(files, fn(file) {
    case file_io.read_binary(file) {
      Error(_) -> Nil
      Ok(data) -> {
        let size = bit_array.byte_size(data)
        case size == 0 {
          True -> Nil
          False -> {
            // produce a handful of deterministic mutations
            let seeds = [1, 2, 3, 5, 7]
            list.each(seeds, fn(s) {
              let pos_tmp = s % size
              let pos = pos_tmp
              let tmp = s * 97
              let val = tmp % 256
              let mutated = mutate_bytes(data, pos, val)

              // Create reader and ensure parsing doesn't crash: result must be
              // either Ok(_) or Error(_). We call read_struct for a top-level
              // struct; if it fails, it's acceptable as long as it's an Error.
              let reader =
                thrifty_reader.with_options(
                  mutated,
                  types.ReaderOptions(
                    max_depth: 16,
                    max_container_items: 1024,
                    max_string_bytes: 1024 * 1024,
                    bool_element_policy: types.AcceptCanonicalOnly,
                  ),
                )

              case thrifty_reader.read_struct(reader) {
                Ok(#(_, _)) -> True |> should.equal(True)
                Error(_) -> True |> should.equal(True)
              }
            })
          }
        }
      }
    }
  })
}
