///|
fn fact_int_wb_fe(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::ZZ)
}

///|
fn fact_int_wb_dup(vals : Array[Int]) -> Array[FieldElem] raise PolyError {
  vals.map(v => fact_int_wb_fe(v))
}

///|
fn fact_int_wb_poly(vals : Array[Int]) -> DensePoly raise PolyError {
  DensePoly::Poly(vals.map(v => DensePoly::Coef(fact_int_wb_fe(v))))
}

///|
fn fact_int_wb_dup_repr(f : Array[FieldElem]) -> String {
  "[" + f.map(c => c.to_string()).join(",") + "]"
}

///|
test "factortools integer wb: Mignotte bounds" {
  inspect(
    dup_zz_mignotte_bound(fact_int_wb_dup([1, 14, 56, 64]), Domain::ZZ),
    content="152",
  )
  inspect(
    dup_zz_mignotte_bound(fact_int_wb_dup([2, 3, 4]), Domain::ZZ),
    content="6",
  )
  inspect(
    dup_zz_mignotte_bound(
      fact_int_wb_dup([87, 4, 80, 17, 9, 12, 49, 26]),
      Domain::ZZ,
    ),
    content="744",
  )
  inspect(
    dmp_zz_mignotte_bound(fact_int_wb_poly([1, 2, 1]), 0, Domain::ZZ),
    content="8",
  )
}

///|
test "factortools integer wb: Eisenstein irreducibility" {
  inspect(
    dup_zz_irreducible_p(fact_int_wb_dup([1, 0, 2]), Domain::ZZ),
    content="true",
  )
  inspect(
    dup_zz_irreducible_p(fact_int_wb_dup([1, 0, 1]), Domain::ZZ),
    content="false",
  )
}

///|
test "factortools integer wb: cyclotomic polynomial" {
  inspect(
    fact_int_wb_dup_repr(dup_zz_cyclotomic_poly(12, Domain::ZZ)),
    content="[1,0,-1,0,1]",
  )
}

///|
test "factortools integer wb: cyclotomic predicate" {
  inspect(
    dup_cyclotomic_p(dup_zz_cyclotomic_poly(12, Domain::ZZ), Domain::ZZ),
    content="true",
  )
  let false_case = fact_int_wb_dup([
    1, 0, 1, 0, 0, 0, -1, 0, 1, 0, -1, 0, 0, 0, 1, 0, 1,
  ])
  let true_case = fact_int_wb_dup([
    1, 0, 1, 0, 0, 0, -1, 0, -1, 0, -1, 0, 0, 0, 1, 0, 1,
  ])
  inspect(dup_cyclotomic_p(false_case, Domain::ZZ), content="false")
  inspect(dup_cyclotomic_p(true_case, Domain::ZZ), content="true")
}

///|
test "factortools integer wb: domain limits" {
  let bad : Result[FieldElem, PolyError] = try? dup_zz_mignotte_bound(
    fact_int_wb_dup([1, 1]),
    Domain::QQ,
  )
  assert_true(bad is Err(PolyError::DomainMismatch))
  inspect(
    dup_cyclotomic_p([fe_from_int(1, Domain::GF(2))], Domain::GF(2)),
    content="false",
  )
}
