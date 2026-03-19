///|
test "iterables flatten parity" {
  let tree : Array[Nested[Int]] = [
    nested_atom(1),
    nested_items([
      nested_atom(2),
      nested_items([nested_atom(3), nested_atom(4)]),
    ]),
  ]
  let ours = int_array_json(flatten(tree))
  let oracle = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.flatten([1, [2, [3, 4]]]))",
  )
  assert_eq(ours, oracle)
}

///|
test "iterables unflatten parity" {
  let ours = int_matrix_json(unflatten([0, 1, 2, 3], 2))
  let oracle = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.unflatten([0, 1, 2, 3], 2))",
  )
  assert_eq(ours, oracle)
}

///|
test "iterables subsets and variations parity" {
  let ours_subsets = int_matrix_json(subsets([1, 2, 3], k=2))
  let oracle_subsets = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.subsets([1, 2, 3], 2)])",
  )
  assert_eq(ours_subsets, oracle_subsets)

  let ours_variations = int_matrix_json(variations([1, 2, 3], n=2))
  let oracle_variations = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.variations([1, 2, 3], 2)])",
  )
  assert_eq(ours_variations, oracle_variations)

  let ours_permutations = int_matrix_json(permutations([1, 2, 3], size=2))
  let oracle_permutations = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.permutations([1, 2, 3], 2)])",
  )
  assert_eq(ours_permutations, oracle_permutations)
}

///|
test "iterables group parity" {
  let ours = group_result_int_json(group([1, 1, 2, 3, 3], multiple=false))
  let oracle = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.group([1, 1, 2, 3, 3], multiple=False))",
  )
  assert_eq(ours, oracle)
}

///|
test "iterables cartes prefixes postfixes parity" {
  let ours_cartes = int_matrix_json(cartes([[1, 2], [3], [4, 5]]))
  let oracle_cartes = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.cartes([1, 2], [3], [4, 5])])",
  )
  assert_eq(ours_cartes, oracle_cartes)

  let ours_prefixes = int_matrix_json(prefixes([1, 2, 3]))
  let oracle_prefixes = @sympy_utilities.utilities_eval_str(
    "json.dumps(list(sympy.utilities.iterables.prefixes([1, 2, 3])))",
  )
  assert_eq(ours_prefixes, oracle_prefixes)

  let ours_postfixes = int_matrix_json(postfixes([1, 2, 3]))
  let oracle_postfixes = @sympy_utilities.utilities_eval_str(
    "json.dumps(list(sympy.utilities.iterables.postfixes([1, 2, 3])))",
  )
  assert_eq(ours_postfixes, oracle_postfixes)
}

///|
test "iterables common prefix suffix uniq parity" {
  let ours_prefix = int_array_json(
    common_prefix([[1, 2, 3], [1, 2, 5], [1, 2]]),
  )
  let oracle_prefix = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.common_prefix([1, 2, 3], [1, 2, 5], [1, 2]))",
  )
  assert_eq(ours_prefix, oracle_prefix)

  let ours_suffix = int_array_json(
    common_suffix([[1, 2, 3], [9, 2, 3], [7, 2, 3]]),
  )
  let oracle_suffix = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.common_suffix([1, 2, 3], [9, 2, 3], [7, 2, 3]))",
  )
  assert_eq(ours_suffix, oracle_suffix)

  let ours_uniq = int_array_json(uniq([1, 2, 1, 3, 2]))
  let oracle_uniq = @sympy_utilities.utilities_eval_str(
    "json.dumps(list(sympy.utilities.iterables.uniq([1, 2, 1, 3, 2])))",
  )
  assert_eq(ours_uniq, oracle_uniq)

  let ours_multiset = int_count_map_json(multiset([3, 1, 3, 2, 1]))
  let oracle_multiset = @sympy_utilities.utilities_eval_str(
    "json.dumps(sorted(sympy.utilities.iterables.multiset([3, 1, 3, 2, 1]).items()))",
  )
  assert_eq(ours_multiset, oracle_multiset)
}

///|
test "iterables multiset combinations and permutations parity" {
  let ours_combinations = int_matrix_json(
    multiset_combinations([1, 1, 2, 3], 2),
  )
  let oracle_combinations = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.multiset_combinations([1, 1, 2, 3], 2)])",
  )
  assert_eq(ours_combinations, oracle_combinations)

  let ours_permutations = int_matrix_json(multiset_permutations([1, 1, 2]))
  let oracle_permutations = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.multiset_permutations([1, 1, 2])])",
  )
  assert_eq(ours_permutations, oracle_permutations)
}

///|
test "iterables rotations and topological sort parity" {
  let ours_rot = int_matrix_json(rotations([1, 2, 3], dir=-1))
  let oracle_rot = @sympy_utilities.utilities_eval_str(
    "json.dumps(list(sympy.utilities.iterables.rotations([1, 2, 3], -1)))",
  )
  assert_eq(ours_rot, oracle_rot)

  let ours_topo = "[\"" +
    topological_sort(["a", "b", "c", "d"], [("a", "b"), ("a", "c"), ("c", "d")]).join(
      "\", \"",
    ) +
    "\"]"
  let oracle_topo = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.topological_sort(([\"a\", \"b\", \"c\", \"d\"], [(\"a\", \"b\"), (\"a\", \"c\"), (\"c\", \"d\")])))",
  )
  assert_eq(ours_topo, oracle_topo)
}

///|
test "iterables graph helpers parity" {
  let ours_scc = int_matrix_json(
    strongly_connected_components([0, 1, 2, 3], [
      (0, 1),
      (1, 0),
      (1, 2),
      (2, 3),
      (3, 2),
    ]),
  )
  let oracle_scc = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.strongly_connected_components(([0, 1, 2, 3], [(0, 1), (1, 0), (1, 2), (2, 3), (3, 2)])))",
  )
  assert_eq(ours_scc, oracle_scc)

  let ours_cc = int_matrix_json(
    connected_components([0, 1, 2, 3], [(0, 1), (2, 3)]),
  )
  let oracle_cc = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.connected_components(([0, 1, 2, 3], [(0, 1), (2, 3)])))",
  )
  assert_eq(ours_cc, oracle_cc)
}

