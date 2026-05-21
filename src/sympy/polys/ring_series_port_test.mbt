///|
fn ring_series_norm(text : String) -> String raise {
  sympy_normalize(text).trim().to_string().replace_all(old=" ", new="")
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
  @sympolys.power_series_ring(@sympolys.Domain::QQ, "x", prec).from_int_coeffs(
    values,
  )
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
