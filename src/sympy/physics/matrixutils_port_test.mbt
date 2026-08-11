///|
test "physics.quantum.matrixutils: parity" {
  let m1 = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  let id2 = matrix_eye(2)
  quantum_test_assert_array_equal(
    matrix_flat_strings(matrix_tensor_product([m1, id2])),
    physics_eval_matrix(
      "matrix_tensor_product(Matrix([[1, 2], [3, 4]]), Matrix([[1, 0], [0, 1]]))",
    ),
    "matrix_tensor_product parity",
  )

  assert_eq(
    Show::to_string(
      flatten_scalar(@symphysics.explicit_matrix_from_ints([[3]])),
    ),
    physics_eval_str("flatten_scalar(Matrix([[3]]))"),
  )
  assert_eq(
    Show::to_string(matrix_to_zero(matrix_zeros(2, 2))),
    physics_eval_str("matrix_to_zero(zeros(2, 2))"),
  )
}
