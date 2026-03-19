///|
/// Oracle parity tests for multiset-partition enumeration.

///|
fn enumerative_states_expr(
  method_expr : String,
  components : Array[String],
) -> String {
  let comps = string_array_json(components)
  let prefix = "json.dumps([[[str(item) for item in part] for part in sympy.utilities.enumerative.list_visitor(state, "
  prefix + comps + ")] for state in " + method_expr + "])"
}

///|
test "enumerative taocp parity" {
  let mult = [4, 3, 1]
  let components = letters_for(mult.length())
  let ours = string_tensor3_json(
    states_to_string_partitions(multiset_partitions_taocp(mult), components),
  )
  let oracle = utilities_eval_str(
    enumerative_states_expr(
      "sympy.utilities.enumerative.multiset_partitions_taocp(" +
      int_array_json(mult) +
      ")",
      components,
    ),
  )
  assert_eq(ours, oracle)
}

///|
test "enumerative constrained parity" {
  let mult = [4, 4, 2, 1]
  let components = letters_for(mult.length())
  let traverser = MultisetPartitionTraverser::new()

  let ours_small = string_tensor3_json(
    states_to_string_partitions(traverser.enum_small(mult, 2), components),
  )
  let oracle_small = utilities_eval_str(
    enumerative_states_expr(
      "sympy.utilities.enumerative.MultisetPartitionTraverser().enum_small(" +
      int_array_json(mult) +
      ", 2)",
      components,
    ),
  )
  assert_eq(ours_small, oracle_small)

  let ours_range = string_tensor3_json(
    states_to_string_partitions(traverser.enum_range(mult, 1, 2), components),
  )
  let oracle_range = utilities_eval_str(
    enumerative_states_expr(
      "sympy.utilities.enumerative.MultisetPartitionTraverser().enum_range(" +
      int_array_json(mult) +
      ", 1, 2)",
      components,
    ),
  )
  assert_eq(ours_range, oracle_range)
}

///|
test "enumerative counting parity" {
  let ours = MultisetPartitionTraverser::new()
    .count_partitions([9, 8, 2])
    .to_string()
  let oracle = utilities_eval_str(
    "str(sympy.utilities.enumerative.MultisetPartitionTraverser().count_partitions([9, 8, 2]))",
  )
  assert_eq(ours, oracle)
}
