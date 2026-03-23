///|
fn rational_trig_fixture() -> @symcore.Expr {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  @symcore.mul([
    @symcore.add([x, @symcore.pow(x, @symcore.int(2))]),
    @symcore.pow(
      @symcore.add([
        @symcore.mul([
          x,
          @symcore.pow(@symcore.function("sin", [y]), @symcore.int(2)),
        ]),
        @symcore.mul([
          x,
          @symcore.pow(@symcore.function("cos", [y]), @symcore.int(2)),
        ]),
      ]),
      @symcore.int(-1),
    ),
  ])
}

///|
test "symsimplify trigsimp after factoring regression" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let factored = @symcore.mul([
    x,
    @symcore.add([
      @symcore.pow(@symcore.function("sin", [y]), @symcore.int(2)),
      @symcore.pow(@symcore.function("cos", [y]), @symcore.int(2)),
    ]),
  ])
  inspect(
    @symprint.debug_repr(trigsimp(factored, max_passes=1)),
    content="sym:x",
  )
}

///|
test "symsimplify ratsimp rational trig regression" {
  let rational_trig = rational_trig_fixture()
  inspect(
    @symprint.debug_repr(ratsimp(rational_trig, max_passes=1)),
    content="(* (^ (+ (^ (call cos sym:y) 2) (^ (call sin sym:y) 2)) -1) (+ sym:x 1))",
  )
}

///|
test "symsimplify dispatcher rational trig regression" {
  let rational_trig = rational_trig_fixture()
  inspect(@symprint.debug_repr(simplify(rational_trig)), content="(+ sym:x 1)")
}

///|
test "symsimplify exptrigsimp exp trig regression" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let exp_trig = @symcore.add([
    @symcore.function("exp", [@symcore.mul([i, x])]),
    @symcore.function("exp", [@symcore.mul([@symcore.int(-1), i, x])]),
  ])
  inspect(
    @symprint.debug_repr(exptrigsimp(exp_trig, max_passes=1)),
    content="(* 2 (call cos sym:x))",
  )
}

///|
test "symsimplify dispatcher exp trig regression" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let exp_trig = @symcore.add([
    @symcore.function("exp", [@symcore.mul([i, x])]),
    @symcore.function("exp", [@symcore.mul([@symcore.int(-1), i, x])]),
  ])
  inspect(
    @symprint.debug_repr(simplify(exp_trig)),
    content="(* 2 (call cos sym:x))",
  )
}

///|
test "symsimplify simplifies expanded rational cancellation regression" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let denom = @symcore.add([@symcore.int(2), @symcore.mul([@symcore.int(2), x])])
  let expr = @symcore.mul([
    @symcore.add([
      @symcore.int(4),
      @symcore.mul([@symcore.int(4), x]),
      @symcore.mul([@symcore.int(-2), denom]),
    ]),
    @symcore.pow(denom, @symcore.int(-1)),
  ])
  inspect(@symprint.debug_repr(simplify(expr)), content="0")

  let square_den = @symcore.pow(@symcore.add([x, y]), @symcore.int(2))
  let square_num = @symcore.add([
    @symcore.mul([@symcore.int(-4), x, @symcore.pow(y, @symcore.int(2))]),
    @symcore.mul([@symcore.int(-2), @symcore.pow(y, @symcore.int(3))]),
    @symcore.mul([@symcore.int(-2), @symcore.pow(x, @symcore.int(2)), y]),
  ])
  inspect(
    @symprint.debug_repr(
      simplify(
        @symcore.mul([square_num, @symcore.pow(square_den, @symcore.int(-1))]),
      ),
    ),
    content="(* -2 sym:y)",
  )
}

///|
test "symsimplify simplifies nested gamma and rational sums regression" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")

  let nested = @symcore.add([
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
  inspect(@symprint.debug_repr(simplify(nested)), content="(* -2 sym:y)")

  let gamma_ratio = @symcore.mul([
    @symcore.function("gamma", [@symcore.add([x, @symcore.int(1)])]),
    @symcore.pow(@symcore.function("gamma", [x]), @symcore.int(-1)),
  ])
  inspect(@symprint.debug_repr(simplify(gamma_ratio)), content="sym:x")

  let trig_gamma = @symcore.add([
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
    gamma_ratio,
  ])
  inspect(@symprint.debug_repr(simplify(trig_gamma)), content="(+ sym:x 1)")

  let ratio = @symcore.mul([
    @symcore.add([x, @symcore.mul([x, y])]),
    @symcore.pow(x, @symcore.int(-1)),
  ])
  inspect(@symprint.debug_repr(simplify(ratio)), content="(+ sym:y 1)")

  let f = @symcore.function("f", [x])
  let functional_ratio = @symcore.mul([
    @symcore.add([f, @symcore.mul([y, f])]),
    @symcore.pow(f, @symcore.int(-1)),
  ])
  inspect(
    @symprint.debug_repr(simplify(functional_ratio)),
    content="(+ sym:y 1)",
  )

  let log_ratio = @symcore.add([
    @symcore.function("log", [@symcore.mul([@symcore.int(2), x])]),
    @symcore.mul([@symcore.int(-1), @symcore.function("log", [@symcore.int(2)])]),
  ])
  inspect(@symprint.debug_repr(simplify(log_ratio)), content="(call log sym:x)")
}
