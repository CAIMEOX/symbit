///|
fn orth_wb_coeffs(coeffs : Array[FieldElem]) -> String {
  let parts : Array[String] = []
  for coeff in coeffs {
    parts.push(coeff.to_string())
  }
  parts.join(",")
}

///|
test "orthogonal low-level dup kernels match standard small values" {
  inspect(orth_wb_coeffs(dup_chebyshevt(4, Domain::ZZ)), content="8,0,-8,0,1")
  inspect(orth_wb_coeffs(dup_chebyshevu(4, Domain::ZZ)), content="16,0,-12,0,1")
  inspect(orth_wb_coeffs(dup_hermite(4, Domain::ZZ)), content="16,0,-48,0,12")
  inspect(orth_wb_coeffs(dup_hermite_prob(4, Domain::ZZ)), content="1,0,-6,0,3")
  inspect(
    orth_wb_coeffs(dup_legendre(4, Domain::QQ)),
    content="35/8,0,-15/4,0,3/8",
  )
  inspect(
    orth_wb_coeffs(dup_laguerre(3, fe_from_int(0, Domain::QQ), Domain::QQ)),
    content="-1/6,3/2,-3,1",
  )
  inspect(
    orth_wb_coeffs(
      dup_jacobi(
        3,
        fe_from_int(1, Domain::QQ),
        fe_from_int(2, Domain::QQ),
        Domain::QQ,
      ),
    ),
    content="21/2,-7/2,-7/2,1/2",
  )
  inspect(
    orth_wb_coeffs(dup_gegenbauer(4, fe_from_int(2, Domain::QQ), Domain::QQ)),
    content="80,0,-48,0,3",
  )
  inspect(
    orth_wb_coeffs(dup_spherical_bessel_fn(4, Domain::ZZ)),
    content="105,0,-45,0,1,0",
  )
  inspect(
    orth_wb_coeffs(dup_spherical_bessel_fn_minus(4, Domain::ZZ)),
    content="-15,0,1,0",
  )
}

///|
test "orthogonal polynomial frontdoors match standard small values" {
  inspect(
    @symprint.pretty_string(chebyshevt_poly(4)).trim().to_owned(),
    content=(
      #|-8*x**2 + 8*x**4 + 1
    ),
  )
  inspect(
    @symprint.pretty_string(chebyshevu_poly(4)).trim().to_owned(),
    content=(
      #|-12*x**2 + 16*x**4 + 1
    ),
  )
  inspect(
    @symprint.pretty_string(hermite_poly(4)).trim().to_owned(),
    content=(
      #|-48*x**2 + 16*x**4 + 12
    ),
  )
  inspect(
    @symprint.pretty_string(hermite_prob_poly(4)).trim().to_owned(),
    content=(
      #|x**4 - 6*x**2 + 3
    ),
  )
  inspect(
    @symprint.pretty_string(legendre_poly(4)).trim().to_owned(),
    content=(
      #|-15*x**2/4 + 35*x**4/8 + 3/8
    ),
  )
  inspect(
    @symprint.pretty_string(laguerre_poly(3)).trim().to_owned(),
    content=(
      #|-3*x - x**3/6 + 3*x**2/2 + 1
    ),
  )
  inspect(
    @symprint.pretty_string(jacobi_poly(3, int(1), int(2))).trim().to_owned(),
    content=(
      #|-7*x**2/2 - 7*x/2 + 21*x**3/2 + 1/2
    ),
  )
  inspect(
    @symprint.pretty_string(gegenbauer_poly(4, int(2))).trim().to_owned(),
    content=(
      #|-48*x**2 + 80*x**4 + 3
    ),
  )
  inspect(
    @symprint.pretty_string(spherical_bessel_fn(4)).trim().to_owned(),
    content=(
      #|x**-1 - 45/x**3 + 105/x**5
    ),
  )
}

///|
test "appell polynomial frontdoors match standard small values" {
  inspect(
    @symprint.pretty_string(bernoulli_poly(5)).trim().to_owned(),
    content=(
      #|x**5 - 5*x**4/2 - x/6 + 5*x**3/3
    ),
  )
  inspect(
    @symprint.pretty_string(bernoulli_c_poly(4)).trim().to_owned(),
    content=(
      #|x**4 - 2*x**2 + 7/15
    ),
  )
  inspect(
    @symprint.pretty_string(genocchi_poly(4)).trim().to_owned(),
    content=(
      #|-4*x**3 + 6*x**2 - 1
    ),
  )
  inspect(
    @symprint.pretty_string(euler_poly(4)).trim().to_owned(),
    content=(
      #|x**4 - 2*x**3 + x
    ),
  )
  inspect(
    @symprint.pretty_string(andre_poly(5)).trim().to_owned(),
    content=(
      #|x**5 - 10*x**3 + 25*x
    ),
  )
}

///|
test "appell low-level dup kernels match standard small values" {
  inspect(
    orth_wb_coeffs(dup_bernoulli(5, Domain::QQ)),
    content="1,-5/2,5/3,0,-1/6,0",
  )
  inspect(
    orth_wb_coeffs(dup_bernoulli_c(4, Domain::QQ)),
    content="1,0,-2,0,7/15",
  )
  inspect(orth_wb_coeffs(dup_genocchi(5, Domain::ZZ)), content="-5,10,0,-5,0")
  inspect(
    orth_wb_coeffs(dup_euler(5, Domain::QQ)),
    content="1,-5/2,0,5/2,0,-1/2",
  )
  inspect(orth_wb_coeffs(dup_andre(5, Domain::ZZ)), content="1,0,-10,0,25,0")
}
