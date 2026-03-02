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
  let frac_coeff = try! ensure_coeff_domain(half, Domain::Frac(Domain::QQ))
  guard frac_coeff.to_string() == "1/2" else {
    fail("Frac ensure_coeff_domain mismatch")
  }

  let a = @symcore.symbol("a")
  let alg_domain = Domain::AlgExt(
    Domain::QQ,
    ["a"],
    [(a ^ @symcore.int(2)) + @symcore.int(1)],
  )
  let alg_coeff = try! ensure_coeff_domain(half, alg_domain)
  guard alg_coeff is FieldElem::AlgExt(_, _, _, _) else {
    fail("AlgExt ensure_coeff_domain should produce AlgExt coefficient")
  }

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let px = PolyBuilder::new(["x"], Domain::QQ).from_expr(x + @symcore.int(1))
  let pxy = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)
  let mul_mismatch_len : Result[Poly, PolyError] = try? px.mul(pxy)
  guard mul_mismatch_len is Err(PolyError::DomainMismatch) else {
    fail("expected DomainMismatch for mismatched generator arity")
  }

  let py = PolyBuilder::new(["y"], Domain::QQ).from_expr(y + @symcore.int(1))
  let mul_mismatch_name : Result[Poly, PolyError] = try? px.mul(py)
  guard mul_mismatch_name is Err(PolyError::DomainMismatch) else {
    fail("expected DomainMismatch for mismatched generator names")
  }

  let neg_pow : Result[Poly, PolyError] = try? px.pow(-1)
  guard neg_pow is Err(PolyError::BadExponent) else {
    fail("expected BadExponent for negative polynomial power")
  }

  guard Domain::Frac(Domain::QQ) == Domain::Frac(Domain::QQ) else {
    fail("Domain::Frac equality failed")
  }
  guard alg_domain == alg_domain else { fail("Domain::AlgExt equality failed") }

  let bad_gen = PolyError::BadGenerator("u")
  inspect("\{bad_gen}", content="BadGenerator(u)")
  inspect("\{PolyError::NonPolynomial}", content="NonPolynomial")
  inspect("\{PolyError::BadExponent}", content="BadExponent")
  inspect("\{PolyError::DomainMismatch}", content="DomainMismatch")
  inspect("\{PolyError::CoefficientNotInteger}", content="CoefficientNotInteger")
  inspect("\{PolyError::DomainNotField}", content="DomainNotField")
  inspect("\{PolyError::DivisionByZero}", content="DivisionByZero")
  inspect(
    "\{PolyError::ExactQuotientFailed}",
    content="ExactQuotientFailed",
  )
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
  guard bad_mod is Err(PolyError::BadModulus) else {
    fail("GF(1) should raise BadModulus")
  }

  let den_zero : Result[@symnum.BigRational, PolyError] = try? normalize_mod(
    sb_rat(1, 5),
    Domain::GF(5),
  )
  guard den_zero is Err(PolyError::DivisionByZero) else {
    fail("1/5 over GF(5) should raise DivisionByZero")
  }

  let frac_norm = try! normalize_mod(sb_rat(8, 3), Domain::Frac(Domain::GF(7)))
  guard frac_norm.to_string() == "5" else {
    fail("Frac(GF(7)) normalization mismatch: \{frac_norm.to_string()}")
  }

  let inv_fail : Result[@symnum.BigRational, PolyError] = try? normalize_mod(
    sb_rat(1, 2),
    Domain::GF(4),
  )
  guard inv_fail is Err(PolyError::DivisionByZero) else {
    fail("GF(4) inverse failure should raise DivisionByZero")
  }
}

