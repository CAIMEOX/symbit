///|
test "alg_ext wb: validation error branches are typed" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")

  let minpoly = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  let bad_gen_res : Result[AlgExtSpec, PolyError] = try? normalize_alg_ext_spec(
    alg_ext_spec(Domain::QQ, "y", minpoly),
  )
  guard bad_gen_res is Err(PolyError::BadGenerator(_)) else {
    fail("expected BadGenerator for mismatched generator")
  }

  let dom_mismatch_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(x + @symcore.int(1))
  let dom_mismatch : Result[AlgExtSpec, PolyError] = try? normalize_alg_ext_spec(
    alg_ext_spec(Domain::ZZ, "x", dom_mismatch_poly),
  )
  guard dom_mismatch is Err(PolyError::DomainMismatch) else {
    fail("expected DomainMismatch when base/domain differ")
  }

  let constant_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(@symcore.int(5))
  let bad_exp : Result[AlgExtSpec, PolyError] = try? normalize_alg_ext_spec(
    alg_ext_spec(Domain::QQ, "x", constant_poly),
  )
  guard bad_exp is Err(PolyError::BadExponent) else {
    fail("expected BadExponent for constant minpoly")
  }

  let non_monic_zz = PolyBuilder::new(["x"], Domain::ZZ).from_expr(
    @symcore.int(2) * (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  let non_field : Result[AlgExtSpec, PolyError] = try? normalize_alg_ext_spec(
    alg_ext_spec(Domain::ZZ, "x", non_monic_zz),
  )
  guard non_field is Err(PolyError::DomainNotField) else {
    fail("expected DomainNotField for non-monic ZZ minpoly")
  }

  let _ = y // keep both symbols in this scope as a cheap guard against dead code elimination assumptions
}

///|
test "alg_ext wb: make_monic_if_field handles zero polynomial explicitly" {
  let zero = Poly::zero(["x"], Domain::QQ)
  let res : Result[Poly, PolyError] = try? make_monic_if_field(zero)
  guard res is Err(PolyError::NonPolynomial) else {
    fail("expected NonPolynomial for zero minpoly in make_monic_if_field")
  }
}
