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
fn fact_dense_port_dup_list_repr(items : Array[Array[FieldElem]]) -> String {
  remove_spaces("[" + items.map(dup_repr).join(",") + "]")
}

///|
fn fact_dense_port_hensel_step_repr(
  value : (
    Array[FieldElem],
    Array[FieldElem],
    Array[FieldElem],
    Array[FieldElem],
  ),
) -> String {
  remove_spaces(
    "(\{dup_repr(value.0)},\{dup_repr(value.1)},\{dup_repr(value.2)},\{dup_repr(value.3)})",
  )
}

///|
fn fact_dense_port_dup_list_opt_repr(
  items : Array[Array[FieldElem]]?,
) -> String {
  match items {
    Some(values) => fact_dense_port_dup_list_repr(values)
    None => "None"
  }
}

///|
fn fact_dense_port_dup_opt_repr(items : Array[FieldElem]?) -> String {
  match items {
    Some(values) => dup_repr(values)
    None => "None"
  }
}

///|
fn fact_dense_port_dup_factor_sqf_repr(
  value : (FieldElem, Array[Array[FieldElem]]),
) -> String {
  remove_spaces("(\{value.0},\{fact_dense_port_dup_list_repr(value.1)})")
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
fn fact_dense_port_wang_test_points_repr(
  value : (FieldElem, Array[FieldElem], Array[FieldElem]),
) -> String {
  remove_spaces("(\{value.0},\{dup_repr(value.1)},\{dup_repr(value.2)})")
}

///|
fn fact_dense_port_wang_lead_coeffs_repr(
  value : (DensePoly, Array[Array[FieldElem]], Array[DensePoly]),
) -> String {
  let factors = "[" + value.1.map(dup_repr).join(",") + "]"
  let coeffs = "[" + value.2.map(dmp_repr).join(",") + "]"
  remove_spaces("(\{dmp_repr(value.0)},\{factors},\{coeffs})")
}

///|
fn fact_dense_port_dup_factor_shape(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{item.0.length()},\{item.1})")
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
fn fact_dense_port_gaussian_coeff_repr(coeff : FieldElem) -> String {
  coeff
  .to_string()
  .replace_all(old=" ", new="")
  .replace_all(old="0-1i", new="-I")
  .replace_all(old="0+1i", new="I")
  .replace_all(old="-1i", new="-I")
  .replace_all(old="+1i", new="+I")
}

///|
fn fact_dense_port_dup_gaussian_repr(f : Array[FieldElem]) -> String {
  "[" + f.map(fact_dense_port_gaussian_coeff_repr).join(",") + "]"
}

///|
fn fact_dense_port_dmp_gaussian_coeffs(
  f : DensePoly,
) -> Array[FieldElem] raise PolyError {
  match f {
    DensePoly::Coef(c) => [c]
    DensePoly::Poly(items) => {
      let out : Array[FieldElem] = Array::new()
      for item in items {
        match item {
          DensePoly::Coef(c) => out.push(c)
          DensePoly::Poly(_) => raise PolyError::NotUnivariate
        }
      }
      out
    }
  }
}

///|
fn fact_dense_port_dup_factor_gaussian_repr(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => {
    "(\{fact_dense_port_dup_gaussian_repr(item.0)},\{item.1})"
  })
  remove_spaces(
    "(\{fact_dense_port_gaussian_coeff_repr(coeff)},[" + parts.join(",") + "])",
  )
}

///|
fn fact_dense_port_dmp_factor_gaussian_repr(
  value : (FieldElem, Array[(DensePoly, Int)]),
) -> String raise PolyError {
  let (coeff, factors) = value
  let parts = factors.map(item => {
    "(\{fact_dense_port_dup_gaussian_repr(fact_dense_port_dmp_gaussian_coeffs(item.0))},\{item.1})"
  })
  remove_spaces(
    "(\{fact_dense_port_gaussian_coeff_repr(coeff)},[" + parts.join(",") + "])",
  )
}

