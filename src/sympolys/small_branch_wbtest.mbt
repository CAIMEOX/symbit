///|
fn sb_rat(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => abort("whitebox test rational expects a nonzero denominator")
  }
}

///|
fn sb_feqq(num : Int, den : Int) -> FieldElem {
  FieldElem::QQ(sb_rat(num, den))
}

///|
fn sb_bi(n : Int) -> BigInt {
  BigInt::from_int(n)
}

///|
test "small branches: core/domain paths" {
  let half = sb_rat(1, 2)
  let frac_coeff = ensure_coeff_domain(half, Domain::Frac(Domain::QQ))
  assert_true(frac_coeff.to_string() == "1/2")

  let a = @symcore.Expr::Symbol("a")
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [
    (a ^ @symcore.int(2)) + @symcore.int(1),
  ])
  let alg_coeff = ensure_coeff_domain(half, alg_domain)
  assert_true(alg_coeff is FieldElem::AlgExt(_, _, _, _))

  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let px = PolyBuilder::new(["x"], Domain::QQ).from_expr(x + @symcore.int(1))
  let pxy = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)
  sympolys_assert_error(fn() raise PolyError { px.mul(pxy) }, "DomainMismatch")

  let py = PolyBuilder::new(["y"], Domain::QQ).from_expr(y + @symcore.int(1))
  sympolys_assert_error(fn() raise PolyError { px.mul(py) }, "DomainMismatch")

  sympolys_assert_error(fn() raise PolyError { px.pow(-1) }, "BadExponent")

  assert_true(Domain::Frac(Domain::QQ) == Domain::Frac(Domain::QQ))
  assert_true(alg_domain == alg_domain)

  let bad_gen = PolyError::BadGenerator("u")
  inspect("\{bad_gen}", content="BadGenerator(u)")
  inspect("\{PolyError::NonPolynomial}", content="NonPolynomial")
  inspect("\{PolyError::BadExponent}", content="BadExponent")
  inspect("\{PolyError::DomainMismatch}", content="DomainMismatch")
  inspect(
    "\{PolyError::CoefficientNotInteger}",
    content="CoefficientNotInteger",
  )
  inspect("\{PolyError::DomainNotField}", content="DomainNotField")
  inspect("\{PolyError::DivisionByZero}", content="DivisionByZero")
  inspect("\{PolyError::ExactQuotientFailed}", content="ExactQuotientFailed")
  inspect(
    "\{PolyError::PolynomialDivisionFailed}",
    content="PolynomialDivisionFailed",
  )
  inspect("\{PolyError::NotUnivariate}", content="NotUnivariate")
  inspect("\{PolyError::BadModulus}", content="BadModulus")
}

///|
test "small branches: domain_utils normalize_mod paths" {
  sympolys_assert_error(
    fn() raise PolyError { normalize_mod(sb_rat(1, 2), Domain::GF(1)) },
    "BadModulus",
  )

  sympolys_assert_error(
    fn() raise PolyError { normalize_mod(sb_rat(1, 5), Domain::GF(5)) },
    "DivisionByZero",
  )

  let frac_norm = normalize_mod(sb_rat(8, 3), Domain::Frac(Domain::GF(7)))
  assert_true(frac_norm.to_string() == "5")

  sympolys_assert_error(
    fn() raise PolyError { normalize_mod(sb_rat(1, 2), Domain::GF(4)) },
    "DivisionByZero",
  )
}

///|
test "small branches: dense conversion guard branches" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let pxy = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)

  sympolys_assert_error(fn() raise PolyError { to_dense(pxy) }, "NotUnivariate")

  sympolys_assert_error(
    fn() raise PolyError { from_dense([sb_feqq(1, 1)], ["x", "y"], Domain::QQ) },
    "NotUnivariate",
  )

  sympolys_assert_error(
    fn() raise PolyError { to_dense_multi(pxy, [2]) },
    "BadGenerator",
  )

  let malformed_coeffs : Map[Monomial, FieldElem] = Map([])
  malformed_coeffs.set(Monomial::{ exps: [1] }, sb_feqq(1, 1))
  let malformed_poly = Poly::{
    coeffs: malformed_coeffs,
    gens: ["x", "y"],
    domain: Domain::QQ,
    order: TermOrder::Lex,
  }
  let malformed_dense = to_dense_multi(malformed_poly, [1, 1])
  assert_true(malformed_dense.all(c => fe_is_zero(c)))

  let out_of_range_coeffs : Map[Monomial, FieldElem] = Map([])
  out_of_range_coeffs.set(Monomial::{ exps: [3, 0] }, sb_feqq(1, 1))
  let out_of_range_poly = Poly::{
    coeffs: out_of_range_coeffs,
    gens: ["x", "y"],
    domain: Domain::QQ,
    order: TermOrder::Lex,
  }
  let out_of_range_dense = to_dense_multi(out_of_range_poly, [1, 1])
  assert_true(out_of_range_dense.all(c => fe_is_zero(c)))

  sympolys_assert_error(
    fn() raise PolyError {
      from_dense_multi([sb_feqq(1, 1)], ["x"], Domain::QQ, [1, 1])
    },
    "BadGenerator",
  )

  sympolys_assert_error(
    fn() raise PolyError {
      from_dense_multi([sb_feqq(1, 1)], ["x", "y"], Domain::QQ, [1, 1])
    },
    "BadGenerator",
  )
}

///|
test "small branches: lll helper branches" {
  let (empty_reduced, empty_transform) = lll_reduce([])
  assert_true(empty_reduced.length() == 0 && empty_transform.length() == 0)

  let ragged : Matrix = [[sb_bi(1)], [sb_bi(1), sb_bi(2)]]
  sympolys_assert_error(
    fn() raise PolyError { lll_reduce(ragged) },
    "DomainMismatch",
  )

  let basis : Matrix = [
    [sb_bi(1), sb_bi(1), sb_bi(1)],
    [sb_bi(1), sb_bi(0), sb_bi(0)],
    [sb_bi(0), sb_bi(1), sb_bi(0)],
  ]
  let (reduced, transform) = lll_reduce(basis, delta=sb_rat(4, 5))
  assert_true(reduced.length() == 3 && transform.length() == 3)

  let swap_m : Matrix = [[sb_bi(1), sb_bi(2)], [sb_bi(3), sb_bi(4)]]
  swap_rows(swap_m, 0, 1)
  assert_true(
    swap_m[0][0].to_string() == "3" && swap_m[1][0].to_string() == "1",
  )

  let gs_basis : Matrix = [
    [sb_bi(1), sb_bi(0)],
    [sb_bi(2), sb_bi(0)],
    [sb_bi(3), sb_bi(0)],
  ]
  let (mu, _bnorm) = gram_schmidt(gs_basis)
  assert_true(mu[2][1].to_string() == "0")

  let k0_basis : Matrix = [[sb_bi(2), sb_bi(1)]]
  let k0_transform : Matrix = [[sb_bi(1)]]
  let k0_mu : Array[Array[@symnum.BigRational]] = [
    [@symnum.BigRational::zero()],
  ]
  size_reduce(k0_basis, k0_transform, k0_mu, 0)
  assert_true(k0_basis[0][0].to_string() == "2")
}
