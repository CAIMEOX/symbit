///|
test "physics.quantum.tensorproduct: parity" {
  let m1 = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  let m2 = @symphysics.explicit_matrix_from_ints([[1, 0], [0, 1]])
  quantum_test_assert_matrix_expr_equal(
    tensor_product_matrix([m1, m2]),
    physics_eval_matrix(
      "TensorProduct(Matrix([[1, 2], [3, 4]]), Matrix([[1, 0], [0, 1]]))",
    ),
    4,
    4,
    "tensorproduct matrix parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        @symquant.tensor_product([
          @symcore.symbol("x") * operator([@symcore.symbol("A")]).as_expr(),
          @symcore.int(2) * operator([@symcore.symbol("B")]).as_expr(),
        ]).as_expr(),
      ),
    ),
    quantum_eval_str(
      "TensorProduct(x*Operator(A), 2*Operator(B))",
    ),
    "tensorproduct scalar normalization parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tensor_product_expand(
          @symquant.tensor_product([
            operator([@symcore.symbol("A")]).as_expr() +
            operator([@symcore.symbol("B")]).as_expr(),
            operator([@symcore.symbol("B")]).as_expr() +
            operator([@symcore.symbol("C")]).as_expr(),
          ]).as_expr(),
        ),
      ),
    ),
    quantum_eval_str(
      "TensorProduct(Operator(A) + Operator(B), Operator(B) + Operator(C)).expand(tensorproduct=True)",
    ),
    "tensorproduct additive expansion parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tensor_product_simp(
          @symcore.raw_mul([
            @symcore.symbol("x"),
            @symcore.raw_pow(
              @symquant.tensor_product([
                operator([@symcore.symbol("A")]).as_expr(),
                operator([@symcore.symbol("B")]).as_expr(),
              ]).as_expr(),
              @symcore.int(2),
            ),
            @symquant.tensor_product([
              operator([@symcore.symbol("C")]).as_expr(),
              operator([@symcore.symbol("D")]).as_expr(),
            ]).as_expr(),
          ]),
        ),
      ),
    ),
    quantum_eval_str(
      "tensor_product_simp(x*TensorProduct(Operator(A), Operator(B))**2*TensorProduct(Operator(C), Operator(D)))",
    ),
    "tensorproduct simp mul/pow parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tensor_product_simp(
          @symquant.tensor_product([
            operator([@symcore.symbol("A")]).as_expr(),
            operator([@symcore.symbol("B")]).as_expr(),
          ]).as_expr() -
          @symcore.raw_pow(
            @symquant.tensor_product([
              operator([@symcore.symbol("C")]).as_expr(),
              operator([@symcore.symbol("D")]).as_expr(),
            ]).as_expr(),
            @symcore.symbol("y"),
          ),
        ),
      ),
    ),
    quantum_eval_str(
      "TensorProduct(Operator(A), Operator(B)) - TensorProduct(Operator(C)**y, Operator(D)**y)",
    ),
    "tensorproduct simp add parity",
  )
}
