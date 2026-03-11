///|
test "physics.quantum.tensorproduct: parity" {
  let m1 = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  let m2 = @symphysics.explicit_matrix_from_ints([[1, 0], [0, 1]])
  try! quantum_test_assert_matrix_expr_equal(
    try! tensor_product_matrix([m1, m2]),
    try! @sympy_physics.physics_eval_matrix(
      "TensorProduct(Matrix([[1, 2], [3, 4]]), Matrix([[1, 0], [0, 1]]))",
    ),
    4,
    4,
    "tensorproduct matrix parity",
  )
}