///|
fn fact_dense_port_dmp_include_repr(items : Array[(DensePoly, Int)]) -> String {
  remove_spaces(
    "[" + items.map(item => "(\{dmp_repr(item.0)},\{item.1})").join(",") + "]",
  )
}

///|
fn fact_dense_port_dmp_list_repr(items : Array[DensePoly]) -> String {
  remove_spaces("[" + items.map(dmp_repr).join(",") + "]")
}

///|
test "factortools: dense factor-list frontdoors parity" {
  let f = [fezz(2), fezz(0), fezz(-2)]
  assert_eq(
    fact_dense_port_dup_factor_repr(@sympolys.dup_zz_factor(f, Domain::ZZ)),
    dup_zz_factor(dup_to_rats(f)),
  )
  assert_eq(
    fact_dense_port_dup_factor_sqf_repr(
      @sympolys.dup_zz_factor_sqf(f, Domain::ZZ),
    ),
    dup_zz_factor_sqf(dup_to_rats(f)),
  )
  assert_eq(
    fact_dense_port_dup_include_repr(
      @sympolys.dup_factor_list_include(f, Domain::ZZ),
    ),
    dup_factor_list_include(dup_to_rats(f)),
  )
  let dmp_f = poly_int([2, 0, -2])
  assert_eq(
    fact_dense_port_dmp_factor_repr(
      @sympolys.dmp_zz_factor(dmp_f, 0, Domain::ZZ),
    ),
    dmp_zz_factor(dense_data_of(dmp_f), 0),
  )
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
test "factortools: Hensel frontdoors parity" {
  let f = [fezz(1), fezz(18), fezz(77)]
  let g = [fezz(1), fezz(2)]
  let h = [fezz(1), fezz(1)]
  let s = [fezz(1)]
  let t = [fezz(-1)]
  assert_eq(
    fact_dense_port_hensel_step_repr(
      @sympolys.dup_zz_hensel_step(5, f, g, h, s, t, Domain::ZZ),
    ),
    dup_zz_hensel_step(
      5,
      dup_to_rats(f),
      dup_to_rats(g),
      dup_to_rats(h),
      dup_to_rats(s),
      dup_to_rats(t),
    ),
  )
  assert_eq(
    fact_dense_port_dup_list_repr(
      @sympolys.dup_zz_hensel_lift(5, f, [g, h], 2, Domain::ZZ),
    ),
    dup_zz_hensel_lift(5, dup_to_rats(f), [dup_to_rats(g), dup_to_rats(h)], 2),
  )
  let f2 = [fezz(1), fezz(14), fezz(45)]
  let factors2 = [[fezz(1), fezz(4)], [fezz(1), fezz(0)]]
  assert_eq(
    fact_dense_port_dup_list_repr(
      @sympolys.dup_zz_hensel_lift(5, f2, factors2, 2, Domain::ZZ),
    ),
    dup_zz_hensel_lift(
      5,
      dup_to_rats(f2),
      [dup_to_rats(factors2[0]), dup_to_rats(factors2[1])],
      2,
    ),
  )
}

///|
test "factortools: Wang helper frontdoors parity" {
  let pass_e = [fezz(2), fezz(3), fezz(5)]
  assert_eq(
    fact_dense_port_dup_opt_repr(
      @sympolys.dmp_zz_wang_non_divisors(pass_e, fezz(1), fezz(1), Domain::ZZ),
    ),
    dmp_zz_wang_non_divisors(dup_to_rats(pass_e), br_int(1), br_int(1)),
  )
  let fail_e = [fezz(2), fezz(4)]
  assert_eq(
    fact_dense_port_dup_opt_repr(
      @sympolys.dmp_zz_wang_non_divisors(fail_e, fezz(1), fezz(1), Domain::ZZ),
    ),
    dmp_zz_wang_non_divisors(dup_to_rats(fail_e), br_int(1), br_int(1)),
  )
  let f = @sympolys.dense_poly([poly_int([1, 1]), poly_int([1]), poly_int([1])])
  let factors = [(poly_int([1, 1]), 1)]
  assert_eq(
    fact_dense_port_wang_test_points_repr(
      @sympolys.dmp_zz_wang_test_points(
        f,
        factors,
        fezz(1),
        [fezz(2)],
        1,
        Domain::ZZ,
      ),
    ),
    dmp_zz_wang_test_points(
      dense_data_of(f),
      [(dense_data_of(factors[0].0), factors[0].1)],
      br_int(1),
      [br_int(2)],
      1,
    ),
  )
  assert_eq(
    fact_dense_port_wang_lead_coeffs_repr(
      @sympolys.dmp_zz_wang_lead_coeffs(
        f,
        factors,
        fezz(1),
        [fezz(3)],
        [[fezz(3), fezz(1), fezz(1)]],
        [fezz(2)],
        1,
        Domain::ZZ,
      ),
    ),
    dmp_zz_wang_lead_coeffs(
      dense_data_of(f),
      [(dense_data_of(factors[0].0), factors[0].1)],
      br_int(1),
      [br_int(3)],
      [[br_int(3), br_int(1), br_int(1)]],
      [br_int(2)],
      1,
    ),
  )
  let negative_lc = @sympolys.dense_poly([
    poly_int([-1, -1]),
    poly_int([1]),
    poly_int([1]),
  ])
  assert_eq(
    fact_dense_port_wang_test_points_repr(
      @sympolys.dmp_zz_wang_test_points(
        negative_lc,
        factors,
        fezz(1),
        [fezz(2)],
        1,
        Domain::ZZ,
      ),
    ),
    dmp_zz_wang_test_points(
      dense_data_of(negative_lc),
      [(dense_data_of(factors[0].0), factors[0].1)],
      br_int(1),
      [br_int(2)],
      1,
    ),
  )
  assert_eq(
    fact_dense_port_wang_lead_coeffs_repr(
      @sympolys.dmp_zz_wang_lead_coeffs(
        negative_lc,
        factors,
        fezz(-1),
        [fezz(3)],
        [[fezz(3), fezz(-1), fezz(-1)]],
        [fezz(2)],
        1,
        Domain::ZZ,
      ),
    ),
    dmp_zz_wang_lead_coeffs(
      dense_data_of(negative_lc),
      [(dense_data_of(factors[0].0), factors[0].1)],
      br_int(-1),
      [br_int(3)],
      [[br_int(3), br_int(-1), br_int(-1)]],
      [br_int(2)],
      1,
    ),
  )
}

///|
test "factortools: Diophantine helper frontdoors parity" {
  let f0 = [fezz(1), fezz(1)]
  let f1 = [fezz(1), fezz(-1)]
  assert_eq(
    fact_dense_port_dup_list_repr(
      @sympolys.dup_zz_diophantine([f0, f1], 0, 5, Domain::ZZ),
    ),
    dup_zz_diophantine([dup_to_rats(f0), dup_to_rats(f1)], 0, 5),
  )
  let g0 = [fezz(1), fezz(0)]
  let g1 = [fezz(1), fezz(-1)]
  let g2 = [fezz(1), fezz(1)]
  assert_eq(
    fact_dense_port_dup_list_repr(
      @sympolys.dup_zz_diophantine([g0, g1, g2], 2, 5, Domain::ZZ),
    ),
    dup_zz_diophantine(
      [dup_to_rats(g0), dup_to_rats(g1), dup_to_rats(g2)],
      2,
      5,
    ),
  )
  let d0 = poly_int([1, 1])
  let d1 = poly_int([1, -1])
  let c = poly_int([2, 3])
  assert_eq(
    fact_dense_port_dmp_list_repr(
      @sympolys.dmp_zz_diophantine([d0, d1], c, [], 0, 5, 1, Domain::ZZ),
    ),
    dmp_zz_diophantine(
      [dense_data_of(d0), dense_data_of(d1)],
      dense_data_of(c),
      [],
      0,
      5,
      1,
    ),
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
test "factortools: dense algebraic-extension factorization parity" {
  let a = @symcore.Expr::Symbol("a")
  let rel = (a ^ @symcore.int(2)) - @symcore.int(2)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let f = [
    @sympolys.fe_from_int(1, alg_domain),
    @sympolys.fe_from_int(0, alg_domain),
    @sympolys.fe_from_int(-2, alg_domain),
  ]
  assert_eq(
    fact_dense_port_dup_factor_shape(@sympolys.dup_ext_factor(f, alg_domain)),
    dup_ext_factor_shape_exprs(["1", "0", "-2"]),
  )
}

///|
test "factortools: dense Gaussian factorization frontdoors parity" {
  let f_qq = [
    @sympolys.fe_from_int(1, Domain::QQ_I),
    @sympolys.fe_from_int(0, Domain::QQ_I),
    @sympolys.fe_from_int(1, Domain::QQ_I),
  ]
  let f_zz = [
    @sympolys.fe_from_int(1, Domain::ZZ_I),
    @sympolys.fe_from_int(0, Domain::ZZ_I),
    @sympolys.fe_from_int(1, Domain::ZZ_I),
  ]
  let rats = [br_int(1), br_int(0), br_int(1)]
  assert_eq(
    fact_dense_port_dup_factor_gaussian_repr(
      @sympolys.dup_qq_i_factor(f_qq, Domain::QQ_I),
    ),
    dup_qq_i_factor(rats),
  )
  assert_eq(
    fact_dense_port_dup_factor_gaussian_repr(
      @sympolys.dup_zz_i_factor(f_zz, Domain::ZZ_I),
    ),
    dup_zz_i_factor(rats),
  )
  let dmp_qq = @sympolys.dense_poly(f_qq.map(c => @sympolys.dense_coef(c)))
  let dmp_zz = @sympolys.dense_poly(f_zz.map(c => @sympolys.dense_coef(c)))
  assert_eq(
    fact_dense_port_dmp_factor_gaussian_repr(
      @sympolys.dmp_qq_i_factor(dmp_qq, 0, Domain::QQ_I),
    ),
    dmp_qq_i_factor(DenseData::Poly(rats.map(c => DenseData::Coef(c))), 0),
  )
  assert_eq(
    fact_dense_port_dmp_factor_gaussian_repr(
      @sympolys.dmp_zz_i_factor(dmp_zz, 0, Domain::ZZ_I),
    ),
    dmp_zz_i_factor(DenseData::Poly(rats.map(c => DenseData::Coef(c))), 0),
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
  let cyclo_minus = [fezz(1), fezz(0), fezz(0), fezz(0), fezz(-1)]
  assert_eq(
    fact_dense_port_dup_list_opt_repr(
      @sympolys.dup_zz_cyclotomic_factor(cyclo_minus, Domain::ZZ),
    ),
    dup_zz_cyclotomic_factor(dup_to_rats(cyclo_minus)),
  )
  let cyclo_plus = [fezz(1), fezz(0), fezz(0), fezz(0), fezz(1)]
  assert_eq(
    fact_dense_port_dup_list_opt_repr(
      @sympolys.dup_zz_cyclotomic_factor(cyclo_plus, Domain::ZZ),
    ),
    dup_zz_cyclotomic_factor(dup_to_rats(cyclo_plus)),
  )
  assert_eq(
    fact_dense_port_dup_list_repr(
      @sympolys.dup_zz_zassenhaus([fezz(1), fezz(0), fezz(-1)], Domain::ZZ),
    ),
    dup_zz_zassenhaus(dup_to_rats([fezz(1), fezz(0), fezz(-1)])),
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
