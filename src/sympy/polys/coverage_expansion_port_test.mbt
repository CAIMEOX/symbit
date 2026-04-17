///|
fn cov_fezz(n : Int) -> FieldElem raise {
  @sympolys.fe_from_int(n, Domain::ZZ)
}

///|
fn cov_brat(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => abort("test rational expects a nonzero denominator")
  }
}

///|
fn cov_expr_rat(num : Int, den : Int) -> @symcore.Expr {
  @symcore.Expr::Number(cov_brat(num, den))
}

///|
fn cov_dup_from_ints(xs : Array[Int]) -> Array[FieldElem] raise {
  let out : Array[FieldElem] = Array::new()
  for x in xs {
    out.push(cov_fezz(x))
  }
  out
}

///|
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
fn cov_poly_norm(poly : Poly) -> String raise {
  sympy_normalize(poly.to_string()).trim().to_string()
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
    let monic_res : Result[String, Error] = try? monic(p.to_expr())
    match monic_res {
      Ok(s) => parts.push(s.trim().to_string())
      Err(_) => parts.push(p.to_string())
    }
  }
  parts.sort()
  parts.join("|")
}

///|
fn cov_poly_list_str(polys : Array[Poly]) -> String raise {
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
fn cov_fe_pow(base : FieldElem, exp : Int) -> FieldElem raise {
  let mut out = cov_fezz(1)
  for _ in 0..<exp {
    out = @sympolys.fe_mul(out, base)
  }
  out
}

///|
test "coverage: core helpers and leading-term API" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1),
  )
  assert_true(!p.is_zero())

  let p_scaled = p.scale_coeff(cov_fezz(3))
  let scaled = cov_poly_norm(p_scaled)
  let expected_scaled = sympy_normalize("3*x**2 + 6*x + 3").trim().to_string()
  assert_eq(scaled, expected_scaled)

  let p_grev = p.with_order(TermOrder::Grevlex)
  assert_true(p_grev.order == TermOrder::Grevlex)

  let lt1 = p.leading_term()
  let lt2 = p.leading_term_with_order(TermOrder::Lex)
  assert_eq(cov_lt_repr(lt1), cov_lt_repr(lt2))

  let as_expr = p.to_expr_with_order(TermOrder::Lex)
  let expr_norm = sympy_normalize(@symprint.pretty_string(as_expr))
    .trim()
    .to_string()
  let poly_norm = cov_poly_norm(p)
  assert_eq(expr_norm, poly_norm)
}

///|
test "coverage: dup_add_mul and dup_sub_mul consistency" {
  let f = cov_dup_from_ints([1, 2, 3])
  let g = cov_dup_from_ints([2, 0, 1])
  let h = cov_dup_from_ints([1, -1])

  let add_mul = @sympolys.dup_add_mul(f, g, h, Domain::ZZ)
  let add_ref = @sympolys.dup_add(
    f,
    @sympolys.dup_mul(g, h, Domain::ZZ),
    Domain::ZZ,
  )
  assert_eq(cov_dup_repr(add_mul), cov_dup_repr(add_ref))

  let sub_mul = @sympolys.dup_sub_mul(f, g, h, Domain::ZZ)
  let sub_ref = @sympolys.dup_sub(
    f,
    @sympolys.dup_mul(g, h, Domain::ZZ),
    Domain::ZZ,
  )
  assert_eq(cov_dup_repr(sub_mul), cov_dup_repr(sub_ref))
}

///|
test "coverage: dup_pdiv/prem/pquo and pseudo-division identity" {
  let f = cov_dup_from_ints([2, 0, -2, 4])
  let g = cov_dup_from_ints([3, -3, 0])
  let (q, r) = @sympolys.dup_pdiv(f, g, Domain::ZZ)
  let prem = @sympolys.dup_prem(f, g, Domain::ZZ)
  let pquo = @sympolys.dup_pquo(f, g, Domain::ZZ)
  assert_eq(cov_dup_repr(r), cov_dup_repr(prem))
  assert_eq(cov_dup_repr(q), cov_dup_repr(pquo))

  // Check lc(g)^n * f = q*g + r.
  let n = @sympolys.dup_degree(f) - @sympolys.dup_degree(g) + 1
  let c = cov_fe_pow(@sympolys.dup_LC(g), n)
  let lhs = @sympolys.dup_mul_term(f, c, 0, Domain::ZZ)
  let rhs = @sympolys.dup_add(
    @sympolys.dup_mul(q, g, Domain::ZZ),
    r,
    Domain::ZZ,
  )
  assert_eq(cov_dup_repr(lhs), cov_dup_repr(rhs))
}

