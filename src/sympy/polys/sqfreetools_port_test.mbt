///|
fn expect_sqf_list_same(poly : Poly) -> Unit raise {
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(Show::to_string(content), parts)
  let ours = canonical_cmp(sort_factor_repr(ours_raw))
  let oracle = canonical_cmp(
    sort_factor_repr(
      match poly.domain {
        GF(p) => sqf_list(poly.to_expr(), modulus=p)
        _ => sqf_list(poly.to_expr())
      },
    ),
  )
  assert_eq(ours, oracle)
}

///|
fn expect_sqf_part_same(poly : Poly) -> Unit raise {
  let sqf = poly.sqf_part()
  let oracle_sqf = sqf_part(poly.to_expr())
  let eq = expr_equal(sqf.to_string(), oracle_sqf)
  assert_true(eq)
}

///|

///|
test "sqfreetools: sqf_list for repeated linear factors over ZZ" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    ((x - expr_int(1)) ^ expr_int(2)) * ((x + expr_int(2)) ^ expr_int(3)),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_part drops multiplicities" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    ((x - expr_int(3)) ^ expr_int(2)) *
    ((x + expr_int(1)) ^ expr_int(1)) *
    ((x + expr_int(5)) ^ expr_int(4)),
  )
  expect_sqf_part_same(poly)
}

///|
test "sqfreetools: sqf_list mixed factors over ZZ" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    expr_int(-1) * (x ^ expr_int(5)) + (x ^ expr_int(4)) + x + expr_int(-1),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list composite even powers over ZZ" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    (x ^ expr_int(8)) +
    expr_int(6) * (x ^ expr_int(6)) +
    expr_int(12) * (x ^ expr_int(4)) +
    expr_int(8) * (x ^ expr_int(2)),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list over QQ keeps content" {
  let b = PolyBuilder::new(["x"], QQ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    expr_int(2) * (x ^ expr_int(2)) + expr_int(4) * x + expr_int(2),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list over GF(2) handles pth powers" {
  let b = PolyBuilder::new(["x"], GF(2))
  let x = expr_sym("x")
  let poly = b.from_expr((x ^ expr_int(2)) + expr_int(1))
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list over GF(3) splits multiplicities" {
  let b = PolyBuilder::new(["x"], GF(3))
  let x = expr_sym("x")
  let poly = b.from_expr(
    (x ^ expr_int(10)) +
    expr_int(2) * (x ^ expr_int(7)) +
    expr_int(2) * (x ^ expr_int(4)) +
    x,
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_part signs normalize" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(expr_int(-1) * (x ^ expr_int(3)) + x + expr_int(1))
  expect_sqf_part_same(poly)
}

///|
test "sqfreetools: sqf_list handles zero and constants" {
  let b = PolyBuilder::new(["x"], ZZ)
  let zero = b.from_expr(expr_int(0))
  let one = b.from_expr(expr_int(7))
  expect_sqf_list_same(zero)
  expect_sqf_list_same(one)
}

///|
test "sqfreetools: sqf_list composite factors over ZZ" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    (((x ^ expr_int(2)) + expr_int(1)) ^ expr_int(2)) *
    ((x ^ expr_int(2)) + expr_int(2) * x + expr_int(2)),
  )
  expect_sqf_list_same(poly)
}

///|
fn sqf_dense_port_dup_factor_repr(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{dup_repr(item.0)},\{item.1})")
  remove_spaces("(\{coeff},[" + parts.join(",") + "])")
}

///|
fn sqf_dense_port_dup_include_repr(
  items : Array[(Array[FieldElem], Int)],
) -> String {
  remove_spaces(
    "[" + items.map(item => "(\{dup_repr(item.0)},\{item.1})").join(",") + "]",
  )
}

