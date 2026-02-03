///|\
fn br_posdec_expr(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    _ if expr > @symcore.int(0) => [expr + @symcore.int(-1)]
    @symcore.Expr::Number(_) => [expr]
    _ => []
  }
}

///|
fn br_branch5_expr(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    _ if expr > @symcore.int(0) && expr < @symcore.int(5) => [expr + @symcore.int(-1)]
    _ if expr > @symcore.int(5) && expr < @symcore.int(10) => [expr + @symcore.int(1)]
    _ if expr == @symcore.int(5) => [expr + @symcore.int(1), expr + @symcore.int(-1)]
    @symcore.Expr::Number(_) => [expr]
    _ => []
  }
}

///|
test "branch tools canon" {
  let expr = basic([
    @symcore.int(2),
    basic([@symcore.int(5), @symcore.int(3)]),
    @symcore.int(8),
  ])

  let brl_posdec = @strategies_branch.canon([br_posdec_expr])
  let res_posdec = brl_posdec(expr).map(expr_str)
  let oracle_posdec = try! @sympy_strategies.branch_canon_posdec(expr)
  assert_set_str_eq(res_posdec, oracle_posdec, "canon posdec")

  let brl_branch5 = @strategies_branch.canon([br_branch5_expr])
  let res_branch5 = brl_branch5(expr).map(expr_str)
  let oracle_branch5 = try! @sympy_strategies.branch_canon_branch5(expr)
  assert_set_str_eq(res_branch5, oracle_branch5, "canon branch5")
}
