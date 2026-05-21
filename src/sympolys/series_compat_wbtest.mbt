///|
fn rs_wb_repr(series : SeriesElem) -> String {
  "[" + series.to_list().map(c => c.to_string()).join(", ") + "]"
}

///|
fn rs_wb_coeffs(values : Array[Int]) -> Array[FieldElem] raise PolyError {
  values.map(v => fe_from_int(v, Domain::QQ))
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
  inspect(rs_wb_repr(rs_diff(f)), content="[2, 6]")
  inspect(rs_wb_repr(rs_integrate(f)), content="[0, 1, 1, 1]")
  inspect(
    rs_wb_repr(rs_series_from_list(one.add(x), rs_wb_coeffs([1, 2, 3]))),
    content="[6, 8, 3]",
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