///|
test "iterables sequence partition and derangement parity" {
  let ours_plain = "[" +
    sequence_partitions([1, 2, 3, 4], 2).map(int_matrix_json).join(", ") +
    "]"
  let oracle_plain = @sympy_utilities.utilities_eval_str(
    "json.dumps([[list(piece) for piece in part] for part in sympy.utilities.iterables.sequence_partitions([1, 2, 3, 4], 2)])",
  )
  assert_eq(ours_plain, oracle_plain)

  let ours_empty = "[" +
    sequence_partitions_empty([1, 2, 3, 4], 2).map(int_matrix_json).join(", ") +
    "]"
  let oracle_empty = @sympy_utilities.utilities_eval_str(
    "json.dumps([[list(piece) for piece in part] for part in sympy.utilities.iterables.sequence_partitions_empty([1, 2, 3, 4], 2)])",
  )
  assert_eq(ours_empty, oracle_empty)

  let ours_derangements = int_matrix_json(generate_derangements([0, 1, 2]))
  let oracle_derangements = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.generate_derangements([0, 1, 2])])",
  )
  assert_eq(ours_derangements, oracle_derangements)
}

///|
test "iterables binary and signed permutation helpers parity" {
  let ours_ibin = int_array_json(ibin(2, bits=4))
  let oracle_ibin = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.ibin(2, 4))",
  )
  assert_eq(ours_ibin, oracle_ibin)

  let ours_all = int_matrix_json(ibin_all(2))
  let oracle_all = @sympy_utilities.utilities_eval_str(
    "json.dumps(list(sympy.utilities.iterables.ibin(2, 'all')))",
  )
  assert_eq(ours_all, oracle_all)

  let ours_str = ibin_str(2, bits=4)
  let oracle_str = @sympy_utilities.utilities_eval_str(
    "json.dumps(sympy.utilities.iterables.ibin(2, 4, str=True))",
  )
  assert_eq("\"" + ours_str + "\"", oracle_str)

  let ours_binary = int_matrix_json(binary_partitions(5))
  let oracle_binary = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(p) for p in sympy.utilities.iterables.binary_partitions(5)])",
  )
  assert_eq(ours_binary, oracle_binary)

  let ours_signs = int_matrix_json(permute_signs([0, 1, 2]))
  let oracle_signs = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.permute_signs((0, 1, 2))])",
  )
  assert_eq(ours_signs, oracle_signs)

  let ours_signed = int_matrix_json(signed_permutations([0, 1, 2]))
  let oracle_signed = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.signed_permutations((0, 1, 2))])",
  )
  assert_eq(ours_signed, oracle_signed)

  let ours_minlex = int_array_json(minlex([1, 0, 2, 0]))
  let oracle_minlex = @sympy_utilities.utilities_eval_str(
    "json.dumps(list(sympy.utilities.iterables.minlex((1, 0, 2, 0))))",
  )
  assert_eq(ours_minlex, oracle_minlex)

  let ours_necklaces = int_matrix_json(necklaces(4, 2))
  let oracle_necklaces = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.necklaces(4, 2)])",
  )
  assert_eq(ours_necklaces, oracle_necklaces)

  let ours_bracelets = int_matrix_json(bracelets(4, 3))
  let oracle_bracelets = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(x) for x in sympy.utilities.iterables.bracelets(4, 3)])",
  )
  assert_eq(ours_bracelets, oracle_bracelets)
}

///|
test "iterables partition helpers parity" {
  let ours_partitions = partition_result_array_json(partitions(4))
  let oracle_partitions = @sympy_utilities.utilities_eval_str(
    "json.dumps([sorted(p.items()) for p in sympy.utilities.iterables.partitions(4)])",
  )
  assert_eq(ours_partitions, oracle_partitions)

  let ours_sized = partition_result_array_json(
    partitions(5, m=Some(2), size=true),
  )
  let oracle_sized = @sympy_utilities.utilities_eval_str(
    "json.dumps([[size, sorted(p.items())] for size, p in sympy.utilities.iterables.partitions(5, m=2, size=True)])",
  )
  assert_eq(ours_sized, oracle_sized)

  let ours_ordered = int_matrix_json(ordered_partitions(5, m=Some(2)))
  let oracle_ordered = @sympy_utilities.utilities_eval_str(
    "json.dumps([list(p) for p in sympy.utilities.iterables.ordered_partitions(5, 2)])",
  )
  assert_eq(ours_ordered, oracle_ordered)
}

///|
test "iterables numbered symbols parity" {
  let gen = numbered_symbols(prefix="x", start=0, exclude=["x1"])
  let ours = [
    @symprint.to_string(gen.next()),
    @symprint.to_string(gen.next()),
    @symprint.to_string(gen.next()),
  ]
  let oracle = @sympy_utilities.utilities_eval_str(
    "json.dumps([str(next(g)) for _ in range(3)] if (g := sympy.utilities.iterables.numbered_symbols(prefix='x', start=0, exclude=[sympy.Symbol('x1')])) else [])",
  )
  inspect("[\"" + ours.join("\", \"") + "\"]", content=oracle)
}
