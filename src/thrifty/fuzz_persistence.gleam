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

import thrifty/file_io
import thrifty/types

/// Persist a failing fuzz payload and associated metadata.
///
/// Inputs
/// - `dir`: output directory. Created if it does not already exist.
/// - `seed`: deterministic seed used when generating the payload.
/// - `iter`: iteration index within the seed loop.
/// - `data`: the mutated payload bytes to persist.
/// - `reason`: the decode error that triggered persistence.
///
/// Outputs
/// - `Ok(Nil)` when both payload and metadata are written successfully.
/// - `Error(String)` when directory creation or file writes fail.
///
/// The metadata is stored as a text file containing simple `key=value` lines
/// for quick inspection.
pub fn persist_failure(
  dir: String,
  seed: Int,
  iter: Int,
  data: BitArray,
  reason: types.DecodeError,
) -> Result(Nil, String) {
  case file_io.ensure_dir(dir) {
    Error(e) -> Error(e)
    Ok(_) -> {
      let basename =
        "fuzz-failure-" <> int.to_string(seed) <> "-" <> int.to_string(iter)
      let bin_path = dir <> "/" <> basename <> ".bin"
      let meta_path = dir <> "/" <> basename <> ".meta"

      case file_io.write_binary_to_path(bin_path, data) {
        Error(e) -> Error(e)
        Ok(_) -> {
          let meta =
            "seed="
            <> int.to_string(seed)
            <> "\niter="
            <> int.to_string(iter)
            <> "\nreason="
            <> types.decode_error_to_string(reason)
            <> "\n"
          let meta_bits = bit_array.from_string(meta)

          case file_io.write_binary_to_path(meta_path, meta_bits) {
            Error(e) -> Error(e)
            Ok(_) -> Ok(Nil)
          }
        }
      }
    }
  }
}
