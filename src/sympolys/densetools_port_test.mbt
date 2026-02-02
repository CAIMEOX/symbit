///|
test "densetools dup integrate/diff/eval" {
  let f = [
    try! fe_from_int(3, Domain::QQ),
    try! fe_from_int(2, Domain::QQ),
    try! fe_from_int(1, Domain::QQ),
  ]
  let ours_i = dup_repr(dup_integrate(f, 1, Domain::QQ))
  let oracle_i = @sympy_polys.dup_integrate(dup_to_rats(f), 1, domain="QQ")
  guard ours_i == oracle_i else { fail("dup_integrate mismatch") }

  let ours_i2 = dup_repr(dup_integrate(f, 2, Domain::QQ))
  let oracle_i2 = @sympy_polys.dup_integrate(dup_to_rats(f), 2, domain="QQ")
  guard ours_i2 == oracle_i2 else { fail("dup_integrate m=2 mismatch") }

  let ours_d = dup_repr(dup_diff(f, 1, Domain::QQ))
  let oracle_d = @sympy_polys.dup_diff(dup_to_rats(f), 1, domain="QQ")
  guard ours_d == oracle_d else { fail("dup_diff mismatch") }

  let ours_d2 = dup_repr(dup_diff(f, 2, Domain::QQ))
  let oracle_d2 = @sympy_polys.dup_diff(dup_to_rats(f), 2, domain="QQ")
  guard ours_d2 == oracle_d2 else { fail("dup_diff m=2 mismatch") }

  let a = try! fe_from_int(2, Domain::QQ)
  let ours_eval = dup_eval(f, a, Domain::QQ).to_string()
  let oracle_eval = @sympy_polys.dup_eval(dup_to_rats(f), br_int(2), domain="QQ")
  guard ours_eval == oracle_eval else { fail("dup_eval mismatch") }
}

///|
test "densetools dmp integrate/diff/eval" {
  let one = feqq(1, 1)
  let two = feqq(2, 1)
  let zero = feqq(0, 1)
  // f = x + 2*y
  let f = dense_poly([poly_fe([one]), poly_fe([two, zero])])

  let ours_i = dmp_repr(dmp_integrate(f, 1, 1, Domain::QQ))
  let oracle_i = @sympy_polys.dmp_integrate(
    dense_data_of(f),
    1,
    1,
    domain="QQ",
  )
  guard ours_i == oracle_i else { fail("dmp_integrate mismatch") }

  let ours_i1 = dmp_repr(dmp_integrate_in(f, 1, 1, 1, Domain::QQ))
  let oracle_i1 = @sympy_polys.dmp_integrate_in(
    dense_data_of(f),
    1,
    1,
    1,
    domain="QQ",
  )
  guard ours_i1 == oracle_i1 else { fail("dmp_integrate_in mismatch") }

  let ours_d = dmp_repr(dmp_diff(f, 1, 1, Domain::QQ))
  let oracle_d = @sympy_polys.dmp_diff(dense_data_of(f), 1, 1, domain="QQ")
  guard ours_d == oracle_d else { fail("dmp_diff mismatch") }

  let ours_d1 = dmp_repr(dmp_diff_in(f, 1, 1, 1, Domain::QQ))
  let oracle_d1 = @sympy_polys.dmp_diff_in(
    dense_data_of(f),
    1,
    1,
    1,
    domain="QQ",
  )
  guard ours_d1 == oracle_d1 else { fail("dmp_diff_in mismatch") }

  let a = feqq(2, 1)
  let ours_eval = dmp_repr(dmp_eval(f, a, 1, Domain::QQ))
  let oracle_eval = @sympy_polys.dmp_eval(
    dense_data_of(f),
    br_int(2),
    1,
    domain="QQ",
  )
  guard ours_eval == oracle_eval else { fail("dmp_eval mismatch") }

  let ours_eval1 = dmp_repr(dmp_eval_in(f, a, 1, 1, Domain::QQ))
  let oracle_eval1 = @sympy_polys.dmp_eval_in(
    dense_data_of(f),
    br_int(2),
    1,
    1,
    domain="QQ",
  )
  guard ours_eval1 == oracle_eval1 else { fail("dmp_eval_in mismatch") }
}

///|
test "densetools monic" {
  let f = [fezz(3), fezz(6), fezz(9)]
  let ours = dup_repr(dup_monic(f, Domain::ZZ))
  let oracle = @sympy_polys.dup_monic(dup_to_rats(f))
  guard ours == oracle else { fail("dup_monic mismatch") }

  let f2 = dense_poly([poly_int([3, 0]), poly_int([6])])
  let ours2 = dmp_repr(dmp_ground_monic(f2, 1, Domain::ZZ))
  let oracle2 = @sympy_polys.dmp_ground_monic(dense_data_of(f2), 1)
  guard ours2 == oracle2 else { fail("dmp_ground_monic mismatch") }
}
