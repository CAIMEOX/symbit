///|
fn nf_wb_iv_text(iv : (@symnum.BigRational, @symnum.BigRational)) -> String {
  "(\{iv.0}, \{iv.1})"
}

///|
fn nf_wb_factor_text(items : Array[(Int, Int)]) -> String {
  let parts : Array[String] = []
  for item in items {
    parts.push("(\{item.0},\{item.1})")
  }
  let body = parts.join(",")
  "[\{body}]"
}

///|
fn nf_wb_factor_pair_text(
  item : (Array[(Int, Int)], Array[(Int, Int)]),
) -> String {
  "\{nf_wb_factor_text(item.0)}||\{nf_wb_factor_text(item.1)}"
}

///|
fn nf_wb_coeff_search_text(values : Array[Array[Int]]) -> String {
  let rows : Array[String] = []
  for row in values {
    let body = row.map(v => v.to_string()).join(",")
    rows.push("[\{body}]")
  }
  let body = rows.join(",")
  "[\{body}]"
}

///|
fn nf_wb_rat_coeffs_text(value : Array[@symnum.BigRational]?) -> String {
  match value {
    Some(items) => "[" + items.map(c => c.to_string()).join(",") + "]"
    None => "None"
  }
}

///|
fn nf_wb_exprs_text(values : Array[Expr]) -> String {
  "[" + values.map(e => @symprint.pretty_string(e)).join(", ") + "]"
}

///|
test "numberfields utilities: rational predicates and numerator denominator" {
  let half = @symnum.BigRational::from_ints(1, 2) catch { _ => fail("half") }
  let neg_int = @symnum.BigRational::from_ints(-6, 3) catch {
    _ => fail("neg-int")
  }

  inspect(is_rat(half), content="true")
  inspect(is_int(half), content="false")
  inspect(is_int(neg_int), content="true")

  let reduced = @symnum.BigRational::from_ints(-6, 8) catch {
    _ => fail("reduced")
  }
  let (num, den) = get_num_denom(reduced)
  inspect("(\{num}, \{den})", content="(-3, 4)")
  inspect(
    to_col([3, -2, 5]).to_matrix_string(),
    content="Matrix([[3], [-2], [5]])",
  )
  inspect(
    is_sq_maxrank_HNF(
      domain_matrix_from_ints([[2, 1, 0], [0, 3, 2], [0, 0, 5]], Domain::ZZ),
    ),
    content="true",
  )
  inspect(
    is_sq_maxrank_HNF(domain_matrix_from_ints([[2, 3], [0, 1]], Domain::ZZ)),
    content="false",
  )
  inspect(nf_wb_exprs_text(s_vars(4)), content="[s1, s2, s3, s4]")
  inspect(nf_wb_exprs_text(s_vars(0)), content="[]")
}

///|
test "numberfields utilities: supplement a subspace" {
  let basis = domain_matrix_from_ints([[1, 2], [7, 3], [0, 4]], Domain::QQ)
  inspect(
    supplement_a_subspace(basis).to_matrix_string(),
    content="Matrix([[1, 2, 1], [7, 3, 0], [0, 4, 0]])",
  )
  let line = domain_matrix_from_ints([[1], [0], [0]], Domain::QQ)
  inspect(
    supplement_a_subspace(line).to_matrix_string(),
    content="Matrix([[1, 0, 0], [0, 1, 0], [0, 0, 1]])",
  )
}

///|
test "numberfields utilities: fundamental discriminant extraction" {
  inspect(
    nf_wb_factor_pair_text(extract_fundamental_discriminant(-432)),
    content="[(-1,1),(3,1)]||[(2,2),(3,1)]",
  )
  inspect(
    nf_wb_factor_pair_text(extract_fundamental_discriminant(12)),
    content="[(2,2),(3,1)]||[]",
  )
  inspect(
    nf_wb_factor_pair_text(extract_fundamental_discriminant(5)),
    content="[(5,1)]||[]",
  )
  sympolys_assert_error(
    fn() raise PolyError { extract_fundamental_discriminant(2) },
    "DomainMismatch",
  )
}

///|
test "numberfields utilities: coefficient search prefix" {
  inspect(
    nf_wb_coeff_search_text(coeff_search(2, 1, count=13)),
    content="[[1,1],[1,0],[1,-1],[0,1],[2,2],[2,1],[2,0],[2,-1],[2,-2],[1,2],[1,-2],[0,2],[3,3]]",
  )
  inspect(nf_wb_coeff_search_text(coeff_search(0, 1, count=5)), content="[]")
  inspect(nf_wb_coeff_search_text(coeff_search(3, 0, count=5)), content="[]")
}

