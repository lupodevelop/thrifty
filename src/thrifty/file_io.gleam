import gleam/erlang/atom

/// Minimal helpers to read binary files via the Erlang file module.
///
/// Notes
/// - This module wraps the Erlang `file:read_file/1` external for convenience.
@external(erlang, "file", "read_file")
fn file_read(path: String) -> Result(BitArray, atom.Atom)

/// Read the binary contents at `path` returning a Gleam `BitArray`.
///
/// Inputs
/// - `path`: filesystem path to the file to read.
///
/// Outputs
/// - `Ok(BitArray)` containing the file contents on success.
/// - `Error(String)` with a human-readable reason on failure.
///
/// Error modes
/// - The function converts Erlang atoms returned by the underlying call
///   into strings for easier consumption by tests and higher-level code.
pub fn read_binary(path: String) -> Result(BitArray, String) {
  case file_read(path) {
    Ok(data) -> Ok(data)
    Error(reason) -> Error(atom.to_string(reason))
  }
}

@external(erlang, "file_io_ffi", "write_file")
fn file_write(path: String, data: BitArray) -> Result(atom.Atom, atom.Atom)

/// Write binary contents to `path`.
///
/// Inputs
/// - `path`: filesystem path where to write the data.
/// - `data`: `BitArray` to write to disk.
///
/// Outputs
/// - `Ok(Nil)` on success.
/// - `Error(String)` with a human-readable reason on failure.
pub fn write_binary_to_path(path: String, data: BitArray) -> Result(Nil, String) {
  case file_write(path, data) {
    Ok(_) -> Ok(Nil)
    Error(reason) -> Error(atom.to_string(reason))
  }
}

@external(erlang, "file_io_ffi", "make_dir")
fn file_make_dir(path: String) -> Result(atom.Atom, atom.Atom)

/// Ensure a directory exists, creating it if necessary.
///
/// Returns `Ok(Nil)` on success or `Error(String)` on failure.
pub fn ensure_dir(path: String) -> Result(Nil, String) {
  case file_make_dir(path) {
    Ok(_) -> Ok(Nil)
    Error(reason) -> Error(atom.to_string(reason))
  }
}
