///|
test "densetools dup integrate/diff/eval" {
  let f = [
    @sympolys.fe_from_int(3, Domain::QQ),
    @sympolys.fe_from_int(2, Domain::QQ),
    @sympolys.fe_from_int(1, Domain::QQ),
  ]
  let ours_i = dup_repr(@sympolys.dup_integrate(f, 1, Domain::QQ))
  let oracle_i = dup_integrate(dup_to_rats(f), 1, domain="QQ")
  assert_eq(ours_i, oracle_i)
  let ours_i2 = dup_repr(@sympolys.dup_integrate(f, 2, Domain::QQ))
  let oracle_i2 = dup_integrate(dup_to_rats(f), 2, domain="QQ")
  assert_eq(ours_i2, oracle_i2)
  let ours_d = dup_repr(@sympolys.dup_diff(f, 1, Domain::QQ))
  let oracle_d = dup_diff(dup_to_rats(f), 1, domain="QQ")
  assert_eq(ours_d, oracle_d)
  let ours_d2 = dup_repr(@sympolys.dup_diff(f, 2, Domain::QQ))
  let oracle_d2 = dup_diff(dup_to_rats(f), 2, domain="QQ")
  assert_eq(ours_d2, oracle_d2)
  let a = @sympolys.fe_from_int(2, Domain::QQ)
  let ours_eval = @sympolys.dup_eval(f, a, Domain::QQ).to_string()
  let oracle_eval = dup_eval(dup_to_rats(f), br_int(2), domain="QQ")
  assert_eq(ours_eval, oracle_eval)
}

///|
test "densetools dmp integrate/diff/eval" {
  let one = feqq(1, 1)
  let two = feqq(2, 1)
  let zero = feqq(0, 1)
  // f = x + 2*y
  let f = @sympolys.dense_poly([poly_fe([one]), poly_fe([two, zero])])
  let ours_i = dmp_repr(@sympolys.dmp_integrate(f, 1, 1, Domain::QQ))
  let oracle_i = dmp_integrate(dense_data_of(f), 1, 1, domain="QQ")
  assert_eq(ours_i, oracle_i)
  let ours_i1 = dmp_repr(@sympolys.dmp_integrate_in(f, 1, 1, 1, Domain::QQ))
  let oracle_i1 = dmp_integrate_in(dense_data_of(f), 1, 1, 1, domain="QQ")
  assert_eq(ours_i1, oracle_i1)
  let ours_d = dmp_repr(@sympolys.dmp_diff(f, 1, 1, Domain::QQ))
  let oracle_d = dmp_diff(dense_data_of(f), 1, 1, domain="QQ")
  assert_eq(ours_d, oracle_d)
  let ours_d1 = dmp_repr(@sympolys.dmp_diff_in(f, 1, 1, 1, Domain::QQ))
  let oracle_d1 = dmp_diff_in(dense_data_of(f), 1, 1, 1, domain="QQ")
  assert_eq(ours_d1, oracle_d1)
  let a = feqq(2, 1)
  let ours_eval = dmp_repr(@sympolys.dmp_eval(f, a, 1, Domain::QQ))
  let oracle_eval = dmp_eval(dense_data_of(f), br_int(2), 1, domain="QQ")
  assert_eq(ours_eval, oracle_eval)
  let ours_eval1 = dmp_repr(@sympolys.dmp_eval_in(f, a, 1, 1, Domain::QQ))
  let oracle_eval1 = dmp_eval_in(dense_data_of(f), br_int(2), 1, 1, domain="QQ")
  assert_eq(ours_eval1, oracle_eval1)
}

///|
test "densetools monic" {
  let f = [fezz(3), fezz(6), fezz(9)]
  let ours = dup_repr(@sympolys.dup_monic(f, Domain::ZZ))
  let oracle = dup_monic(dup_to_rats(f))
  assert_eq(ours, oracle)
  let f2 = @sympolys.dense_poly([poly_int([3, 0]), poly_int([6])])
  let ours2 = dmp_repr(@sympolys.dmp_ground_monic(f2, 1, Domain::ZZ))
  let oracle2 = dmp_ground_monic(dense_data_of(f2), 1)
  assert_eq(ours2, oracle2)
}
