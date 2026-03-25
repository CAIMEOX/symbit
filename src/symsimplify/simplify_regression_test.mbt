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
fn simplify_exact_float_expr(
  num : Int,
  den : Int,
  prec? : Int = 90,
) -> @symcore.Expr {
  let rat = @symnum.BigRational::from_ints(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
  let value = @symcore.Float::from_exact(rat, prec~) catch {
    _ => @symcore.Float::from_int(0, prec~)
  }
  @symcore.float(value)
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

///|
test "symsimplify handles float numeric leaf identities and powers" {
  let zero_f = simplify_exact_float_expr(0, 1, prec=70)
  let one_f = simplify_exact_float_expr(1, 1, prec=70)
  let minus_half_f = simplify_exact_float_expr(-1, 2, prec=70)
  let four_f = simplify_exact_float_expr(4, 1, prec=70)
  let half = match
    (
      try? @symcore.rational_from_ints(1, 2) :
      Result[@symcore.Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => fail("half")
  }

  match simplify(@symcore.function("sin", [zero_f])) {
    @symcore.Expr::Float(f) => assert_eq(f.to_rational(), (0N, 1N))
    _ => fail("expected float zero")
  }
  match simplify(@symcore.function("sqrt", [one_f])) {
    @symcore.Expr::Float(f) => assert_eq(f.to_rational(), (1N, 1N))
    _ => fail("expected float one")
  }
  match simplify(@symcore.function("Abs", [minus_half_f])) {
    @symcore.Expr::Float(f) => assert_eq(f.to_rational(), (1N, 2N))
    _ => fail("expected float abs")
  }
  match simplify(@symcore.pow(four_f, half)) {
    @symcore.Expr::Float(f) => assert_eq(f.to_rational(), (2N, 1N))
    _ => fail("expected float pow")
  }
}
