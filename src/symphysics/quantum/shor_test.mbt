///|
test "physics.quantum.shor: local helper arithmetic" {
  guard ratioize([1, 2, 3], 15) == 6 else { fail("ratioize basic") }
  guard ratioize([20, 1], 15) == 0 else { fail("ratioize cutoff") }
  guard (try! getr(1, 4, 15)) == 4 else { fail("getr quarter") }
  guard (try! getr(3, 8, 15)) == 5 else { fail("getr three eighths") }
}

///|
test "physics.quantum.shor: local period finding and factoring" {
  guard (try! period_find(2, 15)) == 4 else { fail("period_find(2, 15)") }
  guard @symprint.to_string(try! shor(15)) == "Tuple(3, 5)" else {
    fail("shor(15)")
  }
}

///|
test "physics.quantum.shor: local CMod qapply and represent" {
  let op = try! cmod(2, 2, 3)
  let input = (try! qubit("0100")).as_expr()
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([op, input])),
    "Qubit(0, 1, 1, 0)",
    "cmod qapply",
  )

  let matrix = try! represent_matrix(op, nqubits=4)
  guard matrix.height() == 16 && matrix.width() == 16 else {
    fail("cmod matrix shape")
  }
  for col in 0..<16 {
    let basis = (try! qubit_from_bits((try! int_qubit(col, 4)).bits)).as_expr()
    let expected = try! qubit_to_matrix(
      qapply(@symcore.raw_mul([op, basis])),
      nqubits=4,
    )
    for row in 0..<16 {
      guard matrix.get(row, col) == expected.get(row, 0) else {
        fail("cmod matrix column \{col} row \{row}")
      }
    }
  }
}
