///|
test "polys polynomial-family worker binds literal symbols in one recipe" {
  let recipe = PolynomialFamiliesRecipe::new()
  let result = recipe.named_unary(
    "sympy.polys.orthopolys.chebyshevt_poly", 2, "q'quoted",
  )
  assert_eq(recipe.request_scalar(result), "2*q'quoted**2 - 1")
}

///|
test "polys polynomial-family worker renders Poly tuples as expressions" {
  let recipe = PolynomialFamiliesRecipe::new()
  let result = recipe.call_path("sympy.polys.specialpolys.fateman_poly_F_1", [
    DecimalInt("1"),
  ])
  let parts = recipe.request_sequence(result)
  assert_eq(parts.length(), 3)
  assert_eq(parts[2], "1")
}

///|
test "polys polynomial-family worker covers default interpolation and recovery" {
  assert_eq(
    interpolating_poly(2),
    "y0*(x - x1)/(x0 - x1) + y1*(x - x0)/(-x0 + x1)",
  )
  let rejected = try {
    ignore(cyclotomic_poly(0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(cyclotomic_poly(1), "x - 1")
}
