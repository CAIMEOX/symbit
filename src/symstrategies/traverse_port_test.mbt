///|\
fn zero_symbols(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Symbol(_) => @symcore.int(0)
    _ => expr
  }
}

///|
fn promote_basic2(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("Basic", args) if args.length() > 0 => {
      match args[0] {
        @symcore.Expr::Number(n) if n.is_integral() => expr
        _ => @symcore.function("Basic2", args)
      }
    }
    _ => expr
  }
}

///|
test "traverse sall" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let expr = basic([x, y, basic([x, z])])
  let rl = @strategies_traverse.sall(zero_symbols)
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.traverse_sall_zero_symbols(expr), "sall")
}

///|
test "traverse top_down" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let expr = basic([x, y, basic([x, z])])
  let rl = @strategies_traverse.top_down(zero_symbols)
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.traverse_top_down_zero_symbols(expr), "top_down")
}

///|
test "traverse bottom_up" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let expr = basic([x, y, basic([x, z])])
  let rl = @strategies_traverse.bottom_up(zero_symbols)
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.traverse_bottom_up_zero_symbols(expr), "bottom_up")
}

///|
test "traverse top_down_once" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = basic([x, y, basic([@symcore.int(3), @symcore.int(4)])])
  let rl = @strategies_traverse.top_down_once(promote_basic2)
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.traverse_top_down_once(expr), "top_down_once")
}

///|
test "traverse bottom_up_once" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = basic([
    @symcore.int(1),
    @symcore.int(2),
    basic([x, y]),
  ])
  let rl = @strategies_traverse.bottom_up_once(promote_basic2)
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.traverse_bottom_up_once(expr), "bottom_up_once")
}

///|
test "traverse expr_fns" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.add([x, @symcore.pow(y, @symcore.int(3))])
  let e = @strategies_traverse.bottom_up(
    v => v + @symcore.int(1),
    fns=@strategies_util.expr_fns,
  )(expr)
  let b = @strategies_traverse.bottom_up(
    v => @strategies_util.expr_new_raw(
      @strategies_util.ExprOp::Add,
      [v, @symcore.int(1)],
    ),
    fns=@strategies_util.basic_fns,
  )(expr)
  let rebuilt = @strategies_rl.rebuild(b)
  let oracle = try! @sympy_strategies.traverse_expr_fns(expr)
  assert_expr_str_eq(e, oracle, "expr_fns e")
  assert_expr_str_eq(rebuilt, oracle, "expr_fns rebuild")
}
