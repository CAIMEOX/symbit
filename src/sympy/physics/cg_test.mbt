///|
test "physics.quantum.cg: symbolic forms and numeric evaluation" {
  let half = quantum_test_frac(1, 2)

  assert_true(
    !wigner3j(
      @symcore.int(6),
      @symcore.int(0),
      @symcore.int(4),
      @symcore.int(0),
      @symcore.int(2),
      @symcore.int(0),
    ).is_symbolic(),
  )
  assert_true(
    cg(
      @symcore.Expr::Symbol("j1"),
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(0),
    ).is_symbolic(),
  )

  assert_eq(
    @symprint.pretty_string(
      wigner3j(
        @symcore.int(6),
        @symcore.int(0),
        @symcore.int(4),
        @symcore.int(0),
        @symcore.int(2),
        @symcore.int(0),
      ).as_expr(),
    ),
    "Wigner3j(6, 0, 4, 0, 2, 0)",
  )
  assert_eq(
    @symprint.pretty_string(
      cg(
        half,
        half,
        half,
        @symcore.int(-1) * half,
        @symcore.int(1),
        @symcore.int(0),
      ).as_expr(),
    ),
    "CG(1/2, 1/2, 1/2, -1/2, 1, 0)",
  )

  quantum_test_assert_expr_equal(
    wigner3j(
      half,
      @symcore.int(-1) * half,
      half,
      half,
      @symcore.int(0),
      @symcore.int(0),
    ).doit(),
    "-sqrt(2)/2",
    "Wigner3j.doit",
  )
  quantum_test_assert_expr_equal(
    cg(
      half,
      half,
      half,
      @symcore.int(-1) * half,
      @symcore.int(1),
      @symcore.int(0),
    ).doit(),
    "sqrt(2)/2",
    "CG.doit",
  )
  quantum_test_assert_expr_equal(
    wigner6j(
      @symcore.int(1),
      @symcore.int(2),
      @symcore.int(3),
      @symcore.int(2),
      @symcore.int(1),
      @symcore.int(2),
    ).doit(),
    "sqrt(21)/105",
    "Wigner6j.doit",
  )
  quantum_test_assert_expr_equal(
    wigner9j(
      @symcore.int(2),
      @symcore.int(1),
      @symcore.int(1),
      quantum_test_frac(3, 2),
      half,
      @symcore.int(1),
      half,
      half,
      @symcore.int(0),
    ).doit(),
    "sqrt(2)/12",
    "Wigner9j.doit",
  )
}

///|
test "physics.quantum.cg: doit rejects symbolic coefficients" {
  let symbolic = wigner3j(
    @symcore.Expr::Symbol("j"),
    @symcore.int(0),
    @symcore.int(4),
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(0),
  )
  let err : Result[@symcore.Expr, @symphysics.PhysicsError] = try? symbolic.doit()
  assert_true(err is Err(@symphysics.PhysicsError::ValueError(_)))
}
