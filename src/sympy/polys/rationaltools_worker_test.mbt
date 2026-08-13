///|
test "polys P5a3 worker keeps generator punctuation literal" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  let square = (symbol ^ @symcore.int(2)) - @symcore.int(1)
  assert_eq(real_roots(square, gens=[literal]), "[-1, 1]")
  assert_eq(
    apart(square ^ @symcore.int(-1), gen=literal),
    "-1/(2*(x y,z + 1)) + 1/(2*(x y,z - 1))",
  )
}

///|
test "polys P5a3 worker shares Dummy identity in expression graphs" {
  let dummy = @symcore.Expr::Dummy("d", 1701)
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  assert_eq(
    is_zero_dimensional([dummy - x, dummy - y, dummy - @symcore.int(1)]),
    "True",
  )
  assert_eq(
    apart_undetermined_coeffs(dummy, dummy * (x + @symcore.int(1)), "x"),
    "1/(x + 1)",
  )
}

///|
test "polys P5a3 worker preserves partfrac objects and shapes" {
  let x = @symcore.Expr::Symbol("x")
  let p = @symcore.int(1)
  let q = (x ^ @symcore.int(2)) + @symcore.int(1)
  assert_eq(
    apart_full_decomposition(p, q, "x", doit=false),
    "-RootSum(w**2 + 1, Lambda(w, w/(-w + x)))/2",
  )
  assert_eq(
    apart(q ^ @symcore.int(-1), gen="x", full=true),
    "-RootSum(w**2 + 1, Lambda(w, w/(-w + x)))/2",
  )
  assert_eq(
    apart_full_decomposition(p, q, "x"),
    "I/(2*(x + I)) - I/(2*(x - I))",
  )
  assert_eq(apart_list_full_decomposition_count(p, q, "x"), 1)
}

///|
test "polys P5a3 worker preserves tuple and named-group codecs" {
  let x = @symcore.Expr::Symbol("x")
  assert_eq(
    sqf_norm(
      (x ^ @symcore.int(2)) - @symcore.int(2),
      gens=["x"],
      extension="sqrt(3)",
    ),
    "([1], x**2 - 2*sqrt(3)*x + 1, x**4 - 10*x**2 + 1)",
  )
  assert_eq(
    galois_group((x ^ @symcore.int(3)) - @symcore.int(2), gens=["x"]),
    "(S3, false)",
  )
}

///|
test "polys P5a3 worker preserves roots conditions and kwargs" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  assert_eq(
    nroots((x ^ @symcore.int(2)) - @symcore.int(3)),
    "[-1.73205080756888, 1.73205080756888]",
  )
  let literal = "x y,z"
  let variable = @symcore.Expr::Symbol(literal)
  let k = @symcore.Expr::Symbol("k")
  let stable = (variable ^ @symcore.int(3)) +
    (variable ^ @symcore.int(2)) +
    @symcore.int(2) * k * variable +
    @symcore.int(1) -
    k
  assert_eq(hurwitz_conditions(stable, gens=[literal]), "[1, 3*k - 1, 1 - k]")
  assert_eq(
    schur_conditions(stable, gens=[literal]),
    "[-15*k**2 + 20*k - 5, -8*k**2 - 8*k + 8, 3*k**2 + 8*k - 3]",
  )
  let fractions = (x ^ @symcore.int(-1)) +
    (y ^ @symcore.int(-1)) +
    ((x * y) ^ @symcore.int(-1))
  assert_eq(together(fractions, fraction=false), "1/y + 1/x + 1/(x*y)")
  assert_eq(
    together(
      @symcore.function("exp", [(x ^ @symcore.int(-1)) + (y ^ @symcore.int(-1))]),
      deep=true,
    ),
    "exp((x + y)/(x*y))",
  )
}

///|
test "polys P5a3 worker keeps legacy nth-power gens error and recovers" {
  let x = @symcore.Expr::Symbol("x")
  let expression = (x ^ @symcore.int(4)) -
    (x ^ @symcore.int(2)) +
    @symcore.int(1)
  let rejected = try {
    // HEAD appends n after every generator: [expr, *gens, n]. Preserve that
    // observable legacy contract until a separately reviewed API correction.
    nth_power_roots_poly(expression, 2, gens=["x"]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(
    nth_power_roots_poly(expression, 2),
    "x**4 - 2*x**3 + 3*x**2 - 2*x + 1",
  )
}
