///|
fn check_expr(
  label : String,
  expr : @symcore.Expr,
  expected : String,
) -> Unit raise {
  let ours = @symprint.to_string(expr)
  guard ours == expected else {
    println("mismatch [\{label}]: ours=\{ours} expected=\{expected}")
    fail("expr mismatch")
  }
  let oracle : Result[Bool, Error] = try? @sympy_functions.expr_str_eq(
    ours, expected,
  )
  match oracle {
    Ok(true) => ()
    Ok(false) => {
      println("oracle mismatch [\{label}]: ours=\{ours} expected=\{expected}")
      fail("oracle mismatch")
    }
    Err(e) => raise e
  }
}

///|
test "special full parity (wrappers)" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let c = @symcore.symbol("c")
  let d = @symcore.symbol("d")
  let n = @symcore.symbol("n")
  let m = @symcore.symbol("m")
  let q = @symcore.symbol("q")
  let s = @symcore.symbol("s")
  let theta = @symcore.symbol("theta")
  let phi = @symcore.symbol("phi")
  let i = @symcore.symbol("i")
  let j = @symcore.symbol("j")
  let k = @symcore.symbol("k")
  let deg = @symcore.int(1)
  let basis_n = @symcore.int(1)
  let knots = @symcore.function("Tuple", [
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  let values = @symcore.function("Tuple", [
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(0),
    @symcore.int(1),
  ])
  check_expr("gamma", gamma(x), "gamma(x)")
  check_expr("lowergamma", lowergamma(a, x), "lowergamma(a, x)")
  check_expr("uppergamma", uppergamma(a, x), "uppergamma(a, x)")
  check_expr("polygamma", polygamma(n, x), "polygamma(n, x)")
  check_expr("loggamma", loggamma(x), "loggamma(x)")
  check_expr("digamma", digamma(x), "digamma(x)")
  check_expr("trigamma", trigamma(x), "trigamma(x)")
  check_expr("multigamma", multigamma(a, b), "multigamma(a, b)")
  check_expr("zeta", zeta(x), "zeta(x)")
  check_expr("dirichlet_eta", dirichlet_eta(x), "dirichlet_eta(x)")
  check_expr("lerchphi", lerchphi(z, s, a), "lerchphi(z, s, a)")
  check_expr("polylog", polylog(s, z), "polylog(s, z)")
  check_expr("stieltjes", stieltjes(n), "stieltjes(n)")
  check_expr("riemann_xi", riemann_xi(x), "riemann_xi(x)")
  check_expr("erf", erf(x), "erf(x)")
  check_expr("erfc", erfc(x), "erfc(x)")
  check_expr("erfi", erfi(x), "erfi(x)")
  check_expr("erf2", erf2(x, y), "erf2(x, y)")
  check_expr("erfinv", erfinv(x), "erfinv(x)")
  check_expr("erfcinv", erfcinv(x), "erfcinv(x)")
  check_expr("erf2inv", erf2inv(x, y), "erf2inv(x, y)")
  check_expr("ei", ei(x), "Ei(x)")
  check_expr("expint", expint(n, x), "expint(n, x)")
  check_expr("e1", e1(x), "E1(x)")
  check_expr("li", li(x), "li(x)")
  check_expr("li_offset", li_offset(x), "Li(x)")
  check_expr("si", si(x), "Si(x)")
  check_expr("ci", ci(x), "Ci(x)")
  check_expr("shi", shi(x), "Shi(x)")
  check_expr("chi", chi(x), "Chi(x)")
  check_expr("fresnels", fresnels(x), "fresnels(x)")
  check_expr("fresnelc", fresnelc(x), "fresnelc(x)")
  check_expr("eijk", eijk(i, j, k), "Eijk(i, j, k)")
  check_expr("levi_civita", levi_civita([i, j, k]), "LeviCivita(i, j, k)")
  check_expr("kronecker_delta", kronecker_delta(i, j), "KroneckerDelta(i, j)")
  check_expr("dirac_delta", dirac_delta(x), "DiracDelta(x)")
  check_expr("heaviside", heaviside(x), "Heaviside(x)")
  check_expr("besselj", besselj(n, x), "besselj(n, x)")
  check_expr("bessely", bessely(n, x), "bessely(n, x)")
  check_expr("besseli", besseli(n, x), "besseli(n, x)")
  check_expr("besselk", besselk(n, x), "besselk(n, x)")
  check_expr("hankel1", hankel1(n, x), "hankel1(n, x)")
  check_expr("hankel2", hankel2(n, x), "hankel2(n, x)")
  check_expr("jn", jn(n, x), "jn(n, x)")
  check_expr("yn", yn(n, x), "yn(n, x)")
  check_expr(
    "jn_zeros",
    jn_zeros(@symcore.int(2), @symcore.int(3)),
    "jn_zeros(2, 3)",
  )
  check_expr("hn1", hn1(n, x), "hn1(n, x)")
  check_expr("hn2", hn2(n, x), "hn2(n, x)")
  check_expr("airyai", airyai(x), "airyai(x)")
  check_expr("airybi", airybi(x), "airybi(x)")
  check_expr("airyaiprime", airyaiprime(x), "airyaiprime(x)")
  check_expr("airybiprime", airybiprime(x), "airybiprime(x)")
  check_expr("marcumq", marcumq(m, a, b), "marcumq(m, a, b)")
  check_expr("hyper", hyper([a, b], [c], x), "hyper(Tuple(a, b), Tuple(c), x)")
  check_expr(
    "meijerg",
    meijerg([a], [b], [c], [d], x),
    "meijerg(Tuple(Tuple(a), Tuple(b)), Tuple(Tuple(c), Tuple(d)), x)",
  )
  check_expr(
    "appellf1",
    appellf1(a, b, c, d, x, y),
    "appellf1(a, b, c, d, x, y)",
  )
  check_expr("legendre", legendre(n, x), "legendre(n, x)")
  check_expr(
    "assoc_legendre",
    assoc_legendre(n, m, x),
    "assoc_legendre(n, m, x)",
  )
  check_expr("hermite", hermite(n, x), "hermite(n, x)")
  check_expr("hermite_prob", hermite_prob(n, x), "hermite_prob(n, x)")
  check_expr("chebyshevt", chebyshevt(n, x), "chebyshevt(n, x)")
  check_expr("chebyshevu", chebyshevu(n, x), "chebyshevu(n, x)")
  check_expr(
    "chebyshevu_root",
    chebyshevu_root(@symcore.int(2), @symcore.int(1)),
    "chebyshevu_root(2, 1)",
  )
  check_expr(
    "chebyshevt_root",
    chebyshevt_root(@symcore.int(2), @symcore.int(1)),
    "chebyshevt_root(2, 1)",
  )
  check_expr("laguerre", laguerre(n, x), "laguerre(n, x)")
  check_expr(
    "assoc_laguerre",
    assoc_laguerre(n, m, x),
    "assoc_laguerre(n, m, x)",
  )
  check_expr("gegenbauer", gegenbauer(n, a, x), "gegenbauer(n, a, x)")
  check_expr("jacobi", jacobi(n, a, b, x), "jacobi(n, a, b, x)")
  check_expr(
    "jacobi_normalized",
    jacobi_normalized(n, a, b, x),
    "jacobi_normalized(n, a, b, x)",
  )
  check_expr("ynm", ynm(n, m, theta, phi), "Ynm(n, m, theta, phi)")
  check_expr("ynm_c", ynm_c(n, m, theta, phi), "Ynm_c(n, m, theta, phi)")
  check_expr("znm", znm(n, m, theta, phi), "Znm(n, m, theta, phi)")
  check_expr("elliptic_k", elliptic_k(m), "elliptic_k(m)")
  check_expr("elliptic_f", elliptic_f(phi, m), "elliptic_f(phi, m)")
  check_expr("elliptic_e", elliptic_e(phi, m), "elliptic_e(phi, m)")
  check_expr("elliptic_pi", elliptic_pi(n, phi, m), "elliptic_pi(n, phi, m)")
  check_expr("beta", beta(a, b), "beta(a, b)")
  check_expr("betainc", betainc(a, b, x, y), "betainc(a, b, x, y)")
  check_expr(
    "betainc_regularized",
    betainc_regularized(a, b, x, y),
    "betainc_regularized(a, b, x, y)",
  )
  check_expr("mathieus", mathieus(n, q, z), "mathieus(n, q, z)")
  check_expr("mathieuc", mathieuc(n, q, z), "mathieuc(n, q, z)")
  check_expr("mathieusprime", mathieusprime(n, q, z), "mathieusprime(n, q, z)")
  check_expr("mathieucprime", mathieucprime(n, q, z), "mathieucprime(n, q, z)")
  check_expr(
    "singularity",
    singularity_function(x, a, n),
    "SingularityFunction(x, a, n)",
  )
  check_expr(
    "bspline_basis",
    bspline_basis(deg, knots, basis_n, x),
    "bspline_basis(1, Tuple(0, 1, 2, 3), 1, x)",
  )
  check_expr(
    "bspline_basis_set",
    bspline_basis_set(deg, knots, x),
    "bspline_basis_set(1, Tuple(0, 1, 2, 3), x)",
  )
  check_expr(
    "interpolating_spline",
    interpolating_spline(deg, x, knots, values),
    "interpolating_spline(1, x, Tuple(0, 1, 2, 3), Tuple(0, 1, 0, 1))",
  )
}
