///|
test "polys numberfields worker treats former exec inputs as request data" {
  let commented_definition = "x**2 - 2 # request payload\n"
  assert_eq(
    find_min_poly_power_basis(commented_definition, [0, 1]),
    find_min_poly_power_basis("x**2 - 2", [0, 1]),
  )
  assert_eq(
    make_mod_elt_power_basis(commented_definition, [1, 2], denom=3),
    make_mod_elt_power_basis("x**2 - 2", [1, 2], denom=3),
  )
  assert_eq(
    make_mod_elt_submodule(
      commented_definition,
      [[1, 0], [0, 1]],
      [1, 2],
      denom=3,
    ),
    make_mod_elt_submodule("x**2 - 2", [[1, 0], [0, 1]], [1, 2], denom=3),
  )
  assert_eq(to_rational("3.14159\n", "10\n"), to_rational("3.14159", "10"))
}

///|
test "polys numberfields worker preserves intentional optional None" {
  assert_eq(
    numberfield_to_number_field_coeffs("sqrt(5)", "sqrt(2) + sqrt(3)"),
    "None",
  )
  assert_eq(numberfield_field_isomorphism_coeffs("sqrt(2)", "sqrt(3)"), "None")
  assert_false(numberfield_field_isomorphic("sqrt(2)", "sqrt(3)"))
}

///|
test "polys numberfields worker consumes coefficient generator in one request" {
  assert_eq(
    numberfield_coeff_search(2, 1, 8),
    "[[1,1],[1,0],[1,-1],[0,1],[2,2],[2,1],[2,0],[2,-1]]",
  )
}

///|
test "polys numberfields worker constructs DomainMatrix values in one domain" {
  assert_eq(
    numberfield_supplement_a_subspace([[1, 2], [7, 3], [0, 4]], "QQ"),
    "Matrix([[1, 2, 1], [7, 3, 0], [0, 4, 0]])",
  )
  assert_true(numberfield_is_sq_maxrank_HNF([[2, 1], [0, 3]]))
}

///|
test "polys numberfields worker preserves round-two and prime summaries" {
  let x = @symcore.Expr::Symbol("x")
  assert_false(
    has_square_disc((x ^ @symcore.int(2)) - @symcore.int(2), gens=["x"]),
  )
  assert_true(
    has_square_disc((x ^ @symcore.int(2)) - @symcore.int(4), gens=["x"]),
  )
  let sqrt2 = @symcore.int(2) ^ @symcore.rational_from_ints(1, 2)
  assert_eq(isolate(sqrt2), "(1, 2)")
  assert_eq(isolate(sqrt2, eps="1/10"), "(7/5, 10/7)")
  assert_eq(
    round_two((x ^ @symcore.int(2)) - @symcore.int(5), gens=["x"]),
    "(Submodule[[2, 0], [1, 1]]/2, 5)",
  )
  assert_eq(
    prime_decomp(2, (x ^ @symcore.int(2)) - @symcore.int(2), gens=["x"]),
    "[[ (2, x) e=2, f=1 ]]",
  )
}

///|
test "polys numberfields worker reports strict errors then recovers" {
  let rejected = try {
    ignore(round_two(@symcore.int(1), gens=[]))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(numberfield_minpoly("sqrt(2)"), "x**2 - 2")
}
