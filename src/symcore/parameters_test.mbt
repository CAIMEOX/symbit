///|
pub(all) suberror ParameterTestError {
  Boom
}

///|
test "with_evaluate controls core constructor evaluation" {
  let x = Expr::Symbol("x")
  let half = rational_from_ints(3, 2)
  let raw_add_expr = with_evaluate(false, fn() { add([x, x]) })
  let raw_pow_expr = with_evaluate(false, fn() { pow(x, int(1)) })
  let raw_eq_expr = with_evaluate(false, fn() { function("Eq", [x, x]) })
  let raw_integer_expr = with_evaluate(false, fn() {
    function("Integer", [half])
  })
  inspect(to_repr(raw_add_expr), content="(+ sym:x sym:x)")
  inspect(to_repr(raw_pow_expr), content="(^ sym:x 1)")
  inspect(to_repr(raw_eq_expr), content="(call Eq sym:x sym:x)")
  inspect(to_repr(raw_integer_expr), content="1")
  inspect(to_repr(add([x, x])), content="(* 2 sym:x)")
  inspect(to_repr(function("Eq", [x, x])), content="sym:True")
}

///|
test "with_distribute and with_exp_is_pow control canonical constructors" {
  let x = Expr::Symbol("x")
  let distributed = mul([int(2), add([x, int(1)])])
  inspect(@symprint.to_string(distributed), content="2*x + 2")
  inspect(
    @symprint.to_string(
      with_distribute(false, fn() { mul([int(2), add([x, int(1)])]) }),
    ),
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

///|
test "parameter helpers restore state after raised errors" {
  inspect(current_evaluate(), content="true")
  inspect(current_distribute(), content="true")
  inspect(current_exp_is_pow(), content="false")

  let saw_evaluate_false : Ref[Bool] = { val: false }
  let evaluate_result = with_evaluate_raise(false, fn() -> Int raise {
    saw_evaluate_false.val = !current_evaluate()
    raise ParameterTestError::Boom
  }) catch {
    ParameterTestError::Boom => 1
    _ => 0
  }
  inspect(evaluate_result, content="1")
  inspect(saw_evaluate_false.val, content="true")
  inspect(current_evaluate(), content="true")

  let saw_distribute_false : Ref[Bool] = { val: false }
  let distribute_result = with_distribute_raise(false, fn() -> Int raise {
    saw_distribute_false.val = !current_distribute()
    raise ParameterTestError::Boom
  }) catch {
    ParameterTestError::Boom => 2
    _ => 0
  }
  inspect(distribute_result, content="2")
  inspect(saw_distribute_false.val, content="true")
  inspect(current_distribute(), content="true")

  let saw_exp_true : Ref[Bool] = { val: false }
  let exp_result = with_exp_is_pow_raise(true, fn() -> Int raise {
    saw_exp_true.val = current_exp_is_pow()
    raise ParameterTestError::Boom
  }) catch {
    ParameterTestError::Boom => 3
    _ => 0
  }
  inspect(exp_result, content="3")
  inspect(saw_exp_true.val, content="true")
  inspect(current_exp_is_pow(), content="false")
}
