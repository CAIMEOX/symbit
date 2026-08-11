///|
fn fact_wb_fe(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::ZZ)
}

///|
fn fact_wb_gf(n : Int, p : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::GF(p))
}

///|
fn fact_wb_dup(vals : Array[Int]) -> Array[FieldElem] raise PolyError {
  vals.map(v => fact_wb_fe(v))
}

///|
fn fact_wb_gf_dup(
  vals : Array[Int],
  p : Int,
) -> Array[FieldElem] raise PolyError {
  vals.map(v => fact_wb_gf(v, p))
}

///|
fn fact_wb_poly(vals : Array[Int]) -> DensePoly raise PolyError {
  DensePoly::Poly(vals.map(v => DensePoly::Coef(fact_wb_fe(v))))
}

///|
fn fact_wb_dup_repr(f : Array[FieldElem]) -> String {
  "[" + f.map(c => c.to_string()).join(",") + "]"
}

///|
fn fact_wb_dmp_repr(f : DensePoly) -> String {
  match f {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) =>
      "[" + items.map(item => fact_wb_dmp_repr(item)).join(",") + "]"
  }
}

///|
fn fact_wb_dup_factor_repr(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{fact_wb_dup_repr(item.0)},\{item.1})")
  "(\{coeff},[" + parts.join(",") + "])"
}

///|
fn fact_wb_wang_test_points_repr(
  value : (FieldElem, Array[FieldElem], Array[FieldElem]),
) -> String {
  "(\{value.0},\{fact_wb_dup_repr(value.1)},\{fact_wb_dup_repr(value.2)})"
}

///|
fn fact_wb_wang_lead_coeffs_repr(
  value : (DensePoly, Array[Array[FieldElem]], Array[DensePoly]),
) -> String {
  let factors = "[" + value.1.map(fact_wb_dup_repr).join(",") + "]"
  let coeffs = "[" + value.2.map(fact_wb_dmp_repr).join(",") + "]"
  "(\{fact_wb_dmp_repr(value.0)},\{factors},\{coeffs})"
}

///|
fn fact_wb_dup_include_repr(items : Array[(Array[FieldElem], Int)]) -> String {
  "[" +
  items.map(item => "(\{fact_wb_dup_repr(item.0)},\{item.1})").join(",") +
  "]"
}

