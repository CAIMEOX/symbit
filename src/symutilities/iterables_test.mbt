///|
test "iterables flatten behavior" {
  let tree : Array[Nested[Int]] = [
    nested_atom(1),
    nested_items([
      nested_atom(2),
      nested_items([nested_atom(3), nested_atom(4)]),
    ]),
  ]
  assert_eq(try! flatten(tree), [1, 2, 3, 4])
  assert_eq(try! flatten(tree, levels=1), [1, 2, 3, 4])
}

///|
test "iterables reshape and unflatten behavior" {
  assert_eq(unflatten([1, 2, 3, 4], 2), [[1, 2], [3, 4]])
  let shape = [shape_take(2), shape_group([shape_take(1), shape_take(1)])]
  let reshaped = reshape([1, 2, 3, 4, 5, 6, 7, 8], shape)
  inspect(
    nested_int_array_json(reshaped),
    content="[[[1, 2], [[3], [4]]], [[5, 6], [[7], [8]]]]",
  )
}

///|
test "iterables group and combinations behavior" {
  inspect(
    group_result_int_json(group([1, 1, 2, 3, 3])),
    content="[[1, 1], [2], [3, 3]]",
  )
  inspect(
    group_result_int_json(group([1, 1, 2, 3, 3], multiple=false)),
    content="[[1, 2], [2, 1], [3, 2]]",
  )
  inspect(
    int_matrix_json(subsets([1, 2, 3], k=2)),
    content="[[1, 2], [1, 3], [2, 3]]",
  )
  inspect(
    int_matrix_json(variations([1, 2, 3], n=2)),
    content="[[1, 2], [1, 3], [2, 1], [2, 3], [3, 1], [3, 2]]",
  )
  inspect(
    int_matrix_json(permutations([1, 2, 3], size=2)),
    content="[[1, 2], [1, 3], [2, 1], [2, 3], [3, 1], [3, 2]]",
  )
  inspect(
    int_count_map_json(multiset([3, 1, 3, 2, 1])),
    content="[[1, 2], [2, 1], [3, 2]]",
  )
  inspect(
    int_matrix_json(multiset_combinations([1, 1, 2, 3], 2)),
    content="[[1, 1], [1, 2], [1, 3], [2, 3]]",
  )
  inspect(
    int_matrix_json(multiset_permutations([1, 1, 2])),
    content="[[1, 1, 2], [1, 2, 1], [2, 1, 1]]",
  )
}

///|
test "iterables support helpers behavior" {
  assert_eq(cartes([[1, 2], [3], [4, 5]]), [
    [1, 3, 4],
    [1, 3, 5],
    [2, 3, 4],
    [2, 3, 5],
  ])
  assert_eq(prefixes([1, 2, 3]), [[1], [1, 2], [1, 2, 3]])
  assert_eq(postfixes([1, 2, 3]), [[3], [2, 3], [1, 2, 3]])
  assert_eq(common_prefix([[1, 2, 3], [1, 2, 5], [1, 2]]), [1, 2])
  assert_eq(common_suffix([[1, 2, 3], [9, 2, 3], [7, 2, 3]]), [2, 3])
  assert_eq(uniq([1, 2, 1, 3, 2]), [1, 2, 3])
  assert_true(has_dups([1, 2, 1]))
  assert_false(has_dups([1, 2, 3]))
  assert_true(has_variety([1, 2, 1]))
  assert_false(has_variety([1, 1, 1]))
  assert_eq(rotate_left([1, 2, 3], 1), [2, 3, 1])
  assert_eq(rotate_right([1, 2, 3], 1), [3, 1, 2])
  assert_eq(least_rotation([3, 1, 5, 1, 2]), 3)
}

///|
test "iterables topological sort and capture behavior" {
  let sorted = topological_sort(["a", "b", "c", "d"], [
    ("a", "b"),
    ("a", "c"),
    ("c", "d"),
  ])
  assert_eq(sorted, ["a", "b", "c", "d"])
  let log = capture(write => {
    write("hello")
    write(" world")
  })
  assert_eq(log, "hello world")
}

///|
test "iterables graph and run helpers behavior" {
  inspect(
    int_matrix_json(
      strongly_connected_components([0, 1, 2, 3], [
        (0, 1),
        (1, 0),
        (1, 2),
        (2, 3),
        (3, 2),
      ]),
    ),
    content="[[2, 3], [0, 1]]",
  )
  inspect(
    int_matrix_json(connected_components([0, 1, 2, 3], [(0, 1), (2, 3)])),
    content="[[0, 1], [2, 3]]",
  )
  inspect(
    int_matrix_json(runs([0, 1, 2, 2, 1, 4, 3, 2, 2])),
    content="[[0, 1, 2], [2], [1, 4], [3], [2], [2]]",
  )
}

