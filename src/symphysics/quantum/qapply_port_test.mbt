///|
test "physics.quantum.qapply: parity extensions" {
  let zero = (try! qubit("0")).as_expr()
  let one = (try! qubit("1")).as_expr()
  let zero_bra = (try! qubit_bra("0")).as_expr()
  let half = try! @symcore.rational_from_ints(1, 2)
  let n = @symcore.symbol("n")

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "TensorProduct(XGate(0), IdentityGate(0))*TensorProduct(Qubit(0), Qubit(1))",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([
          tensor_product([x_gate(0).as_expr(), identity_gate(0).as_expr()]).as_expr(),
          tensor_product([zero, one]).as_expr(),
        ])),
      ),
    ),
    "tensor-product pair qapply parity",
  )

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "TensorProduct(XGate(0)*Qubit(0), IdentityGate(0)*Qubit(1))",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(
          tensor_product([
            @symcore.raw_mul([x_gate(0).as_expr(), zero]),
            @symcore.raw_mul([identity_gate(0).as_expr(), one]),
          ]).as_expr(),
        ),
      ),
    ),
    "tensor-product raw qapply parity",
  )

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "Density((XGate(0)*Qubit(0), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(
          density([(@symcore.raw_mul([x_gate(0).as_expr(), zero]), half)]).as_expr(),
        ),
      ),
    ),
    "density qapply parity",
  )

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("XGate(0)**2*Qubit(0)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([x_gate(0).as_expr() ^ @symcore.int(2), zero])),
      ),
    ),
    "power qapply parity",
  )

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("QubitBra(0)*XGate(0)", dagger=true),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([zero_bra, x_gate(0).as_expr()]), dagger=true),
      ),
    ),
    "dagger qapply parity",
  )

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "Sum(XGate(0)*Qubit(0), (n, 0, 2))",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_function("Sum", [
          @symcore.raw_mul([x_gate(0).as_expr(), zero]),
          @symcore.raw_function("Tuple", [n, @symcore.int(0), @symcore.int(2)]),
        ])),
      ),
    ),
    "sum-body qapply parity",
  )
}
