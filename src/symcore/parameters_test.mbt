///|
test "with_evaluate controls core constructor evaluation" {
  let x = Expr::Symbol("x")
  let half = rational_from_ints(3, 2)
  let raw_add_expr = with_evaluate(false, fn() { add([x, x]) })
  let raw_pow_expr = with_evaluate(false, fn() { pow(x, int(1)) })
  let raw_eq_expr = with_evaluate(false, fn() { function("Eq", [x, x]) })
  let raw_integer_expr = with_evaluate(false, fn() { function("Integer", [half]) })
  inspect(@symprint.debug_repr(raw_add_expr), content="(+ sym:x sym:x)")
  inspect(@symprint.debug_repr(raw_pow_expr), content="(^ sym:x 1)")
  inspect(@symprint.debug_repr(raw_eq_expr), content="(call Eq sym:x sym:x)")
  inspect(
    @symprint.debug_repr(raw_integer_expr),
    content="1",
  )
  inspect(@symprint.debug_repr(add([x, x])), content="(* 2 sym:x)")
  inspect(@symprint.debug_repr(function("Eq", [x, x])), content="sym:True")
}
