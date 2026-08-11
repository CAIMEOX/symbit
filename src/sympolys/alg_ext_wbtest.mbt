///|
test "alg_ext wb: validation error branches are typed" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")

  let minpoly = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  sympolys_assert_error(
    fn() raise PolyError {
      normalize_alg_ext_spec(alg_ext_spec(Domain::QQ, "y", minpoly))
    },
    "BadGenerator",
  )

  let dom_mismatch_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    x + @symcore.int(1),
  )
  sympolys_assert_error(
    fn() raise PolyError {
      normalize_alg_ext_spec(alg_ext_spec(Domain::ZZ, "x", dom_mismatch_poly))
    },
    "DomainMismatch",
  )

  let constant_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    @symcore.int(5),
  )
  sympolys_assert_error(
    fn() raise PolyError {
      normalize_alg_ext_spec(alg_ext_spec(Domain::QQ, "x", constant_poly))
    },
    "BadExponent",
  )

  let non_monic_zz = PolyBuilder::new(["x"], Domain::ZZ).from_expr(
    @symcore.int(2) * (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  sympolys_assert_error(
    fn() raise PolyError {
      normalize_alg_ext_spec(alg_ext_spec(Domain::ZZ, "x", non_monic_zz))
    },
    "DomainNotField",
  )

  let _ = y // keep both symbols in this scope as a cheap guard against dead code elimination assumptions
}

///|
test "alg_ext wb: make_monic_if_field handles zero polynomial explicitly" {
  let zero = Poly::zero(["x"], Domain::QQ)
  sympolys_assert_error(
    fn() raise PolyError { make_monic_if_field(zero) },
    "NonPolynomial",
  )
}
