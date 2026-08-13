///|
test "polys P3a4 worker materializes integer dictionaries declaratively" {
  assert_eq(
    galois_recipe_string_call("gf_from_dict", [
      CallIntDict({ 2: 1, 0: 4 }),
      CallInt(5),
      DomainObject,
    ]),
    "[1,0,4]",
  )
}

///|
test "polys P3a4 worker materializes integer matrices declaratively" {
  assert_eq(
    galois_recipe_string_call("gf_Qbasis", [
      CallIntMatrix([[1, 0], [0, 1]]),
      CallInt(5),
      DomainObject,
    ]),
    "[[1,0],[0,1]]",
  )
}

///|
test "polys P3a4 worker materializes factor powers with leading coefficient" {
  assert_eq(
    galois_recipe_string_call("gf_expand", [
      FactorPowersWithLeadingCoefficient([([1, 1], 2)], 3),
      CallInt(5),
      DomainObject,
    ]),
    "[3,1,3]",
  )
}

///|
test "polys P3a4 worker preserves raw dictionary string rendering" {
  assert_eq(
    galois_recipe_string_call(
      "gf_to_dict",
      [CallIntList([1, 0, 4]), CallInt(5), CallBool(true)],
      raw=true,
    ),
    "{0: -1, 2: 1}",
  )
}

///|
test "polys P3a4 worker decodes integer results strictly" {
  assert_eq(
    galois_recipe_int_call("gf_crt", [
      CallIntList([1, 2]),
      CallIntList([3, 5]),
      DomainObject,
    ]),
    7,
  )
}

///|
test "polys P3a4 worker decodes boolean results strictly" {
  assert_true(
    galois_recipe_bool_call("gf_sqf_p", [
      CallIntList([1, 0, 1]),
      CallInt(5),
      DomainObject,
    ]),
  )
}

///|
test "polys P3a4 worker recovers after a strict algorithm failure" {
  let rejected = try {
    galois_recipe_string_call("gf_exquo", [
      CallIntList([1]),
      CallIntList([]),
      CallInt(5),
      DomainObject,
    ])
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(
    galois_recipe_string_call("gf_strip", [CallIntList([0, 0, 3])]),
    "[3]",
  )
}
