namespace py golden_example_thrift

struct Inner {
  1: i32 id
  2: string name
}

struct UserProfile {
  1: string name
  2: i32 user_id
  3: bool is_active
  4: i64 reputation
}

struct Complex {
  1: map<i32, list<Inner>> map_list_struct
  2: list<map<string, set<i32>>> list_map_set
  3: i32 i32_edge
  4: i64 i64_edge
  5: bool flag
}

struct BoolList {
  1: list<bool> values
}