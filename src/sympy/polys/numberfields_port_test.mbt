///|
fn nf_norm(expr : @symcore.Expr) -> String raise {
  sympy_normalize(@symprint.pretty_string(expr))
  .trim()
  .to_string()
  .replace_all(old=" ", new="")
}

///|
fn nf_oracle_minpoly(expr : String, gen? : String = "x") -> String raise {
  sympy_normalize(numberfield_minpoly(expr, gen~))
  .trim()
  .to_string()
  .replace_all(old=" ", new="")
}

///|
fn nf_oracle_find_min_poly_power_basis(
  def_expr : String,
  col : Array[Int],
  denom? : Int = 1,
) -> String raise {
  sympy_normalize(find_min_poly_power_basis(def_expr, col, denom~))
  .trim()
  .to_string()
  .replace_all(old=" ", new="")
}

///|
fn nf_coeffs_norm(coeffs : Array[@symnum.BigRational]?) -> String {
  match coeffs {
    Some(items) => {
      let body = items.map(c => c.to_string()).join(",")
      "[\{body}]"
    }
    None => "None"
  }
}

///|
fn nf_reps_norm(reps : Array[Array[@symnum.BigRational]]) -> String {
  let outer = reps.map(rep => {
    let body = rep.map(c => c.to_string()).join(",")
    "[\{body}]"
  })
  let joined = outer.join(",")
  "[\{joined}]"
}

///|
fn nf_factor_norm(items : Array[(Int, Int)]) -> String {
  let parts : Array[String] = []
  for item in items {
    parts.push("(\{item.0},\{item.1})")
  }
  let body = parts.join(",")
  "[\{body}]"
}

///|
fn nf_factor_pair_norm(item : (Array[(Int, Int)], Array[(Int, Int)])) -> String {
  "\{nf_factor_norm(item.0)}||\{nf_factor_norm(item.1)}"
}

///|
fn nf_num_denom_norm(value : @symnum.BigRational) -> String {
  let (num, den) = @sympolys.get_num_denom(value)
  "(\{num},\{den})"
}

///|
fn nf_coeff_search_norm(values : Array[Array[Int]]) -> String {
  let rows : Array[String] = []
  for row in values {
    let body = row.map(v => v.to_string()).join(",")
    rows.push("[\{body}]")
  }
  let body = rows.join(",")
  "[\{body}]"
}

///|
fn nf_mod_elt_summary(value : @sympolys.ModuleElement) -> String {
  "\{value.type_name()}:\{value}"
}

///|
fn nf_exprs_norm(values : Array[@symcore.Expr]) -> String {
  let body = values.map(e => @symprint.pretty_string(e)).join(",")
  "[\{body}]"
}

///|
test "numberfields: utility frontdoor parity" {
  let half = @symnum.BigRational::from_ints(1, 2) catch { _ => fail("half") }
  let minus_three_halves = @symnum.BigRational::from_ints(-3, 2) catch {
    _ => fail("minus-three-halves")
  }
  let two = @symnum.BigRational::from_int(2)

  assert_eq(@sympolys.is_rat(half), numberfield_is_rat("1/2"))
  assert_eq(@sympolys.is_int(half), numberfield_is_int("1/2"))
  assert_eq(@sympolys.is_int(two), numberfield_is_int("2"))
  assert_eq(
    nf_num_denom_norm(minus_three_halves),
    numberfield_get_num_denom("-3/2"),
  )
  assert_eq(
    @sympolys.to_col([3, -2, 5]).to_matrix_string().replace_all(old=" ", new=""),
    numberfield_to_col([3, -2, 5]).replace_all(old=" ", new=""),
  )
  assert_eq(
    nf_exprs_norm(@sympolys.s_vars(4)),
    numberfield_s_vars(4).replace_all(old=" ", new=""),
  )
  assert_eq(nf_exprs_norm(@sympolys.s_vars(0)), numberfield_s_vars(0))
  let hnf_true = [[2, 1, 0], [0, 3, 2], [0, 0, 5]]
  let hnf_bad_bound = [[2, 3], [0, 1]]
  assert_eq(
    @sympolys.is_sq_maxrank_HNF(
      @sympolys.domain_matrix_from_ints(hnf_true, @sympolys.Domain::ZZ),
    ),
    numberfield_is_sq_maxrank_HNF(hnf_true),
  )
  assert_eq(
    @sympolys.is_sq_maxrank_HNF(
      @sympolys.domain_matrix_from_ints(hnf_bad_bound, @sympolys.Domain::ZZ),
    ),
    numberfield_is_sq_maxrank_HNF(hnf_bad_bound),
  )
  let x = @symcore.Expr::Symbol("x")
  let b = @sympolys.PolyBuilder::new(["x"], @sympolys.Domain::ZZ)
  let pb = @sympolys.numberfield_power_basis(
    b.from_expr((x ^ @symcore.int(2)) - @symcore.int(2)),
  )
  let power_elt = @sympolys.make_mod_elt(pb, [1N, 2N], denom=3N)
  assert_eq(
    nf_mod_elt_summary(power_elt),
    make_mod_elt_power_basis("x**2 - 2", [1, 2], denom=3),
  )
  let sm = @sympolys.numberfield_submodule([[1N, 0N], [0N, 1N]])
  let module_elt = @sympolys.make_mod_elt(sm, [1N, 2N], denom=3N)
  assert_eq(
    nf_mod_elt_summary(module_elt),
    make_mod_elt_submodule("x**2 - 2", [[1, 0], [0, 1]], [1, 2], denom=3),
  )
  let subspace_rows = [[1, 2], [7, 3], [0, 4]]
  assert_eq(
    @sympolys.supplement_a_subspace(
      @sympolys.domain_matrix_from_ints(subspace_rows, @sympolys.Domain::QQ),
    )
    .to_matrix_string()
    .replace_all(old=" ", new=""),
    numberfield_supplement_a_subspace(subspace_rows, "QQ").replace_all(
      old=" ",
      new="",
    ),
  )

  for a in [-432, -4, 5, 8, 12] {
    let ours = nf_factor_pair_norm(
      @sympolys.extract_fundamental_discriminant(a),
    )
    let oracle = numberfield_extract_fundamental_discriminant(a)
    assert_eq(ours, oracle)
  }

  assert_eq(
    nf_coeff_search_norm(@sympolys.coeff_search(2, 1, count=13)),
    numberfield_coeff_search(2, 1, 13),
  )
  assert_eq(
    nf_coeff_search_norm(@sympolys.coeff_search(3, 1, count=8)),
    numberfield_coeff_search(3, 1, 8),
  )
}

