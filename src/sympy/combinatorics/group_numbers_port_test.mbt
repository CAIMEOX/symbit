///|
test "combinatorics group_numbers nilpotent/abelian/cyclic parity" {
  let n1 = 21
  assert_true(group_numbers_is_nilpotent_equiv(n1, is_nilpotent_number(n1)))
  assert_true(group_numbers_is_abelian_equiv(n1, is_abelian_number(n1)))
  assert_true(group_numbers_is_cyclic_equiv(n1, is_cyclic_number(n1)))
  let n2 = 27
  assert_true(group_numbers_is_nilpotent_equiv(n2, is_nilpotent_number(n2)))
  assert_true(group_numbers_is_abelian_equiv(n2, is_abelian_number(n2)))
  assert_true(group_numbers_is_cyclic_equiv(n2, is_cyclic_number(n2)))
}

///|
test "combinatorics group_numbers groups_count parity" {
  let nvals : Array[Int] = [1, 3, 10, 12, 52]
  for n in nvals {
    let res : Result[BigInt, Error] = try groups_count(n) |> Ok catch {
      error => Err(error)
    }
    match res {
      Ok(v) =>
        assert_true(group_numbers_groups_count_equiv(n, true, v.to_string()))
      Err(_) => assert_true(group_numbers_groups_count_equiv(n, false, "0"))
    }
  }
  expect_error(fn() raise { groups_count(99) })
}