///|
test "coverage: root upper/lower bound wrapper consistency" {
  let f = [1, 0, -2, 1]
  let poly = cov_dup_from_ints(f)
  let up = @sympolys.dup_root_upper_bound(poly, Domain::ZZ)
  let lo = @sympolys.dup_root_lower_bound(poly, Domain::ZZ)
  let up_ref = @sympolys.dup_cauchy_upper_bound(poly, Domain::ZZ)
  let lo_ref = @sympolys.dup_cauchy_lower_bound(poly, Domain::ZZ)
  assert_eq(up.to_string(), up_ref.to_string())
  assert_eq(lo.to_string(), lo_ref.to_string())
}

///|
test "coverage: galoistools scalar helpers" {
  assert_true(@sympolys.gf_LC([]) == 0 && @sympolys.gf_TC([]) == 0)
  assert_eq(@sympolys.gf_LC([0, 2, 3]), 0)
  assert_eq(@sympolys.gf_TC([0, 2, 3]), 3)

  let monic = @sympolys.gf_monic([2, 4, 2], 5)
  assert_eq("\{monic}", "[1, 2, 1]")

  let f = [1, 0, 1]
  let g = [1, 1]
  let (q, r) = @sympolys.gf_div(f, g, 5)
  let quo = @sympolys.gf_quo(f, g, 5)
  let rem = @sympolys.gf_rem(f, g, 5)
  assert_eq("\{q}", "\{quo}")
  assert_eq("\{r}", "\{rem}")
}

///|
test "coverage: qq_utils clear_denominators" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let poly = b.from_expr(cov_expr_rat(1, 2) * x + cov_expr_rat(1, 3))
  let lifted = @sympolys.clear_denominators(poly)
  match lifted.domain {
    Domain::ZZ => ()
    _ => fail("clear_denominators should lift to ZZ")
  }
  let ours = cov_poly_norm(lifted)
  let expected = sympy_normalize("3*x + 2").trim().to_string()
  assert_eq(ours, expected)
}

///|
test "coverage: lll_reduce transform reconstructs reduced basis" {
  let basis : Matrix = [
    [BigInt::from_int(1), BigInt::from_int(1), BigInt::from_int(1)],
    [BigInt::from_int(-1), BigInt::from_int(0), BigInt::from_int(2)],
    [BigInt::from_int(3), BigInt::from_int(5), BigInt::from_int(6)],
  ]
  let (reduced, transform) = @sympolys.lll_reduce(basis)
  assert_eq(reduced.length(), basis.length())
  assert_eq(transform.length(), basis.length())
  for i in 0..<basis.length() {
    assert_eq(reduced[i].length(), basis[i].length())
    assert_eq(transform[i].length(), basis.length())
    let mut all_zero = true
    for v in reduced[i] {
      if !v.is_zero() {
        all_zero = false
        break
      }
    }
    assert_true(!all_zero)
  }
}

///|
test "coverage: groebner_expr parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let exprs = [x * y - @symcore.int(1), y - @symcore.int(1)]
  let ours_basis = @sympolys.groebner_expr(
    exprs,
    gens=["x", "y"],
    domain=Domain::QQ,
    order=TermOrder::Lex,
  )
  let ours = cov_norm_basis(cov_groebner_basis_str(ours_basis))
  let oracle = cov_norm_basis(groebner(exprs, order="lex"))
  assert_eq(ours, oracle)
}

///|
test "coverage: resultant_poly multivariate output parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f = b.from_expr(x + y)
  let g = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let ours_poly = f.resultant_poly(g, 0)
  let ours = cov_poly_norm(ours_poly)
  let oracle = resultant(
      f.to_expr(),
      g.to_expr(),
      x="x",
      gens=["x", "y"],
      domain="QQ",
    )
    .trim()
    .to_string()
  let oracle_norm = sympy_normalize(oracle).trim().to_string()
  assert_eq(ours, oracle_norm)
}

///|
test "coverage: subresultants PG aliases" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let pg = @sympolys.subresultants_pg(p, q)
  let eu = @sympolys.euclid_q(p, q)
  assert_eq(cov_poly_list_str(pg), cov_poly_list_str(eu))
  let mpg = @sympolys.modified_subresultants_pg(p, q)
  let st = @sympolys.sturm_q(p, q)
  assert_eq(cov_poly_list_str(mpg), cov_poly_list_str(st))
}

///|
test "coverage: dense conversions and raw dict helpers" {
  let dense = cov_dup_from_ints([1, 0, -2])
  let poly = @sympolys.from_dense(dense, ["x"], Domain::ZZ)
  let back = @sympolys.to_dense(poly, degree=2)
  assert_eq(cov_dup_repr(back), cov_dup_repr(dense))

  let child_hi = @sympolys.dense_poly([
    @sympolys.dense_coef(cov_fezz(1)),
    @sympolys.dense_coef(cov_fezz(0)),
  ])
  let child_lo = @sympolys.dense_poly([@sympolys.dense_coef(cov_fezz(2))])
  let dmp = @sympolys.dense_poly([child_hi, child_lo])
  let raw = @sympolys.dmp_to_raw_dict(dmp, 1, Domain::ZZ)
  assert_eq(raw.length(), 2)
  match raw.get(1) {
    Some(v) =>
      if cov_dense_repr(v) != cov_dense_repr(child_hi) {
        fail("dmp_to_raw_dict high coeff mismatch")
      }
    None => fail("missing x^1 coefficient")
  }
  match raw.get(0) {
    Some(v) =>
      if cov_dense_repr(v) != cov_dense_repr(child_lo) {
        fail("dmp_to_raw_dict low coeff mismatch")
      }
    None => fail("missing x^0 coefficient")
  }
}

