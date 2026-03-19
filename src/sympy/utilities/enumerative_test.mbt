///|
/// Behavior tests for multiset-partition enumeration.

///|
fn letters_for(n : Int) -> Array[String] {
  let letters = [
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
    "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
  ]
  let out : Array[String] = []
  for i in 0..<n {
    out.push(letters[i])
  }
  out
}

///|
fn states_to_string_partitions(
  states : Array[MultisetPartitionState],
  components : Array[String],
) -> Array[Array[Array[String]]] {
  states.map(state => list_visitor(state, components))
}

///|
test "enumerative list and factoring visitors" {
  let states = multiset_partitions_taocp([1, 2, 1])
  inspect(
    string_matrix_json(list_visitor(states[0], ["a", "b", "c"])),
    content="[[\"a\", \"b\", \"b\", \"c\"]]",
  )
  inspect(
    string_matrix_json(list_visitor(states[1], ["1", "2", "3"])),
    content="[[\"1\", \"2\", \"2\"], [\"3\"]]",
  )

  let factor_states = multiset_partitions_taocp([3, 1])
  inspect(
    int_matrix_json(
      factor_states.map(state => factoring_visitor(state, [2, 3])),
    ),
    content="[[24], [8, 3], [12, 2], [4, 6], [4, 2, 3], [6, 2, 2], [2, 2, 2, 3]]",
  )
}

///|
test "enumerative traverser versions agree" {
  let mult = [5, 2, 2, 1]
  let traverser = MultisetPartitionTraverser::new()
  let enum_all_states = traverser.enum_all(mult)
  let taocp_states = multiset_partitions_taocp(mult)
  assert_eq(enum_all_states, taocp_states)
}

///|
test "enumerative constrained traversals" {
  let traverser = MultisetPartitionTraverser::new()
  let components = ["a", "b"]
  inspect(
    string_tensor3_json(
      states_to_string_partitions(traverser.enum_small([2, 2], 2), components),
    ),
    content="[[[\"a\", \"a\", \"b\", \"b\"]], [[\"a\", \"a\", \"b\"], [\"b\"]], [[\"a\", \"a\"], [\"b\", \"b\"]], [[\"a\", \"b\", \"b\"], [\"a\"]], [[\"a\", \"b\"], [\"a\", \"b\"]]]",
  )
  inspect(
    string_tensor3_json(
      states_to_string_partitions(traverser.enum_large([2, 2], 2), components),
    ),
    content="[[[\"a\", \"a\"], [\"b\"], [\"b\"]], [[\"a\", \"b\"], [\"a\"], [\"b\"]], [[\"a\"], [\"a\"], [\"b\", \"b\"]], [[\"a\"], [\"a\"], [\"b\"], [\"b\"]]]",
  )
  inspect(
    string_tensor3_json(
      states_to_string_partitions(
        traverser.enum_range([2, 2], 1, 2),
        components,
      ),
    ),
    content="[[[\"a\", \"a\", \"b\"], [\"b\"]], [[\"a\", \"a\"], [\"b\", \"b\"]], [[\"a\", \"b\", \"b\"], [\"a\"]], [[\"a\", \"b\"], [\"a\", \"b\"]]]",
  )
}

///|
test "enumerative counts match slow path" {
  let traverser = MultisetPartitionTraverser::new()
  assert_eq(traverser.count_partitions([2, 2]), 9)
  assert_eq(traverser.count_partitions([3, 3, 3]), 686)
  assert_eq(traverser.count_partitions([4, 4, 4, 2]), 127750)
  assert_eq(traverser.count_partitions_slow([4, 4, 2, 1]), 6033)
  assert_eq(
    traverser.count_partitions([4, 4, 2, 1]),
    traverser.count_partitions_slow([4, 4, 2, 1]),
  )
}

///|
test "enumerative range versions agree on subranges" {
  let mult = [6, 3, 2, 1]
  let lb = 4
  let ub = 7
  let traverser_a = MultisetPartitionTraverser::new()
  let traverser_b = MultisetPartitionTraverser::new()
  let traverser_c = MultisetPartitionTraverser::new()
  let range_states = traverser_a.enum_range(mult, lb, ub)
  let small_filtered = traverser_b
    .enum_small(mult, ub)
    .filter(state => state.lpart >= lb)
  let large_filtered = traverser_c
    .enum_large(mult, lb)
    .filter(state => state.lpart < ub)
  assert_eq(range_states, small_filtered)
  assert_eq(range_states, large_filtered)
}
