///|
fn order_to_sympy(order : TermOrder) -> String {
  match order {
    TermOrder::Lex => "lex"
    TermOrder::Grlex => "grlex"
    TermOrder::Grevlex => "grevlex"
    TermOrder::Ilex => "ilex"
    TermOrder::Igrlex => "igrlex"
    TermOrder::Igrevlex => "igrevlex"
  }
}

///|
fn normalize_basis_str(s : String) -> String {
  let parts : Array[String] = Array::new()
  for part in s.split("|") {
    let raw = part.to_string()
    let trimmed = raw.trim().to_string()
    parts.push(trimmed)
  }
  parts.sort()
  parts.join("|")
}

///|
fn tuple_int_string(values : Array[Int]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "(\{joined})"
}

///|
fn f5_signature_string(s : @sympolys.Signature) -> String {
  "(\{tuple_int_string(s.0.to_array())}, \{s.1})"
}

///|
fn f5_lbp_string(f : @sympolys.LabeledPolynomial) -> String {
  "\{f5_signature_string(f.0)}|\{f.1.to_string()}|\{f.2}"
}

///|
fn expect_groebner_same(polys : Array[Poly], order : TermOrder) -> Unit raise {
  let basis = Poly::groebner(polys, order~)
  let ours = normalize_basis_str(groebner_to_string(basis))
  let exprs = polys.map(p => p.to_expr())
  let oracle = normalize_basis_str(groebner(exprs, order=order_to_sympy(order)))
  assert_eq(ours, oracle)
}

///|
test "groebnertools: simple lex pair" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f1 = b.from_expr(x * y - @symcore.int(1))
  let f2 = b.from_expr(x - @symcore.int(1))
  expect_groebner_same([f1, f2], TermOrder::Lex)
}

///|
test "groebnertools: spoly and basis predicates parity" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f1 = b.from_expr(x * y - @symcore.int(1))
  let f2 = b.from_expr(x - @symcore.int(1))

  let ours_s = sympy_normalize(@sympolys.spoly(f1, f2).to_string())
  let oracle_s = sympy_normalize(
    groebnertools_spoly(f1.to_expr(), f2.to_expr(), gens=["x", "y"]),
  )
  assert_eq(ours_s, oracle_s)

  let basis = Poly::groebner([f1, f2], order=TermOrder::Lex)
  let basis_exprs = basis.map(p => p.to_expr())
  assert_eq(
    @sympolys.is_groebner(basis).to_string(),
    is_groebner(basis_exprs, gens=["x", "y"]),
  )
  assert_eq(
    @sympolys.is_minimal(basis).to_string(),
    is_minimal(basis_exprs, gens=["x", "y"]),
  )
  assert_eq(
    @sympolys.is_reduced(basis).to_string(),
    is_reduced(basis_exprs, gens=["x", "y"]),
  )
  assert_eq(
    normalize_basis_str(groebner_to_string(@sympolys.red_groebner(basis))),
    normalize_basis_str(red_groebner(basis_exprs, gens=["x", "y"])),
  )
  assert_eq(
    @sympolys.is_groebner([f1, f2]).to_string(),
    is_groebner([f1.to_expr(), f2.to_expr()], gens=["x", "y"]),
  )
}

///|
test "groebnertools: gcd and lcm parity" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let f = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(2)))
  let g = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(3)))
  assert_eq(
    sympy_normalize(@sympolys.groebner_gcd(f, g).to_string()),
    sympy_normalize(groebnertools_gcd(f.to_expr(), g.to_expr(), gens=["x"])),
  )
  assert_eq(
    sympy_normalize(@sympolys.groebner_lcm(f, g).to_string()),
    sympy_normalize(groebnertools_lcm(f.to_expr(), g.to_expr(), gens=["x"])),
  )
}

///|
test "groebnertools: f5 signature helper parity" {
  assert_eq(
    @sympolys.sig_cmp(
      @sympolys.sig(@sympolys.monomial_from_array([0, 3]), 3),
      @sympolys.sig(@sympolys.monomial_from_array([1, 0]), 3),
      @sympolys.TermOrder::Lex,
    ).to_string(),
    groebnertools_sig_cmp([0, 3], 3, [1, 0], 3, gens=["x", "y"]),
  )
  assert_eq(
    @sympolys.sig_cmp(
      @sympolys.sig(@sympolys.monomial_from_array([1, 0]), 2),
      @sympolys.sig(@sympolys.monomial_from_array([1, 0]), 3),
      @sympolys.TermOrder::Lex,
    ).to_string(),
    groebnertools_sig_cmp([1, 0], 2, [1, 0], 3, gens=["x", "y"]),
  )
  assert_eq(
    f5_signature_string(
      @sympolys.sig_mult(
        @sympolys.sig(@sympolys.monomial_from_array([1, 0]), 3),
        @sympolys.monomial_from_array([0, 2]),
      ),
    ),
    groebnertools_sig_mult([1, 0], 3, [0, 2]),
  )
}

