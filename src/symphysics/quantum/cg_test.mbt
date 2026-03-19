///|
test "physics.quantum.cg: symbolic forms and numeric evaluation" {
  let half = quantum_test_frac(1, 2)

  guard !wigner3j(
    @symcore.int(6),
    @symcore.int(0),
    @symcore.int(4),
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(0),
  ).is_symbolic() else {
    fail("numeric Wigner3j should not be symbolic")
  }
  guard cg(
    @symcore.symbol("j1"),
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(0),
  ).is_symbolic() else {
    fail("symbolic CG should be symbolic")
  }

  guard @symprint.to_string(
      wigner3j(
        @symcore.int(6),
        @symcore.int(0),
        @symcore.int(4),
        @symcore.int(0),
        @symcore.int(2),
        @symcore.int(0),
      ).as_expr(),
    ) ==
    "Wigner3j(6, 0, 4, 0, 2, 0)" else {
    fail("Wigner3j string form mismatch")
  }
  guard @symprint.to_string(
      cg(
        half,
        half,
        half,
        @symcore.int(-1) * half,
        @symcore.int(1),
        @symcore.int(0),
      ).as_expr(),
    ) ==
    "CG(1/2, 1/2, 1/2, -1/2, 1, 0)" else {
    fail("CG string form mismatch")
  }

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
    @symcore.symbol("j"),
    @symcore.int(0),
    @symcore.int(4),
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(0),
  )
  let err : Result[@symcore.Expr, @symphysics.PhysicsError] = try? symbolic.doit()
  guard err is Err(@symphysics.PhysicsError::ValueError(_)) else {
    fail("symbolic Wigner3j.doit should reject nonnumeric input")
  }
}
