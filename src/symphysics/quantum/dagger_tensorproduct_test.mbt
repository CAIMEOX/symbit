///|
test "physics.quantum.dagger: symbolic and matrix behaviors" {
  guard @symprint.to_string(dagger(@symcore.symbol("x"), evaluate=false)) ==
    "Dagger(x)" else {
    fail("unevaluated dagger")
  }
  guard @symprint.to_string(
      dagger(@symcore.raw_mul([@symcore.symbol("a"), @symcore.symbol("b")])),
    ) ==
    "conjugate(b)*conjugate(a)" else {
    fail("product dagger should reverse order")
  }

  let mat = try! @symphysics.explicit_matrix_from_rows([
    [@symcore.symbol("I"), @symcore.int(2) * @symcore.symbol("I")],
    [@symcore.int(0), @symcore.int(1)],
  ])
  try! quantum_test_assert_matrix_expr_equal(
    matrix_dagger(mat),
    ["-I", "0", "-2*I", "1"],
    2,
    2,
    "matrix dagger",
  )
}

///|
test "physics.quantum.tensorproduct: symbolic wrapper and matrix behavior" {
  let tp = tensor_product([
    @symcore.symbol("a") + @symcore.symbol("b"),
    @symcore.symbol("c"),
  ])
  guard tp.to_string() == "(a + b)xc" else {
    fail("tensor-product string form")
  }
  guard tp.dagger().to_string() == "(conjugate(a) + conjugate(b))xconjugate(c)" else {
    fail("tensor-product dagger")
  }

  let sigma_x = try! @symphysics.msigma(1)
  try! quantum_test_assert_matrix_equal(
    try! tensor_product_matrix([sigma_x, matrix_eye(2)]),
    [
      "0", "0", "1", "0", "0", "0", "0", "1", "1", "0", "0", "0", "0", "1", "0",
      "0",
    ],
    4,
    4,
    "tensor-product matrix",
  )
}
