///|
test "physics.quantum.qapply: parity extensions" {
  let zero = qubit("0").as_expr()
  let one = qubit("1").as_expr()
  let zero_bra = qubit_bra("0").as_expr()
  let half = @symcore.rational_from_ints(1, 2)
  let n = @symcore.Expr::Symbol("n")

  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "TensorProduct(XGate(0), IdentityGate(0))*TensorProduct(Qubit(0), Qubit(1))",
    ),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(
          @symcore.raw_mul([
            @symquant.tensor_product([
              x_gate(0).as_expr(),
              identity_gate(0).as_expr(),
            ]).as_expr(),
            @symquant.tensor_product([zero, one]).as_expr(),
          ]),
        ),
      ),
    ),
    "tensor-product pair qapply parity",
  )

  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "TensorProduct(XGate(0)*Qubit(0), IdentityGate(0)*Qubit(1))",
    ),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(
          @symquant.tensor_product([
            @symcore.raw_mul([x_gate(0).as_expr(), zero]),
            @symcore.raw_mul([identity_gate(0).as_expr(), one]),
          ]).as_expr(),
        ),
      ),
    ),
    "tensor-product raw qapply parity",
  )

  quantum_test_assert_string_equal(
    quantum_qapply_str("Density((XGate(0)*Qubit(0), Rational(1, 2)))"),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(
          density([(@symcore.raw_mul([x_gate(0).as_expr(), zero]), half)]).as_expr(),
        ),
      ),
    ),
    "density qapply parity",
  )

  quantum_test_assert_string_equal(
    quantum_qapply_str("XGate(0)**2*Qubit(0)"),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(@symcore.raw_mul([x_gate(0).as_expr() ^ @symcore.int(2), zero])),
      ),
    ),
    "power qapply parity",
  )

  quantum_test_assert_string_equal(
    quantum_qapply_str("QubitBra(0)*XGate(0)", dagger=true),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(@symcore.raw_mul([zero_bra, x_gate(0).as_expr()]), dagger=true),
      ),
    ),
    "dagger qapply parity",
  )

  quantum_test_assert_string_equal(
    quantum_qapply_str("Sum(XGate(0)*Qubit(0), (n, 0, 2))"),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(
          @symcore.raw_function("Sum", [
            @symcore.raw_mul([x_gate(0).as_expr(), zero]),
            @symcore.raw_function("Tuple", [n, @symcore.int(0), @symcore.int(2)]),
          ]),
        ),
      ),
    ),
    "sum-body qapply parity",
  )
}

///|
test "physics.quantum.qapply: spin and (anti)commutator parity" {
  let one = @symcore.int(1)
  let zero_state = qubit("0").as_expr()

  quantum_test_assert_string_equal(
    quantum_qapply_srepr("Jx*JzKet(1, 0)"),
    quantum_qapply_srepr(
      @symprint.pretty_string(
        qapply(@symcore.raw_mul([jx(), jz_ket(one, @symcore.int(0)).as_expr()])),
      ),
    ),
    "Jx qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_srepr("Jminus*Jminus*JzKet(1, 1)"),
    quantum_qapply_srepr(
      @symprint.pretty_string(
        qapply(
          @symcore.raw_mul([jminus(), jminus(), jz_ket(one, one).as_expr()]),
        ),
      ),
    ),
    "double lowering parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_srepr("AntiCommutator(XGate(0), ZGate(0))*Qubit(0)"),
    quantum_qapply_srepr(
      @symprint.pretty_string(
        qapply(
          @symcore.raw_mul([
            anticommutator(
              x_gate(0).as_expr(),
              z_gate(0).as_expr(),
              evaluate=false,
            ),
            zero_state,
          ]),
        ),
      ),
    ),
    "gate anticommutator parity",
  )
}
