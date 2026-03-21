///|
test "physics.quantum.wavefunction: local orthogonal and differential semantics" {
  let n = @symcore.symbol("n")
  let x = @symcore.symbol("x")
  let f_of_x = @symcore.raw_function("f", [x])

  let ok = orthogonal_ket([n])
  let ob = orthogonal_bra([n])
  inspect(ok.to_string(), content="|n>")
  inspect(ob.dual().to_string(), content="|n>")
  inspect(
    @symprint.to_string(inner_product(ob.as_expr(), ok.as_expr())),
    content="1",
  )
  inspect(
    @symprint.to_string(
      inner_product(
        orthogonal_bra([n]).as_expr(),
        orthogonal_ket([n + @symcore.int(1)]).as_expr(),
      ),
    ),
    content="0",
  )

  let wf = @symquant.wavefunction(x ^ @symcore.int(2), [x])
  inspect(@symprint.to_string(wf.call([@symcore.int(2)])), content="4")
  inspect(
    @symprint.to_string(
      @symquant.wavefunction(x ^ @symcore.int(2), [
        @symcore.raw_function("Tuple", [x, @symcore.int(0), @symcore.int(1)]),
      ]).call([@symcore.int(2)]),
    ),
    content="0",
  )
  inspect(
    @symprint.to_string(wf.prob().as_expr()),
    content="Wavefunction((x**2*conjugate(x)**2), x)",
  )
  inspect(
    @symprint.to_string(dagger(wf.as_expr())),
    content="Wavefunction((conjugate(x)**2), x)",
  )

  let dop = differential_operator(
    @symcore.raw_function("Derivative", [f_of_x, x]),
    f_of_x,
  )
  inspect(
    @symprint.to_string(qapply(@symcore.raw_mul([dop.as_expr(), wf.as_expr()]))),
    content="Wavefunction((2*x), x)",
  )
  let dop2 = differential_operator(
    @symcore.raw_mul([
      @symcore.raw_pow(x, @symcore.int(-1)),
      @symcore.raw_function("Derivative", [f_of_x, x]),
    ]),
    f_of_x,
  )
  inspect(
    @symprint.to_string(
      qapply(@symcore.raw_mul([dop2.as_expr(), wf.as_expr()])),
    ),
    content="Wavefunction(2, x)",
  )
  inspect(
    represent(wf.as_expr()).to_string(),
    content="Wavefunction((x**2), x)",
  )
}

///|
test "physics.quantum.wavefunction: norm and normalization helpers" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let finite = @symquant.wavefunction(
    (x ^ @symcore.int(2)) * y + (y ^ @symcore.int(2)) * x,
    [
      @symcore.raw_function("Tuple", [x, @symcore.int(0), @symcore.int(1)]),
      @symcore.raw_function("Tuple", [y, @symcore.int(0), @symcore.int(2)]),
    ],
  )
  quantum_test_assert_expr_equal(
    finite.norm(),
    "sqrt(42)/3",
    "wavefunction finite-box norm",
  )

  let normalized_wf = @symquant.wavefunction(
    @symcore.raw_function("sqrt", [@symcore.int(5)]) * (x ^ @symcore.int(2)),
    [@symcore.raw_function("Tuple", [x, @symcore.int(0), @symcore.int(1)])],
  )
  assert_true(normalized_wf.is_normalized())
  quantum_test_assert_expr_equal(
    normalized_wf.normalize().as_expr(),
    @symprint.to_string(normalized_wf.as_expr()),
    "wavefunction normalize leaves normalized state unchanged",
  )

  let divergent = @symquant.wavefunction(x ^ @symcore.int(2), [x])
  quantum_test_assert_expr_equal(
    divergent.norm(),
    "oo",
    "wavefunction divergent norm",
  )
}
