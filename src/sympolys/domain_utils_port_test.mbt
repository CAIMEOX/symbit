///|
fn expr_rat_du(n : Int, d : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(n, d)
}

///|
test "domain_utils: normalize_mod parity over GF(p)" {
  let r1 = try! @symnum.BigRational::new(
    BigInt::from_int(3),
    BigInt::from_int(2),
  )
  let got1 = normalize_mod(r1, Domain::GF(5)).to_string()
  let oracle1 = @sympy_polys.mod_rational(3, 2, 5).trim().to_string()
  guard got1 == oracle1 else {
    fail("normalize_mod GF(5) mismatch: ours=\{got1}, oracle=\{oracle1}")
  }
  let r2 = try! @symnum.BigRational::new(
    BigInt::from_int(-7),
    BigInt::from_int(3),
  )
  let got2 = normalize_mod(r2, Domain::GF(5)).to_string()
  let oracle2 = @sympy_polys.mod_rational(-7, 3, 5).trim().to_string()
  guard got2 == oracle2 else {
    fail("normalize_mod GF(5) mismatch: ours=\{got2}, oracle=\{oracle2}")
  }
}

///|
test "domain_utils: normalize_mod leaves QQ/ZZ unchanged" {
  let r = try! @symnum.BigRational::new(
    BigInt::from_int(5),
    BigInt::from_int(7),
  )
  let got_q = normalize_mod(r, Domain::QQ).to_string()
  let oracle_q = @sympy_polys.poly_expr(
      expr_rat_du(5, 7),
      gens=["x"],
      domain="QQ",
    )
    .trim()
    .to_string()
  guard got_q == oracle_q else {
    fail("normalize_mod QQ mismatch: ours=\{got_q}, oracle=\{oracle_q}")
  }
  let r2 = try! @symnum.BigRational::new(
    BigInt::from_int(4),
    BigInt::from_int(1),
  )
  let got_z = normalize_mod(r2, Domain::ZZ).to_string()
  let oracle_z = @sympy_polys.poly_expr(
      @symcore.int(4),
      gens=["x"],
      domain="ZZ",
    )
    .trim()
    .to_string()
  guard got_z == oracle_z else {
    fail("normalize_mod ZZ mismatch: ours=\{got_z}, oracle=\{oracle_z}")
  }
}

///|
test "domain_utils: GF/QQ/ZZ coercions align with SymPy" {
  let x = @symcore.symbol("x")
  let expr = expr_rat_du(3, 2) * x + expr_rat_du(1, 3)
  let gf_poly = PolyBuilder::new(["x"], Domain::GF(5)).from_expr(expr)
  let gf_ours = sympy_normalize(gf_poly.to_string()).trim().to_string()
  let c1 = @sympy_polys.mod_rational(3, 2, 5)
  let c0 = @sympy_polys.mod_rational(1, 3, 5)
  let gf_expected = "\{c1}*x + \{c0}"
  let gf_oracle = @sympy_polys.sympy_normalize(gf_expected).trim().to_string()
  guard gf_ours == gf_oracle else {
    fail("GF coercion mismatch: ours=\{gf_ours}, oracle=\{gf_oracle}")
  }
  let qq_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(expr)
  let qq_ours = sympy_normalize(qq_poly.to_string()).trim().to_string()
  let qq_oracle = @sympy_polys.poly_expr(expr, gens=["x"], domain="QQ")
    .trim()
    .to_string()
  guard qq_ours == qq_oracle else {
    fail("QQ coercion mismatch: ours=\{qq_ours}, oracle=\{qq_oracle}")
  }
  let zz_poly = PolyBuilder::new(["x"], Domain::ZZ).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1),
  )
  let zz_ours = sympy_normalize(zz_poly.to_string()).trim().to_string()
  let zz_oracle = @sympy_polys.poly_expr(
      (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1),
      gens=["x"],
      domain="ZZ",
    )
    .trim()
    .to_string()
  guard zz_ours == zz_oracle else {
    fail("ZZ coercion mismatch: ours=\{zz_ours}, oracle=\{zz_oracle}")
  }
}
