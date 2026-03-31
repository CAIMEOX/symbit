///|
test "symassume installs wild property resolver for source-driven matches" {
  let real_wild = @symcore.Expr::Wild("r", [], [@symcore.WildProperty::Real])
  let positive_wild = @symcore.Expr::Wild("p", [], [
    @symcore.WildProperty::Positive,
  ])
  let finite_wild = @symcore.Expr::Wild("f", [], [@symcore.WildProperty::Finite])
  let nonzero_wild = @symcore.Expr::Wild("n", [], [
    @symcore.WildProperty::Nonzero,
  ])
  let real_expr = @symcore.function("sin", [@symcore.int(1)])
  let positive_expr = @symcore.function("exp", [@symcore.int(1)])

  guard @symcore.wild_matches(real_wild, real_expr) is Some(_) else {
    fail("expected symassume-backed real wildcard match")
  }
  guard @symcore.wild_matches(positive_wild, positive_expr) is Some(_) else {
    fail("expected symassume-backed positive wildcard match")
  }
  guard @symcore.wild_matches(finite_wild, positive_expr) is Some(_) else {
    fail("expected symassume-backed finite wildcard match")
  }
  guard @symcore.wild_matches(nonzero_wild, positive_expr) is Some(_) else {
    fail("expected symassume-backed nonzero wildcard match")
  }
  guard !(@symcore.wild_matches(
      finite_wild,
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
    )
    is Some(_)) else {
    fail("expected infinity to fail finite wildcard match")
  }
  guard !(@symcore.wild_matches(nonzero_wild, @symcore.int(0)) is Some(_)) else {
    fail("expected zero to fail nonzero wildcard match")
  }
}
