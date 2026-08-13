///|
test "polys P5a8 roots treat punctuation generators as literal data" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    roots_linear(@symcore.int(2) * x + @symcore.int(1), gens=[literal]),
    "[-1/2]",
  )
}

///|
test "polys P5a8 specialized roots preserve compact list codecs" {
  let x = @symcore.Expr::Symbol("x")
  assert_eq(roots_linear(@symcore.int(2) * x + @symcore.int(1)), "[-1/2]")
  assert_eq(
    roots_quadratic(
      (x ^ @symcore.int(2)) - @symcore.int(3) * x + @symcore.int(2),
    ),
    "[1,2]",
  )
  assert_eq(roots_cubic((x - @symcore.int(1)) ^ @symcore.int(3)), "[1,1,1]")
  assert_eq(roots_quartic(x ^ @symcore.int(4)), "[0,0,0,0]")
  assert_eq(roots_quintic((x ^ @symcore.int(5)) - @symcore.int(32)), "[]")
  assert_eq(roots_binomial((x ^ @symcore.int(2)) - @symcore.int(4)), "[-2,2]")
  assert_eq(roots_cyclotomic(x + @symcore.int(1)), "[-1]")
}

///|
test "polys P5a8 preprocess roots preserves its exact pair codec" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    preprocess_roots(
      @symcore.int(2) * (x ^ @symcore.int(2)) +
      @symcore.int(4) * x +
      @symcore.int(2),
      gens=[literal],
    ),
    "1||xy,z**2+2*xy,z+1",
  )
}

///|
test "polys P5a8 root factors preserves literal gens and compact factors" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    root_factors((x - @symcore.int(1)) * (x + @symcore.int(2)), gens=[literal]),
    "[xy,z+2,xy,z-1]",
  )
}

///|
test "polys P5a8 rootof preserves radicals option presence" {
  let x = @symcore.Expr::Symbol("x")
  let expr = (x ^ @symcore.int(2)) - @symcore.int(2)
  assert_eq(rootof(expr, 0), "-sqrt(2)")
  assert_eq(rootof(expr, 0, radicals=false), "CRootOf(x**2 - 2, 0)")
}

///|
test "polys P5a8 specialized roots share repeated Dummy identity" {
  let dummy = @symcore.Expr::Dummy("d", 2301)
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.Expr::Add([dummy, Mul([@symcore.int(-1), dummy]), x])
  assert_eq(roots_linear(expr, gens=["x"]), "[0]")
}

///|
test "polys P5a8 roots worker recovers after a strict algorithm error" {
  let rejected = try {
    roots_linear(@symcore.int(1)) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let x = @symcore.Expr::Symbol("x")
  assert_eq(roots_linear(x, gens=["x"]), "[0]")
}
