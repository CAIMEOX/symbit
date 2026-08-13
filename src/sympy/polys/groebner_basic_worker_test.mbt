///|
test "polys P5a6 groebner shares Dummy identity across expressions" {
  let dummy = @symcore.Expr::Dummy("d", 2001)
  assert_eq(
    groebner([
      dummy - @symcore.int(1),
      (dummy ^ @symcore.int(2)) - @symcore.int(1),
    ]),
    "_d - 1",
  )
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  assert_eq(groebner([b - a, c - b]), "a - c | b - c")
  assert_eq(groebner([b - a, c - b], order=""), "a - c | b - c")
}

///|
test "polys P5a6 ring generators treat punctuation as literal data" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    groebnertools_gcd(
      (x ^ @symcore.int(2)) - @symcore.int(1),
      x - @symcore.int(1),
      gens=[literal],
    ),
    "x y,z - 1",
  )
}

///|
test "polys P5a6 ring conversion preserves shared Expr identity" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(groebnertools_spoly(x, x, gens=[literal]), "0")
}

///|
test "polys P5a6 ring frontdoors keep raw strings and sorted basis output" {
  let x = @symcore.Expr::Symbol("x")
  let f = (x - @symcore.int(1)) * (x + @symcore.int(2))
  let g = (x - @symcore.int(1)) * (x + @symcore.int(3))
  assert_eq(groebnertools_gcd(f, g), "x - 1")
  assert_eq(groebnertools_lcm(f, g), "x**3 + 4*x**2 + x - 6")
  assert_eq(
    red_groebner(
      [(x ^ @symcore.int(2)) - @symcore.int(1), x - @symcore.int(1)],
      gens=["x"],
    ),
    "x - 1",
  )
  let y = @symcore.Expr::Symbol("y")
  assert_eq(
    groebnertools_spoly(
      (x ^ @symcore.int(2)) + y,
      x * y + @symcore.int(1),
      order="grlex",
    ),
    "y**2 - x",
  )
}

///|
test "polys P5a6 lcm and reduction keep punctuation generators literal" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  let f = (x ^ @symcore.int(2)) - @symcore.int(1)
  let g = x - @symcore.int(1)
  assert_eq(groebnertools_lcm(f, g, gens=[literal]), "x y,z**2 - 1")
  assert_eq(red_groebner([f, g], gens=[literal]), "x y,z - 1")
}

///|
test "polys P5a6 predicates return lowercase booleans and recover after errors" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  let basis = [x - @symcore.int(1)]
  assert_eq(is_groebner(basis, gens=[literal]), "true")
  assert_eq(is_minimal(basis, gens=[literal]), "true")
  assert_eq(is_reduced(basis, gens=[literal]), "true")
  let redundant = [(x ^ @symcore.int(2)) - @symcore.int(1), x - @symcore.int(1)]
  assert_eq(is_groebner(redundant, gens=[literal]), "true")
  assert_eq(is_minimal(redundant, gens=[literal]), "false")
  assert_eq(is_reduced(redundant, gens=[literal]), "false")
  let rejected = try {
    is_groebner(basis, gens=[literal], order="not-an-order") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(is_groebner(basis, gens=[literal]), "true")
}
