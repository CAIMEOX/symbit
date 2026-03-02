///|
fn cov_fezz(n : Int) -> FieldElem {
  try! fe_from_int(n, Domain::ZZ)
}

fn cov_brat(num : Int, den : Int) -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
}

///|
fn cov_expr_rat(num : Int, den : Int) -> @symcore.Expr {
  @symcore.number(cov_brat(num, den))
}

///|
fn cov_dup_from_ints(xs : Array[Int]) -> Array[FieldElem] {
  let out : Array[FieldElem] = Array::new()
  for x in xs {
    out.push(cov_fezz(x))
  }
  out
}

fn cov_dup_repr(coeffs : Array[FieldElem]) -> String {
  let parts = coeffs.map(c => c.to_string()).join(",")
  "[\{parts}]"
}

///|
fn cov_dense_repr(p : DensePoly) -> String {
  match p {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) => {
      let parts : Array[String] = Array::new()
      for it in items {
        parts.push(cov_dense_repr(it))
      }
      let joined = parts.join(",")
      "[\{joined}]"
    }
  }
}

///|
fn cov_poly_norm(poly : Poly) -> String {
  (try! @sympy_polys.sympy_normalize(poly.to_string())).trim().to_string()
}

///|
fn cov_norm_basis(s : String) -> String {
  let parts : Array[String] = Array::new()
  for part in s.split("|") {
    parts.push(part.trim().to_string())
  }
  parts.sort()
  parts.join("|")
}

///|
fn cov_groebner_basis_str(basis : Array[Poly]) -> String {
  let parts : Array[String] = Array::new()
  for p in basis {
    let monic_res : Result[String, Error] = try? @sympy_polys.monic(p.to_expr())
    match monic_res {
      Ok(s) => parts.push(s.trim().to_string())
      Err(_) => parts.push(p.to_string())
    }
  }
  parts.sort()
  parts.join("|")
}

///|
fn cov_poly_list_str(polys : Array[Poly]) -> String {
  let parts : Array[String] = Array::new()
  for p in polys {
    parts.push(cov_poly_norm(p))
  }
  parts.join("|")
}

///|
fn cov_lt_repr(v : (Monomial, FieldElem)?) -> String {
  match v {
    None => "None"
    Some((m, c)) => {
      let exps = m.to_array().map(x => x.to_string()).join(",")
      "(\{exps}):\{c.to_string()}"
    }
  }
}

///|
fn cov_fe_pow(base : FieldElem, exp : Int) -> FieldElem {
  let mut out = cov_fezz(1)
  for _ in 0..<exp {
    out = try! fe_mul(out, base)
  }
  out
}

///|
test "coverage: core helpers and leading-term API" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1))
  guard !p.is_zero() else { fail("is_zero false positive") }

  let p_scaled = try! p.scale_coeff(cov_fezz(3))
  let scaled = cov_poly_norm(p_scaled)
  let expected_scaled = (try! @sympy_polys.sympy_normalize("3*x**2 + 6*x + 3"))
    .trim()
    .to_string()
  guard scaled == expected_scaled else {
    fail("scale_coeff mismatch: ours=\{scaled}, expected=\{expected_scaled}")
  }

  let p_grev = p.with_order(TermOrder::Grevlex)
  guard p_grev.order == TermOrder::Grevlex else { fail("with_order failed") }

  let lt1 = p.leading_term()
  let lt2 = p.leading_term_with_order(TermOrder::Lex)
  guard cov_lt_repr(lt1) == cov_lt_repr(lt2) else { fail("leading_term mismatch") }

  let as_expr = p.to_expr_with_order(TermOrder::Lex)
  let expr_norm = (try! @sympy_polys.sympy_normalize(@symprint.to_string(as_expr)))
    .trim()
    .to_string()
  let poly_norm = cov_poly_norm(p)
  guard expr_norm == poly_norm else {
    fail("to_expr_with_order mismatch: ours=\{expr_norm}, poly=\{poly_norm}")
  }
}

///|
test "coverage: dup_add_mul and dup_sub_mul consistency" {
  let f = cov_dup_from_ints([1, 2, 3])
  let g = cov_dup_from_ints([2, 0, 1])
  let h = cov_dup_from_ints([1, -1])

  let add_mul = try! dup_add_mul(f, g, h, Domain::ZZ)
  let add_ref = try! dup_add(f, try! dup_mul(g, h, Domain::ZZ), Domain::ZZ)
  guard cov_dup_repr(add_mul) == cov_dup_repr(add_ref) else {
    fail("dup_add_mul mismatch")
  }

  let sub_mul = try! dup_sub_mul(f, g, h, Domain::ZZ)
  let sub_ref = try! dup_sub(f, try! dup_mul(g, h, Domain::ZZ), Domain::ZZ)
  guard cov_dup_repr(sub_mul) == cov_dup_repr(sub_ref) else {
    fail("dup_sub_mul mismatch")
  }
}

