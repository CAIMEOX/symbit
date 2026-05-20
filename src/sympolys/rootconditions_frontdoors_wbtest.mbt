///|
fn rootcond_wb_fe(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::ZZ)
}

///|
fn rootcond_wb_dup_repr(coeffs : Array[FieldElem]) -> String {
  let body = coeffs.map(c => c.to_string()).join(",")
  "[\{body}]"
}

///|
test "rootconditions dup frontdoors" {
  let hurwitz = dup_routh_hurwitz(
    [rootcond_wb_fe(1), rootcond_wb_fe(3), rootcond_wb_fe(3), rootcond_wb_fe(1)],
    Domain::ZZ,
  )
  inspect(rootcond_wb_dup_repr(hurwitz), content="[3,8,1]")
  let schur = dup_schur_conditions(
    [rootcond_wb_fe(1), rootcond_wb_fe(0), rootcond_wb_fe(0)],
    Domain::ZZ,
  )
  inspect(rootcond_wb_dup_repr(schur), content="[2,1]")
  let root_at_minus_one = dup_schur_conditions(
    [rootcond_wb_fe(1), rootcond_wb_fe(3), rootcond_wb_fe(3), rootcond_wb_fe(1)],
    Domain::ZZ,
  )
  inspect(rootcond_wb_dup_repr(root_at_minus_one), content="[-1]")
}
