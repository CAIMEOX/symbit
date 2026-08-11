///|
fn fact_int_wb_fe(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, ZZ)
}

///|
fn fact_int_wb_dup(vals : Array[Int]) -> Array[FieldElem] raise PolyError {
  vals.map(v => fact_int_wb_fe(v))
}

///|
fn fact_int_wb_poly(vals : Array[Int]) -> DensePoly raise PolyError {
  Poly(vals.map(v => Coef(fact_int_wb_fe(v))))
}

///|
fn fact_int_wb_dup_repr(f : Array[FieldElem]) -> String {
  "[" + f.map(c => Show::to_string(c)).join(",") + "]"
}

///|
fn fact_int_wb_dup_list_repr(items : Array[Array[FieldElem]]) -> String {
  "[" + items.map(fact_int_wb_dup_repr).join(",") + "]"
}

///|
fn fact_int_wb_factor_repr(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{fact_int_wb_dup_repr(item.0)},\{item.1})")
  "(\{coeff},[" + parts.join(",") + "])"
}

///|
fn fact_int_wb_factor_sqf_repr(
  value : (FieldElem, Array[Array[FieldElem]]),
) -> String {
  let (coeff, factors) = value
  "(\{coeff},\{fact_int_wb_dup_list_repr(factors)})"
}

///|
fn fact_int_wb_dmp_factor_repr(
  value : (FieldElem, Array[(DensePoly, Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{fact_int_wb_dmp_repr(item.0)},\{item.1})")
  "(\{coeff},[" + parts.join(",") + "])"
}

///|
fn fact_int_wb_dmp_repr(f : DensePoly) -> String {
  match f {
    Coef(c) => Show::to_string(c)
    Poly(items) =>
      "[" + items.map(item => fact_int_wb_dmp_repr(item)).join(",") + "]"
  }
}

///|
test "factortools integer wb: Mignotte bounds" {
  inspect(
    dup_zz_mignotte_bound(fact_int_wb_dup([1, 14, 56, 64]), ZZ),
    content="152",
  )
  inspect(dup_zz_mignotte_bound(fact_int_wb_dup([2, 3, 4]), ZZ), content="6")
  inspect(
    dup_zz_mignotte_bound(fact_int_wb_dup([87, 4, 80, 17, 9, 12, 49, 26]), ZZ),
    content="744",
  )
  inspect(
    dmp_zz_mignotte_bound(fact_int_wb_poly([1, 2, 1]), 0, ZZ),
    content="8",
  )
}

///|
test "factortools integer wb: Eisenstein irreducibility" {
  inspect(dup_zz_irreducible_p(fact_int_wb_dup([1, 0, 2]), ZZ), content="true")
  inspect(dup_zz_irreducible_p(fact_int_wb_dup([1, 0, 1]), ZZ), content="false")
}

///|
test "factortools integer wb: cyclotomic polynomial" {
  inspect(
    fact_int_wb_dup_repr(dup_zz_cyclotomic_poly(12, ZZ)),
    content="[1,0,-1,0,1]",
  )
}

///|
test "factortools integer wb: ZZ factor frontdoors" {
  let f = fact_int_wb_dup([2, 0, -2])
  inspect(
    fact_int_wb_factor_repr(dup_zz_factor(f, ZZ)),
    content="(2,[([1,-1],1),([1,1],1)])",
  )
  inspect(
    fact_int_wb_factor_sqf_repr(dup_zz_factor_sqf(f, ZZ)),
    content="(2,[[1,-1],[1,1]])",
  )
  inspect(
    fact_int_wb_dup_list_repr(
      dup_zz_zassenhaus(fact_int_wb_dup([1, 0, -1]), ZZ),
    ),
    content="[[1,-1],[1,1]]",
  )
  inspect(
    fact_int_wb_dmp_factor_repr(
      dmp_zz_factor(fact_int_wb_poly([2, 0, -2]), 0, ZZ),
    ),
    content="(2,[([1,-1],1),([1,1],1)])",
  )
}

///|
test "factortools integer wb: cyclotomic factor frontdoor" {
  let minus = dup_zz_cyclotomic_factor(fact_int_wb_dup([1, 0, 0, 0, -1]), ZZ)
  match minus {
    Some(factors) =>
      inspect(
        fact_int_wb_dup_list_repr(factors),
        content="[[1,-1],[1,1],[1,0,1]]",
      )
    None => fail("x**4 - 1 should be cyclotomic-factorable")
  }
  let plus = dup_zz_cyclotomic_factor(fact_int_wb_dup([1, 0, 0, 0, 1]), ZZ)
  match plus {
    Some(factors) =>
      inspect(fact_int_wb_dup_list_repr(factors), content="[[1,0,0,0,1]]")
    None => fail("x**4 + 1 should be cyclotomic-factorable")
  }
  let none = dup_zz_cyclotomic_factor(fact_int_wb_dup([1, 1, 1]), ZZ)
  assert_true(none is None)
}

///|
test "factortools integer wb: cyclotomic predicate" {
  inspect(dup_cyclotomic_p(dup_zz_cyclotomic_poly(12, ZZ), ZZ), content="true")
  let false_case = fact_int_wb_dup([
    1, 0, 1, 0, 0, 0, -1, 0, 1, 0, -1, 0, 0, 0, 1, 0, 1,
  ])
  let true_case = fact_int_wb_dup([
    1, 0, 1, 0, 0, 0, -1, 0, -1, 0, -1, 0, 0, 0, 1, 0, 1,
  ])
  inspect(dup_cyclotomic_p(false_case, ZZ), content="false")
  inspect(dup_cyclotomic_p(true_case, ZZ), content="true")
}

///|
test "factortools integer wb: domain limits" {
  sympolys_assert_error(
    fn() raise PolyError { dup_zz_mignotte_bound(fact_int_wb_dup([1, 1]), QQ) },
    "DomainMismatch",
  )
  inspect(dup_cyclotomic_p([fe_from_int(1, GF(2))], GF(2)), content="false")
}
