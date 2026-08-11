///|
test "physics.quantum.wavefunction: parity" {
  let n = @symcore.Expr::Symbol("n")
  let x = @symcore.Expr::Symbol("x")
  let wf = @symquant.wavefunction(x ^ @symcore.int(2), [x])
  let f_of_x = @symcore.raw_function("f", [x])
  let dop = differential_operator(
    @symcore.raw_function("Derivative", [f_of_x, x]),
    f_of_x,
  )
  let dop2 = differential_operator(
    @symcore.raw_mul([
      @symcore.raw_pow(x, @symcore.int(-1)),
      @symcore.raw_function("Derivative", [f_of_x, x]),
    ]),
    f_of_x,
  )

  quantum_test_assert_string_equal(
    quantum_doit_str("InnerProduct(OrthogonalBra(n), OrthogonalKet(n))"),
    @symprint.pretty_string(
      inner_product(
        orthogonal_bra([n]).as_expr(),
        orthogonal_ket([n]).as_expr(),
      ),
    ),
    "orthogonal equal parity",
  )
  quantum_test_assert_string_equal(
    quantum_doit_str("InnerProduct(OrthogonalBra(n), OrthogonalKet(n + 1))"),
    @symprint.pretty_string(
      inner_product(
        orthogonal_bra([n]).as_expr(),
        orthogonal_ket([n + @symcore.int(1)]).as_expr(),
      ),
    ),
    "orthogonal shifted parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Dagger(Wavefunction(x**2, x))"),
    quantum_eval_str(@symprint.pretty_string(dagger(wf.as_expr()))),
    "wavefunction dagger parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Wavefunction(x**2, x).prob()"),
    quantum_eval_str(@symprint.pretty_string(wf.prob().as_expr())),
    "wavefunction prob parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "DifferentialOperator(Derivative(wf(x), x), wf(x))*Wavefunction(x**2, x)",
    ),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(@symcore.raw_mul([dop.as_expr(), wf.as_expr()])),
      ),
    ),
    "differential operator qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "DifferentialOperator(x**(-1)*Derivative(wf(x), x), wf(x))*Wavefunction(x**2, x)",
    ),
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(@symcore.raw_mul([dop2.as_expr(), wf.as_expr()])),
      ),
    ),
    "scaled differential operator qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("represent(Wavefunction(x**2, x))"),
    quantum_eval_str(Show::to_string(represent(wf.as_expr()))),
    "represent wavefunction parity",
  )
}

///|
test "physics.quantum.wavefunction: norm parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let finite = @symquant.wavefunction(
    (x ^ @symcore.int(2)) * y + (y ^ @symcore.int(2)) * x,
    [
      @symcore.raw_function("Tuple", [x, @symcore.int(0), @symcore.int(1)]),
      @symcore.raw_function("Tuple", [y, @symcore.int(0), @symcore.int(2)]),
    ],
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Wavefunction(x**2*y + y**2*x, (x, 0, 1), (y, 0, 2)).norm"),
    quantum_eval_str(@symprint.pretty_string(finite.norm())),
    "wavefunction finite norm parity",
  )

  let normalized_wf = @symquant.wavefunction(
    @symcore.raw_function("sqrt", [@symcore.int(5)]) * (x ^ @symcore.int(2)),
    [@symcore.raw_function("Tuple", [x, @symcore.int(0), @symcore.int(1)])],
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Wavefunction(sqrt(5)*x**2, (x, 0, 1)).normalize()"),
    quantum_eval_str(
      @symprint.pretty_string(normalized_wf.normalize().as_expr()),
    ),
    "wavefunction normalize parity",
  )
}
