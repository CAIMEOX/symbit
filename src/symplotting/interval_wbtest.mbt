///|
test "symplotting interval membership or keeps SymPy validity semantics" {
  let lhs = interval_membership(Some(true), None)
  let rhs = interval_membership(Some(false), Some(true))
  let out = interval_membership_or(lhs, rhs)
  assert_eq(out.truth, Some(true))
  assert_eq(out.validity, None)
}
