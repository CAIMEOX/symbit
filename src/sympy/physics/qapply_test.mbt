///|
test "physics.quantum.qapply: tensor, density, power, dagger, and sum" {
  let zero = qubit("0").as_expr()
  let one = qubit("1").as_expr()
  let zero_bra = qubit_bra("0").as_expr()
  let one_bra = qubit_bra("1").as_expr()
  let half = @symcore.rational_from_ints(1, 2)
  let n = @symcore.Expr::Symbol("n")

  let tensor_mul = @symcore.raw_mul([
    @symquant.tensor_product([x_gate(0).as_expr(), identity_gate(0).as_expr()]).as_expr(),
    @symquant.tensor_product([zero, one]).as_expr(),
  ])
  inspect(
    @symprint.pretty_string(qapply(tensor_mul)),
    content="TensorProduct(Qubit(1), Qubit(1))",
  )

  let tensor_raw = @symquant.tensor_product([
    @symcore.raw_mul([x_gate(0).as_expr(), zero]),
    @symcore.raw_mul([identity_gate(0).as_expr(), one]),
  ]).as_expr()
  inspect(
    @symprint.pretty_string(qapply(tensor_raw)),
    content="TensorProduct(Qubit(1), Qubit(1))",
  )

  let rho = density([(@symcore.raw_mul([x_gate(0).as_expr(), zero]), half)]).as_expr()
  inspect(
    @symprint.pretty_string(qapply(rho)),
    content="Density(Tuple(Qubit(1), 1/2))",
  )

  inspect(
    @symprint.pretty_string(
      qapply(@symcore.raw_mul([x_gate(0).as_expr() ^ @symcore.int(2), zero])),
    ),
    content="Qubit(0)",
  )

  inspect(
    @symprint.pretty_string(
      qapply(@symcore.raw_mul([zero_bra, x_gate(0).as_expr()]), dagger=true),
    ),
    content="QubitBra(1)",
  )

  inspect(
    @symprint.pretty_string(
      qapply(
        @symcore.raw_function("Sum", [
          @symcore.raw_mul([x_gate(0).as_expr(), zero]),
          @symcore.raw_function("Tuple", [n, @symcore.int(0), @symcore.int(2)]),
        ]),
      ),
    ),
    content="Sum(Qubit(1), Tuple(n, 0, 2))",
  )

  quantum_test_assert_string_equal(
    @symprint.pretty_string(
      qapply(@symcore.raw_mul([zero_bra, x_gate(0).as_expr()]), dagger=true),
    ),
    @symprint.pretty_string(one_bra),
    "dagger bra application",
  )
}

///|
test "physics.quantum.qapply: spin ladders and (anti)commutator action" {
  let one = @symcore.int(1)
  let zero_state = qubit("0").as_expr()
  let z = jz_ket(one, @symcore.int(0)).as_expr()
  let po = jz_ket(one, one).as_expr()

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jx(), z])),
    "sqrt(2)/2*hbar*JzKet(1, 1) + sqrt(2)/2*hbar*JzKet(1, -1)",
    "Jx action on JzKet(1, 0)",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jminus(), jminus(), po])),
    "2*hbar**2*JzKet(1, -1)",
    "double lowering",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([commutator(jx(), jy(), evaluate=false), jz(), po])),
    "I*hbar**3*JzKet(1, 1)",
    "commutator action",
  )
  quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([
        anticommutator(x_gate(0).as_expr(), z_gate(0).as_expr(), evaluate=false),
        zero_state,
      ]),
    ),
    "0",
    "gate anticommutator action",
  )
}