///|
test "small branches: dense conversion guard branches" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let pxy = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)

  let non_uni : Result[Array[FieldElem], PolyError] = try? to_dense(pxy)
  guard non_uni is Err(PolyError::NotUnivariate) else {
    fail("to_dense on multivariate should raise NotUnivariate")
  }

  let bad_from_dense : Result[Poly, PolyError] = try? from_dense(
    [sb_feqq(1, 1)],
    ["x", "y"],
    Domain::QQ,
  )
  guard bad_from_dense is Err(PolyError::NotUnivariate) else {
    fail("from_dense with two generators should raise NotUnivariate")
  }

  let bad_to_dense_shape : Result[Array[FieldElem], PolyError] = try? to_dense_multi(
    pxy,
    [2],
  )
  guard bad_to_dense_shape is Err(PolyError::BadGenerator(_)) else {
    fail("to_dense_multi bad shape should raise BadGenerator")
  }

  let malformed_coeffs : Map[Monomial, FieldElem] = Map::new()
  malformed_coeffs.set(Monomial::{ exps: [1] }, sb_feqq(1, 1))
  let malformed_poly = Poly::{
    coeffs: malformed_coeffs,
    gens: ["x", "y"],
    domain: Domain::QQ,
    order: TermOrder::Lex,
  }
  let malformed_dense = try! to_dense_multi(malformed_poly, [1, 1])
  guard malformed_dense.all(c => fe_is_zero(c)) else {
    fail("malformed exponent length should be skipped")
  }

  let out_of_range_coeffs : Map[Monomial, FieldElem] = Map::new()
  out_of_range_coeffs.set(Monomial::{ exps: [3, 0] }, sb_feqq(1, 1))
  let out_of_range_poly = Poly::{
    coeffs: out_of_range_coeffs,
    gens: ["x", "y"],
    domain: Domain::QQ,
    order: TermOrder::Lex,
  }
  let out_of_range_dense = try! to_dense_multi(out_of_range_poly, [1, 1])
  guard out_of_range_dense.all(c => fe_is_zero(c)) else {
    fail("out-of-range exponent should be skipped")
  }

  let bad_from_dense_multi_shape : Result[Poly, PolyError] = try? from_dense_multi(
    [sb_feqq(1, 1)],
    ["x"],
    Domain::QQ,
    [1, 1],
  )
  guard bad_from_dense_multi_shape is Err(PolyError::BadGenerator(_)) else {
    fail("from_dense_multi bad shape should raise BadGenerator")
  }

  let bad_from_dense_multi_len : Result[Poly, PolyError] = try? from_dense_multi(
    [sb_feqq(1, 1)],
    ["x", "y"],
    Domain::QQ,
    [1, 1],
  )
  guard bad_from_dense_multi_len is Err(PolyError::BadGenerator(_)) else {
    fail("from_dense_multi dense-length mismatch should raise BadGenerator")
  }
}

///|
test "small branches: lll helper branches" {
  let (empty_reduced, empty_transform) = try! lll_reduce([])
  guard empty_reduced.length() == 0 && empty_transform.length() == 0 else {
    fail("lll_reduce([]) should return empty matrices")
  }

  let ragged : Matrix = [[sb_bi(1)], [sb_bi(1), sb_bi(2)]]
  let ragged_res : Result[(Matrix, Matrix), PolyError] = try? lll_reduce(ragged)
  guard ragged_res is Err(PolyError::DomainMismatch) else {
    fail("ragged matrix should raise DomainMismatch")
  }

  let basis : Matrix = [
    [sb_bi(1), sb_bi(1), sb_bi(1)],
    [sb_bi(1), sb_bi(0), sb_bi(0)],
    [sb_bi(0), sb_bi(1), sb_bi(0)],
  ]
  let (reduced, transform) = try! lll_reduce(basis, delta=sb_rat(4, 5))
  guard reduced.length() == 3 && transform.length() == 3 else {
    fail("lll_reduce with explicit delta should preserve matrix shape")
  }

  let swap_m : Matrix = [[sb_bi(1), sb_bi(2)], [sb_bi(3), sb_bi(4)]]
  swap_rows(swap_m, 0, 1)
  guard swap_m[0][0].to_string() == "3" && swap_m[1][0].to_string() == "1" else {
    fail("swap_rows should swap rows in-place")
  }

  let gs_basis : Matrix = [
    [sb_bi(1), sb_bi(0)],
    [sb_bi(2), sb_bi(0)],
    [sb_bi(3), sb_bi(0)],
  ]
  let (mu, _bnorm) = gram_schmidt(gs_basis)
  guard mu[2][1].to_string() == "0" else {
    fail("gram_schmidt zero-norm projection branch mismatch")
  }

  let k0_basis : Matrix = [[sb_bi(2), sb_bi(1)]]
  let k0_transform : Matrix = [[sb_bi(1)]]
  let k0_mu : Array[Array[@symnum.BigRational]] = [[@symnum.BigRational::zero()]]
  size_reduce(k0_basis, k0_transform, k0_mu, 0)
  guard k0_basis[0][0].to_string() == "2" else {
    fail("size_reduce(k=0) should be a no-op")
  }
}
