///|
fn ring_series_norm(text : String) -> String raise {
  sympy_normalize(text).trim().to_owned().replace_all(old=" ", new="")
}

///|
fn ring_series_expr(series : @sympolys.SeriesElem) -> String raise {
  ring_series_norm(@symprint.pretty_string(series.to_expr()))
}

///|
fn ring_series_make(
  values : Array[Int],
  prec : Int,
) -> @sympolys.SeriesElem raise @sympolys.PolyError {
  @sympolys.power_series_ring(QQ, "x", prec).from_int_coeffs(values)
}

///|
fn ring_series_tan_fun(
  q : @sympolys.SeriesElem,
  n : Int,
) -> @sympolys.SeriesElem raise @sympolys.PolyError {
  @sympolys.rs_tan(q, prec=n)
}

///|
fn ring_series_mul_fun(
  p : @sympolys.SeriesElem,
  q : @sympolys.SeriesElem,
  n : Int,
) -> @sympolys.SeriesElem raise @sympolys.PolyError {
  @sympolys.rs_mul(p, q, prec=n)
}

///|
fn ring_series_coeffs(values : Array[Int]) -> Array[@sympolys.FieldElem] raise {
  values.map(v => @sympolys.fe_from_int(v, QQ))
}

///|
test "ring_series: arithmetic frontdoor parity" {
  let f = ring_series_make([1, 2, 3], 6)
  let g = ring_series_make([0, 1, 1], 6)
  let one_plus_x = ring_series_make([1, 1], 6)

  assert_eq(
    ring_series_expr(@sympolys.rs_mul(f, g)),
    ring_series_norm(rs_mul_ring_series([1, 2, 3], [0, 1, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_square(one_plus_x)),
    ring_series_norm(rs_square_ring_series([1, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_pow(one_plus_x, 5)),
    ring_series_norm(rs_pow_ring_series([1, 1], 5, 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_series_inversion(one_plus_x)),
    ring_series_norm(rs_series_inversion_ring_series([1, 1], 6)),
  )
  assert_eq(
    @sympolys.rs_is_puiseux(one_plus_x).to_string(),
    rs_is_puiseux_ring_series([1, 1]).to_lower(),
  )
  assert_eq(@sympolys.rs_min_pow(ring_series_make([0, 0, 1, 1], 6)), 2)
  assert_eq(
    ring_series_expr(@sympolys.rs_nth_root(one_plus_x, 3)),
    ring_series_norm(rs_nth_root_ring_series([1, 1], 3, 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_nth_root(one_plus_x, -3)),
    ring_series_norm(rs_nth_root_ring_series([1, 1], -3, 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_diff(f)),
    ring_series_norm(rs_diff_ring_series([1, 2, 3])),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_integrate(f)),
    ring_series_norm(rs_integrate_ring_series([1, 2, 3])),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_subs(ring_series_make([1, 1, 1], 5), g, prec=5),
    ),
    ring_series_norm(rs_subs_ring_series([1, 1, 1], [0, 1, 1], 5)),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_newton(ring_series_make([-2, 0, 1], 6), prec=5),
    ),
    ring_series_norm(rs_newton_ring_series([-2, 0, 1], 5)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_newton(ring_series_make([1, 1], 7), prec=6)),
    ring_series_norm(rs_newton_ring_series([1, 1], 6)),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_compose_add(
        ring_series_make([-2, 0, 1], 5),
        ring_series_make([-3, 0, 1], 5),
      ),
    ),
    ring_series_norm(rs_compose_add_ring_series([-2, 0, 1], [-3, 0, 1])),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_compose_add(
        ring_series_make([-2, 0, 0, 1], 7),
        ring_series_make([-3, 0, 1], 7),
      ),
    ),
    ring_series_norm(rs_compose_add_ring_series([-2, 0, 0, 1], [-3, 0, 1])),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_series_reversion(ring_series_make([0, 1, -1], 6), 6),
    ),
    ring_series_norm(
      rs_series_reversion_ring_series([0, 1, -1], 6).replace_all(
        old="y",
        new="x",
      ),
    ),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_series_reversion(ring_series_make([0, 2, 1], 5), 5),
    ),
    ring_series_norm(
      rs_series_reversion_ring_series([0, 2, 1], 5).replace_all(
        old="y",
        new="x",
      ),
    ),
  )
}

