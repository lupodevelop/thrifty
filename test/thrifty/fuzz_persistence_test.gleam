import gleam/bit_array
import thrifty/file_io
import thrifty/fuzz_persistence
import thrifty/types

pub fn persist_failure_test() {
  let dir = "artifact/fuzz-failures-test"
  let seed = 123
  let iter = 7
  let data = bit_array.from_string("payload")
  let reason = types.InvalidVarint

  case fuzz_persistence.persist_failure(dir, seed, iter, data, reason) {
    Error(e) -> panic as e
    Ok(_) -> Nil
  }

  let bin_path = dir <> "/fuzz-failure-123-7.bin"
  let meta_path = dir <> "/fuzz-failure-123-7.meta"

  let assert Ok(bin_bits) = file_io.read_binary(bin_path)
  let assert Ok(bin_string) = bit_array.to_string(bin_bits)
  assert bin_string == "payload"

  let assert Ok(meta_bits) = file_io.read_binary(meta_path)
  let assert Ok(meta_string) = bit_array.to_string(meta_bits)
  let expected = "seed=123\niter=7\nreason=InvalidVarint\n"
  assert meta_string == expected
}
