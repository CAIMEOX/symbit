///|
test "polys basic polytools keeps one punctuation generator literal" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  assert_eq(degree(symbol, gen=literal), "1")
}

///|
test "polys basic polytools shares Dummy identity across operands" {
  let dummy = @symcore.Expr::Dummy("d", 1501)
  assert_eq(pdiv(dummy, dummy), "1||0")
}

///|
test "polys count_roots preserves optional endpoint positions" {
  let x = @symcore.Expr::Symbol("x")
  let expression = (x + @symcore.int(4)) *
    (x + @symcore.int(1)) *
    (x - @symcore.int(2)) *
    (x - @symcore.int(3)) *
    (x - @symcore.int(5))
  assert_eq(count_roots(expression, inf_num=3, inf_den=2, has_inf=true), "3")
  assert_eq(count_roots(expression, sup_num=-1, sup_den=2, has_sup=true), "2")
  assert_eq(
    count_roots(expression, inf_num=-2, sup_num=4, has_inf=true, has_sup=true),
    "3",
  )
}

///|
test "polys intervals keeps a punctuation generator literal" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  let expression = (symbol ^ @symcore.int(2)) - @symcore.int(1)
  assert_eq(
    intervals(expression, gens=[literal]),
    "([((-1, -1), 1), ((1, 1), 1)], [])",
  )
}

///|
test "polys poly_from_expr front keeps a punctuation generator literal" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  assert_eq(poly_from_expr_front(symbol, gens=[literal]), literal)
}

///|
test "polys parallel_poly_from_expr preserves list shape and literal gens" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  assert_eq(
    parallel_poly_from_expr_front([symbol, symbol + @symcore.int(1)], gens=[
      literal,
    ]),
    "x y,z||x y,z + 1",
  )
}

///|
test "polys refine_root only emits eps when its numerator is present" {
  let x = @symcore.Expr::Symbol("x")
  let expression = (x ^ @symcore.int(2)) - @symcore.int(3)
  assert_eq(
    refine_root(expression, 1, 1, 2, 1, eps_num=0, eps_den=0),
    "(3/2, 2)",
  )
  assert_eq(
    refine_root(expression, 1, 1, 2, 1, eps_num=1, eps_den=100),
    "(19/11, 26/15)",
  )
}

///|
test "polys leading fronts keep literal gens and optional order" {
  let literal = "x y,z"
  let symbol = @symcore.Expr::Symbol(literal)
  assert_eq(polytools_lc(symbol, gens=[literal], order="lex"), "1")
  assert_eq(polytools_lm(symbol, gens=[literal], order="lex"), literal)
  assert_eq(polytools_lt(symbol, gens=[literal], order="lex"), literal)
}

///|
test "polys basic polytools preserves Euclid and scalar output codecs" {
  let x = @symcore.Expr::Symbol("x")
  let p = (x ^ @symcore.int(2)) - @symcore.int(1)
  let q = @symcore.int(2) * x - @symcore.int(1)
  assert_eq(degree_list(p, gens=["x"]), "(2,)")
  assert_eq(prem(p, q), "-3")
  assert_eq(pquo(p, q), "2*x + 1")
  assert_eq(half_gcdex(p, q), "-4/3||1")
  assert_eq(gcdex(p, q), "-4/3||2*x/3 + 1/3||1")
  assert_eq(invert(p, q), "-4/3")
  assert_eq(
    trunc(
      @symcore.int(2) * (x ^ @symcore.int(3)) +
      @symcore.int(3) * (x ^ @symcore.int(2)) +
      @symcore.int(5) * x +
      @symcore.int(7),
      3,
    ),
    "-x**3 - x + 1",
  )
}

///|
test "polys basic polytools preserves constructor and collection codecs" {
  let x = @symcore.Expr::Symbol("x")
  let square = (x ^ @symcore.int(2)) - @symcore.int(1)
  assert_eq(all_roots(square), "[-1, 1]")
  assert_eq(
    ground_roots(
      ((x - @symcore.int(1)) ^ @symcore.int(2)) * (x + @symcore.int(2)),
    ),
    "{-2: 1, 1: 2}",
  )
  assert_eq(poly_front(square), "x**2 - 1")
  assert_eq(
    sqf(((x - @symcore.int(1)) ^ @symcore.int(2)) * (x + @symcore.int(2))),
    "(x - 1)**2*(x + 2)",
  )
  assert_eq(
    gff_list(
      (x ^ @symcore.int(5)) +
      @symcore.int(2) * (x ^ @symcore.int(4)) -
      (x ^ @symcore.int(3)) -
      @symcore.int(2) * (x ^ @symcore.int(2)),
    ),
    "(x, 1)||(x + 2, 4)",
  )
}

///|
test "polys basic polytools worker recovers after an exception" {
  let rejected = try {
    invert(@symcore.int(1), @symcore.int(0)) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(degree(Symbol("x"), gen="x"), "1")
}
