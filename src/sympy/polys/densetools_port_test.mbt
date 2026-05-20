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

///|
test "densetools content and primitive" {
  let f = [fezz(6), fezz(8), fezz(12)]
  let ours_content = @sympolys.dup_content(f, Domain::ZZ).to_string()
  let oracle_content = dup_content(dup_to_rats(f), domain="ZZ")
  assert_eq(ours_content, oracle_content)
  let ours_primitive = @sympolys.dup_primitive(f, Domain::ZZ)
  let ours_primitive_str = "(\{ours_primitive.0},\{dup_repr(ours_primitive.1)})"
  let oracle_primitive = dup_primitive(dup_to_rats(f), domain="ZZ")
  assert_eq(ours_primitive_str, oracle_primitive)

  let xy = @sympolys.dense_poly([poly_int([2, 6]), poly_int([4, 12])])
  let ours_ground_content = @sympolys.dmp_ground_content(xy, 1, Domain::ZZ).to_string()
  let oracle_ground_content = dmp_ground_content(
    dense_data_of(xy),
    1,
    domain="ZZ",
  )
  assert_eq(ours_ground_content, oracle_ground_content)
  let ours_ground_primitive = @sympolys.dmp_ground_primitive(xy, 1, Domain::ZZ)
  let ours_ground_primitive_str = "(\{ours_ground_primitive.0},\{dmp_repr(ours_ground_primitive.1)})"
  let oracle_ground_primitive = dmp_ground_primitive(
    dense_data_of(xy),
    1,
    domain="ZZ",
  )
  assert_eq(ours_ground_primitive_str, oracle_ground_primitive)
}
