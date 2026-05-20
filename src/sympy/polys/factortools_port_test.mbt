///|
fn expect_factor_list_same(poly : Poly, modulus : Int?) -> Unit raise {
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      match modulus {
        Some(p) => factor_list(poly.to_expr(), modulus=p)
        None => factor_list(poly.to_expr())
      },
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "factortools: x^5 - x over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let poly = b.from_expr(x * ((x ^ @symcore.int(4)) - @symcore.int(1)))
  expect_factor_list_same(poly, None)
}

///|
test "factortools: x^6 + x^3 + 1 over GF(2)" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let x = @symcore.Expr::Symbol("x")
  let poly = b.from_expr(
    (x ^ @symcore.int(6)) + (x ^ @symcore.int(3)) + @symcore.int(1),
  )
  expect_factor_list_same(poly, Some(2))
}

///|
test "factortools: sqf_list compares with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let poly = b.from_expr(
    ((x - @symcore.int(2)) ^ @symcore.int(2)) *
    ((x + @symcore.int(3)) ^ @symcore.int(3)),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(sqf_list(poly.to_expr())).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "factortools: QQ content factors (1/2)*(x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let poly = b.from_expr(
    expr_rat(1, 2) * ((x ^ @symcore.int(2)) - @symcore.int(1)),
  )
  expect_factor_list_same(poly, None)
}

///|
test "factortools: extension argument no longer rejected" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let poly = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let factors = poly.factor(extension=["sqrt(2)"])
  let ours = sort_factor_repr(factor_list_to_string("1", factors))
    .trim()
    .to_string()
  let oracle = sort_factor_repr(
      factor_list(poly.to_expr(), extension=["sqrt(2)"]),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
fn fact_dense_port_dup_include_repr(
  items : Array[(Array[FieldElem], Int)],
) -> String {
  remove_spaces(
    "[" + items.map(item => "(\{dup_repr(item.0)},\{item.1})").join(",") + "]",
  )
}

///|
fn fact_dense_port_dup_factor_repr(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{dup_repr(item.0)},\{item.1})")
  remove_spaces("(\{coeff},[" + parts.join(",") + "])")
}

