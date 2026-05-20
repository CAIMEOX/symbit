///|
fn dt_port_extract_repr(
  value : (FieldElem, Array[FieldElem], Array[FieldElem]),
) -> String {
  "(\{value.0},\{dup_repr(value.1)},\{dup_repr(value.2)})"
}

///|
fn dt_port_clear_repr(value : (FieldElem, Array[FieldElem])) -> String {
  "(\{value.0},\{dup_repr(value.1)})"
}

///|
fn dt_port_dmp_extract_repr(
  value : (FieldElem, DensePoly, DensePoly),
) -> String {
  "(\{value.0},\{dmp_repr(value.1)},\{dmp_repr(value.2)})"
}

///|
fn dt_port_dmp_clear_repr(value : (FieldElem, DensePoly)) -> String {
  "(\{value.0},\{dmp_repr(value.1)})"
}

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

///|
test "densetools extract trunc oracle parity" {
  let f = [fezz(6), fezz(12), fezz(18)]
  let g = [fezz(4), fezz(8), fezz(12)]
  assert_eq(
    dt_port_extract_repr(@sympolys.dup_extract(f, g, Domain::ZZ)),
    dup_extract(dup_to_rats(f), dup_to_rats(g), domain="ZZ"),
  )

  let xy1 = @sympolys.dense_poly([poly_int([6, 12]), poly_int([18])])
  let xy2 = @sympolys.dense_poly([poly_int([4, 8]), poly_int([12])])
  assert_eq(
    dt_port_dmp_extract_repr(
      @sympolys.dmp_ground_extract(xy1, xy2, 1, Domain::ZZ),
    ),
    dmp_ground_extract(dense_data_of(xy1), dense_data_of(xy2), 1, domain="ZZ"),
  )

  let h = [fezz(2), fezz(3), fezz(5), fezz(7)]
  assert_eq(
    dup_repr(@sympolys.dup_trunc(h, fezz(3), Domain::ZZ)),
    dup_trunc(dup_to_rats(h), br_int(3), domain="ZZ"),
  )
  let xy = @sympolys.dense_poly([
    poly_int([3, 8]),
    poly_int([5, 6]),
    poly_int([2, 3]),
  ])
  assert_eq(
    dmp_repr(@sympolys.dmp_ground_trunc(xy, fezz(3), 1, Domain::ZZ)),
    dmp_ground_trunc(dense_data_of(xy), br_int(3), 1, domain="ZZ"),
  )
  let modulus = poly_int([1, -1])
  assert_eq(
    dmp_repr(@sympolys.dmp_trunc(xy, modulus, 1, Domain::ZZ)),
    dmp_trunc(dense_data_of(xy), dense_data_of(modulus), 1, domain="ZZ"),
  )
}

