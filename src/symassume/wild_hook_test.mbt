///|
test "symassume installs wild property resolver for source-driven matches" {
  let real_wild = @symcore.Expr::Wild("r", [], [@symcore.WildProperty::Real])
  let positive_wild = @symcore.Expr::Wild(
    "p",
    [],
    [@symcore.WildProperty::Positive],
  )
  let real_expr = @symcore.function("sin", [@symcore.int(1)])
  let positive_expr = @symcore.function("exp", [@symcore.int(1)])

  guard @symcore.wild_matches(real_wild, real_expr) is Some(_) else {
    fail("expected symassume-backed real wildcard match")
  }
  guard @symcore.wild_matches(positive_wild, positive_expr) is Some(_) else {
    fail("expected symassume-backed positive wildcard match")
  }
}
