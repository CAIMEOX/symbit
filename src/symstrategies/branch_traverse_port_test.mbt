///|\
fn br_inc_if_int(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    @symcore.Expr::Number(_) => [expr + @symcore.int(1)]
    _ => []
  }
}

///|
fn br_split5(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    _ if expr == @symcore.int(5) => [
      expr + @symcore.int(-1),
      expr + @symcore.int(1),
    ]
    _ => []
  }
}

///|
test "branch traverse top_down" {
  let expr = basic([@symcore.int(1), @symcore.int(2)])
  let brl = @strategies_branch.top_down(br_inc_if_int)
  let ours = brl(expr).map(expr_str)
  let oracle = try! @sympy_strategies.branch_traverse_top_down_inc(expr)
  assert_set_str_eq(ours, oracle, "top_down easy")

  let expr2 = basic([
    @symcore.int(1),
    basic([@symcore.int(2)]),
    basic([@symcore.int(3), basic([@symcore.int(4)]), @symcore.int(5)]),
  ])
  let ours2 = brl(expr2).map(expr_str)
  let oracle2 = try! @sympy_strategies.branch_traverse_top_down_inc(expr2)
  assert_set_str_eq(ours2, oracle2, "top_down big")
}

///|
test "branch traverse top_down split5" {
  let expr = basic([basic([@symcore.int(5), @symcore.int(6)]), @symcore.int(1)])
  let brl = @strategies_branch.top_down(br_split5)
  let ours = brl(expr).map(expr_str)
  let oracle = try! @sympy_strategies.branch_traverse_top_down_split5(expr)
  assert_set_str_eq(ours, oracle, "top_down split5")
}

///|
test "branch traverse sall" {
  let expr = basic([@symcore.int(1), @symcore.int(2)])
  let brl = @strategies_branch.sall(br_inc_if_int)
  let ours = brl(expr).map(expr_str)
  let oracle = try! @sympy_strategies.branch_traverse_sall_inc(expr)
  assert_set_str_eq(ours, oracle, "sall inc")

  let expr2 = basic([@symcore.int(1), @symcore.int(2), basic([@symcore.int(3), @symcore.int(4)])])
  let brl2 = @strategies_branch.sall(
    @strategies_branch.do_one([br_inc_if_int, @strategies_branch.identity]),
  )
  let ours2 = brl2(expr2).map(expr_str)
  let oracle2 = try! @sympy_strategies.branch_traverse_sall_do_one(expr2)
  assert_set_str_eq(ours2, oracle2, "sall do_one")
}
