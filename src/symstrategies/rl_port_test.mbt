///|\
fn basic(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function("Basic", args)
}

///|
fn raw_add(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @strategies_util.expr_new_raw(@strategies_util.ExprOp::Add, args)
}

///|
fn raw_mul(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @strategies_util.expr_new_raw(@strategies_util.ExprOp::Mul, args)
}

///|
fn coeff_mul(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr) {
  match expr {
    @symcore.Expr::Mul(args) if args.length() > 0 => {
      match args[0] {
        @symcore.Expr::Number(_) => {
          if args.length() == 2 {
            (args[0], args[1])
          } else {
            let rest_args : Array[@symcore.Expr] = Array::new()
            for i in 1..<args.length() {
              rest_args.push(args[i])
            }
            (args[0], raw_mul(rest_args))
          }
        }
        _ => (@symcore.int(1), expr)
      }
    }
    @symcore.Expr::Number(_) => (expr, @symcore.int(1))
    _ => (@symcore.int(1), expr)
  }
}

///|
fn key_coeff(expr : @symcore.Expr) -> @symcore.Expr {
  coeff_mul(expr).1
}

///|
fn count_coeff(expr : @symcore.Expr) -> @symcore.Expr {
  coeff_mul(expr).0
}

///|
fn combine_coeff(cnt : @symcore.Expr, arg : @symcore.Expr) -> @symcore.Expr {
  @symcore.mul([cnt, arg])
}

///|
test "rl rm_id" {
  let rmzeros = @strategies_rl.rm_id(x => x == @symcore.int(0))
  let expr1 = basic([@symcore.int(0), @symcore.int(1)])
  let expr2 = basic([@symcore.int(0), @symcore.int(0)])
  let expr3 = basic([@symcore.int(2), @symcore.int(1)])
  assert_expr_str_eq(rmzeros(expr1), try! @sympy_strategies.rl_rm_id(expr1), "rm_id 01")
  assert_expr_str_eq(rmzeros(expr2), try! @sympy_strategies.rl_rm_id(expr2), "rm_id 00")
  assert_expr_str_eq(rmzeros(expr3), try! @sympy_strategies.rl_rm_id(expr3), "rm_id 21")
}

///|
test "rl glom" {
  let x = @symcore.symbol("x")
  let expr = raw_add([
    x,
    raw_mul([@symcore.int(-1), x]),
    raw_mul([@symcore.int(3), x]),
    @symcore.int(2),
    @symcore.int(3),
  ])
  let rl = @strategies_rl.glom(key_coeff, count_coeff, combine_coeff)
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.rl_glom(expr), "glom")
}

///|
test "rl flatten" {
  let expr = basic([
    @symcore.int(1),
    @symcore.int(2),
    basic([@symcore.int(3), @symcore.int(4)]),
  ])
  let result = @strategies_rl.flatten(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.rl_flatten(expr), "flatten")
}

///|
test "rl unpack" {
  let expr1 = basic([@symcore.int(2)])
  let expr2 = basic([@symcore.int(2), @symcore.int(3)])
  assert_expr_str_eq(@strategies_rl.unpack(expr1), try! @sympy_strategies.rl_unpack(expr1), "unpack1")
  assert_expr_str_eq(@strategies_rl.unpack(expr2), try! @sympy_strategies.rl_unpack(expr2), "unpack2")
}

///|
test "rl sort" {
  let expr = basic([@symcore.int(3), @symcore.int(1), @symcore.int(2)])
  let rl = @strategies_rl.sort(expr => @symprint.to_string(expr))
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.rl_sort(expr), "sort")
}

///|
test "rl distribute custom" {
  let expr = @symcore.function("T1", [
    @symcore.int(1),
    @symcore.int(2),
    @symcore.function("T2", [@symcore.int(3), @symcore.int(4)]),
    @symcore.int(5),
  ])
  let rl = @strategies_rl.distribute(
    @strategies_util.ExprOp::Function("T1"),
    @strategies_util.ExprOp::Function("T2"),
  )
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.rl_distribute_custom(), "distribute custom")
}

///|
test "rl distribute add/mul" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = raw_mul([@symcore.int(2), raw_add([x, y])])
  let rl = @strategies_rl.distribute(
    @strategies_util.ExprOp::Mul,
    @strategies_util.ExprOp::Add,
  )
  let result = rl(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.rl_distribute_add_mul(expr), "distribute add/mul")
}

///|
test "rl subs" {
  let rl = @strategies_rl.subs(@symcore.int(1), @symcore.int(2))
  let expr1 = @symcore.int(1)
  let expr2 = @symcore.int(3)
  assert_expr_str_eq(rl(expr1), try! @sympy_strategies.rl_subs(expr1, @symcore.int(1), @symcore.int(2)), "subs1")
  assert_expr_str_eq(rl(expr2), try! @sympy_strategies.rl_subs(expr2, @symcore.int(1), @symcore.int(2)), "subs2")
}

///|
test "rl rebuild" {
  let expr = @strategies_util.expr_new_raw(
    @strategies_util.ExprOp::Add,
    [@symcore.int(1), @symcore.int(2)],
  )
  let result = @strategies_rl.rebuild(expr)
  assert_expr_str_eq(result, try! @sympy_strategies.rl_rebuild(expr), "rebuild")
}