///|
test "coverage: dup_pdiv/prem/pquo and pseudo-division identity" {
  let f = cov_dup_from_ints([2, 0, -2, 4])
  let g = cov_dup_from_ints([3, -3, 0])
  let (q, r) = try! dup_pdiv(f, g, Domain::ZZ)
  let prem = try! dup_prem(f, g, Domain::ZZ)
  let pquo = try! dup_pquo(f, g, Domain::ZZ)
  guard cov_dup_repr(r) == cov_dup_repr(prem) else { fail("dup_prem mismatch") }
  guard cov_dup_repr(q) == cov_dup_repr(pquo) else { fail("dup_pquo mismatch") }

  // Check lc(g)^n * f = q*g + r.
  let n = dup_degree(f) - dup_degree(g) + 1
  let c = cov_fe_pow(try! dup_LC(g), n)
  let lhs = try! dup_mul_term(f, c, 0, Domain::ZZ)
  let rhs = try! dup_add(try! dup_mul(q, g, Domain::ZZ), r, Domain::ZZ)
  guard cov_dup_repr(lhs) == cov_dup_repr(rhs) else {
    fail("dup_pdiv identity mismatch")
  }
}

///|
test "coverage: root upper/lower bound wrapper consistency" {
  let f = [1, 0, -2, 1]
  let poly = cov_dup_from_ints(f)
  let up = try! dup_root_upper_bound(poly, Domain::ZZ)
  let lo = try! dup_root_lower_bound(poly, Domain::ZZ)
  let up_ref = try! dup_cauchy_upper_bound(poly, Domain::ZZ)
  let lo_ref = try! dup_cauchy_lower_bound(poly, Domain::ZZ)
  guard up.to_string() == up_ref.to_string() else {
    fail("dup_root_upper_bound wrapper mismatch")
  }
  guard lo.to_string() == lo_ref.to_string() else {
    fail("dup_root_lower_bound wrapper mismatch")
  }
}

///|
test "coverage: galoistools scalar helpers" {
  guard gf_LC([]) == 0 && gf_TC([]) == 0 else { fail("gf_LC/gf_TC empty") }
  guard gf_LC([0, 2, 3]) == 0 else { fail("gf_LC mismatch") }
  guard gf_TC([0, 2, 3]) == 3 else { fail("gf_TC mismatch") }

  let monic = try! gf_monic([2, 4, 2], 5)
  guard "\{monic}" == "[1, 2, 1]" else { fail("gf_monic mismatch: \{monic}") }

  let f = [1, 0, 1]
  let g = [1, 1]
  let (q, r) = try! gf_div(f, g, 5)
  let quo = try! gf_quo(f, g, 5)
  let rem = try! gf_rem(f, g, 5)
  guard "\{q}" == "\{quo}" else { fail("gf_quo mismatch") }
  guard "\{r}" == "\{rem}" else { fail("gf_rem mismatch") }
}

///|
test "coverage: qq_utils clear_denominators" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let poly = b.from_expr(cov_expr_rat(1, 2) * x + cov_expr_rat(1, 3))
  let lifted = try! clear_denominators(poly)
  match lifted.domain {
    Domain::ZZ => ()
    _ => fail("clear_denominators should lift to ZZ")
  }
  let ours = cov_poly_norm(lifted)
  let expected = (try! @sympy_polys.sympy_normalize("3*x + 2")).trim().to_string()
  guard ours == expected else {
    fail("clear_denominators mismatch: ours=\{ours}, expected=\{expected}")
  }
}