///|
fn sqf_dense_port_dmp_factor_repr(
  value : (FieldElem, Array[(DensePoly, Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{dmp_repr(item.0)},\{item.1})")
  remove_spaces("(\{coeff},[" + parts.join(",") + "])")
}

///|
fn sqf_dense_port_dmp_include_repr(items : Array[(DensePoly, Int)]) -> String {
  remove_spaces(
    "[" + items.map(item => "(\{dmp_repr(item.0)},\{item.1})").join(",") + "]",
  )
}

///|
test "sqfreetools: dense dup square-free frontdoors parity" {
  let repeated = [fezz(1), fezz(-2), fezz(1)]
  let squarefree = [fezz(1), fezz(0), fezz(-1)]
  assert_eq(@sympolys.dup_sqf_p(repeated, ZZ), dup_sqf_p(dup_to_rats(repeated)))
  assert_eq(
    @sympolys.dup_sqf_p(squarefree, ZZ),
    dup_sqf_p(dup_to_rats(squarefree)),
  )
  let part_input = [fezz(1), fezz(0), fezz(-3), fezz(-2)]
  assert_eq(
    dup_repr(@sympolys.dup_sqf_part(part_input, ZZ)),
    dup_sqf_part(dup_to_rats(part_input)),
  )
  let f = [fezz(2), fezz(16), fezz(50), fezz(76), fezz(56), fezz(16)]
  assert_eq(
    sqf_dense_port_dup_factor_repr(@sympolys.dup_sqf_list(f, ZZ)),
    dup_sqf_list(dup_to_rats(f)),
  )
  assert_eq(
    sqf_dense_port_dup_factor_repr(@sympolys.dup_sqf_list(f, ZZ, all=true)),
    dup_sqf_list(dup_to_rats(f), all=true),
  )
  assert_eq(
    sqf_dense_port_dup_include_repr(@sympolys.dup_sqf_list_include(f, ZZ)),
    dup_sqf_list_include(dup_to_rats(f)),
  )
}

///|
test "sqfreetools: dense dmp univariate wrappers parity" {
  let f = poly_int([2, 16, 50, 76, 56, 16])
  let repeated = poly_int([1, -2, 1])
  assert_eq(
    @sympolys.dmp_sqf_p(repeated, 0, ZZ),
    dmp_sqf_p(dense_data_of(repeated), 0),
  )
  assert_eq(
    dmp_repr(@sympolys.dmp_sqf_part(poly_int([1, 0, -3, -2]), 0, ZZ)),
    dmp_sqf_part(dense_data_of(poly_int([1, 0, -3, -2])), 0),
  )
  assert_eq(
    sqf_dense_port_dmp_factor_repr(@sympolys.dmp_sqf_list(f, 0, ZZ)),
    dmp_sqf_list(dense_data_of(f), 0),
  )
  assert_eq(
    sqf_dense_port_dmp_include_repr(@sympolys.dmp_sqf_list_include(f, 0, ZZ)),
    dmp_sqf_list_include(dense_data_of(f), 0),
  )
}

///|
test "sqfreetools: dense greatest factorial factorization parity" {
  let f = [fezz(1), fezz(2), fezz(-1), fezz(-2), fezz(0), fezz(0)]
  assert_eq(
    sqf_dense_port_dup_include_repr(@sympolys.dup_gff_list(f, ZZ)),
    dup_gff_list(dup_to_rats(f)),
  )
  let dmp_f = poly_int([1, 2, -1, -2, 0, 0])
  assert_eq(
    sqf_dense_port_dmp_include_repr(@sympolys.dmp_gff_list(dmp_f, 0, ZZ)),
    dmp_gff_list(dense_data_of(dmp_f), 0),
  )
}

///|
fn sqf_dense_port_alg_minpoly_sqrt3() -> Poly raise PolyError {
  let a = @symcore.Expr::Symbol("a")
  PolyBuilder::new(["a"], QQ).from_expr((a ^ @symcore.int(2)) - @symcore.int(3))
}

///|
fn sqf_dense_port_alg_domain_sqrt3() -> Domain raise PolyError {
  let minpoly = sqf_dense_port_alg_minpoly_sqrt3()
  AlgExt(QQ, ["a"], [minpoly.to_expr()])
}

///|
fn sqf_dense_port_dup_norm_repr(
  value : (Int, Array[FieldElem], Array[FieldElem]),
) -> String {
  remove_spaces("(\{value.0},\{dup_repr(value.1)},\{dup_repr(value.2)})")
}

///|
fn sqf_dense_port_dmp_norm_repr(
  value : (Array[Int], DensePoly, DensePoly),
) -> String {
  remove_spaces(
    "(\{Repr(value.0).to_string()},\{dmp_repr(value.1)},\{dmp_repr(value.2)})",
  )
}

///|
test "sqfreetools: dense algebraic norm frontdoors parity" {
  let domain = sqf_dense_port_alg_domain_sqrt3()
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let x_plus_a_poly = Poly::from_expr(x + a, ["x"], domain)
  let x_plus_a = @sympolys.dup_reverse(@sympolys.to_dense(x_plus_a_poly))
  assert_eq(
    dmp_repr(@sympolys.dmp_norm(poly_fe(x_plus_a), 0, domain)),
    dmp_norm_exprs(["1", "sqrt(3)"], 0),
  )
  let f_poly = Poly::from_expr(
    (x ^ @symcore.int(2)) - @symcore.int(2),
    ["x"],
    domain,
  )
  let f = @sympolys.dup_reverse(@sympolys.to_dense(f_poly))
  assert_eq(
    sqf_dense_port_dup_norm_repr(@sympolys.dup_sqf_norm(f, domain)),
    dup_sqf_norm_exprs(["1", "0", "-2"]).replace_all(old="sqrt(3)", new="a"),
  )
  assert_eq(
    sqf_dense_port_dmp_norm_repr(@sympolys.dmp_sqf_norm(poly_fe(f), 0, domain)),
    dmp_sqf_norm_exprs(["1", "0", "-2"], 0).replace_all(old="sqrt(3)", new="a"),
  )
}