///|
test "densetools shift transform compose oracle parity" {
  let mirrored = [fezz(1), fezz(2), fezz(-4), fezz(2)]
  assert_eq(
    dup_repr(@sympolys.dup_mirror(mirrored, Domain::ZZ)),
    dup_mirror(dup_to_rats(mirrored), domain="ZZ"),
  )
  let quadratic = [fezz(1), fezz(-2), fezz(1)]
  assert_eq(
    dup_repr(@sympolys.dup_scale(quadratic, fezz(2), Domain::ZZ)),
    dup_scale(dup_to_rats(quadratic), br_int(2), domain="ZZ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_shift(quadratic, fezz(2), Domain::ZZ)),
    dup_shift(dup_to_rats(quadratic), br_int(2), domain="ZZ"),
  )
  assert_eq(
    dup_repr(
      @sympolys.dup_transform(
        quadratic,
        [fezz(1), fezz(0), fezz(1)],
        [fezz(1), fezz(-1)],
        Domain::ZZ,
      ),
    ),
    dup_transform(
      dup_to_rats(quadratic),
      [br_int(1), br_int(0), br_int(1)],
      [br_int(1), br_int(-1)],
      domain="ZZ",
    ),
  )
  let composed = [fezz(1), fezz(1), fezz(0)]
  assert_eq(
    dup_repr(@sympolys.dup_compose(composed, [fezz(1), fezz(-1)], Domain::ZZ)),
    dup_compose(dup_to_rats(composed), [br_int(1), br_int(-1)], domain="ZZ"),
  )

  let shifted = @sympolys.dense_poly([
    poly_int([1, 0]),
    poly_int([2, 3]),
    poly_int([4, 5]),
  ])
  assert_eq(
    dmp_repr(@sympolys.dmp_shift(shifted, [fezz(1), fezz(2)], 1, Domain::ZZ)),
    dmp_shift(dense_data_of(shifted), [br_int(1), br_int(2)], 1, domain="ZZ"),
  )
  let f = @sympolys.dense_poly([poly_int([1, 2]), poly_int([1, 0])])
  let y = @sympolys.dense_poly([poly_int([1, 0])])
  assert_eq(
    dmp_repr(@sympolys.dmp_compose(f, y, 1, Domain::ZZ)),
    dmp_compose(dense_data_of(f), dense_data_of(y), 1, domain="ZZ"),
  )
}

///|
test "densetools eval tail diff eval clear denoms revert oracle parity" {
  let signs = [fezz(1), fezz(0), fezz(-1), fezz(-1), fezz(1)]
  assert_eq(
    @sympolys.dup_sign_variations(signs, Domain::ZZ).to_string(),
    dup_sign_variations(dup_to_rats(signs), domain="ZZ"),
  )

  let rationals = [feqq(1, 2), feqq(1, 3)]
  assert_eq(
    dt_port_clear_repr(@sympolys.dup_clear_denoms(rationals, Domain::QQ)),
    dup_clear_denoms(dup_to_rats(rationals), domain="QQ"),
  )
  let rational_xy = @sympolys.dense_poly([
    poly_fe([feqq(1, 2)]),
    poly_fe([feqq(1, 3), feqq(1, 1)]),
  ])
  assert_eq(
    dt_port_dmp_clear_repr(
      @sympolys.dmp_clear_denoms(rational_xy, 1, Domain::QQ),
    ),
    dmp_clear_denoms(dense_data_of(rational_xy), 1, domain="QQ"),
  )

  let eval_poly = @sympolys.dense_poly([poly_int([2, 3]), poly_int([1, 2])])
  assert_eq(
    dmp_repr(@sympolys.dmp_eval_tail(eval_poly, [fezz(2)], 1, Domain::ZZ)),
    dmp_eval_tail(dense_data_of(eval_poly), [br_int(2)], 1, domain="ZZ"),
  )
  assert_eq(
    dmp_repr(
      @sympolys.dmp_eval_tail(eval_poly, [fezz(2), fezz(2)], 1, Domain::ZZ),
    ),
    dmp_eval_tail(
      dense_data_of(eval_poly),
      [br_int(2), br_int(2)],
      1,
      domain="ZZ",
    ),
  )

  let diff_poly = @sympolys.dense_poly([
    poly_int([1, 2, 3]),
    poly_int([2, 3, 1]),
  ])
  assert_eq(
    dmp_repr(
      @sympolys.dmp_diff_eval_in(diff_poly, 1, fezz(2), 0, 1, Domain::ZZ),
    ),
    dmp_diff_eval_in(dense_data_of(diff_poly), 1, br_int(2), 0, 1, domain="ZZ"),
  )
  assert_eq(
    dmp_repr(
      @sympolys.dmp_diff_eval_in(diff_poly, 1, fezz(2), 1, 1, Domain::ZZ),
    ),
    dmp_diff_eval_in(dense_data_of(diff_poly), 1, br_int(2), 1, 1, domain="ZZ"),
  )

  let inv_poly = [feqq(-1, 1), feqq(1, 1)]
  assert_eq(
    dup_repr(@sympolys.dup_revert(inv_poly, 4, Domain::QQ)),
    dup_revert(dup_to_rats(inv_poly), 4, domain="QQ"),
  )
  let inv_dmp = poly_fe(inv_poly)
  assert_eq(
    dmp_repr(@sympolys.dmp_revert(inv_dmp, 4, 0, Domain::QQ)),
    dmp_revert(dense_data_of(inv_dmp), 4, 0, domain="QQ"),
  )
}

///|
test "densetools series compose reversion oracle parity" {
  let f = [fezz(1), fezz(1), fezz(1)]
  let g = [fezz(1), fezz(1)]
  assert_eq(
    dup_repr(@sympolys.dup_series_compose(f, g, 3, Domain::ZZ)),
    dup_series_compose(dup_to_rats(f), dup_to_rats(g), 3, domain="ZZ"),
  )

  let reversion = [feqq(-1, 1), feqq(1, 1), feqq(0, 1)]
  assert_eq(
    dup_repr(@sympolys.dup_series_reversion(reversion, 4, Domain::QQ)),
    dup_series_reversion(dup_to_rats(reversion), 4, domain="QQ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_series_reversion(reversion, 5, Domain::QQ)),
    dup_series_reversion(dup_to_rats(reversion), 5, domain="QQ"),
  )
}
