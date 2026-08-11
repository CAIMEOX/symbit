///|
fn fezz_wb(n : Int) -> FieldElem {
  FieldElem::QQ(@symnum.BigRational::from_int(n))
}

///|
fn[T] sympolys_assert_error(
  action : () -> T raise PolyError,
  expected : String,
) -> Unit raise {
  try action() catch {
    error => assert_true(error.to_string().has_prefix(expected))
  } noraise {
    _ => fail("expected \{expected} to be raised")
  }
}

///|
test "errors: exact division failures are explicit" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let p = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let q = b.from_expr(x + @symcore.int(1))
  sympolys_assert_error(
    fn() raise PolyError { p.div_exact_univar(q) },
    "ExactQuotientFailed",
  )

  sympolys_assert_error(
    fn() raise PolyError {
      dup_exquo_ground([fezz_wb(1)], fezz_wb(2), Domain::ZZ)
    },
    "ExactQuotientFailed",
  )
}

///|
test "errors: empty monomial and root-isolation inputs are typed" {
  sympolys_assert_error(
    fn() raise PolyError { monomial_max([]) },
    "NonPolynomial",
  )
  sympolys_assert_error(
    fn() raise PolyError { monomial_min([]) },
    "NonPolynomial",
  )

  sympolys_assert_error(
    fn() raise PolyError { dup_cauchy_upper_bound([fezz_wb(1)], Domain::QQ) },
    "BadExponent",
  )

  sympolys_assert_error(
    fn() raise PolyError { dup_sturm([], Domain::QQ) },
    "NonPolynomial",
  )
}

///|
test "errors: normalize_mod on AlgExt reduces in base domain" {
  let alpha = @symcore.Expr::Symbol("alpha")
  let rel = (alpha ^ @symcore.int(2)) + @symcore.int(1)
  let d = Domain::AlgExt(Domain::QQ, ["alpha"], [rel])
  let value = @symnum.BigRational::new(BigInt::from_int(3), BigInt::from_int(2))
  let got = normalize_mod(value, d)
  inspect(got, content="3/2")
}

///|
test "rr: coefficients are no longer QQ-backed" {
  let half = @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  match ensure_coeff_domain(half, Domain::RR) {
    FieldElem::CC(real, imag) => {
      inspect(real, content="1/2")
      inspect(imag, content="0")
    }
    _ => fail("RR coefficients should use CC(real, 0) storage")
  }

  let rr_half = fe_from_rational(half, Domain::RR)
  let rr_one = fe_from_int(1, Domain::RR)
  match fe_add(rr_half, rr_one) {
    FieldElem::CC(real, imag) => {
      inspect(real, content="3/2")
      inspect(imag, content="0")
    }
    _ => fail("RR arithmetic should stay in the RR/CC representation")
  }
}
