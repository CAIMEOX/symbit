///|
test "physics.quantum.tensorproduct: symbolic and matrix subset" {
  let a = operator([@symcore.symbol("A")]).as_expr()
  let b = operator([@symcore.symbol("B")]).as_expr()
  let c = operator([@symcore.symbol("C")]).as_expr()
  inspect(tensor_product([a, b]).to_string(), content="Operator(A)xOperator(B)")
  inspect(
    tensor_product([a + b, c]).to_string(),
    content="(Operator(A) + Operator(B))xOperator(C)",
  )
  inspect(
    tensor_product([a, b]).dagger().to_string(),
    content="Dagger(A)xDagger(B)",
  )
  try! quantum_test_assert_expr_equal(
    tensor_product([@symcore.symbol("x") * a, @symcore.int(2) * b]).as_expr(),
    "2*x*TensorProduct(Operator(A), Operator(B))",
    "tensorproduct scalar normalization",
  )
  try! quantum_test_assert_expr_equal(
    tensor_product_expand(tensor_product([a + b, b + c]).as_expr()),
    "TensorProduct(Operator(A), Operator(B)) + TensorProduct(Operator(A), Operator(C)) + TensorProduct(Operator(B), Operator(B)) + TensorProduct(Operator(B), Operator(C))",
    "tensorproduct additive expansion",
  )
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  try! quantum_test_assert_expr_equal(
    tensor_product_simp(
      @symcore.raw_mul([
        @symcore.raw_pow(tensor_product([a, b]).as_expr(), @symcore.int(2)),
        tensor_product([c, operator([@symcore.symbol("D")]).as_expr()]).as_expr(),
        x,
      ]),
    ),
    "x*TensorProduct(Operator(A)**2*Operator(C), Operator(B)**2*Operator(D))",
    "tensorproduct multiplicative simplification",
  )
  try! quantum_test_assert_expr_equal(
    tensor_product_simp(
      tensor_product([a, b]).as_expr() -
      @symcore.raw_pow(
        tensor_product([c, operator([y]).as_expr()]).as_expr(),
        y,
      ),
    ),
    "TensorProduct(Operator(A), Operator(B)) - TensorProduct(Operator(C)**y, Operator(y)**y)",
    "tensorproduct additive simp recursion",
  )

  let m1 = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  let m2 = @symphysics.explicit_matrix_from_ints([[1, 0], [0, 1]])
  inspect(
    @symphysics.explicit_matrix_rows_string(
      try! tensor_product_matrix([m1, m2]),
    ),
    content="[[1, 0, 2, 0], [0, 1, 0, 2], [3, 0, 4, 0], [0, 3, 0, 4]]",
  )
}

///|
test "physics.quantum.tensorproduct: density and trace interplay" {
  let a = operator([@symcore.symbol("A")]).as_expr()
  let b = operator([@symcore.symbol("B")]).as_expr()
  let c = operator([@symcore.symbol("C")]).as_expr()
  let tp = tensor_product([a, b, c]).as_expr()
  let rho = density([(tp, @symcore.int(1))])

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(rho.doit())),
    try! @sympy_physics.quantum_eval_str(
      "Density((TensorProduct(Operator(A), Operator(B), Operator(C)), 1)).doit()",
    ),
    "tensorproduct density doit",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(tr_doit(tr(rho.as_expr(), indices=[1]))),
    ),
    try! @sympy_physics.quantum_eval_str(
      "Tr(Density((TensorProduct(Operator(A), Operator(B), Operator(C)), 1)), (1,)).doit()",
    ),
    "tensorproduct density partial trace",
  )
}