///|
fn fact_dense_port_dmp_factor_repr(
  value : (FieldElem, Array[(DensePoly, Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{dmp_repr(item.0)},\{item.1})")
  remove_spaces("(\{coeff},[" + parts.join(",") + "])")
}

///|
fn fact_dense_port_dmp_include_repr(items : Array[(DensePoly, Int)]) -> String {
  remove_spaces(
    "[" + items.map(item => "(\{dmp_repr(item.0)},\{item.1})").join(",") + "]",
  )
}

///|
test "factortools: dense factor-list frontdoors parity" {
  let f = [fezz(2), fezz(0), fezz(-2)]
  assert_eq(
    fact_dense_port_dup_include_repr(
      @sympolys.dup_factor_list_include(f, Domain::ZZ),
    ),
    dup_factor_list_include(dup_to_rats(f)),
  )
  let dmp_f = poly_int([2, 0, -2])
  assert_eq(
    fact_dense_port_dmp_factor_repr(
      @sympolys.dmp_factor_list(dmp_f, 0, Domain::ZZ),
    ),
    dmp_factor_list(dense_data_of(dmp_f), 0),
  )
  assert_eq(
    fact_dense_port_dmp_include_repr(
      @sympolys.dmp_factor_list_include(dmp_f, 0, Domain::ZZ),
    ),
    dmp_factor_list_include(dense_data_of(dmp_f), 0),
  )
}

///|
test "factortools: dense trial-division frontdoors parity" {
  let f = [fezz(1), fezz(0), fezz(-3), fezz(2)]
  let factors = [[fezz(1), fezz(-1)], [fezz(1), fezz(2)]]
  assert_eq(
    fact_dense_port_dup_include_repr(
      @sympolys.dup_trial_division(f, factors, Domain::ZZ),
    ),
    dup_trial_division(dup_to_rats(f), [
      dup_to_rats(factors[0]),
      dup_to_rats(factors[1]),
    ]),
  )
  let dmp_f = poly_int([1, 0, -3, 2])
  let dmp_factors = [poly_int([1, -1]), poly_int([1, 2])]
  assert_eq(
    fact_dense_port_dmp_include_repr(
      @sympolys.dmp_trial_division(dmp_f, dmp_factors, 0, Domain::ZZ),
    ),
    dmp_trial_division(
      dense_data_of(dmp_f),
      [dense_data_of(dmp_factors[0]), dense_data_of(dmp_factors[1])],
      0,
    ),
  )
}

///|
test "factortools: dense irreducibility frontdoors parity" {
  let irreducible = [fezz(1), fezz(0), fezz(1)]
  let reducible = [fezz(1), fezz(0), fezz(-1)]
  let repeated = poly_int([1, 2, 1])
  assert_eq(
    @sympolys.dup_irreducible_p(irreducible, Domain::ZZ),
    dup_irreducible_p(dup_to_rats(irreducible)),
  )
  assert_eq(
    @sympolys.dup_irreducible_p(reducible, Domain::ZZ),
    dup_irreducible_p(dup_to_rats(reducible)),
  )
  assert_eq(
    @sympolys.dmp_irreducible_p(repeated, 0, Domain::ZZ),
    dmp_irreducible_p(dense_data_of(repeated), 0),
  )
}

///|
test "factortools: dense finite-field factorization parity" {
  let f = [
    @sympolys.fe_from_int(1, Domain::GF(2)),
    @sympolys.fe_from_int(0, Domain::GF(2)),
    @sympolys.fe_from_int(1, Domain::GF(2)),
  ]
  let ours = fact_dense_port_dup_factor_repr(
    @sympolys.dup_gf_factor(f, Domain::GF(2)),
  )
  assert_eq(ours, "(1,[([1,1],2)])")
  assert_true(
    dup_gf_factor([1, 0, 1], 2).contains("SymmetricModularIntegerMod2"),
  )
}

///|
test "factortools: integer Mignotte frontdoors parity" {
  let f = [fezz(1), fezz(14), fezz(56), fezz(64)]
  assert_eq(
    @sympolys.dup_zz_mignotte_bound(f, Domain::ZZ).to_string(),
    dup_zz_mignotte_bound(dup_to_rats(f)),
  )
  let hard = [
    fezz(87),
    fezz(4),
    fezz(80),
    fezz(17),
    fezz(9),
    fezz(12),
    fezz(49),
    fezz(26),
  ]
  assert_eq(
    @sympolys.dup_zz_mignotte_bound(hard, Domain::ZZ).to_string(),
    dup_zz_mignotte_bound(dup_to_rats(hard)),
  )
  let dmp_f = poly_int([1, 2, 1])
  assert_eq(
    @sympolys.dmp_zz_mignotte_bound(dmp_f, 0, Domain::ZZ).to_string(),
    dmp_zz_mignotte_bound(dense_data_of(dmp_f), 0),
  )
}

///|
test "factortools: integer cyclotomic and Eisenstein parity" {
  let eisenstein = [fezz(1), fezz(0), fezz(2)]
  let not_eisenstein = [fezz(1), fezz(0), fezz(1)]
  assert_eq(
    @sympolys.dup_zz_irreducible_p(eisenstein, Domain::ZZ),
    dup_zz_irreducible_p(dup_to_rats(eisenstein)),
  )
  assert_eq(
    @sympolys.dup_zz_irreducible_p(not_eisenstein, Domain::ZZ),
    dup_zz_irreducible_p(dup_to_rats(not_eisenstein)),
  )
  assert_eq(
    dup_repr(@sympolys.dup_zz_cyclotomic_poly(12, Domain::ZZ)),
    dup_zz_cyclotomic_poly(12),
  )
  let false_case = [
    fezz(1),
    fezz(0),
    fezz(1),
    fezz(0),
    fezz(0),
    fezz(0),
    fezz(-1),
    fezz(0),
    fezz(1),
    fezz(0),
    fezz(-1),
    fezz(0),
    fezz(0),
    fezz(0),
    fezz(1),
    fezz(0),
    fezz(1),
  ]
  let true_case = [
    fezz(1),
    fezz(0),
    fezz(1),
    fezz(0),
    fezz(0),
    fezz(0),
    fezz(-1),
    fezz(0),
    fezz(-1),
    fezz(0),
    fezz(-1),
    fezz(0),
    fezz(0),
    fezz(0),
    fezz(1),
    fezz(0),
    fezz(1),
  ]
  assert_eq(
    @sympolys.dup_cyclotomic_p(false_case, Domain::ZZ),
    dup_cyclotomic_p(dup_to_rats(false_case)),
  )
  assert_eq(
    @sympolys.dup_cyclotomic_p(true_case, Domain::ZZ),
    dup_cyclotomic_p(dup_to_rats(true_case)),
  )
}
