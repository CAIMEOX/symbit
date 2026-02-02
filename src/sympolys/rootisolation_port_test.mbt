///|
test "rootisolation: cauchy/mignotte bounds parity" {
  let f = [
    feqq(1, 1),
    feqq(0, 1),
    feqq(-2, 1),
  ] // x^2 - 2
  let ours_upper = dup_cauchy_upper_bound(f, Domain::QQ).to_string()
  let oracle_upper = @sympy_polys.dup_cauchy_upper_bound(dup_to_rats(f), domain="QQ")
  guard ours_upper == oracle_upper else { fail("cauchy upper mismatch") }

  let ours_lower = dup_cauchy_lower_bound(f, Domain::QQ).to_string()
  let oracle_lower = @sympy_polys.dup_cauchy_lower_bound(dup_to_rats(f), domain="QQ")
  guard ours_lower == oracle_lower else { fail("cauchy lower mismatch") }

  let ours_m = dup_mignotte_sep_bound_squared(f, Domain::QQ).to_string()
  let oracle_m = @sympy_polys.dup_mignotte_sep_bound_squared(dup_to_rats(f), domain="QQ")
  guard ours_m == oracle_m else { fail("mignotte bound mismatch") }
}