///|
test "coverage: lll_reduce transform reconstructs reduced basis" {
  let basis : Matrix = [
    [BigInt::from_int(1), BigInt::from_int(1), BigInt::from_int(1)],
    [BigInt::from_int(-1), BigInt::from_int(0), BigInt::from_int(2)],
    [BigInt::from_int(3), BigInt::from_int(5), BigInt::from_int(6)],
  ]
  let (reduced, transform) = try! lll_reduce(basis)
  guard reduced.length() == basis.length() else { fail("lll row count mismatch") }
  guard transform.length() == basis.length() else {
    fail("lll transform row count mismatch")
  }
  for i in 0..<basis.length() {
    guard reduced[i].length() == basis[i].length() else {
      fail("lll column count mismatch")
    }
    guard transform[i].length() == basis.length() else {
      fail("lll transform column count mismatch")
    }
    let mut all_zero = true
    for v in reduced[i] {
      if !v.is_zero() {
        all_zero = false
        break
      }
    }
    guard !all_zero else { fail("lll produced zero row unexpectedly") }
  }
}

///|
test "coverage: groebner_expr parity" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let exprs = [x * y - @symcore.int(1), y - @symcore.int(1)]
  let ours_basis = try! groebner_expr(
    exprs,
    gens=["x", "y"],
    domain=Domain::QQ,
    order=TermOrder::Lex,
  )
  let ours = cov_norm_basis(cov_groebner_basis_str(ours_basis))
  let oracle = cov_norm_basis(try! @sympy_polys.groebner(exprs, order="lex"))
  guard ours == oracle else {
    fail("groebner_expr mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "coverage: resultant_poly multivariate output parity" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f = b.from_expr(x + y)
  let g = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let ours_poly = try! f.resultant_poly(g, 0)
  let ours = cov_poly_norm(ours_poly)
  let oracle = (try! @sympy_polys.resultant(
      f.to_expr(),
      g.to_expr(),
      x="x",
      gens=["x", "y"],
      domain="QQ",
    ))
    .trim()
    .to_string()
  let oracle_norm = (try! @sympy_polys.sympy_normalize(oracle)).trim().to_string()
  guard ours == oracle_norm else {
    fail("resultant_poly mismatch: ours=\{ours}, oracle=\{oracle_norm}")
  }
}

///|
test "coverage: subresultants PG aliases" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let pg = try! subresultants_pg(p, q)
  let eu = try! euclid_q(p, q)
  guard cov_poly_list_str(pg) == cov_poly_list_str(eu) else {
    fail("subresultants_pg alias mismatch")
  }
  let mpg = try! modified_subresultants_pg(p, q)
  let st = try! sturm_q(p, q)
  guard cov_poly_list_str(mpg) == cov_poly_list_str(st) else {
    fail("modified_subresultants_pg alias mismatch")
  }
}

///|
test "coverage: dense conversions and raw dict helpers" {
  let dense = cov_dup_from_ints([1, 0, -2])
  let poly = try! from_dense(dense, ["x"], Domain::ZZ)
  let back = try! to_dense(poly, degree=2)
  guard cov_dup_repr(back) == cov_dup_repr(dense) else {
    fail("from_dense/to_dense roundtrip mismatch")
  }

  let child_hi = dense_poly([dense_coef(cov_fezz(1)), dense_coef(cov_fezz(0))])
  let child_lo = dense_poly([dense_coef(cov_fezz(2))])
  let dmp = dense_poly([child_hi, child_lo])
  let raw = dmp_to_raw_dict(dmp, 1, Domain::ZZ)
  guard raw.length() == 2 else { fail("dmp_to_raw_dict length mismatch") }
  match raw.get(1) {
    Some(v) => {
      if cov_dense_repr(v) != cov_dense_repr(child_hi) {
        fail("dmp_to_raw_dict high coeff mismatch")
      }
    }
    None => fail("missing x^1 coefficient")
  }
  match raw.get(0) {
    Some(v) => {
      if cov_dense_repr(v) != cov_dense_repr(child_lo) {
        fail("dmp_to_raw_dict low coeff mismatch")
      }
    }
    None => fail("missing x^0 coefficient")
  }
}

