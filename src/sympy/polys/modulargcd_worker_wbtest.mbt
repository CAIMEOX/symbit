///|
test "polys modular-gcd worker keeps ring elements in one recipe" {
  let symbol = @symcore.Expr::Symbol("x")
  let recipe = ModularGcdRecipe::new("ZZ")
  let result = recipe.call(
    "modgcd_univariate",
    (symbol ^ @symcore.int(2)) - @symcore.int(1),
    symbol - @symcore.int(1),
    "x",
  )
  assert_eq(
    recipe.request_result(result, elements_as_expr=false),
    "(x-1,x+1,1)",
  )
}

///|
test "polys modular-gcd worker recovers after strict input failure" {
  let rejected = try {
    ignore(sympify_pythonrational(1, 0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(sympify_pythonrational(-6, -8), "3/4")
}

///|
test "polys modular-gcd worker rejects None inside result tuples" {
  let recipe = ModularGcdRecipe::new("ZZ")
  let malformed = recipe.polys.builder.tuple([
    Null,
    DecimalInt("1"),
    DecimalInt("1"),
  ])
  let rejected = try {
    ignore(recipe.request_result(malformed, elements_as_expr=false))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let x = @symcore.Expr::Symbol("x")
  assert_eq(
    modgcd_univariate(
      (x ^ @symcore.int(2)) - @symcore.int(1),
      x - @symcore.int(1),
    ),
    "(x-1,x+1,1)",
  )
}
