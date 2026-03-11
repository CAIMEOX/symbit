///|
test "physics.quantum.matrixutils: tensor product and scalar flattening" {
  let m1 = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  let id2 = matrix_eye(2)
  let kron = try! matrix_tensor_product([m1, id2])
  inspect(@symphysics.explicit_matrix_rows_string(kron), content="[[1, 0, 2, 0], [0, 1, 0, 2], [3, 0, 4, 0], [0, 3, 0, 4]]")

  let scalar = try! flatten_scalar(@symphysics.explicit_matrix_from_ints([[3]]))
  inspect(matrix_scalar_value_to_string(scalar), content="3")

  let zero_value = try! matrix_to_zero(matrix_zeros(2, 3))
  inspect(matrix_scalar_value_to_string(zero_value), content="0")
}