///|
test "coverage: monomial and field-element helper APIs" {
  let m1 = @sympolys.monomial_from_array([2, 1])
  let m2 = @sympolys.monomial_from_array([3, 2])
  let m3 = @sympolys.monomial_from_array([1, 3])
  let div12 = @sympolys.monomial_divides(m1, m2)
  let div21 = @sympolys.monomial_divides(m2, m1)
  assert_true(div12)
  assert_true(!div21)
  assert_true(@sympolys.compare_monomial_order(m1, m3, TermOrder::Lex) > 0)
  assert_eq(@sympolys.monomial_count(3, 2), 10)

  let neg = cov_fezz(-3)
  let pos = cov_fezz(3)
  assert_true(@sympolys.fe_is_zero(cov_fezz(0)))
  assert_true(@sympolys.fe_is_one(cov_fezz(1)))
  assert_true(@sympolys.fe_is_negative(neg) && !@sympolys.fe_is_positive(neg))
  assert_true(@sympolys.fe_is_positive(pos) && !@sympolys.fe_is_negative(pos))
  let inv2 = @sympolys.fe_inv(cov_fezz(2))
  let one = @sympolys.fe_mul(cov_fezz(2), inv2)
  assert_true(@sympolys.fe_is_one(one))
  let sub = @sympolys.fe_sub(cov_fezz(5), cov_fezz(2))
  let neg_sub = @sympolys.fe_neg(sub)
  assert_true(sub.to_string() == "3" && neg_sub.to_string() == "-3")
}

///|
test "coverage: core neg/sub APIs" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(3),
  )
  let q = b.from_expr(@symcore.int(3) * x - @symcore.int(1))
  let neg_p = cov_poly_norm(p.neg())
  let sub_pq = cov_poly_norm(p.sub(q))
  let expect_neg = sympy_normalize("-x**2 - 2*x - 3").trim().to_string()
  let expect_sub = sympy_normalize("x**2 - x + 4").trim().to_string()
  assert_eq(neg_p, expect_neg)
  assert_eq(sub_pq, expect_sub)
}

///|
test "coverage: content/primitive/pseudo_div_univar_int APIs" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let f = b.from_expr(
    @symcore.int(6) * (x ^ @symcore.int(2)) +
    @symcore.int(9) * x +
    @symcore.int(3),
  )
  let content = f.content()
  assert_eq(content.to_string(), "3")
  let primitive = f.primitive_part()
  let expect_primitive = sympy_normalize("2*x**2 + 3*x + 1").trim().to_string()
  assert_eq(cov_poly_norm(primitive), expect_primitive)

  let g = b.from_expr(@symcore.int(2) * x + @symcore.int(1))
  let (pq, pr, steps) = f.pseudo_div_univar_int(g)
  let lc = match g.leading_term() {
    Some((_, c)) => c
    None => fail("unexpected zero divisor")
  }
  let scaled_f = f.scale_coeff(cov_fe_pow(lc, steps))
  let rhs = pq.mul(g).add(pr)
  assert_eq(cov_poly_norm(scaled_f), cov_poly_norm(rhs))
}

///|
test "coverage: algebraic-extension public helpers" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let raw = b.from_expr(
    @symcore.int(2) * (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  let spec = @sympolys.alg_ext_spec(Domain::QQ, "x", raw)
  let normalized = @sympolys.normalize_alg_ext_spec(spec)
  let minpoly_norm = cov_poly_norm(normalized.minpoly)
  let expect_minpoly = sympy_normalize("x**2 + 1/2").trim().to_string()
  assert_eq(minpoly_norm, expect_minpoly)
  let ext = @sympolys.build_alg_extension(spec)
  match ext {
    Domain::AlgExt(base, gens, rels) => {
      assert_true(base is Domain::QQ)
      assert_eq(gens, ["x"])
      let rel = sympy_normalize(@symprint.pretty_string(rels[0]))
        .trim()
        .to_string()
      assert_eq(rel, expect_minpoly)
    }
    _ => fail("expected Domain::AlgExt")
  }
}

///|
test "coverage: gf_degree edge behavior" {
  assert_eq(@sympolys.gf_degree([]), -1)
  assert_eq(@sympolys.gf_degree([0]), 0)
  assert_eq(@sympolys.gf_degree([1, 0, 0]), 2)
}
