///|
test "polys P3a2 worker keeps dup_from_sympy raw before finite-field conversion" {
  assert_eq(
    dup_from_sympy([br_int(7), br_int(-1)], domain="GF(5)"),
    "[2mod5,4mod5]",
  )
}

///|
test "polys P3a2 worker keeps nested data and optional order kwargs" {
  let nested : DenseData = Poly([
    Poly([Coef(br_int(1)), Coef(br_int(0))]),
    Poly([Coef(br_int(2))]),
  ])
  assert_eq(
    dmp_list_terms(nested, 1, order="grlex", domain="GF(5)"),
    "[((1,1),1mod5),((0,0),2mod5)]",
  )
}

///|
test "polys P3a2 worker materializes algebraic coefficients with from_sympy" {
  assert_eq(
    dmp_alg_inject_exprs(["sqrt(2)", "0", "1"], 0),
    "([[1,0,0],[1]],1,QQ)",
  )
  assert_eq(
    dmp_alg_inject_exprs(["sqrt(2)+1", "sqrt(2)"], 0),
    "([[1,1],[1,0]],1,QQ)",
  )
  assert_eq(dmp_lift_exprs(["1", "sqrt(2)", "2"], 0), "[1,0,2,0,4]")
}

///|
test "polys P3a2 worker propagates euclid errors then recovers" {
  let rejected = try {
    dup_invert([br_int(0)], [br_int(1), br_int(0)], domain="GF(5)") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(
    dup_invert([br_int(1)], [br_int(1), br_int(1)], domain="GF(5)"),
    "[1mod5]",
  )
}
