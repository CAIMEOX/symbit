///|
fn orth_port_rat(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => abort("orthopolys port rational expects nonzero denominator")
  }
}

///|
fn orth_port_dup_repr(coeffs : Array[FieldElem]) -> String {
  let parts = coeffs.map(c => Show::to_string(c)).join(",")
  "[\{parts}]"
}

///|
fn orth_port_expr_norm(expr : Expr) -> String raise {
  sympy_normalize(@symprint.pretty_string(expr))
}

///|
test "orthopolys: low-level dup kernels oracle parity" {
  assert_eq(
    orth_port_dup_repr(@sympolys.dup_chebyshevt(4, ZZ)),
    dup_chebyshevt(4),
  )
  assert_eq(
    orth_port_dup_repr(@sympolys.dup_chebyshevu(4, ZZ)),
    dup_chebyshevu(4),
  )
  assert_eq(orth_port_dup_repr(@sympolys.dup_hermite(4, ZZ)), dup_hermite(4))
  assert_eq(
    orth_port_dup_repr(@sympolys.dup_hermite_prob(4, ZZ)),
    dup_hermite_prob(4),
  )
  assert_eq(orth_port_dup_repr(@sympolys.dup_legendre(4, QQ)), dup_legendre(4))
  assert_eq(
    orth_port_dup_repr(
      @sympolys.dup_laguerre(3, @sympolys.fe_from_int(0, QQ), QQ),
    ),
    dup_laguerre(3, orth_port_rat(0, 1)),
  )
  assert_eq(
    orth_port_dup_repr(
      @sympolys.dup_jacobi(
        3,
        @sympolys.fe_from_int(1, QQ),
        @sympolys.fe_from_int(2, QQ),
        QQ,
      ),
    ),
    dup_jacobi(3, orth_port_rat(1, 1), orth_port_rat(2, 1)),
  )
  assert_eq(
    orth_port_dup_repr(
      @sympolys.dup_gegenbauer(4, @sympolys.fe_from_int(2, QQ), QQ),
    ),
    dup_gegenbauer(4, orth_port_rat(2, 1)),
  )
  assert_eq(
    orth_port_dup_repr(@sympolys.dup_spherical_bessel_fn(4, ZZ)),
    dup_spherical_bessel_fn(4),
  )
  assert_eq(
    orth_port_dup_repr(@sympolys.dup_spherical_bessel_fn_minus(4, ZZ)),
    dup_spherical_bessel_fn_minus(4),
  )
}

///|
test "orthopolys: new expression frontdoors oracle parity" {
  assert_eq(
    orth_port_expr_norm(@sympolys.gegenbauer_poly(4, @symcore.int(2))),
    sympy_normalize(gegenbauer_poly(4, orth_port_rat(2, 1))),
  )
  assert_eq(
    orth_port_expr_norm(@sympolys.spherical_bessel_fn(4)),
    sympy_normalize(spherical_bessel_fn(4)),
  )
  assert_eq(
    orth_port_expr_norm(@sympolys.spherical_bessel_fn(-4)),
    sympy_normalize(spherical_bessel_fn(-4)),
  )
}

///|
test "appellseqs: low-level dup kernels oracle parity" {
  assert_eq(
    orth_port_dup_repr(@sympolys.dup_bernoulli(5, QQ)),
    dup_bernoulli(5),
  )
  assert_eq(
    orth_port_dup_repr(@sympolys.dup_bernoulli_c(4, QQ)),
    dup_bernoulli_c(4),
  )
  assert_eq(orth_port_dup_repr(@sympolys.dup_genocchi(5, ZZ)), dup_genocchi(5))
  assert_eq(orth_port_dup_repr(@sympolys.dup_euler(5, QQ)), dup_euler(5))
  assert_eq(orth_port_dup_repr(@sympolys.dup_andre(5, ZZ)), dup_andre(5))
}
