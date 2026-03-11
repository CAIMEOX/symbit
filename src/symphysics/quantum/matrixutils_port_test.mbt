///|
test "physics.quantum.matrixutils: parity" {
  let m1 = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  let id2 = matrix_eye(2)
  try! quantum_test_assert_array_equal(
    try! matrix_flat_strings(try! matrix_tensor_product([m1, id2])),
    try! @sympy_physics.physics_eval_matrix(
      "matrix_tensor_product(Matrix([[1, 2], [3, 4]]), Matrix([[1, 0], [0, 1]]))",
    ),
    "matrix_tensor_product parity",
  )

  guard matrix_scalar_value_to_string(try! flatten_scalar(@symphysics.explicit_matrix_from_ints([[3]]))) ==
    (try! @sympy_physics.physics_eval_str("flatten_scalar(Matrix([[3]]))")) else {
    fail("flatten_scalar parity")
  }
  guard matrix_scalar_value_to_string(try! matrix_to_zero(matrix_zeros(2, 2))) ==
    (try! @sympy_physics.physics_eval_str("matrix_to_zero(zeros(2, 2))")) else {
    fail("matrix_to_zero parity")
  }
}
