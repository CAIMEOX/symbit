///|
test "polys P3a3 worker parses finite-field specs for sqf calls" {
  assert_eq(
    dup_sqf_list(
      [br_int(1), br_int(-1), br_int(1), br_int(0), br_int(1), br_int(-2)],
      domain="GF(5)",
    ),
    "(1mod5,[([1mod5,4mod5],2),([1mod5,2mod5],3)])",
  )
  assert_eq(
    dup_gf_factor([1, 0, 1], 2),
    "(SymmetricModularIntegerMod2(1),[([SymmetricModularIntegerMod2(1),SymmetricModularIntegerMod2(1)],2)])",
  )
}

///|
test "polys P3a3 worker preserves the sqf all option" {
  assert_eq(
    dup_sqf_list(
      [br_int(1), br_int(0), br_int(-2), br_int(0), br_int(1)],
      all=true,
    ),
    "(1,[([1],1),([1,0,-1],2)])",
  )
}

///|
test "polys P3a3 worker materializes nested factor containers" {
  let nested : DenseData = Poly([
    Poly([Coef(br_int(1)), Coef(br_int(0))]),
    Poly([Coef(br_int(-1))]),
  ])
  assert_eq(dmp_factor_list(nested, 1, domain="QQ"), "(1,[([[1,0],[-1]],1)])")
  assert_eq(
    dup_trial_division([br_int(1), br_int(0), br_int(-3), br_int(2)], [
      [br_int(1), br_int(-1)],
      [br_int(1), br_int(2)],
    ]),
    "[([1,2],1),([1,-1],2)]",
  )
  assert_eq(
    dup_factor_list_include(
      [br_rat(1, 2), br_int(0), br_rat(-1, 2)],
      domain="QQ",
    ),
    "[([1/2,-1/2],1),([1,1],1)]",
  )
  assert_eq(dup_sqf_list([], domain="QQ"), "(0,[])")
}

///|
test "polys P3a3 worker uses algebraic from_sympy and ext shape formatting" {
  assert_eq(
    dup_sqf_norm_exprs(["1", "0", "-2"]),
    "(1,[1,-2*sqrt(3),1],[1,0,-10,0,1])",
  )
  assert_eq(
    dup_ext_factor_shape_exprs(["1", "0", "-2"]),
    "(ANP([MPQ(1,1)],[MPQ(1,1),MPQ(0,1),MPQ(-2,1)],QQ),[(2,1),(2,1)])",
  )
}

///|
test "polys P3a3 worker preserves the irreducible option" {
  assert_true(
    dup_cyclotomic_p([br_int(1), br_int(0), br_int(1)], irreducible=true),
  )
  assert_false(
    dup_cyclotomic_p(
      [br_int(1), br_int(1), br_int(1), br_int(1)],
      irreducible=true,
    ),
  )
}

///|
test "polys P3a3 worker propagates optional None strictly then recovers" {
  let rejected = try {
    dmp_zz_wang_non_divisors([br_int(2), br_int(4)], br_int(1), br_int(1))
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(
    dup_zz_factor([br_int(1), br_int(0), br_int(-1)]),
    "(1,[([1,-1],1),([1,1],1)])",
  )
}