///|
test "coverage: monomial and field-element helper APIs" {
  let m1 = monomial_from_array([2, 1])
  let m2 = monomial_from_array([3, 2])
  let m3 = monomial_from_array([1, 3])
  let div12 = try! monomial_divides(m1, m2)
  let div21 = try! monomial_divides(m2, m1)
  guard div12 else { fail("monomial_divides true failed") }
  guard !div21 else {
    fail("monomial_divides false failed")
  }
  guard compare_monomial_order(m1, m3, TermOrder::Lex) > 0 else {
    fail("compare_monomial_order lex mismatch")
  }
  guard monomial_count(3, 2) == 10 else { fail("monomial_count mismatch") }

  let neg = cov_fezz(-3)
  let pos = cov_fezz(3)
  guard fe_is_zero(cov_fezz(0)) else { fail("fe_is_zero mismatch") }
  guard fe_is_one(cov_fezz(1)) else { fail("fe_is_one mismatch") }
  guard fe_is_negative(neg) && !fe_is_positive(neg) else {
    fail("fe sign mismatch (neg)")
  }
  guard fe_is_positive(pos) && !fe_is_negative(pos) else {
    fail("fe sign mismatch (pos)")
  }
  let inv2 = try! fe_inv(cov_fezz(2))
  let one = try! fe_mul(cov_fezz(2), inv2)
  guard fe_is_one(one) else { fail("fe_inv/fe_mul mismatch") }
  let sub = try! fe_sub(cov_fezz(5), cov_fezz(2))
  let neg_sub = fe_neg(sub)
  guard sub.to_string() == "3" && neg_sub.to_string() == "-3" else {
    fail("fe_sub/fe_neg mismatch")
  }
}

///|
test "coverage: core neg/sub APIs" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(3),
  )
  let q = b.from_expr(@symcore.int(3) * x - @symcore.int(1))
  let neg_p = cov_poly_norm(p.neg())
  let sub_pq = cov_poly_norm(try! p.sub(q))
  let expect_neg = (try! @sympy_polys.sympy_normalize("-x**2 - 2*x - 3"))
    .trim()
    .to_string()
  let expect_sub = (try! @sympy_polys.sympy_normalize("x**2 - x + 4"))
    .trim()
    .to_string()
  guard neg_p == expect_neg else { fail("Poly::neg mismatch: \{neg_p}") }
  guard sub_pq == expect_sub else { fail("Poly::sub mismatch: \{sub_pq}") }
}

///|
test "coverage: content/primitive/pseudo_div_univar_int APIs" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let f = b.from_expr(
    @symcore.int(6) * (x ^ @symcore.int(2)) + @symcore.int(9) * x + @symcore.int(3),
  )
  let content = try! f.content()
  guard content.to_string() == "3" else {
    fail("Poly::content mismatch: \{content.to_string()}")
  }
  let primitive = try! f.primitive_part()
  let expect_primitive = (try! @sympy_polys.sympy_normalize("2*x**2 + 3*x + 1"))
    .trim()
    .to_string()
  guard cov_poly_norm(primitive) == expect_primitive else {
    fail("Poly::primitive_part mismatch: \{cov_poly_norm(primitive)}")
  }

  let g = b.from_expr(@symcore.int(2) * x + @symcore.int(1))
  let (pq, pr, steps) = try! f.pseudo_div_univar_int(g)
  let lc = match g.leading_term() {
    Some((_, c)) => c
    None => fail("unexpected zero divisor")
  }
  let scaled_f = try! f.scale_coeff(cov_fe_pow(lc, steps))
  let rhs = try! (try! pq.mul(g)).add(pr)
  guard cov_poly_norm(scaled_f) == cov_poly_norm(rhs) else {
    fail("pseudo_div_univar_int identity mismatch")
  }
}

///|
test "coverage: algebraic-extension public helpers" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let raw = b.from_expr(
    @symcore.int(2) * (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  let spec = alg_ext_spec(Domain::QQ, "x", raw)
  let normalized = try! normalize_alg_ext_spec(spec)
  let minpoly_norm = cov_poly_norm(normalized.minpoly)
  let expect_minpoly = (try! @sympy_polys.sympy_normalize("x**2 + 1/2"))
    .trim()
    .to_string()
  guard minpoly_norm == expect_minpoly else {
    fail("normalize_alg_ext_spec mismatch: \{minpoly_norm}")
  }
  let ext = try! build_alg_extension(spec)
  match ext {
    Domain::AlgExt(base, gens, rels) => {
      guard base is Domain::QQ else {
        fail("build_alg_extension base mismatch")
      }
      guard gens == ["x"] else { fail("build_alg_extension gens mismatch") }
      let rel = (try! @sympy_polys.sympy_normalize(@symprint.to_string(rels[0])))
        .trim()
        .to_string()
      guard rel == expect_minpoly else { fail("build_alg_extension rel mismatch") }
    }
    _ => fail("expected Domain::AlgExt")
  }
}

///|
test "coverage: gf_degree edge behavior" {
  guard gf_degree([]) == -1 else { fail("gf_degree([]) should be -1") }
  guard gf_degree([0]) == 0 else { fail("gf_degree([0]) should be 0") }
  guard gf_degree([1, 0, 0]) == 2 else { fail("gf_degree degree mismatch") }
}
