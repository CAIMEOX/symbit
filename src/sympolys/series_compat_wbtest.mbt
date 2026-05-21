///|
fn rs_wb_repr(series : SeriesElem) -> String {
  "[" + series.to_list().map(c => c.to_string()).join(", ") + "]"
}

///|
fn rs_wb_coeffs(values : Array[Int]) -> Array[FieldElem] raise PolyError {
  values.map(v => fe_from_int(v, Domain::QQ))
}

///|
fn rs_wb_tan_fun(q : SeriesElem, n : Int) -> SeriesElem raise PolyError {
  rs_tan(q, prec=n)
}

///|
test "ring series frontdoors: pprint" {
  inspect(
    series_pprint(rs_wb_coeffs([1, 2, 3]), prec=5),
    content="3 + 2*x + x**2 + O(x**5)",
  )
  inspect(
    series_pprint(rs_wb_coeffs([1, 0, 3]), prec=5, sym="t"),
    content="3 + t**2 + O(t**5)",
  )
  inspect(
    series_pprint(rs_wb_coeffs([1, 0, 3]), prec=5, sym="t", ascending=false),
    content="t**2 + 3 + O(t**5)",
  )
  inspect(series_pprint([], prec=4), content="O(x**4)")
  inspect(series_pprint([]), content="0")
}

///|
test "ring series frontdoors: arithmetic wrappers" {
  let ring = power_series_ring(Domain::QQ, "x", 6)
  let x = ring.gen()
  let one = ring.one()
  let f = ring.from_int_coeffs([1, 2, 3])
  let g = ring.from_int_coeffs([0, 1, 1])

  inspect(rs_wb_repr(rs_trunc(f, 2)), content="[1, 2]")
  inspect(rs_wb_repr(rs_mul(f, g)), content="[0, 1, 3, 5, 3]")
  inspect(rs_wb_repr(rs_square(one.add(x))), content="[1, 2, 1]")
  inspect(rs_wb_repr(rs_pow(one.add(x), 5)), content="[1, 5, 10, 10, 5, 1]")
  inspect(
    rs_wb_repr(rs_series_inversion(one.add(x))),
    content="[1, -1, 1, -1, 1, -1]",
  )
  inspect(rs_is_puiseux(one.add(x)), content="false")
  inspect(rs_min_pow(x.mul(x).mul(one.add(x))), content="2")
  inspect(
    rs_wb_repr(rs_nth_root(one.add(x), 3)),
    content="[1, 1/3, -1/9, 5/81, -10/243, 22/729]",
  )
  inspect(
    rs_wb_repr(rs_nth_root(one.add(x), -3)),
    content="[1, -1/3, 2/9, -14/81, 35/243, -91/729]",
  )
  inspect(rs_wb_repr(rs_diff(f)), content="[2, 6]")
  inspect(rs_wb_repr(rs_integrate(f)), content="[0, 1, 1, 1]")
  inspect(
    rs_wb_repr(rs_series_from_list(one.add(x), rs_wb_coeffs([1, 2, 3]))),
    content="[6, 8, 3]",
  )
  let p = ring.from_int_coeffs([1, 1, 1])
  let replacement = ring.from_int_coeffs([0, 1, 1])
  inspect(
    rs_wb_repr(rs_subs(p, replacement, prec=5)),
    content="[1, 1, 2, 2, 1]",
  )
  let newton_input = ring.from_int_coeffs([-2, 0, 1])
  inspect(
    rs_wb_repr(rs_newton(newton_input, prec=5)),
    content="[2, 0, 4, 0, 8]",
  )
  inspect(
    rs_wb_repr(rs_newton(ring.from_int_coeffs([1, 1]), prec=6)),
    content="[1, -1, 1, -1, 1, -1, 1]",
  )
  inspect(
    rs_wb_repr(rs_fun(x, rs_wb_tan_fun, prec=6)),
    content="[0, 1, 0, 1/3, 0, 2/15]",
  )
  inspect(
    rs_wb_repr(rs_LambertW(x, prec=6)),
    content="[0, 1, -1, 3/2, -8/3, 125/24]",
  )
  inspect(
    rs_wb_repr(rs_LambertW(x.add(x.mul(x)), prec=6)),
    content="[0, 1, 0, -1/2, 5/6, -23/24]",
  )
  inspect(
    rs_wb_repr(
      rs_compose_add(
        ring.from_int_coeffs([-2, 0, 1]),
        ring.from_int_coeffs([-3, 0, 1]),
      ),
    ),
    content="[1, 0, -10, 0, 1]",
  )
  inspect(
    rs_wb_repr(
      rs_compose_add(
        ring.from_int_coeffs([-1, 1]),
        ring.from_int_coeffs([1, 0, 1]),
      ),
    ),
    content="[2, -2, 1]",
  )
}