///|
test "numberfields frontdoors: isolate rational and real radicals" {
  let half = @symcore.rational_from_ints(1, 2)
  inspect(nf_wb_iv_text(isolate(half)), content="(1/2, 1/2)")

  let sqrt2 = int(2) ^ @symcore.rational_from_ints(1, 2)
  inspect(nf_wb_iv_text(isolate(sqrt2)), content="(1, 2)")
  inspect(nf_wb_iv_text(isolate(int(0) - sqrt2)), content="(-2, -1)")
  inspect(nf_wb_iv_text(isolate(int(2) * sqrt2)), content="(2, 3)")
}

///|
test "numberfields frontdoors: field isomorphism algorithm aliases" {
  let half = @symcore.rational_from_ints(1, 2)
  let sqrt2 = int(2) ^ half
  let sqrt8 = int(8) ^ half
  let sqrt3 = int(3) ^ half

  inspect(
    nf_wb_rat_coeffs_text(field_isomorphism_pslq(sqrt2, sqrt8)),
    content="[1/2,0]",
  )
  inspect(
    nf_wb_rat_coeffs_text(field_isomorphism_factor(sqrt2, sqrt8)),
    content="[1/2,0]",
  )
  inspect(
    nf_wb_rat_coeffs_text(field_isomorphism_pslq(sqrt2, sqrt3)),
    content="None",
  )
  inspect(
    nf_wb_rat_coeffs_text(field_isomorphism_factor(sqrt2, sqrt3)),
    content="None",
  )
}

///|
test "numberfields frontdoors: round_two and prime decomposition" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  inspect(
    round_two(b.from_expr((x ^ int(2)) - int(2))),
    content="(Submodule[[1, 0], [0, 1]], 8)",
  )
  inspect(
    round_two(b.from_expr((x ^ int(2)) - int(5))),
    content="(Submodule[[2, 0], [1, 1]]/2, 5)",
  )
  let inert = prime_decomp(3, b.from_expr((x ^ int(2)) - int(2)))
  inspect(inert.map(item => item.to_string()).join(" | "), content="(3)")
  let ramified = prime_decomp(2, b.from_expr((x ^ int(2)) - int(2)))
  inspect(ramified.map(item => item.to_string()).join(" | "), content="(2, x)")
  inspect(prime_valuation(8, ramified[0]), content="6")
}

///|
test "numberfields frontdoors: make_mod_elt preserves module flavor" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let pb = numberfield_power_basis(b.from_expr((x ^ int(2)) - int(2)))
  let power_elt = make_mod_elt(pb, [1N, 2N], denom=3N) catch {
    _ => fail("power element")
  }
  inspect(power_elt.type_name(), content="PowerBasisElement")
  inspect(power_elt, content="[1, 2]/3")

  let sm = numberfield_submodule([[1N, 0N], [0N, 1N]]) catch {
    _ => fail("submodule")
  }
  let module_elt = make_mod_elt(sm, [1N, 2N], denom=3N) catch {
    _ => fail("module element")
  }
  inspect(module_elt.type_name(), content="ModuleElement")
  inspect(module_elt, content="[1, 2]/3")

  sympolys_assert_error(
    fn() raise PolyError { make_mod_elt(pb, [1N, 2N], denom=0N) },
    "DivisionByZero",
  )
  sympolys_assert_error(
    fn() raise PolyError { make_mod_elt(pb, [1N]) },
    "DomainMismatch",
  )
}

///|
test "numberfields frontdoors: find_min_poly for quadratic power basis elements" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let pb = numberfield_power_basis(b.from_expr((x ^ int(2)) - int(2)))
  let theta = make_mod_elt(pb, [0N, 1N]) catch { _ => fail("theta") }
  inspect(
    @symprint.pretty_string(find_min_poly(theta, Domain::QQ).to_expr()),
    content="x**2 - 2",
  )
  let shifted = make_mod_elt(pb, [1N, 1N]) catch { _ => fail("shifted") }
  inspect(
    @symprint.pretty_string(find_min_poly(shifted, Domain::QQ).to_expr()),
    content="x**2 - 2*x - 1",
  )
  let scaled = make_mod_elt(pb, [1N, 2N], denom=3N) catch {
    _ => fail("scaled")
  }
  inspect(
    @symprint.pretty_string(find_min_poly(scaled, Domain::QQ).to_expr()),
    content="x**2 - 2*x - 7",
  )
  let constant = make_mod_elt(pb, [2N, 0N], denom=3N) catch {
    _ => fail("constant")
  }
  inspect(
    @symprint.pretty_string(find_min_poly(constant, Domain::QQ).to_expr()),
    content="x - 2",
  )
}
