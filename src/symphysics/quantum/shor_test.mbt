///|
test "physics.quantum.shor: local helper arithmetic" {
  assert_eq(ratioize([1, 2, 3], 15), 6)
  assert_eq(ratioize([20, 1], 15), 0)
  assert_eq(getr(1, 4, 15), 4)
  assert_eq(getr(3, 8, 15), 5)
}

///|
test "physics.quantum.shor: local period finding and factoring" {
  assert_eq(period_find(2, 15), 4)
  assert_eq(@symprint.to_string(shor(15)), "Tuple(3, 5)")
}

///|
test "physics.quantum.shor: local CMod qapply and represent" {
  let op = cmod(2, 2, 3)
  let input = qubit("0100").as_expr()
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([op, input])),
    "Qubit(0, 1, 1, 0)",
    "cmod qapply",
  )

  let matrix = represent_matrix(op, nqubits=4)
  assert_true(matrix.height() == 16 && matrix.width() == 16)
  for col in 0..<16 {
    let basis = qubit_from_bits(int_qubit(col, 4).bits).as_expr()
    let expected = qubit_to_matrix(
      qapply(@symcore.raw_mul([op, basis])),
      nqubits=4,
    )
    for row in 0..<16 {
      assert_true(matrix.get(row, col) == expected.get(row, 0))
    }
  }
}
