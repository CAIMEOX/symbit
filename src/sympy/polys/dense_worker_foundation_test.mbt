///|
test "polys dense worker preserves scalar zero and rational coefficients" {
  assert_eq(dup_neg([br_int(0), br_rat(1, 2)], domain="QQ"), "[0,-1/2]")
  assert_eq(
    dup_add_ground([br_rat(1, 2), br_rat(1, 3)], br_rat(1, 6), domain="QQ"),
    "[1/2,1/2]",
  )
}

///|
test "polys dense worker preserves nested dense shape" {
  let nested : DenseData = Poly([
    Poly([Coef(br_int(1)), Coef(br_int(0))]),
    Poly([Coef(br_int(2))]),
  ])
  assert_eq(dmp_neg(nested, 1), "[[-1,0],[-2]]")
  assert_eq(dmp_add(nested, nested, 1), "[[2,0],[4]]")
}

///|
test "polys dense worker rejects strict errors then recovers" {
  let rejected = try {
    dup_exquo_ground([br_int(1)], br_int(0)) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(dup_add([br_int(1)], [br_int(2)]), "[3]")
}

///|
test "polys dense worker keeps rootconditions request scoped" {
  assert_eq(dup_schur_conditions([br_int(1), br_int(0), br_int(0)]), "[2,1]")
  assert_eq(
    dup_routh_hurwitz([br_int(1), br_int(3), br_int(3), br_int(1)]),
    "[3,8,1]",
  )
}

///|
test "polys dense worker keeps raw conversion and exact formatting" {
  assert_eq(dup_abs([br_int(-2), br_rat(-1, 2)], domain="QQ"), "[2,1/2]")
  let raw_rejected = try {
    dup_exquo_ground([br_rat(1, 2), br_int(1)], br_rat(1, 2), domain="QQ")
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(raw_rejected)
  assert_eq(
    dup_rr_div([br_int(1), br_int(0), br_int(1)], [br_int(1), br_int(-1)]),
    "([1,1],[2])",
  )
}

///|
test "polys dense worker recovers after domain conversion error" {
  let rejected = try {
    dup_neg([br_rat(1, 2)], domain="ZZ") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(dup_neg([br_rat(1, 2)], domain="QQ"), "[-1/2]")
}
