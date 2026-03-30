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

///|
test "with_distribute and with_exp_is_pow control canonical constructors" {
  let x = Expr::Symbol("x")
  let distributed = mul([int(2), add([x, int(1)])])
  inspect(@symprint.to_string(distributed), content="2*x + 2")
  inspect(
    @symprint.to_string(with_distribute(false, fn() { mul([int(2), add([x, int(1)])]) })),
    content="2*(x + 1)",
  )
  inspect(@symprint.to_string(function("exp", [x])), content="exp(x)")
  inspect(
    @symprint.to_string(with_exp_is_pow(true, fn() { function("exp", [x]) })),
    content="E**x",
  )
}

///|
test "legacy normalization ignores temporary constructor parameters" {
  let x = Expr::Symbol("x")
  let half = rational_from_ints(3, 2)
  inspect(
    @symprint.to_string(
      with_evaluate(false, fn() {
        normalize_legacy_expr(Expr::Function("Eq", [x, x]))
      }),
    ),
    content="True",
  )
  inspect(
    @symprint.to_string(
      with_evaluate(false, fn() {
        normalize_legacy_expr(Expr::Function("Integer", [half]))
      }),
    ),
    content="1",
  )
  inspect(
    @symprint.to_string(
      with_exp_is_pow(true, fn() {
        normalize_legacy_expr(Expr::Function("exp", [x]))
      }),
    ),
    content="exp(x)",
  )
}
