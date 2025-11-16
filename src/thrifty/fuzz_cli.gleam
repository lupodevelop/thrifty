// Copyright 2025 The thrifty contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list

import thrifty/file_io
import thrifty/fuzz_persistence
import thrifty/fuzz_utils
import thrifty/reader as thrifty_reader
import thrifty/types

const files = [
  "artifact/golden/user_profile.bin",
  "artifact/golden/ping_message.bin",
  "artifact/golden/complex_struct.bin",
  "artifact/golden/bool_list.bin",
]

const seeds = [13, 29, 41, 53, 67, 79, 97, 109]

const iterations_per_seed = 200

// Enable persistence of failing fuzz inputs. Default false to avoid polluting
// workspaces and CI runs. Set to `True` locally to collect failures.
const save_failures_enabled = False

const save_failures_dir = "artifact/fuzz-failures"

/// Run a short deterministic fuzz run over the configured golden payloads.
///
/// Purpose
/// - Convenience entrypoint for manual or CI smoke tests that exercise the
///   reader against small, mutated variants of canonical golden payloads.
///
/// Behavior
/// - Iterates the predefined `files` list, reads each binary, and applies a set
///   of deterministic single-byte mutations controlled by `seeds` and
///   `iterations_per_seed`.
/// - Each mutated payload is passed to the reader created with conservative
///   `ReaderOptions` to verify the reader does not crash on malformed inputs.
///
/// Outputs
/// - Prints progress to stdout. This function is intended as a smoke-test only
///   and does not return structured results; callers should inspect logs or
///   extend the harness to persist failing cases.
pub fn main() {
  io.println("Starting fuzz run over golden payloads")
  list.each(files, fuzz_file)
  io.println("Fuzz run completed without crashes")
}

fn fuzz_file(file: String) {
  case file_io.read_binary(file) {
    Error(error) -> io.println("Skipping " <> file <> ": " <> error)
    Ok(data) -> fuzz_payloads(file, data)
  }
}

/// Read a golden file and trigger fuzzing of its payloads.
///
/// Inputs
/// - `file`: path to a golden binary file.
///
/// Behavior
/// - On read error prints a message and continues. On success delegates to
///   `fuzz_payloads/2` to run deterministic mutations.
fn fuzz_payloads(file: String, data: BitArray) {
  let size = bit_array.byte_size(data)
  case size == 0 {
    True -> io.println("Skipping empty payload: " <> file)
    False -> {
      io.println("Fuzzing " <> file <> " (" <> int.to_string(size) <> " bytes)")
      list.each(seeds, fn(seed) {
        fuzz_with_seed(data, size, seed, iterations_per_seed)
      })
    }
  }
}

/// Prepare fuzzing state for a given payload and spawn seed-based iterations.
///
/// Inputs
/// - `file`: path to the golden file (used only for logging).
/// - `data`: payload bytes to mutate.
///
/// Behavior
/// - Skips empty payloads. Logs size and iterates `seeds` invoking `fuzz_with_seed`.
fn fuzz_with_seed(data: BitArray, size: Int, seed: Int, iterations: Int) {
  fuzz_loop(data, size, seed, 0, iterations)
}

/// Run deterministic single-byte mutation iterations for a single seed.
///
/// Inputs
/// - `data`: original payload.
/// - `size`: payload byte size.
/// - `seed`: deterministic seed controlling mutation positions/values.
/// - `iterations`: number of mutations to generate for this seed.
fn fuzz_loop(data: BitArray, size: Int, seed: Int, index: Int, remaining: Int) {
  case remaining == 0 {
    True -> Nil
    False -> {
      let position = normalize_mod(seed * 31 + index * 17, size)
      let value = normalize_mod(seed * 97 + index * 101, 256)
      let mutated = fuzz_utils.mutate_byte(data, position, value)

      let reader =
        thrifty_reader.with_options(
          mutated,
          types.ReaderOptions(
            max_depth: 32,
            max_container_items: 4096,
            max_string_bytes: 4_194_304,
            bool_element_policy: types.AcceptCanonicalOnly,
          ),
        )

      case thrifty_reader.read_struct(reader) {
        Ok(_) -> Nil
        Error(err) -> {
          // Persist failing mutated input when enabled.
          let _ =
            maybe_save_failure(
              save_failures_enabled,
              save_failures_dir,
              seed,
              index,
              mutated,
              err,
            )
          Nil
        }
      }

      fuzz_loop(data, size, seed, index + 1, remaining - 1)
    }
  }
}

/// Attempt to save a failing payload and a small metadata file.
fn maybe_save_failure(
  enabled: Bool,
  dir: String,
  seed: Int,
  iter: Int,
  data: BitArray,
  reason: types.DecodeError,
) -> Result(Nil, String) {
  case enabled {
    False -> Ok(Nil)
    True -> {
      // Ensure directory exists (best-effort). If creation fails we still
      // continue the fuzz run but return the error for debugging.
      fuzz_persistence.persist_failure(dir, seed, iter, data, reason)
    }
  }
}

/// Core fuzz loop that mutates a single byte and invokes the reader.
///
/// Notes
/// - This harness is purposely conservative: it uses `with_options` to limit
///   resources and discards reader results. Extend to persist failing inputs
///   when required.
fn normalize_mod(value: Int, modulus: Int) -> Int {
  let rem = value % modulus
  case rem < 0 {
    True -> rem + modulus
    False -> rem
  }
}
/// Normalize a possibly-negative integer modulo `modulus` into the range
/// `[0, modulus-1]`.
