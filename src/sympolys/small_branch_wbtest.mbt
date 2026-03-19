///|
fn sb_rat(num : Int, den : Int) -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
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
  assert_eq(frac_coeff.to_string(), "1/2")

  let a = @symcore.symbol("a")
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [
    (a ^ @symcore.int(2)) + @symcore.int(1),
  ])
  let alg_coeff = ensure_coeff_domain(half, alg_domain)
  assert_true(alg_coeff is FieldElem::AlgExt(_, _, _, _))

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let px = PolyBuilder::new(["x"], Domain::QQ).from_expr(x + @symcore.int(1))
  let pxy = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)
  let mul_mismatch_len : Result[Poly, PolyError] = try? px.mul(pxy)
  assert_true(mul_mismatch_len is Err(PolyError::DomainMismatch))

  let py = PolyBuilder::new(["y"], Domain::QQ).from_expr(y + @symcore.int(1))
  let mul_mismatch_name : Result[Poly, PolyError] = try? px.mul(py)
  assert_true(mul_mismatch_name is Err(PolyError::DomainMismatch))

  let neg_pow : Result[Poly, PolyError] = try? px.pow(-1)
  assert_true(neg_pow is Err(PolyError::BadExponent))

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
  let bad_mod : Result[@symnum.BigRational, PolyError] = try? normalize_mod(
    sb_rat(1, 2),
    Domain::GF(1),
  )
  assert_true(bad_mod is Err(PolyError::BadModulus))

  let den_zero : Result[@symnum.BigRational, PolyError] = try? normalize_mod(
    sb_rat(1, 5),
    Domain::GF(5),
  )
  assert_true(den_zero is Err(PolyError::DivisionByZero))

  let frac_norm = normalize_mod(sb_rat(8, 3), Domain::Frac(Domain::GF(7)))
  assert_eq(frac_norm.to_string(), "5")

  let inv_fail : Result[@symnum.BigRational, PolyError] = try? normalize_mod(
    sb_rat(1, 2),
    Domain::GF(4),
  )
  assert_true(inv_fail is Err(PolyError::DivisionByZero))
}

///|
test "small branches: dense conversion guard branches" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let pxy = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)

  let non_uni : Result[Array[FieldElem], PolyError] = try? to_dense(pxy)
  assert_true(non_uni is Err(PolyError::NotUnivariate))

  let bad_from_dense : Result[Poly, PolyError] = try? from_dense(
    [sb_feqq(1, 1)],
    ["x", "y"],
    Domain::QQ,
  )
  assert_true(bad_from_dense is Err(PolyError::NotUnivariate))

  let bad_to_dense_shape : Result[Array[FieldElem], PolyError] = try? to_dense_multi(
    pxy,
    [2],
  )
  assert_true(bad_to_dense_shape is Err(PolyError::BadGenerator(_)))

  let malformed_coeffs : Map[Monomial, FieldElem] = Map::new()
  malformed_coeffs.set(Monomial::{ exps: [1] }, sb_feqq(1, 1))
  let malformed_poly = Poly::{
    coeffs: malformed_coeffs,
    gens: ["x", "y"],
    domain: Domain::QQ,
    order: TermOrder::Lex,
  }
  let malformed_dense = to_dense_multi(malformed_poly, [1, 1])
  assert_true(malformed_dense.all(c => fe_is_zero(c)))

  let out_of_range_coeffs : Map[Monomial, FieldElem] = Map::new()
  out_of_range_coeffs.set(Monomial::{ exps: [3, 0] }, sb_feqq(1, 1))
  let out_of_range_poly = Poly::{
    coeffs: out_of_range_coeffs,
    gens: ["x", "y"],
    domain: Domain::QQ,
    order: TermOrder::Lex,
  }
  let out_of_range_dense = to_dense_multi(out_of_range_poly, [1, 1])
  assert_true(out_of_range_dense.all(c => fe_is_zero(c)))

  let bad_from_dense_multi_shape : Result[Poly, PolyError] = try? from_dense_multi(
    [sb_feqq(1, 1)],
    ["x"],
    Domain::QQ,
    [1, 1],
  )
  assert_true(bad_from_dense_multi_shape is Err(PolyError::BadGenerator(_)))

  let bad_from_dense_multi_len : Result[Poly, PolyError] = try? from_dense_multi(
    [sb_feqq(1, 1)],
    ["x", "y"],
    Domain::QQ,
    [1, 1],
  )
  assert_true(bad_from_dense_multi_len is Err(PolyError::BadGenerator(_)))
}

///|
test "small branches: lll helper branches" {
  let (empty_reduced, empty_transform) = lll_reduce([])
  assert_true(empty_reduced.length() == 0 && empty_transform.length() == 0)

  let ragged : Matrix = [[sb_bi(1)], [sb_bi(1), sb_bi(2)]]
  let ragged_res : Result[(Matrix, Matrix), PolyError] = try? lll_reduce(ragged)
  assert_true(ragged_res is Err(PolyError::DomainMismatch))

  let basis : Matrix = [
    [sb_bi(1), sb_bi(1), sb_bi(1)],
    [sb_bi(1), sb_bi(0), sb_bi(0)],
    [sb_bi(0), sb_bi(1), sb_bi(0)],
  ]
  let (reduced, transform) = lll_reduce(basis, delta=sb_rat(4, 5))
  assert_true(reduced.length() == 3 && transform.length() == 3)

  let swap_m : Matrix = [[sb_bi(1), sb_bi(2)], [sb_bi(3), sb_bi(4)]]
  swap_rows(swap_m, 0, 1)
  assert_true(swap_m[0][0].to_string() == "3" && swap_m[1][0].to_string() == "1")

  let gs_basis : Matrix = [
    [sb_bi(1), sb_bi(0)],
    [sb_bi(2), sb_bi(0)],
    [sb_bi(3), sb_bi(0)],
  ]
  let (mu, _bnorm) = gram_schmidt(gs_basis)
  assert_eq(mu[2][1].to_string(), "0")

  let k0_basis : Matrix = [[sb_bi(2), sb_bi(1)]]
  let k0_transform : Matrix = [[sb_bi(1)]]
  let k0_mu : Array[Array[@symnum.BigRational]] = [
    [@symnum.BigRational::zero()],
  ]
  size_reduce(k0_basis, k0_transform, k0_mu, 0)
  assert_eq(k0_basis[0][0].to_string(), "2")
}
