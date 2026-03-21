///|
test "physics.quantum.represent: parity for gate powers, (anti)commutators, and outer products" {
  inspect(
    matrix_scalar_value_to_string(
      represent(x_gate(0).as_expr() ^ @symcore.int(2), nqubits=1),
    ),
    content=physics_eval_str("represent(XGate(0)**2, nqubits=1)"),
  )
  inspect(
    matrix_scalar_value_to_string(
      represent(
        @symcore.raw_mul([x_gate(0).as_expr(), x_gate(0).as_expr()]),
        nqubits=1,
      ),
    ),
    content=physics_eval_str("represent(XGate(0)*XGate(0), nqubits=1)"),
  )

  let phase2 = represent(phase_gate(0).as_expr() ^ @symcore.int(2), nqubits=1)
  match phase2 {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        physics_eval_matrix("represent(PhaseGate(0)**2, nqubits=1)"),
        2,
        2,
        "represent phase square parity",
      )
    _ => fail("represent phase square parity should be a matrix")
  }

  let comm = represent(
    commutator(sigma_x().as_expr(), sigma_y().as_expr(), evaluate=false),
  )
  match comm {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        physics_eval_matrix("represent(Commutator(SigmaX(), SigmaY()))"),
        2,
        2,
        "represent commutator parity",
      )
    _ => fail("represent commutator parity should be a matrix")
  }

  let anti = represent(
    anticommutator(sigma_x().as_expr(), sigma_y().as_expr(), evaluate=false),
  )
  match anti {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        physics_eval_matrix("represent(AntiCommutator(SigmaX(), SigmaY()))"),
        2,
        2,
        "represent anticommutator parity",
      )
    _ => fail("represent anticommutator parity should be a matrix")
  }

  let outer = represent(
    outer_product(qubit("0").as_expr(), qubit_bra("1").as_expr()),
    nqubits=1,
  )
  match outer {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        physics_eval_matrix(
          "represent(OuterProduct(Qubit(0), QubitBra(1)), nqubits=1)",
        ),
        2,
        2,
        "represent qubit outer product parity",
      )
    _ => fail("represent qubit outer product parity should be a matrix")
  }
}
