///|
test "polys Poly worker keeps generator names literal" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  assert_eq(poly_expr(symbol, gens=[literal]), literal)
}

///|
test "polys dict_from_expr worker keeps generator names literal" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  assert_eq(dict_from_expr(symbol, gens=[literal]), "{(1,):1}||[\"x y,z\"]")
}

///|
test "polys expr_from_dict worker keeps generator names literal" {
  let literal = "x y,z"
  assert_eq(expr_from_dict("{(1,): 2}", [literal]), "2*x y,z")
}

///|
test "polys polyutils worker shares Dummy identity across expression lists" {
  let dummy = @symcore.Expr::Dummy("d", 1301)
  assert_eq(
    parallel_dict_from_expr([dummy, dummy]),
    "[{(1,):1},{(1,):1}]||[\"_d\"]",
  )
}

///|
test "polys polyutils worker sort_gens treats punctuation as one Symbol" {
  assert_eq(sort_gens(["x y,z"]), ["x y,z"])
}

///|
test "polys polyutils worker unify_gens treats punctuation as one Symbol" {
  assert_eq(unify_gens(["x y,z"], ["x y,z"]), ["x y,z"])
}

///|
test "polys polyutils worker analyze_gens treats punctuation as one Symbol" {
  assert_eq(analyze_gens(["x y,z"]), ["x y,z"])
}

///|
test "polys polyutils worker analyze_gens_nested preserves one literal Symbol" {
  assert_eq(analyze_gens_nested([["x y,z"]]), ["x y,z"])
}

///|
test "polys expr_equal parses comments as request data" {
  assert_true(expr_equal("x # request comment", "x"))
}

///|
test "polys polyutils worker recovers after an exception" {
  let rejected = try {
    mod_rational(1, 0, 5) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(mod_rational(3, 2, 5), "4")
}
