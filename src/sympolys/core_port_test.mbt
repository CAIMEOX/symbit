///|
test "core: add/mul/pow parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let p = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1),
  )
  let q = b.from_expr(x + @symcore.int(3))
  let add = p.add(q)
  let mul = p.mul(q)
  let pow = q.pow(2)
  let add_ours = add.to_string()
  guard @sympy_polys.expr_equal(add_ours, "x**2 + 2*x + 1 + x + 3") else {
    fail("add mismatch: ours=\{add_ours}")
  }
  let mul_ours = mul.to_string()
  guard @sympy_polys.expr_equal(mul_ours, "(x**2 + 2*x + 1)*(x + 3)") else {
    fail("mul mismatch: ours=\{mul_ours}")
  }
  let pow_ours = pow.to_string()
  guard @sympy_polys.expr_equal(pow_ours, "(x + 3)**2") else {
    fail("pow mismatch: ours=\{pow_ours}")
  }
}

///|
test "core: domain mismatch raises" {
  let x = @symcore.symbol("x")
  let p = PolyBuilder::new(["x"], Domain::ZZ).from_expr(x + @symcore.int(1))
  let q = PolyBuilder::new(["x"], Domain::QQ).from_expr(x + @symcore.int(1))
  let res : Result[Poly, PolyError] = try? p.add(q)
  guard res is Err(PolyError::DomainMismatch) else {
    fail("expected DomainMismatch")
  }
}

///|
test "core: add_term merges to zero" {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  let mono = monomial_one(1)
  add_term(coeffs, mono, fe_from_int(1, Domain::ZZ), Domain::ZZ)
  add_term(coeffs, mono, fe_from_int(-1, Domain::ZZ), Domain::ZZ)
  guard coeffs.length() == 0 else {
    fail("expected zero after canceling terms")
  }
}

///|
test "core: ensure_coeff_domain parity in GF" {
  let c = try! @symnum.BigRational::new(
    BigInt::from_int(3),
    BigInt::from_int(2),
  )
  let fe = ensure_coeff_domain(c, Domain::GF(5))
  let ours = fe.to_string()
  let oracle = @sympy_polys.mod_rational(3, 2, 5).trim().to_string()
  guard ours == oracle else {
    fail("GF coeff mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "core: ensure_coeff_domain rejects non-integral in ZZ" {
  let c = try! @symnum.BigRational::new(
    BigInt::from_int(1),
    BigInt::from_int(2),
  )
  let res : Result[FieldElem, PolyError] = try? ensure_coeff_domain(
    c,
    Domain::ZZ,
  )
  guard res is Err(PolyError::CoefficientNotInteger) else {
    fail("expected CoefficientNotInteger")
  }
}