///|
test "numberfields: minpoly parity for rationals and radicals" {
  let q = @symcore.rational_from_ints(3, 2)
  let q_mp = @sympolys.minpoly(q, gen="x")
  let q_ours = nf_norm(q_mp.to_expr())
  let q_oracle = nf_oracle_minpoly("3/2", gen="x")
  assert_eq(q_ours, q_oracle)

  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let s_mp = @sympolys.minpoly(sqrt2, gen="x")
  let s_ours = nf_norm(s_mp.to_expr())
  let s_oracle = nf_oracle_minpoly("sqrt(2)", gen="x")
  assert_eq(s_ours, s_oracle)
}

///|
test "numberfields: find_min_poly power-basis parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = @sympolys.PolyBuilder::new(["x"], @sympolys.Domain::ZZ)
  let pb = @sympolys.numberfield_power_basis(
    b.from_expr((x ^ @symcore.int(2)) - @symcore.int(2)),
  )

  let theta = @sympolys.make_mod_elt(pb, [0N, 1N])
  assert_eq(
    nf_norm(@sympolys.find_min_poly(theta, @sympolys.Domain::QQ).to_expr()),
    nf_oracle_find_min_poly_power_basis("x**2 - 2", [0, 1]),
  )

  let shifted = @sympolys.make_mod_elt(pb, [1N, 1N])
  assert_eq(
    nf_norm(@sympolys.find_min_poly(shifted, @sympolys.Domain::QQ).to_expr()),
    nf_oracle_find_min_poly_power_basis("x**2 - 2", [1, 1]),
  )

  let scaled = @sympolys.make_mod_elt(pb, [1N, 2N], denom=3N)
  assert_eq(
    nf_norm(@sympolys.find_min_poly(scaled, @sympolys.Domain::QQ).to_expr()),
    nf_oracle_find_min_poly_power_basis("x**2 - 2", [1, 2], denom=3),
  )

  let constant = @sympolys.make_mod_elt(pb, [2N, 0N], denom=3N)
  assert_eq(
    nf_norm(@sympolys.find_min_poly(constant, @sympolys.Domain::QQ).to_expr()),
    nf_oracle_find_min_poly_power_basis("x**2 - 2", [2, 0], denom=3),
  )
}

///|
test "numberfields: affine radical minpoly parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let one_third = @symcore.rational_from_ints(1, 3)
  let sqrt2 = @symcore.int(2) ^ half

  let shifted = @symcore.int(1) + sqrt2
  let shifted_ours = nf_norm(@sympolys.minpoly(shifted, gen="x").to_expr())
  let shifted_oracle = nf_oracle_minpoly("1 + sqrt(2)", gen="x")
  assert_eq(shifted_ours, shifted_oracle)

  let scaled = @symcore.int(3) * sqrt2 - one_third
  let scaled_ours = nf_norm(@sympolys.minpoly(scaled, gen="x").to_expr())
  let scaled_oracle = nf_oracle_minpoly("3*sqrt(2) - 1/3", gen="x")
  assert_eq(scaled_ours, scaled_oracle)
}

