///|
test "rootconditions: dense frontdoor oracle parity" {
  let stable = [fezz(1), fezz(3), fezz(3), fezz(1)]
  let ours_hurwitz = dup_repr(@sympolys.dup_routh_hurwitz(stable, Domain::ZZ))
  let oracle_hurwitz = dup_routh_hurwitz(dup_to_rats(stable))
  assert_eq(ours_hurwitz, oracle_hurwitz)
  let inside_unit = [fezz(1), fezz(0), fezz(0)]
  let ours_schur = dup_repr(
    @sympolys.dup_schur_conditions(inside_unit, Domain::ZZ),
  )
  let oracle_schur = dup_schur_conditions(dup_to_rats(inside_unit))
  assert_eq(ours_schur, oracle_schur)
  let at_minus_one = dup_repr(
    @sympolys.dup_schur_conditions(stable, Domain::ZZ),
  )
  let oracle_at_minus_one = dup_schur_conditions(dup_to_rats(stable))
  assert_eq(at_minus_one, oracle_at_minus_one)
}
