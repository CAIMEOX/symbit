///|
test "physics.quantum.qapply: tensor, density, power, dagger, and sum" {
  let zero = (try! qubit("0")).as_expr()
  let one = (try! qubit("1")).as_expr()
  let zero_bra = (try! qubit_bra("0")).as_expr()
  let one_bra = (try! qubit_bra("1")).as_expr()
  let half = try! @symcore.rational_from_ints(1, 2)
  let n = @symcore.symbol("n")

  let tensor_mul = @symcore.raw_mul([
    tensor_product([x_gate(0).as_expr(), identity_gate(0).as_expr()]).as_expr(),
    tensor_product([zero, one]).as_expr(),
  ])
  inspect(
    @symprint.to_string(qapply(tensor_mul)),
    content="TensorProduct(Qubit(1), Qubit(1))",
  )

  let tensor_raw = tensor_product([
    @symcore.raw_mul([x_gate(0).as_expr(), zero]),
    @symcore.raw_mul([identity_gate(0).as_expr(), one]),
  ]).as_expr()
  inspect(
    @symprint.to_string(qapply(tensor_raw)),
    content="TensorProduct(Qubit(1), Qubit(1))",
  )

  let rho = density([(@symcore.raw_mul([x_gate(0).as_expr(), zero]), half)]).as_expr()
  inspect(
    @symprint.to_string(qapply(rho)),
    content="Density(Tuple(Qubit(1), 1/2))",
  )

  inspect(
    @symprint.to_string(
      qapply(@symcore.raw_mul([x_gate(0).as_expr() ^ @symcore.int(2), zero])),
    ),
    content="Qubit(0)",
  )

  inspect(
    @symprint.to_string(
      qapply(@symcore.raw_mul([zero_bra, x_gate(0).as_expr()]), dagger=true),
    ),
    content="QubitBra(1)",
  )

  inspect(
    @symprint.to_string(
      qapply(@symcore.raw_function("Sum", [
        @symcore.raw_mul([x_gate(0).as_expr(), zero]),
        @symcore.raw_function("Tuple", [n, @symcore.int(0), @symcore.int(2)]),
      ])),
    ),
    content="Sum(Qubit(1), Tuple(n, 0, 2))",
  )

  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      qapply(@symcore.raw_mul([zero_bra, x_gate(0).as_expr()]), dagger=true),
    ),
    @symprint.to_string(one_bra),
    "dagger bra application",
  )
}