///|
test "numberfields: multiquadratic minpoly parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half
  let sqrt6 = @symcore.int(6) ^ half

  let cases = [
    (sqrt2 + sqrt3, "sqrt(2) + sqrt(3)"),
    (sqrt2 * sqrt3, "sqrt(2)*sqrt(3)"),
    (@symcore.int(1) + sqrt2 + sqrt3, "1 + sqrt(2) + sqrt(3)"),
    (sqrt2 + sqrt3 + sqrt6, "sqrt(2) + sqrt(3) + sqrt(6)"),
  ]

  for item in cases {
    let (expr, oracle_expr) = item
    let ours = nf_norm(@sympolys.minpoly(expr, gen="x").to_expr())
    let oracle = nf_oracle_minpoly(oracle_expr, gen="x")
    assert_eq(ours, oracle)
  }
}

///|
test "numberfields: perfect-power radicals reduce to true minpoly" {
  let third = @symcore.rational_from_ints(1, 3)
  let quarter = @symcore.rational_from_ints(1, 4)

  let cbrt8 = @symcore.int(8) ^ third
  let mp_cbrt8 = nf_norm(@sympolys.minpoly(cbrt8, gen="x").to_expr())
  let oracle_cbrt8 = nf_oracle_minpoly("8**(1/3)", gen="x")
  assert_eq(mp_cbrt8, oracle_cbrt8)

  let fourth4 = @symcore.int(4) ^ quarter
  let mp_fourth4 = nf_norm(@sympolys.minpoly(fourth4, gen="x").to_expr())
  let oracle_fourth4 = nf_oracle_minpoly("4**(1/4)", gen="x")
  assert_eq(mp_fourth4, oracle_fourth4)

  let one_sixteenth = @symcore.rational_from_ints(1, 16)
  let fourth_small = one_sixteenth ^ quarter
  let mp_small = nf_norm(@sympolys.minpoly(fourth_small, gen="x").to_expr())
  let oracle_small = nf_oracle_minpoly("(1/16)**(1/4)", gen="x")
  assert_eq(mp_small, oracle_small)
}

///|
test "numberfields: @sympolys.to_number_field(expr, theta) coeff parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half
  let sqrt5 = @symcore.int(5) ^ half
  let theta = sqrt2 + sqrt3

  let ours_s2 = nf_coeffs_norm(
    Some(@sympolys.to_number_field_coeffs(sqrt2, theta)),
  )
  let oracle_s2 = numberfield_to_number_field_coeffs(
    "sqrt(2)", "sqrt(2) + sqrt(3)",
  ).replace_all(old=" ", new="")
  assert_eq(ours_s2, oracle_s2)

  let ours_s3 = nf_coeffs_norm(
    Some(@sympolys.to_number_field_coeffs(sqrt3, theta)),
  )
  let oracle_s3 = numberfield_to_number_field_coeffs(
    "sqrt(3)", "sqrt(2) + sqrt(3)",
  ).replace_all(old=" ", new="")
  assert_eq(ours_s3, oracle_s3)

  let fail_case : Result[Array[@symnum.BigRational], PolyError] = try? @sympolys.to_number_field_coeffs(
    sqrt5, theta,
  )
  match fail_case {
    Ok(value) => fail("expected embedding failure for sqrt(5), got \{value}")
    Err(_) => ()
  }
}

///|
test "numberfields: to_number_field and primitive_element parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half
  let k = @sympolys.to_number_field(sqrt2, gen="a")
  match k {
    Domain::AlgExt(base, gens, rels) => {
      assert_true(base is Domain::QQ && gens.equal(["a"]) && rels.length() == 1)
      let rel = nf_norm(rels[0])
      assert_eq(rel, "a**2-2")
    }
    _ => fail("expected algebraic extension domain")
  }

  let (prim, coeffs) = @sympolys.primitive_element([sqrt2, sqrt3])
  assert_eq(coeffs, [1, 1])
  let prim_norm = nf_norm(prim)
  let oracle_coeffs = numberfield_primitive_coeffs(
    ["sqrt(2)", "sqrt(3)"],
    gen="x",
  )
  assert_eq(coeffs, oracle_coeffs)
  assert_eq(prim_norm, nf_norm(sqrt2 + sqrt3))
}

