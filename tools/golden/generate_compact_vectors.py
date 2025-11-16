#!/usr/bin/env python3
"""Generate Compact Protocol golden vectors using thriftpy2.

This script writes the binary payloads under `artifact/golden/` so that the
Gleam tests can validate behaviour against an authoritative reference
implementation (thriftpy2).
"""

from __future__ import annotations

import pathlib
from typing import Dict

import thriftpy2
from thriftpy2.protocol import TCompactProtocolFactory
from thriftpy2.thrift import TMessageType
from thriftpy2.transport import TMemoryBuffer

ROOT = pathlib.Path(__file__).resolve().parents[2]
# Write generated golden artifacts to artifact/golden by default (not under ref/)
REF_GOLDEN = ROOT / "artifact" / "golden"
THRIFT_FILE = REF_GOLDEN / "example.thrift"


def _compact_bytes(write_callable) -> bytes:
  buffer = TMemoryBuffer()
  proto = TCompactProtocolFactory().get_protocol(buffer)
  write_callable(proto)
  return buffer.getvalue()


def generate_payloads() -> Dict[str, bytes]:
  module = thriftpy2.load(str(THRIFT_FILE), module_name="golden_example_thrift")

  profile = module.UserProfile(
    name="Ada",
    user_id=42,
    is_active=True,
    reputation=9000,
  )

  struct_bytes = _compact_bytes(lambda proto: profile.write(proto))

  def write_message(proto):
    proto.write_message_begin("Ping", TMessageType.CALL, 1)
    profile.write(proto)
    proto.write_message_end()

  message_bytes = _compact_bytes(write_message)

  # Complex payloads
  # 1) complex_struct: nested map<int, list<InnerStruct>> + list<map<string,set<i32>>> + edges
  complex = module.Complex(
    map_list_struct={
      1: [module.Inner(id=1, name="a"), module.Inner(id=2, name="b")],
      2: [],
    },
    list_map_set=[
      {"k1": set([1, 2, 3])},
      {"k2": set([])},
    ],
    i32_edge=2_147_483_647,
    i64_edge=9_223_372_036_854_775_807,
    flag=False,
  )

  complex_bytes = _compact_bytes(lambda proto: complex.write(proto))

  # 2) boolean container: list<bool> as struct
  bool_list = module.BoolList(values=[True, False, True, False])
  bool_list_bytes = _compact_bytes(lambda proto: bool_list.write(proto))

  # 3) malformed: take a valid payload and truncate the last few bytes
  malformed = struct_bytes[:-3] if len(struct_bytes) > 3 else struct_bytes

  return {
    "user_profile.bin": struct_bytes,
    "ping_message.bin": message_bytes,
    "complex_struct.bin": complex_bytes,
    "bool_list.bin": bool_list_bytes,
    "user_profile_truncated.bin": malformed,
  }


def main() -> int:
  payloads = generate_payloads()
  # Ensure the output directory exists
  REF_GOLDEN.mkdir(parents=True, exist_ok=True)
  for filename, data in payloads.items():
    out_path = REF_GOLDEN / filename
    out_path.write_bytes(data)
    rel = out_path.relative_to(ROOT)
    print(f"wrote {rel} ({len(data)} bytes)")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