///|
test "groebnertools: f5 labeled polynomial helper parity" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = @sympolys.lbp(
    @sympolys.sig(@sympolys.monomial_from_array([1, 0]), 2),
    b.from_expr(x + y),
    3,
  )
  let g = @sympolys.lbp(
    @sympolys.sig(@sympolys.monomial_from_array([0, 2]), 3),
    b.from_expr(y),
    4,
  )
  assert_eq(
    @sympolys.lbp_cmp(f, g).to_string(),
    groebnertools_lbp_cmp([1, 0], 2, x + y, 3, [0, 2], 3, y, 4, gens=["x", "y"]),
  )
  assert_eq(
    f5_lbp_string(@sympolys.lbp_sub(f, g)),
    groebnertools_lbp_sub([1, 0], 2, x + y, 3, [0, 2], 3, y, 4, gens=["x", "y"]),
  )
  assert_eq(
    f5_lbp_string(
      @sympolys.lbp_mul_term(
        f,
        (
          @sympolys.monomial_from_array([0, 1]),
          @sympolys.fe_from_int(2, @sympolys.Domain::QQ),
        ),
      ),
    ),
    groebnertools_lbp_mul_term([1, 0], 2, x + y, 3, [0, 1], 2, gens=["x", "y"]),
  )
}

///|
test "groebnertools: f5 critical s-polynomial parity" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f_expr = x * y - @symcore.int(1)
  let g_expr = x - @symcore.int(1)
  let f = @sympolys.lbp(
    @sympolys.sig(@sympolys.monomial_from_array([0, 0]), 1),
    b.from_expr(f_expr),
    1,
  )
  let g = @sympolys.lbp(
    @sympolys.sig(@sympolys.monomial_from_array([0, 0]), 2),
    b.from_expr(g_expr),
    2,
  )
  assert_eq(
    f5_lbp_string(@sympolys.s_poly(@sympolys.critical_pair(f, g))),
    groebnertools_critical_s_poly([0, 0], 1, f_expr, 1, [0, 0], 2, g_expr, 2, gens=[
      "x", "y",
    ]),
  )
}

///|
test "groebnertools: f5 rewritable and reduce parity" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let comparable = @sympolys.lbp(
    @sympolys.sig(@sympolys.monomial_from_array([0, 0]), 2),
    b.from_expr(x),
    2,
  )
  assert_eq(
    @sympolys.is_rewritable_or_comparable(
      @sympolys.sig(@sympolys.monomial_from_array([1, 0]), 1),
      1,
      [comparable],
    ).to_string(),
    groebnertools_is_rewritable_or_comparable_one(
      [1, 0],
      1,
      1,
      [0, 0],
      2,
      x,
      2,
      gens=["x", "y"],
    ),
  )
  let f_expr = x + y
  let h_expr = x
  let f = @sympolys.lbp(
    @sympolys.sig(@sympolys.monomial_from_array([0, 0]), 2),
    b.from_expr(f_expr),
    3,
  )
  let h = @sympolys.lbp(
    @sympolys.sig(@sympolys.monomial_from_array([0, 0]), 3),
    b.from_expr(h_expr),
    1,
  )
  assert_eq(
    f5_lbp_string(@sympolys.f5_reduce(f, [h])),
    groebnertools_f5_reduce_one([0, 0], 2, f_expr, 3, [0, 0], 3, h_expr, 1, gens=[
      "x", "y",
    ]),
  )
}

///|
test "groebnertools: grevlex ordering changes basis" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ).order(TermOrder::Grevlex)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f1 = b.from_expr((x ^ @symcore.int(2)) + y)
  let f2 = b.from_expr(x - @symcore.int(1))
  expect_groebner_same([f1, f2], TermOrder::Grevlex)
}

///|
test "groebnertools: lex basis for x^2 + 2*x*y^2, x*y + 2*y^3 - 1" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x * (y ^ @symcore.int(2)),
  )
  let g = b.from_expr(
    x * y + @symcore.int(2) * (y ^ @symcore.int(3)) - @symcore.int(1),
  )
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for x^3-2*x*y, x^2*y + x - 2*y^2" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = b.from_expr((x ^ @symcore.int(3)) + @symcore.int(-2) * x * y)
  let g = b.from_expr(
    (x ^ @symcore.int(2)) * y + x + @symcore.int(-2) * (y ^ @symcore.int(2)),
  )
  expect_groebner_same([f, g], TermOrder::Grlex)
}

///|
test "groebnertools: lex basis for x - z^2, y - z^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f = b.from_expr(x - (z ^ @symcore.int(2)))
  let g = b.from_expr(y - (z ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for x - z^2, y - z^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f = b.from_expr(x - (z ^ @symcore.int(2)))
  let g = b.from_expr(y - (z ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Grlex)
}

///|
test "groebnertools: lex basis for y - x^2, z - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f = b.from_expr(y - (x ^ @symcore.int(2)))
  let g = b.from_expr(z - (x ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for y - x^2, z - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f = b.from_expr(y - (x ^ @symcore.int(2)))
  let g = b.from_expr(z - (x ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Grlex)
}

///|
test "groebnertools: grevlex basis for x*y + z, x - z, y - z" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(
    TermOrder::Grevlex,
  )
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f1 = b.from_expr(x * y + z)
  let f2 = b.from_expr(x - z)
  let f3 = b.from_expr(y - z)
  expect_groebner_same([f1, f2, f3], TermOrder::Grevlex)
}

///|
test "groebnertools: lex basis for sphere constraints" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f1 = b.from_expr(
    (x ^ @symcore.int(2)) +
    (y ^ @symcore.int(2)) +
    (z ^ @symcore.int(2)) +
    @symcore.int(-1),
  )
  let f2 = b.from_expr(x - y)
  let f3 = b.from_expr(y - z)
  expect_groebner_same([f1, f2, f3], TermOrder::Lex)
}

///|
test "groebnertools: lex basis for z - x^2, y - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f = b.from_expr(z - (x ^ @symcore.int(2)))
  let g = b.from_expr(y - (x ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for x - y^2, z - y^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let f = b.from_expr(x - (y ^ @symcore.int(2)))
  let g = b.from_expr(z - (y ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Grlex)
}
