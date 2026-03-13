///|
test "physics.quantum.tensorproduct: symbolic and matrix subset" {
  let a = @symcore.symbol("A")
  let b = @symcore.symbol("B")
  let c = @symcore.symbol("C")
  inspect(tensor_product([a, b]).to_string(), content="AxB")
  inspect(tensor_product([a + b, c]).to_string(), content="(A + B)xC")
  inspect(
    tensor_product([a, b]).dagger().to_string(),
    content="conjugate(A)xconjugate(B)",
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
