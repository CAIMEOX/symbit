///|
test "polys P5a7 matrix FGLM keeps source and target orders with literal gens" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    matrix_fglm(
      [(x ^ @symcore.int(2)) - @symcore.int(1)],
      gens=[literal],
      source_order="grlex",
      target_order="lex",
    ),
    "x y,z**2 - 1",
  )
}

///|
test "polys P5a7 F5 signatures preserve tuple formatting and order" {
  let literal = "x y,z"
  assert_eq(
    groebnertools_sig_cmp([0], 3, [1], 3, gens=[literal], order="lex"),
    "-1",
  )
  assert_eq(groebnertools_sig_mult([1], 3, [2]), "((3,), 3)")
}

///|
test "polys P5a7 LBP operations keep literal gens and QQ terms" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    groebnertools_lbp_cmp(
      [0],
      1,
      x,
      1,
      [0],
      1,
      x,
      2,
      gens=[literal],
      order="lex",
    ),
    "1",
  )
  assert_eq(
    groebnertools_lbp_sub(
      [0],
      1,
      x,
      1,
      [0],
      1,
      x,
      2,
      gens=[literal],
      order="lex",
    ),
    "((0,), 1)|0|1",
  )
  assert_eq(
    groebnertools_lbp_mul_term(
      [0],
      1,
      x,
      1,
      [1],
      2,
      gens=[literal],
      order="lex",
    ),
    "((1,), 1)|2*x y,z**2|1",
  )
}

///|
test "polys P5a7 critical pair and F5 reduction stay in one ring" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    groebnertools_critical_s_poly(
      [0],
      1,
      x,
      1,
      [0],
      1,
      x,
      2,
      gens=[literal],
      order="lex",
    ),
    "((0,), 1)|0|1",
  )
  assert_eq(
    groebnertools_is_rewritable_or_comparable_one(
      [1],
      1,
      1,
      [0],
      1,
      x,
      2,
      gens=[literal],
      order="lex",
    ),
    "true",
  )
  assert_eq(
    groebnertools_f5_reduce_one(
      [0],
      1,
      x,
      1,
      [0],
      1,
      x,
      2,
      gens=[literal],
      order="lex",
    ),
    "((0,), 1)|x y,z|1",
  )
}

///|
test "polys P5a7 rejects invalid orders and worker recovers" {
  let x = @symcore.Expr::Symbol("x")
  let rejected = try {
    groebnertools_lbp_cmp(
      [0],
      1,
      x,
      1,
      [0],
      1,
      x,
      2,
      gens=["x"],
      order="not-an-order",
    )
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(groebnertools_sig_mult([1], 3, [2]), "((3,), 3)")
}
