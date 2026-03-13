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

  let m1 = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  let m2 = @symphysics.explicit_matrix_from_ints([[1, 0], [0, 1]])
  inspect(
    @symphysics.explicit_matrix_rows_string(
      try! tensor_product_matrix([m1, m2]),
    ),
    content="[[1, 0, 2, 0], [0, 1, 0, 2], [3, 0, 4, 0], [0, 3, 0, 4]]",
  )
}