///|
test "ring series frontdoors: analytic wrappers" {
  let ring = power_series_ring(Domain::QQ, "x", 6)
  let x = ring.gen()
  let one = ring.one()

  inspect(rs_wb_repr(rs_exp(x)), content="[1, 1, 1/2, 1/6, 1/24, 1/120]")
  inspect(
    rs_wb_repr(rs_log(one.add(x))),
    content="[0, 1, -1/2, 1/3, -1/4, 1/5]",
  )
  inspect(rs_wb_repr(rs_sin(x)), content="[0, 1, 0, -1/6, 0, 1/120]")
  inspect(rs_wb_repr(rs_cos(x)), content="[1, 0, -1/2, 0, 1/24]")
  let (cosx, sinx) = rs_cos_sin(x)
  inspect(rs_wb_repr(cosx), content="[1, 0, -1/2, 0, 1/24]")
  inspect(rs_wb_repr(sinx), content="[0, 1, 0, -1/6, 0, 1/120]")
  inspect(rs_wb_repr(rs_tan(x)), content="[0, 1, 0, 1/3, 0, 2/15]")
  inspect(rs_wb_repr(rs_sinh(x)), content="[0, 1, 0, 1/6, 0, 1/120]")
  inspect(rs_wb_repr(rs_cosh(x)), content="[1, 0, 1/2, 0, 1/24]")
  let (coshx, sinhx) = rs_cosh_sinh(x)
  inspect(rs_wb_repr(coshx), content="[1, 0, 1/2, 0, 1/24]")
  inspect(rs_wb_repr(sinhx), content="[0, 1, 0, 1/6, 0, 1/120]")
  inspect(rs_wb_repr(rs_tanh(x)), content="[0, 1, 0, -1/3, 0, 2/15]")
  inspect(rs_wb_repr(rs_atan(x)), content="[0, 1, 0, -1/3, 0, 1/5]")
  inspect(rs_wb_repr(rs_atanh(x)), content="[0, 1, 0, 1/3, 0, 1/5]")
  inspect(rs_wb_repr(rs_asin(x)), content="[0, 1, 0, 1/6, 0, 3/40]")
  inspect(rs_wb_repr(rs_asinh(x)), content="[0, 1, 0, -1/6, 0, 3/40]")
}

///|
test "ring series frontdoors: exponent transforms" {
  let ring = power_series_ring(Domain::QQ, "x", 6)
  let p = ring.from_int_coeffs([1, 2, 3])
  let dense = ring.from_int_coeffs([1, 1, 1, 1])

  inspect(rs_wb_repr(mul_xin(p, 2)), content="[0, 0, 1, 2, 3]")
  inspect(rs_wb_repr(mul_xin(p, -1)), content="[2, 3]")
  inspect(rs_wb_repr(pow_xin(p, 2)), content="[1, 0, 2, 0, 3]")
  inspect(rs_wb_repr(pow_xin(p, 0)), content="[6]")
  inspect(rs_wb_repr(rs_hadamard_exp(dense)), content="[1, 1, 1/2, 1/6]")
  inspect(
    rs_wb_repr(rs_hadamard_exp(dense, inverse=true)),
    content="[1, 1, 2, 6]",
  )
}
