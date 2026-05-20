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
  let bad : Result[Array[(Array[FieldElem], Int)], PolyError] = try? dup_trial_division(
    f,
    [fact_wb_dup([1, 3])],
    Domain::ZZ,
  )
  assert_true(bad is Err(PolyError::PolynomialDivisionFailed))
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
  let bad : Result[(FieldElem, Array[(DensePoly, Int)]), PolyError] = try? dmp_gf_factor(
    DensePoly::Poly([]),
    0,
    Domain::GF(2),
  )
  assert_true(bad is Err(PolyError::NotUnivariate))
}

///|
test "factortools dense wb: dmp multivariate limits" {
  let bad_factor : Result[(FieldElem, Array[(DensePoly, Int)]), PolyError] = try? dmp_factor_list(
    DensePoly::Poly([fact_wb_poly([1, 0]), fact_wb_poly([1])]),
    1,
    Domain::ZZ,
  )
  assert_true(bad_factor is Err(PolyError::NotUnivariate))
  let bad_trial : Result[Array[(DensePoly, Int)], PolyError] = try? dmp_trial_division(
    DensePoly::Poly([fact_wb_poly([1, 0]), fact_wb_poly([1])]),
    [],
    1,
    Domain::ZZ,
  )
  assert_true(bad_trial is Err(PolyError::NotUnivariate))
}
