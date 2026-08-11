///|
///\
test "tools subs" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let d = @symcore.Expr::Symbol("d")
  let e = @symcore.Expr::Symbol("e")
  let f = @symcore.Expr::Symbol("f")
  let mapping : Map[@symcore.Expr, @symcore.Expr] = Map([])
  mapping[a] = d
  mapping[d] = a
  mapping[basic([e])] = basic([f])
  let expr = basic([a, basic([b, c]), basic([d, basic([e])])])
  let rl = @strategies_tools.subs(mapping)
  let result = rl(expr)
  assert_expr_str_eq(result, tools_subs(expr, mapping), "tools subs")
}

///|
test "tools subs empty" {
  let expr = basic([@symcore.int(1), @symcore.int(2)])
  let rl = @strategies_tools.subs(Map([]))
  let result = rl(expr)
  assert_expr_str_eq(result, tools_subs_empty(expr), "tools subs empty")
}

///|
test "tools typed" {
  let rmzeros = @strategies_rl.rm_id(x => x == @symcore.int(0))
  let rmones = @strategies_rl.rm_id(x => x == @symcore.int(1))
  let ruletypes : Map[@strategies_util.ExprOp, (@symcore.Expr) -> @symcore.Expr] = Map([],
  )
  ruletypes[Function("A")] = rmzeros
  ruletypes[Function("B")] = rmones
  let remove_something = @strategies_tools.typed(ruletypes)
  let exprA = @symcore.function("A", [@symcore.int(0), @symcore.int(1)])
  let exprB = @symcore.function("B", [@symcore.int(0), @symcore.int(1)])
  let resA = remove_something(exprA)
  let resB = remove_something(exprB)
  assert_expr_str_eq(resA, tools_typed(exprA), "typed A")
  assert_expr_str_eq(resB, tools_typed(exprB), "typed B")
}
