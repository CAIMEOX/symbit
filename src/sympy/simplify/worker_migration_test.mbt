///|
test "simplify oracle treats symbol names as request data" {
  let symbol = @symcore.Expr::Symbol("x y,z")
  assert_eq(expr_srepr(symbol), "Symbol('x y,z')")
}

///|
test "simplify oracle preserves shared Dummy identity" {
  let dummy = @symcore.Expr::Dummy("d", 17)
  assert_true(radsimp_equivalent(dummy, dummy))
}

///|
test "simplify oracle distinguishes None and recovers" {
  let k = @symcore.Expr::Symbol("k")
  let sine = @symcore.function("sin", [k])
  let none_rejected = try {
    hypersimp_srepr(sine, k) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(none_rejected)
  assert_eq(expr_srepr(@symcore.int(2)), "Integer(2)")
}

///|
test "simplify oracle reports missing rules and recovers" {
  let x = @symcore.Expr::Symbol("x")
  let missing_rejected = try {
    tr_rule_equivalent("definitely_missing_rule", x, x) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(missing_rejected)
  assert_eq(
    simplify_srepr(@symcore.add([x, x])),
    "Mul(Integer(2), Symbol('x'))",
  )
}
