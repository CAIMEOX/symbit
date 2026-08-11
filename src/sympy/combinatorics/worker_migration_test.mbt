///|
test "combinatorics worker transports optional and nested data" {
  assert_true(perm_array_form_equiv_from_array([1, 0], [1, 0, 2, 3], size=4))
  let dummies = [2, 3, 4, 5]
  assert_true(
    tensor_can_dummy_sgs_equiv(dummies, None, 6, dummy_sgs(dummies, None, 6)),
  )
}

///|
test "combinatorics worker treats quoted strings as data" {
  let values = ["q'quoted", "line\nslash\\", "tail"]
  assert_true(
    perm_apply_array_equiv([1, 0, 2], values, [
      "line\nslash\\", "q'quoted", "tail",
    ]),
  )
}

///|
test "combinatorics worker recovers after rejected dynamic lookup" {
  let rejected = try {
    named_group_order_equiv("Missing'\\nGroup", 3, 0) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(gray_to_bin_equiv("100", gray_to_bin("100")))
}

///|
test "combinatorics worker rejects negative free-group indices and recovers" {
  let rejected = try {
    free_group_inverse_equiv(["x", "y"], [(-1, 1)], [(1, -1)]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(free_group_inverse_equiv(["x", "y"], [(0, 1)], [(0, -1)]))
}

///|
test "combinatorics worker rejects a missing next permutation and recovers" {
  let rejected = try {
    perm_next_lex_equiv([2, 1, 0], false, []) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(perm_next_lex_equiv([0, 1], true, [1, 0]))
}
