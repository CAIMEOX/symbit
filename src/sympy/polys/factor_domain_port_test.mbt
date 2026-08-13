///|
test "factor domain: P5a4 focused frontdoor parity with SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let builder = PolyBuilder::new(["x"], ZZ)
  let repeated = builder.from_expr(
    ((x - @symcore.int(2)) ^ @symcore.int(2)) *
    ((x + @symcore.int(3)) ^ @symcore.int(3)),
  )

  let (factor_content, factors) = @sympolys.factor_list(repeated)
  let ours_factors = sort_factor_repr(
    factor_list_to_string(Show::to_string(factor_content), factors),
  )
  let oracle_factors = sort_factor_repr(factor_list(repeated.to_expr()))
  assert_eq(ours_factors, oracle_factors)

  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.monic(repeated).to_string())),
    remove_spaces(monic(repeated.to_expr())),
  )

  let (sqf_content, sqf_factors) = @sympolys.sqf_list(repeated)
  let ours_sqf = sort_factor_repr(
    factor_list_to_string(Show::to_string(sqf_content), sqf_factors),
  )
  let oracle_sqf = sort_factor_repr(sqf_list(repeated.to_expr()))
  assert_eq(ours_sqf, oracle_sqf)
  assert_true(
    expr_equal(
      @sympolys.sqf_part(repeated).to_string(),
      sqf_part(repeated.to_expr()),
    ),
  )

  let p = builder.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let q = builder.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  assert_true(
    expr_equal(@sympolys.gcd(p, q).to_string(), gcd(p.to_expr(), q.to_expr())),
  )
  assert_eq(
    Show::to_string(@sympolys.resultant(p, q, var_index=0)),
    resultant(p.to_expr(), q.to_expr(), x="x"),
  )
  let (quotient, remainder) = @sympolys.div(p, q)
  assert_eq(
    div_pair_to_string(quotient, remainder),
    div(p.to_expr(), q.to_expr()),
  )

  let h = builder.from_expr((x ^ @symcore.int(2)) - @symcore.int(4))
  assert_true(
    expr_equal(
      @sympolys.gcd_list([p, q, h]).to_string(),
      gcd_list([p.to_expr(), q.to_expr(), h.to_expr()]),
    ),
  )
  assert_true(
    expr_equal(
      @sympolys.lcm_list([p, q, h]).to_string(),
      lcm_list([p.to_expr(), q.to_expr(), h.to_expr()]),
    ),
  )

  let y = @symcore.Expr::Symbol("y")
  let multivariate = PolyBuilder::new(["x", "y"], ZZ).from_expr(
    @symcore.int(2) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(3)) +
    @symcore.int(4) * x * (y ^ @symcore.int(2)),
  )
  assert_true(
    expr_equal(
      @sympolys.terms_gcd(multivariate).to_string(),
      terms_gcd(multivariate.to_expr()),
    ),
  )
}
