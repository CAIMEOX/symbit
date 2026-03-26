///|
fn assert_dispatcher_parity(expr : @symcore.Expr) -> Unit raise {
  assert_eq(expr_srepr(simplify(expr)), simplify_srepr(expr))
}

///|
test "symsimplify dispatcher parity on expanded rational cancellation" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")

  let denom = @symcore.add([@symcore.int(2), @symcore.mul([@symcore.int(2), x])])
  let expr1 = @symcore.mul([
    @symcore.add([
      @symcore.int(4),
      @symcore.mul([@symcore.int(4), x]),
      @symcore.mul([@symcore.int(-2), denom]),
    ]),
    @symcore.pow(denom, @symcore.int(-1)),
  ])
  assert_dispatcher_parity(expr1)

  let expr2 = @symcore.mul([
    @symcore.add([
      @symcore.mul([@symcore.int(-4), x, @symcore.pow(y, @symcore.int(2))]),
      @symcore.mul([@symcore.int(-2), @symcore.pow(y, @symcore.int(3))]),
      @symcore.mul([@symcore.int(-2), @symcore.pow(x, @symcore.int(2)), y]),
    ]),
    @symcore.pow(@symcore.add([x, y]), @symcore.int(-2)),
  ])
  assert_dispatcher_parity(expr2)
}

///|
test "symsimplify dispatcher parity on nested gamma and rational sums" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")

  let expr1 = @symcore.add([
    @symcore.mul([@symcore.int(-1), x]),
    @symcore.mul([@symcore.int(-1), y]),
    @symcore.mul([
      @symcore.int(-1),
      @symcore.pow(@symcore.add([x, y]), @symcore.int(-1)),
      @symcore.pow(y, @symcore.int(2)),
    ]),
    @symcore.mul([
      @symcore.pow(@symcore.add([x, y]), @symcore.int(-1)),
      @symcore.pow(x, @symcore.int(2)),
    ]),
  ])
  assert_dispatcher_parity(expr1)

  let gamma_ratio = @symcore.mul([
    @symcore.function("gamma", [@symcore.add([x, @symcore.int(1)])]),
    @symcore.pow(@symcore.function("gamma", [x]), @symcore.int(-1)),
  ])
  assert_dispatcher_parity(gamma_ratio)

  let trig_gamma = @symcore.add([
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
    gamma_ratio,
  ])
  assert_dispatcher_parity(trig_gamma)

  let ratio = @symcore.mul([
    @symcore.add([x, @symcore.mul([x, y])]),
    @symcore.pow(x, @symcore.int(-1)),
  ])
  assert_dispatcher_parity(ratio)

  let f = @symcore.function("f", [x])
  let functional_ratio = @symcore.mul([
    @symcore.add([f, @symcore.mul([y, f])]),
    @symcore.pow(f, @symcore.int(-1)),
  ])
  assert_dispatcher_parity(functional_ratio)

  let log_ratio = @symcore.add([
    @symcore.function("log", [@symcore.mul([@symcore.int(2), x])]),
    @symcore.mul([@symcore.int(-1), @symcore.function("log", [@symcore.int(2)])]),
  ])
  assert_dispatcher_parity(log_ratio)
}
