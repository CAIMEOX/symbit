///|
test "physics.quantum.represent: gate powers, (anti)commutators, and outer products" {
  inspect(
    matrix_scalar_value_to_string(
      represent(x_gate(0).as_expr() ^ @symcore.int(2), nqubits=1),
    ),
    content="1",
  )
  inspect(
    matrix_scalar_value_to_string(
      represent(
        @symcore.raw_mul([x_gate(0).as_expr(), x_gate(0).as_expr()]),
        nqubits=1,
      ),
    ),
    content="1",
  )

  let phase2 = represent(phase_gate(0).as_expr() ^ @symcore.int(2), nqubits=1)
  match phase2 {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        ["1", "0", "0", "-1"],
        2,
        2,
        "represent phase square",
      )
    _ => fail("represent phase square should be a matrix")
  }

  let comm = represent(
    commutator(sigma_x().as_expr(), sigma_y().as_expr(), evaluate=false),
  )
  match comm {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        ["2*I", "0", "0", "-2*I"],
        2,
        2,
        "represent commutator",
      )
    _ => fail("represent commutator should be a matrix")
  }

  let anti = represent(
    anticommutator(sigma_x().as_expr(), sigma_y().as_expr(), evaluate=false),
  )
  match anti {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        ["0", "0", "0", "0"],
        2,
        2,
        "represent anticommutator",
      )
    _ => fail("represent anticommutator should be a matrix")
  }

  let outer = represent(
    outer_product(qubit("0").as_expr(), qubit_bra("1").as_expr()),
    nqubits=1,
  )
  match outer {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        ["0", "1", "0", "0"],
        2,
        2,
        "represent qubit outer product",
      )
    _ => fail("represent qubit outer product should be a matrix")
  }
}