///|
test "ring_series: pprint parity" {
  assert_eq(
    @sympolys.series_pprint(ring_series_coeffs([1, 2, 3]), prec=5),
    series_pprint_oracle([1, 2, 3], 5),
  )
  assert_eq(
    @sympolys.series_pprint(
      ring_series_coeffs([1, 0, 3]),
      prec=5,
      sym="t",
      ascending=false,
    ),
    series_pprint_oracle([1, 0, 3], 5, sym="t", ascending=false),
  )
}

///|
test "ring_series: analytic frontdoor parity" {
  let x = ring_series_make([0, 1], 6)
  let one_plus_x = ring_series_make([1, 1], 6)

  assert_eq(
    ring_series_expr(@sympolys.rs_exp(x)),
    ring_series_norm(rs_exp_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_log(one_plus_x)),
    ring_series_norm(rs_log_ring_series([1, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_sin(x)),
    ring_series_norm(rs_sin_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_cos(x)),
    ring_series_norm(rs_cos_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_tan(x)),
    ring_series_norm(rs_tan_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_sinh(x)),
    ring_series_norm(rs_sinh_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_cosh(x)),
    ring_series_norm(rs_cosh_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_tanh(x)),
    ring_series_norm(rs_tanh_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_atan(x)),
    ring_series_norm(rs_atan_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_atanh(x)),
    ring_series_norm(rs_atanh_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_asin(x)),
    ring_series_norm(rs_asin_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_asinh(x)),
    ring_series_norm(rs_asinh_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_fun(x, ring_series_tan_fun, prec=6)),
    ring_series_norm(rs_fun_tan_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_puiseux(ring_series_tan_fun, x, prec=6)),
    ring_series_norm(rs_puiseux_tan_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_puiseux2(
        ring_series_mul_fun,
        x,
        ring_series_make([1, 1], 6),
        prec=6,
      ),
    ),
    ring_series_norm(rs_puiseux2_mul_ring_series([0, 1], [1, 1], 6)),
  )
  let sx = @symcore.Expr::Symbol("x")
  let sin_plus_exp = @symcore.function("sin", [sx]) +
    @symcore.function("exp", [sx])
  assert_eq(
    ring_series_expr(@sympolys.rs_series(sin_plus_exp, "x", 5)),
    ring_series_norm(rs_series_expr(sin_plus_exp, "x", 5)),
  )
  let reciprocal = (@symcore.int(1) + sx) ^ @symcore.int(-1)
  // Both SymPy 1.13.3 and the sibling 1.15-dev front door preserve this
  // reciprocal as a ring element instead of truncating its geometric series.
  // Keep the MoonBit expansion and the oracle contract explicit separately.
  assert_eq(
    ring_series_expr(@sympolys.rs_series(reciprocal, "x", 5)),
    "x**4-x**3+x**2-x+1",
  )
  assert_eq(ring_series_norm(rs_series_expr(reciprocal, "x", 5)), "1/(x+1)")
  assert_eq(
    ring_series_expr(@sympolys.rs_LambertW(x, prec=6)),
    ring_series_norm(rs_LambertW_ring_series([0, 1], 6)),
  )
  assert_eq(
    ring_series_expr(
      @sympolys.rs_LambertW(ring_series_make([0, 1, 1], 6), prec=6),
    ),
    ring_series_norm(rs_LambertW_ring_series([0, 1, 1], 6)),
  )
}

///|
test "ring_series: exponent transform parity" {
  let p = ring_series_make([1, 2, 3], 6)
  let dense = ring_series_make([1, 1, 1, 1], 6)

  assert_eq(
    ring_series_expr(@sympolys.mul_xin(p, 2)),
    ring_series_norm(mul_xin_ring_series([1, 2, 3], 2)),
  )
  assert_eq(
    ring_series_expr(@sympolys.pow_xin(p, 2)),
    ring_series_norm(pow_xin_ring_series([1, 2, 3], 2)),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_hadamard_exp(dense)),
    ring_series_norm(rs_hadamard_exp_ring_series([1, 1, 1, 1])),
  )
  assert_eq(
    ring_series_expr(@sympolys.rs_hadamard_exp(dense, inverse=true)),
    ring_series_norm(rs_hadamard_exp_ring_series([1, 1, 1, 1], inverse=true)),
  )
}