///|
test "iterables sequence partition and derangement helpers behavior" {
  let plain = "[" +
    sequence_partitions([1, 2, 3, 4], 2).map(int_matrix_json).join(", ") +
    "]"
  inspect(
    plain,
    content="[[[1], [2, 3, 4]], [[1, 2], [3, 4]], [[1, 2, 3], [4]]]",
  )
  let with_empty = "[" +
    sequence_partitions_empty([1, 2, 3, 4], 2).map(int_matrix_json).join(", ") +
    "]"
  inspect(
    with_empty,
    content="[[[], [1, 2, 3, 4]], [[1], [2, 3, 4]], [[1, 2], [3, 4]], [[1, 2, 3], [4]], [[1, 2, 3, 4], []]]",
  )
  inspect(
    int_matrix_json(generate_derangements([0, 1, 2])),
    content="[[1, 2, 0], [2, 0, 1]]",
  )
}

///|
test "iterables binary and signed permutation helpers behavior" {
  inspect(int_array_json(ibin(2)), content="[1, 0]")
  inspect(int_array_json(ibin(2, bits=4)), content="[0, 0, 1, 0]")
  inspect(
    int_matrix_json(ibin_all(2)),
    content="[[0, 0], [0, 1], [1, 0], [1, 1]]",
  )
  inspect(ibin_str(2, bits=4), content="0010")
  inspect(
    "[\"" + ibin_all_str(2).join("\", \"") + "\"]",
    content="[\"00\", \"01\", \"10\", \"11\"]",
  )
  inspect(
    int_matrix_json(binary_partitions(5)),
    content="[[4, 1], [2, 2, 1], [2, 1, 1, 1], [1, 1, 1, 1, 1]]",
  )
  inspect(
    int_matrix_json(permute_signs([0, 1, 2])),
    content="[[0, 1, 2], [0, -1, 2], [0, 1, -2], [0, -1, -2]]",
  )
  inspect(
    int_matrix_json(signed_permutations([0, 1, 2])),
    content="[[0, 1, 2], [0, -1, 2], [0, 1, -2], [0, -1, -2], [0, 2, 1], [0, -2, 1], [0, 2, -1], [0, -2, -1], [1, 0, 2], [-1, 0, 2], [1, 0, -2], [-1, 0, -2], [1, 2, 0], [-1, 2, 0], [1, -2, 0], [-1, -2, 0], [2, 0, 1], [-2, 0, 1], [2, 0, -1], [-2, 0, -1], [2, 1, 0], [-2, 1, 0], [2, -1, 0], [-2, -1, 0]]",
  )
  inspect(int_array_json(minlex([1, 0, 2, 0])), content="[0, 1, 0, 2]")
  inspect(
    int_matrix_json(necklaces(4, 2)),
    content="[[0, 0, 0, 0], [0, 0, 0, 1], [0, 0, 1, 1], [0, 1, 0, 1], [0, 1, 1, 1], [1, 1, 1, 1]]",
  )
  inspect(
    int_matrix_json(bracelets(4, 3)),
    content="[[0, 0, 0, 0], [0, 0, 0, 1], [0, 0, 0, 2], [0, 0, 1, 1], [0, 0, 1, 2], [0, 0, 2, 2], [0, 1, 0, 1], [0, 1, 0, 2], [0, 1, 1, 1], [0, 1, 1, 2], [0, 1, 2, 1], [0, 1, 2, 2], [0, 2, 0, 2], [0, 2, 1, 2], [0, 2, 2, 2], [1, 1, 1, 1], [1, 1, 1, 2], [1, 1, 2, 2], [1, 2, 1, 2], [1, 2, 2, 2], [2, 2, 2, 2]]",
  )
}

///|
test "iterables partition helpers behavior" {
  inspect(
    partition_result_array_json(partitions(4)),
    content="[[[4, 1]], [[1, 1], [3, 1]], [[2, 2]], [[1, 2], [2, 1]], [[1, 4]]]",
  )
  inspect(
    partition_result_array_json(partitions(5, m=Some(2), size=true)),
    content="[[1, [[5, 1]]], [2, [[1, 1], [4, 1]]], [2, [[2, 1], [3, 1]]]]",
  )
  inspect(
    int_matrix_json(ordered_partitions(5, m=Some(2))),
    content="[[1, 4], [2, 3]]",
  )
}

///|
test "iterables numbered symbols and take behavior" {
  let gen = numbered_symbols(prefix="t", start=1, exclude=["t2"])
  assert_eq(@symprint.to_string(gen.next()), "t1")
  assert_eq(@symprint.to_string(gen.next()), "t3")
  assert_eq(@symprint.to_string(gen.next()), "t4")
  assert_eq(take([1, 2, 3, 4].iter(), 3), [1, 2, 3])
}

///|
test "iterables sift behavior" {
  let buckets = sift([1, 2, 3, 4, 5], x => x % 2)
  assert_eq(buckets[0], [2, 4])
  assert_eq(buckets[1], [1, 3, 5])
  assert_eq(sift_binary([1, 2, 3, 4], x => x % 2 == 1), ([1, 3], [2, 4]))
}