///|
test "numberfields: primitive_element ex reps parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half

  let (prim, coeffs, reps) = @sympolys.primitive_element_ex([sqrt2, sqrt3])
  assert_eq(coeffs, [1, 1])
  assert_eq(nf_norm(prim), nf_norm(sqrt2 + sqrt3))

  let oracle_coeffs = numberfield_primitive_coeffs(
    ["sqrt(2)", "sqrt(3)"],
    gen="x",
  )
  assert_eq(coeffs, oracle_coeffs)

  let ours_reps = nf_reps_norm(reps)
  let oracle_reps = numberfield_primitive_reps(["sqrt(2)", "sqrt(3)"], gen="x").replace_all(
    old=" ",
    new="",
  )
  assert_eq(ours_reps, oracle_reps)
}

///|
test "numberfields: field_isomorphic parity for simple algebraic fields" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half

  let qa = @sympolys.to_number_field(sqrt2, gen="a")
  let qb = @sympolys.to_number_field(sqrt2, gen="b")
  let qc = @sympolys.to_number_field(sqrt3, gen="c")

  let ours_same = @sympolys.field_isomorphic(qa, qb)
  let ours_diff = @sympolys.field_isomorphic(qa, qc)

  let oracle_same = numberfield_field_isomorphic("sqrt(2)", "sqrt(2)")
  let oracle_diff = numberfield_field_isomorphic("sqrt(2)", "sqrt(3)")

  assert_eq(ours_same, oracle_same)
  assert_eq(ours_diff, oracle_diff)
}

///|
test "numberfields: subfield field_isomorphism coefficient parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt8 = @symcore.int(8) ^ half
  let sqrt3 = @symcore.int(3) ^ half

  let cases = [
    (sqrt2, @symcore.int(-1) * sqrt2, "sqrt(2)", "-sqrt(2)"),
    (sqrt2, sqrt8, "sqrt(2)", "sqrt(8)"),
    (@symcore.int(1) + sqrt2, sqrt2, "1 + sqrt(2)", "sqrt(2)"),
    (
      @symcore.int(1) + @symcore.int(2) * sqrt2,
      @symcore.int(-3) + @symcore.int(4) * sqrt8,
      "1 + 2*sqrt(2)",
      "-3 + 4*sqrt(8)",
    ),
    (sqrt2, sqrt2 + sqrt3, "sqrt(2)", "sqrt(2) + sqrt(3)"),
    (sqrt3, sqrt2 + sqrt3, "sqrt(3)", "sqrt(2) + sqrt(3)"),
    (
      sqrt2,
      @symcore.int(4) ^ @symcore.rational_from_ints(1, 4),
      "sqrt(2)",
      "4**(1/4)",
    ),
    (@symcore.rational_from_ints(3, 2), sqrt2, "3/2", "sqrt(2)"),
    (sqrt2, @symcore.rational_from_ints(3, 2), "sqrt(2)", "3/2"),
    (sqrt2, sqrt3, "sqrt(2)", "sqrt(3)"),
  ]

  for item in cases {
    let lhs = item.0
    let rhs = item.1
    let lhs_str = item.2
    let rhs_str = item.3
    let ours = nf_coeffs_norm(@sympolys.field_isomorphism(lhs, rhs))
    let oracle = numberfield_field_isomorphism_coeffs(lhs_str, rhs_str).replace_all(
      old=" ",
      new="",
    )
    assert_eq(ours, oracle)
  }
}

///|
test "numberfields: field_isomorphism algorithm alias parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt8 = @symcore.int(8) ^ half
  let sqrt3 = @symcore.int(3) ^ half

  let oracle = numberfield_field_isomorphism_coeffs("sqrt(2)", "sqrt(8)").replace_all(
    old=" ",
    new="",
  )
  assert_eq(
    nf_coeffs_norm(@sympolys.field_isomorphism_pslq(sqrt2, sqrt8)),
    oracle,
  )
  assert_eq(
    nf_coeffs_norm(@sympolys.field_isomorphism_factor(sqrt2, sqrt8)),
    oracle,
  )
  assert_eq(
    nf_coeffs_norm(@sympolys.field_isomorphism_pslq(sqrt2, sqrt3)),
    numberfield_field_isomorphism_coeffs("sqrt(2)", "sqrt(3)").replace_all(
      old=" ",
      new="",
    ),
  )
}

///|
test "numberfields: is_isomorphism_possible basic sanity" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half
  let sqrt8 = @symcore.int(8) ^ half
  let theta = sqrt2 + sqrt3

  assert_true(@sympolys.is_isomorphism_possible(sqrt2, sqrt8))
  assert_true(@sympolys.is_isomorphism_possible(sqrt2, sqrt3))
  assert_true(@sympolys.is_isomorphism_possible(sqrt2, theta))
  assert_true(
    @sympolys.is_isomorphism_possible(@symcore.rational_from_ints(3, 2), sqrt2),
  )
}