///|
fn fact_wb_dmp_factor_repr(
  value : (FieldElem, Array[(DensePoly, Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{fact_wb_dmp_repr(item.0)},\{item.1})")
  "(\{coeff},[" + parts.join(",") + "])"
}

///|
fn fact_wb_gaussian_coeff(real : Int, imag : Int) -> FieldElem {
  FieldElem::CC(
    @symnum.BigRational::from_int(real),
    @symnum.BigRational::from_int(imag),
  )
}

///|
fn fact_wb_gaussian_coeff_repr(coeff : FieldElem) -> String {
  match coeff {
    FieldElem::CC(real, imag) => {
      if imag.is_zero() {
        return real.to_string()
      }
      let imag_abs = if imag.numerator() < BigInt::from_int(0) {
        imag.neg_r()
      } else {
        imag
      }
      let imag_text = if imag_abs.is_one() { "I" } else { "\{imag_abs}*I" }
      if real.is_zero() {
        if imag.numerator() < BigInt::from_int(0) {
          "-\{imag_text}"
        } else {
          imag_text
        }
      } else if imag.numerator() < BigInt::from_int(0) {
        "\{real} - \{imag_text}"
      } else {
        "\{real} + \{imag_text}"
      }
    }
    _ => coeff.to_string()
  }
}

///|
fn fact_wb_dup_gaussian_repr(f : Array[FieldElem]) -> String {
  "[" + f.map(fact_wb_gaussian_coeff_repr).join(",") + "]"
}

///|
fn fact_wb_dup_factor_gaussian_repr(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => {
    "(\{fact_wb_dup_gaussian_repr(item.0)},\{item.1})"
  })
  "(\{fact_wb_gaussian_coeff_repr(coeff)},[" + parts.join(",") + "])"
}

///|
fn fact_wb_dmp_factor_gaussian_repr(
  value : (FieldElem, Array[(DensePoly, Int)]),
) -> String raise PolyError {
  let (coeff, factors) = value
  let parts = factors.map(item => {
    "(\{fact_wb_dup_gaussian_repr(dmp_to_coeffs(item.0))},\{item.1})"
  })
  "(\{fact_wb_gaussian_coeff_repr(coeff)},[" + parts.join(",") + "])"
}

///|
fn fact_wb_dmp_include_repr(items : Array[(DensePoly, Int)]) -> String {
  "[" +
  items.map(item => "(\{fact_wb_dmp_repr(item.0)},\{item.1})").join(",") +
  "]"
}

///|
test "factortools dense wb: factor list include" {
  let f = fact_wb_dup([2, 0, -2])
  inspect(
    fact_wb_dup_include_repr(dup_factor_list_include(f, Domain::ZZ)),
    content="[([2,-2],1),([1,1],1)]",
  )
  inspect(
    fact_wb_dmp_factor_repr(
      dmp_factor_list(fact_wb_poly([2, 0, -2]), 0, Domain::ZZ),
    ),
    content="(2,[([1,-1],1),([1,1],1)])",
  )
  inspect(
    fact_wb_dmp_include_repr(
      dmp_factor_list_include(fact_wb_poly([2, 0, -2]), 0, Domain::ZZ),
    ),
    content="[([2,-2],1),([1,1],1)]",
  )
}

///|
test "factortools dense wb: trial division" {
  let f = fact_wb_dup([1, 0, -3, 2])
  let factors = [fact_wb_dup([1, -1]), fact_wb_dup([1, 2])]
  inspect(
    fact_wb_dup_include_repr(dup_trial_division(f, factors, Domain::ZZ)),
    content="[([1,2],1),([1,-1],2)]",
  )
  let dmp_factors = [fact_wb_poly([1, -1]), fact_wb_poly([1, 2])]
  inspect(
    fact_wb_dmp_include_repr(
      dmp_trial_division(
        fact_wb_poly([1, 0, -3, 2]),
        dmp_factors,
        0,
        Domain::ZZ,
      ),
    ),
    content="[([1,2],1),([1,-1],2)]",
  )
  let xy = DensePoly::Poly([
    fact_wb_poly([2]),
    DensePoly::Poly([]),
    fact_wb_poly([-2, 0, 0]),
  ])
  let xy_factors = [
    DensePoly::Poly([fact_wb_poly([1]), fact_wb_poly([-1, 0])]),
    DensePoly::Poly([fact_wb_poly([1]), fact_wb_poly([1, 0])]),
  ]
  inspect(
    fact_wb_dmp_include_repr(dmp_trial_division(xy, xy_factors, 1, Domain::ZZ)),
    content="[([[1],[-1,0]],1),([[1],[1,0]],1)]",
  )
  sympolys_assert_error(
    fn() raise PolyError {
      dup_trial_division(f, [fact_wb_dup([1, 3])], Domain::ZZ)
    },
    "PolynomialDivisionFailed",
  )
}

///|
test "factortools dense wb: irreducible predicate" {
  inspect(dup_irreducible_p(fact_wb_dup([1, 0, 1]), Domain::ZZ), content="true")
  inspect(
    dup_irreducible_p(fact_wb_dup([1, 0, -1]), Domain::ZZ),
    content="false",
  )
  inspect(
    dmp_irreducible_p(fact_wb_poly([1, 0, 1]), 0, Domain::ZZ),
    content="true",
  )
  inspect(
    dmp_irreducible_p(fact_wb_poly([1, 2, 1]), 0, Domain::ZZ),
    content="false",
  )
}

///|
test "factortools dense wb: finite field factorization" {
  inspect(
    fact_wb_dup_factor_repr(
      dup_gf_factor(fact_wb_gf_dup([1, 0, 1], 2), Domain::GF(2)),
    ),
    content="(1,[([1,1],2)])",
  )
  sympolys_assert_error(
    fn() raise PolyError {
      dmp_gf_factor(DensePoly::Poly([]), 0, Domain::GF(2))
    },
    "NotUnivariate",
  )
}

///|
fn fact_wb_hensel_step_repr(
  value : (
    Array[FieldElem],
    Array[FieldElem],
    Array[FieldElem],
    Array[FieldElem],
  ),
) -> String {
  "(\{fact_wb_dup_repr(value.0)},\{fact_wb_dup_repr(value.1)},\{fact_wb_dup_repr(value.2)},\{fact_wb_dup_repr(value.3)})"
}

///|
fn fact_wb_hensel_lift_repr(items : Array[Array[FieldElem]]) -> String {
  "[" + items.map(fact_wb_dup_repr).join(",") + "]"
}

///|
fn fact_wb_dup_opt_repr(items : Array[FieldElem]?) -> String {
  match items {
    Some(values) => fact_wb_dup_repr(values)
    None => "None"
  }
}

///|
test "factortools dense wb: Hensel step and lift" {
  let f = fact_wb_dup([1, 18, 77])
  let g = fact_wb_dup([1, 2])
  let h = fact_wb_dup([1, 1])
  inspect(
    fact_wb_hensel_step_repr(
      dup_zz_hensel_step(
        5,
        f,
        g,
        h,
        fact_wb_dup([1]),
        fact_wb_dup([-1]),
        Domain::ZZ,
      ),
    ),
    content="([1,7],[1,11],[6],[-6])",
  )
  inspect(
    fact_wb_hensel_lift_repr(dup_zz_hensel_lift(5, f, [g, h], 2, Domain::ZZ)),
    content="[[1,7],[1,11]]",
  )
  inspect(
    fact_wb_hensel_lift_repr(
      dup_zz_hensel_lift(
        5,
        fact_wb_dup([1, 14, 45]),
        [fact_wb_dup([1, 4]), fact_wb_dup([1, 0])],
        2,
        Domain::ZZ,
      ),
    ),
    content="[[1,9],[1,5]]",
  )
}

///|
test "factortools dense wb: Wang non divisors" {
  inspect(
    fact_wb_dup_opt_repr(
      dmp_zz_wang_non_divisors(
        fact_wb_dup([2, 3, 5]),
        fact_wb_fe(1),
        fact_wb_fe(1),
        Domain::ZZ,
      ),
    ),
    content="[2,3,5]",
  )
  inspect(
    fact_wb_dup_opt_repr(
      dmp_zz_wang_non_divisors(
        fact_wb_dup([2, 4]),
        fact_wb_fe(1),
        fact_wb_fe(1),
        Domain::ZZ,
      ),
    ),
    content="None",
  )
}

///|
test "factortools dense wb: Wang test points" {
  let f = DensePoly::Poly([
    fact_wb_poly([1, 1]),
    fact_wb_poly([1]),
    fact_wb_poly([1]),
  ])
  let factors = [(fact_wb_poly([1, 1]), 1)]
  inspect(
    fact_wb_wang_test_points_repr(
      dmp_zz_wang_test_points(
        f,
        factors,
        fact_wb_fe(1),
        [fact_wb_fe(2)],
        1,
        Domain::ZZ,
      ),
    ),
    content="(1,[3,1,1],[3])",
  )
  let negative_lc = DensePoly::Poly([
    fact_wb_poly([-1, -1]),
    fact_wb_poly([1]),
    fact_wb_poly([1]),
  ])
  inspect(
    fact_wb_wang_test_points_repr(
      dmp_zz_wang_test_points(
        negative_lc,
        factors,
        fact_wb_fe(1),
        [fact_wb_fe(2)],
        1,
        Domain::ZZ,
      ),
    ),
    content="(-1,[3,-1,-1],[3])",
  )
  sympolys_assert_error(
    fn() raise PolyError {
      dmp_zz_wang_test_points(
        f,
        [(fact_wb_poly([1]), 1)],
        fact_wb_fe(1),
        [fact_wb_fe(2)],
        1,
        Domain::ZZ,
      )
    },
    "BadGenerator",
  )
}

///|
test "factortools dense wb: Wang leading coefficients" {
  let f = DensePoly::Poly([
    fact_wb_poly([1, 1]),
    fact_wb_poly([1]),
    fact_wb_poly([1]),
  ])
  let factors = [(fact_wb_poly([1, 1]), 1)]
  inspect(
    fact_wb_wang_lead_coeffs_repr(
      dmp_zz_wang_lead_coeffs(
        f,
        factors,
        fact_wb_fe(1),
        [fact_wb_fe(3)],
        [fact_wb_dup([3, 1, 1])],
        [fact_wb_fe(2)],
        1,
        Domain::ZZ,
      ),
    ),
    content="([[1,1],[1],[1]],[[3,1,1]],[[1,1]])",
  )
  let negative_f = DensePoly::Poly([
    fact_wb_poly([-1, -1]),
    fact_wb_poly([1]),
    fact_wb_poly([1]),
  ])
  inspect(
    fact_wb_wang_lead_coeffs_repr(
      dmp_zz_wang_lead_coeffs(
        negative_f,
        factors,
        fact_wb_fe(-1),
        [fact_wb_fe(3)],
        [fact_wb_dup([3, -1, -1])],
        [fact_wb_fe(2)],
        1,
        Domain::ZZ,
      ),
    ),
    content="([[-1,-1],[1],[1]],[[-3,1,1]],[[-1,-1]])",
  )
}

///|
test "factortools dense wb: Diophantine helpers" {
  inspect(
    fact_wb_hensel_lift_repr(
      dup_zz_diophantine(
        [fact_wb_dup([1, 1]), fact_wb_dup([1, -1])],
        0,
        5,
        Domain::ZZ,
      ),
    ),
    content="[[2],[-2]]",
  )
  inspect(
    fact_wb_hensel_lift_repr(
      dup_zz_diophantine(
        [fact_wb_dup([1, 0]), fact_wb_dup([1, -1]), fact_wb_dup([1, 1])],
        2,
        5,
        Domain::ZZ,
      ),
    ),
    content="[[],[-2],[-2]]",
  )
  let dmp_res = dmp_zz_diophantine(
    [fact_wb_poly([1, 1]), fact_wb_poly([1, -1])],
    fact_wb_poly([2, 3]),
    [],
    0,
    5,
    1,
    Domain::ZZ,
  )
  inspect(
    "[" + dmp_res.map(fact_wb_dmp_repr).join(",") + "]",
    content="[[2],[]]",
  )
  let chain_factors = [
    DensePoly::Poly([fact_wb_poly([1]), fact_wb_poly([2])]),
    DensePoly::Poly([fact_wb_poly([1, 1]), fact_wb_poly([1])]),
  ]
  let chain_c = DensePoly::Poly([fact_wb_poly([1]), fact_wb_poly([0])])
  let chain_res = dmp_zz_diophantine(
    chain_factors,
    chain_c,
    [fact_wb_fe(2)],
    1,
    5,
    1,
    Domain::ZZ,
  )
  inspect(
    "[" + chain_res.map(fact_wb_dmp_repr).join(",") + "]",
    content="[[[]],[[1],[]]]",
  )
  sympolys_assert_error(
    fn() raise PolyError {
      dmp_zz_diophantine(
        [fact_wb_poly([1, 1]), fact_wb_poly([1, -1])],
        fact_wb_poly([1]),
        [],
        0,
        5,
        0,
        Domain::QQ,
      )
    },
    "DomainMismatch",
  )
}

///|
test "factortools dense wb: Wang Hensel lifting" {
  let f = DensePoly::Poly([
    fact_wb_poly([1, 1]),
    fact_wb_poly([2, 3]),
    fact_wb_poly([2]),
  ])
  let factors = [fact_wb_dup([1, 2]), fact_wb_dup([3, 1])]
  let lead_coeffs = [fact_wb_poly([1]), fact_wb_poly([1, 1])]
  let lifted = dmp_zz_wang_hensel_lifting(
    f,
    factors,
    lead_coeffs,
    [fact_wb_fe(2)],
    5,
    1,
    Domain::ZZ,
  )
  inspect(
    "[" + lifted.map(fact_wb_dmp_repr).join(",") + "]",
    content="[[[1],[2]],[[1,1],[1]]]",
  )
}

///|
test "factortools dense wb: Wang frontdoor" {
  let f = DensePoly::Poly([
    fact_wb_poly([1, 1]),
    fact_wb_poly([2, 3]),
    fact_wb_poly([2]),
  ])
  inspect(
    "[" + dmp_zz_wang(f, 1, Domain::ZZ).map(fact_wb_dmp_repr).join(",") + "]",
    content="[[[1],[2]],[[1,1],[1]]]",
  )
  let xy = DensePoly::Poly([
    fact_wb_poly([2]),
    DensePoly::Poly([]),
    fact_wb_poly([-2, 0, 0]),
  ])
  inspect(
    fact_wb_dmp_factor_repr(dmp_zz_factor(xy, 1, Domain::ZZ)),
    content="(2,[([[1],[-1,0]],1),([[1],[1,0]],1)])",
  )
}

///|
test "factortools dense wb: algebraic extension factorization" {
  let a = @symcore.Expr::Symbol("a")
  let rel = (a ^ @symcore.int(2)) - @symcore.int(2)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let f = [
    fe_from_int(1, alg_domain),
    fe_from_int(0, alg_domain),
    fe_from_int(-2, alg_domain),
  ]
  let (coeff, factors) = dup_ext_factor(f, alg_domain)
  assert_true(coeff.to_string() == "1")
  assert_true(factors.length() == 2)
  assert_true(factors.all(item => item.0.length() == 2 && item.1 == 1))

  let (dmp_coeff, dmp_factors) = dmp_ext_factor(
    dmp_from_coeffs(f),
    0,
    alg_domain,
  )
  assert_true(dmp_coeff.to_string() == "1")
  assert_true(dmp_factors.length() == 2)

  sympolys_assert_error(
    fn() raise PolyError { dup_ext_factor(fact_wb_dup([1, 0, -2]), Domain::ZZ) },
    "DomainMismatch",
  )
}

///|
test "factortools dense wb: Gaussian factorization frontdoors" {
  let f = [
    fact_wb_gaussian_coeff(1, 0),
    fact_wb_gaussian_coeff(0, 0),
    fact_wb_gaussian_coeff(1, 0),
  ]
  inspect(
    fact_wb_dup_factor_gaussian_repr(dup_qq_i_factor(f, Domain::QQ_I)),
    content="(1,[([1,-I],1),([1,I],1)])",
  )
  inspect(
    fact_wb_dup_factor_gaussian_repr(dup_zz_i_factor(f, Domain::ZZ_I)),
    content="(1,[([1,-I],1),([1,I],1)])",
  )
  inspect(
    fact_wb_dmp_factor_gaussian_repr(
      dmp_qq_i_factor(dmp_from_coeffs(f), 0, Domain::QQ_I),
    ),
    content="(1,[([1,-I],1),([1,I],1)])",
  )
  inspect(
    fact_wb_dmp_factor_gaussian_repr(
      dmp_zz_i_factor(dmp_from_coeffs(f), 0, Domain::ZZ_I),
    ),
    content="(1,[([1,-I],1),([1,I],1)])",
  )
  sympolys_assert_error(
    fn() raise PolyError { dup_qq_i_factor(f, Domain::QQ) },
    "DomainMismatch",
  )
}

///|
test "factortools dense wb: dmp multivariate limits and empty trials" {
  sympolys_assert_error(
    fn() raise PolyError {
      dmp_factor_list(
        DensePoly::Poly([fact_wb_poly([1, 0]), fact_wb_poly([1])]),
        1,
        Domain::ZZ,
      )
    },
    "NotUnivariate",
  )
  inspect(
    fact_wb_dmp_include_repr(
      dmp_trial_division(
        DensePoly::Poly([fact_wb_poly([1, 0]), fact_wb_poly([1])]),
        [],
        1,
        Domain::ZZ,
      ),
    ),
    content="[]",
  )
}
