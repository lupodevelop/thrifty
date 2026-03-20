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
import gleam/string

import thrifty/types
import thrifty/varint

/// Message type enumeration for Thrift messages.
pub type MessageType {
  Call
  Reply
  Exception
  Oneway
}

/// Message header structure.
pub type MessageHeader {
  MessageHeader(name: String, message_type: MessageType, sequence_id: Int)
}

/// Encode a Thrift message header to a `BitArray` using Compact Protocol
/// framing.
///
/// Inputs
/// - `header`: a `MessageHeader` record with name, message_type and sequence id.
///
/// Outputs
/// - Returns a `BitArray` containing the protocol id, version/type byte,
///   varint-encoded sequence id, varint length of method name and UTF-8
///   bytes for the method name.
///
/// Format
/// - Protocol ID: 0x82 (1 byte)
/// - Version & Type: (version << 5) | type (1 byte, version=1)
/// - Sequence ID: varint i32
/// - Method name: length (varint) + UTF-8 bytes
pub fn encode_message_header(header: MessageHeader) -> BitArray {
  let protocol_id = 0x82
  let version = 1
  let type_value = message_type_to_int(header.message_type)
  let version_and_type = version * 32 + type_value

  // Encode seq_id as unsigned 32-bit two's-complement varint, matching the
  // reference Java implementation which uses unsigned right-shift (>>>).
  let seq_id_u32 =
    { header.sequence_id % 4_294_967_296 + 4_294_967_296 } % 4_294_967_296
  let seq_id_varint = varint.encode_varint(seq_id_u32)

  let name_bytes =
    string.to_utf_codepoints(header.name)
    |> string.from_utf_codepoints
    |> bit_array.from_string
  let name_length = bit_array.byte_size(name_bytes)
  let name_length_varint = varint.encode_varint(name_length)

  <<
    protocol_id:int-size(8),
    version_and_type:int-size(8),
    seq_id_varint:bits,
    name_length_varint:bits,
    name_bytes:bits,
  >>
}

/// Decode a Thrift message header from `data` starting at `byte_pos`.
///
/// Inputs
/// - `data`: the `BitArray` containing the encoded message header and payload.
/// - `byte_pos`: byte offset where the header begins.
///
/// Outputs
/// - `Ok(#(MessageHeader, next_byte_position))` on success where
///   `next_byte_position` points after the method name bytes.
/// - `Error(types.DecodeError)` on protocol mismatch, unsupported version,
///   invalid varint encodings, or invalid UTF-8 in the method name.
pub fn decode_message_header(
  data: BitArray,
  byte_pos: Int,
) -> Result(#(MessageHeader, Int), types.DecodeError) {
  // Read protocol ID
  case bit_array.slice(data, byte_pos, 1) {
    Error(_) -> Error(types.UnexpectedEndOfInput)
    Ok(<<protocol_id:int-size(8)>>) -> {
      case protocol_id == 0x82 {
        False -> Error(types.InvalidWireFormat("Invalid protocol ID"))
        True -> {
          // Read version & type
          case bit_array.slice(data, byte_pos + 1, 1) {
            Error(_) -> Error(types.UnexpectedEndOfInput)
            Ok(<<version_and_type:int-size(8)>>) -> {
              let version = version_and_type / 32
              let type_value = version_and_type % 32
              case version == 1 {
                False -> Error(types.InvalidWireFormat("Unsupported version"))
                True -> {
                  case int_to_message_type(type_value) {
                    Error(e) -> Error(e)
                    Ok(msg_type) -> {
                      // Read sequence ID first
                      case varint.decode_varint(data, byte_pos + 2) {
                        Error(e) -> Error(e)
                        Ok(#(seq_id_raw, pos_after_seq)) -> {
                          // Sign-extend back to i32: values > INT32_MAX were
                          // negative before the uint32 encoding on the write side.
                          let seq_id = case seq_id_raw > 2_147_483_647 {
                            True -> seq_id_raw - 4_294_967_296
                            False -> seq_id_raw
                          }
                          // Read method name length
                          case varint.decode_varint(data, pos_after_seq) {
                            Error(e) -> Error(e)
                            Ok(#(name_length, name_bytes_start)) -> {
                              // Read method name bytes
                              case
                                bit_array.slice(
                                  data,
                                  name_bytes_start,
                                  name_length,
                                )
                              {
                                Error(_) -> Error(types.UnexpectedEndOfInput)
                                Ok(name_bytes) -> {
                                  case bit_array.to_string(name_bytes) {
                                    Error(_) ->
                                      Error(types.InvalidWireFormat(
                                        "Invalid UTF-8 in method name",
                                      ))
                                    Ok(name) -> {
                                      let next_pos =
                                        name_bytes_start + name_length
                                      let header =
                                        MessageHeader(
                                          name: name,
                                          message_type: msg_type,
                                          sequence_id: seq_id,
                                        )
                                      Ok(#(header, next_pos))
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            Ok(_) -> Error(types.InvalidWireFormat("Invalid version/type byte"))
          }
        }
      }
    }
    Ok(_) -> Error(types.InvalidWireFormat("Invalid protocol ID byte"))
  }
}

/// Convert a `MessageType` to the protocol numeric value used in the
/// version/type byte.
///
/// Inputs
/// - `mt`: message type enum.
///
/// Outputs
/// - Integer value used in encoding the version/type byte.
fn message_type_to_int(mt: MessageType) -> Int {
  case mt {
    Call -> 1
    Reply -> 2
    Exception -> 3
    Oneway -> 4
  }
}

/// Convert a numeric message type to `MessageType`.
///
/// Inputs
/// - `n`: numeric type extracted from the version/type byte.
///
/// Outputs
/// - `Ok(MessageType)` when recognized.
/// - `Error(types.UnsupportedType(n))` when unknown.
fn int_to_message_type(n: Int) -> Result(MessageType, types.DecodeError) {
  case n {
    1 -> Ok(Call)
    2 -> Ok(Reply)
    3 -> Ok(Exception)
    4 -> Ok(Oneway)
    _ -> Error(types.UnsupportedType(n))
  }
}
///
/// Inputs
/// - `n`: numeric type extracted from the version/type byte.
///
/// Outputs
/// - `Ok(MessageType)` when recognized.
/// - `Error(types.UnsupportedType(n))` when unknown.
