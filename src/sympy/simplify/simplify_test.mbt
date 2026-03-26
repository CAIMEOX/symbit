///|
test "symsimplify basic algebra rules" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    @symprint.debug_repr(simplify(@symcore.add([x, x]))),
    content="(* 2 sym:x)",
  )
  inspect(
    @symprint.debug_repr(
      simplify(@symcore.add([x, @symcore.mul([@symcore.int(2), x])])),
    ),
    content="(* 3 sym:x)",
  )
  inspect(
    @symprint.debug_repr(powsimp(@symcore.mul([x, x, y]))),
    content="(* (^ sym:x 2) sym:y)",
  )
}

///|
test "symsimplify function identities" {
  let x = @symcore.Expr::Symbol("x")
  let trig = @symcore.add([
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
  ])
  inspect(@symprint.debug_repr(trigsimp(trig)), content="1")
  inspect(
    @symprint.debug_repr(simplify(@symcore.function("exp", [@symcore.int(0)]))),
    content="1",
  )
  inspect(
    @symprint.debug_repr(simplify(@symcore.function("log", [@symcore.int(1)]))),
    content="0",
  )
}

///|
test "symsimplify dispatcher handles composite heuristics" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)

  let numerator = @symcore.add([x, @symcore.pow(x, @symcore.int(2))])
  let denominator = @symcore.add([
    @symcore.mul([
      x,
      @symcore.pow(@symcore.function("sin", [y]), @symcore.int(2)),
    ]),
    @symcore.mul([
      x,
      @symcore.pow(@symcore.function("cos", [y]), @symcore.int(2)),
    ]),
  ])
  let rational_trig = @symcore.mul([
    numerator,
    @symcore.pow(denominator, @symcore.int(-1)),
  ])
  inspect(@symprint.debug_repr(simplify(rational_trig)), content="(+ sym:x 1)")

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
test "symsimplify dispatcher handles special heuristics" {
  let x = @symcore.Expr::Symbol("x")

  let logs = @symcore.add([
    @symcore.function("log", [x]),
    @symcore.function("log", [@symcore.int(2)]),
  ])
  inspect(
    @symprint.debug_repr(simplify(logs)),
    content="(call log (* 2 sym:x))",
  )

  let gamma_expr = @symcore.function("gamma", [@symcore.int(6)])
  inspect(@symprint.debug_repr(simplify(gamma_expr)), content="120")

  let kd = @symcore.function("KroneckerDelta", [
    @symcore.int(2),
    @symcore.int(3),
  ])
  inspect(@symprint.debug_repr(simplify(kd)), content="0")

  let bj = @symcore.function("besselj", [@symcore.int(0), @symcore.int(0)])
  inspect(@symprint.debug_repr(simplify(bj)), content="1")
}

///|
test "symsimplify numeric power denest" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.pow(@symcore.pow(x, @symcore.int(2)), @symcore.int(3))
  inspect(@symprint.debug_repr(simplify(expr)), content="(^ sym:x 6)")
  let num = @symcore.pow(@symcore.int(2), @symcore.int(3))
  inspect(@symprint.debug_repr(simplify(num)), content="8")
}

///|
test "symsimplify fraction numer denom collect basics" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.mul([
    @symcore.int(2),
    @symcore.pow(x, @symcore.int(-1)),
    y,
  ])
  let (n, d) = fraction(expr)
  inspect(@symprint.debug_repr(n), content="(* 2 sym:y)")
  inspect(@symprint.debug_repr(d), content="sym:x")
  inspect(@symprint.debug_repr(numer(expr)), content="(* 2 sym:y)")
  inspect(@symprint.debug_repr(denom(expr)), content="sym:x")
  let collected = collect(
    @symcore.add([
      @symcore.mul([@symcore.int(2), x]),
      @symcore.mul([@symcore.int(3), @symcore.pow(x, @symcore.int(2))]),
      y,
    ]),
    x,
  )
  inspect(
    @symprint.debug_repr(collected),
    content="(+ (* 2 sym:x) (* 3 (^ sym:x 2)) sym:y)",
  )
}

///|
test "symsimplify advanced rewrites basics" {
  let x = @symcore.Expr::Symbol("x")
  let k = @symcore.Expr::Symbol("k")
  let pd = powdenest(
    @symcore.pow(@symcore.pow(x, @symcore.int(2)), @symcore.int(3)),
  )
  inspect(@symprint.debug_repr(pd), content="(^ sym:x 6)")
  let ee = exptrigsimp(
    @symcore.add([
      @symcore.function("exp", [@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), x])]),
      @symcore.function("exp", [
        @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), x]),
      ]),
    ]),
  )
  inspect(@symprint.debug_repr(ee), content="(* 2 (call cos sym:x))")
  let gs = gammasimp(@symcore.function("gamma", [@symcore.int(6)]))
  inspect(@symprint.debug_repr(gs), content="(call factorial 5)")
  let hs = hypersimp(@symcore.function("factorial", [k]), k)
  inspect(@symprint.debug_repr(hs), content="(+ sym:k 1)")
  let f1 = fu(
    @symcore.add([
      @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
      @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
    ]),
  )
  assert_true(f1 != @symcore.int(0))
}

///|
test "symsimplify compat api basics" {
  let x = @symcore.Expr::Symbol("x")
  let k0 = kroneckersimp(
    @symcore.function("KroneckerDelta", [@symcore.int(2), @symcore.int(3)]),
  )
  inspect(@symprint.debug_repr(k0), content="0")
  let k1 = kroneckersimp(@symcore.function("KroneckerDelta", [x, x]))
  inspect(@symprint.debug_repr(k1), content="1")

  let j0 = besselsimp(
    @symcore.function("besselj", [@symcore.int(0), @symcore.int(0)]),
  )
  inspect(@symprint.debug_repr(j0), content="1")
  let j2 = besselsimp(
    @symcore.function("besselj", [@symcore.int(2), @symcore.int(0)]),
  )
  inspect(@symprint.debug_repr(j2), content="0")

  let n = nsimplify(
    @symcore.add([
      @symcore.rational_from_ints(1, 3),
      @symcore.rational_from_ints(1, 6),
    ]),
  )
  inspect(@symprint.debug_repr(n), content="1/2")

  let cs = collect_sqrt(
    @symcore.add([
      @symcore.mul([@symcore.int(2), @symcore.function("sqrt", [x])]),
      @symcore.mul([@symcore.int(3), @symcore.function("sqrt", [x])]),
    ]),
  )
  inspect(@symprint.debug_repr(cs), content="(* 5 (call sqrt sym:x))")

  let ca = collect_abs(
    @symcore.add([
      @symcore.mul([@symcore.int(2), @symcore.function("Abs", [x])]),
      @symcore.function("Abs", [x]),
    ]),
  )
  inspect(@symprint.debug_repr(ca), content="(* 3 (call Abs sym:x))")

  let frac_expr = @symcore.mul([
    @symcore.add([x, @symcore.int(1)]),
    @symcore.pow(@symcore.add([x, @symcore.int(2)]), @symcore.int(-1)),
  ])
  let fe = fraction_expand(frac_expr)
  assert_true(fe == frac_expr || simplify(fe) == simplify(frac_expr))

  let split = split_surds(
    @symcore.add([
      @symcore.function("sqrt", [@symcore.int(2)]),
      @symcore.function("sqrt", [@symcore.int(8)]),
    ]),
  )
  inspect(@symprint.debug_repr(split.0), content="2")
}

///|
test "symsimplify compat api advanced cases" {
  let a = @symcore.Expr::Symbol("a")
  let i = @symcore.Expr::Symbol("i")
  let j = @symcore.Expr::Symbol("j")
  let x = @symcore.Expr::Symbol("x")
  let z = @symcore.Expr::Symbol("z")
  let half = @symcore.rational_from_ints(1, 2)
  let minus_half = @symcore.rational_from_ints(-1, 2)
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)

  let kd_cancel = kroneckersimp(
    @symcore.add([
      @symcore.int(1),
      @symcore.mul([
        @symcore.function("KroneckerDelta", [@symcore.int(0), i]),
        @symcore.function("KroneckerDelta", [@symcore.int(1), i]),
      ]),
    ]),
  )
  assert_true(kd_cancel == @symcore.int(1))

  let kd_subst = kroneckersimp(
    @symcore.mul([
      @symcore.function("KroneckerDelta", [i, j]),
      @symcore.function("KroneckerDelta", [j, @symcore.int(1)]),
      @symcore.function("f", [i]),
    ]),
  )
  assert_true(kd_subst == @symcore.function("f", [@symcore.int(1)]))

  let bj_half = besselsimp(@symcore.function("besselj", [half, z]))
  assert_true(
    bj_half ==
    @symcore.mul([
      @symcore.function("sqrt", [@symcore.int(2)]),
      @symcore.function("sin", [z]),
      @symcore.pow(
        @symcore.mul([
          @symcore.function("sqrt", [pi]),
          @symcore.function("sqrt", [z]),
        ]),
        @symcore.int(-1),
      ),
    ]),
  )

  let bi_half = besselsimp(@symcore.function("besseli", [minus_half, z]))
  assert_true(
    bi_half ==
    @symcore.mul([
      @symcore.function("sqrt", [@symcore.int(2)]),
      @symcore.function("cosh", [z]),
      @symcore.pow(
        @symcore.mul([
          @symcore.function("sqrt", [pi]),
          @symcore.function("sqrt", [z]),
        ]),
        @symcore.int(-1),
      ),
    ]),
  )

  let recurrence = besselsimp(
    @symcore.add([
      @symcore.function("besselj", [@symcore.add([a, @symcore.int(-1)]), x]),
      @symcore.function("besselj", [@symcore.add([a, @symcore.int(1)]), x]),
      @symcore.mul([
        @symcore.int(-2),
        a,
        @symcore.function("besselj", [a, x]),
        @symcore.pow(x, @symcore.int(-1)),
      ]),
    ]),
  )
  assert_true(recurrence == @symcore.int(0))

  let exact_ns = nsimplify(
    @symcore.add([
      @symcore.pow(@symcore.int(27), @symcore.rational_from_ints(1, 3)),
      @symcore.pow(@symcore.int(16), @symcore.rational_from_ints(-1, 2)),
    ]),
  )
  assert_true(exact_ns == @symcore.rational_from_ints(13, 4))

  let trig_ns = nsimplify(
    @symcore.add([
      @symcore.function("sin", [
        @symcore.mul([pi, @symcore.rational_from_ints(1, 6)]),
      ]),
      @symcore.function("cos", [
        @symcore.mul([pi, @symcore.rational_from_ints(1, 3)]),
      ]),
      @symcore.function("sqrt", [@symcore.int(4)]),
    ]),
  )
  assert_true(trig_ns == @symcore.int(3))

  let golden = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::GoldenRatio)
  let golden_ns = nsimplify(
    @symcore.add([
      @symcore.function("sqrt", [@symcore.int(5)]),
      @symcore.int(-1),
    ]),
    constants=[golden],
  )
  assert_true(
    golden_ns ==
    @symcore.add([@symcore.mul([@symcore.int(2), golden]), @symcore.int(-2)]),
  )
}

///|
test "symsimplify traversal/cse_opts basics" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.add([y, @symcore.mul([@symcore.int(-1), x])])
  ignore(sub_post(sub_pre(expr)))

  let nested = @symcore.function("sin", [@symcore.add([x, x])])
  let used = apply_at_level(nested, node => simplify(node), level=1)
  inspect(@symprint.debug_repr(used), content="(call sin (* 2 sym:x))")
}

///|
test "symsimplify fu rules smoke" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)

  inspect(
    @symprint.debug_repr(tr1(@symcore.function("sec", [x]))),
    content="(^ (call cos sym:x) -1)",
  )
  inspect(
    @symprint.debug_repr(tr2(@symcore.function("tan", [x]))),
    content="(* (^ (call cos sym:x) -1) (call sin sym:x))",
  )
  inspect(
    @symprint.debug_repr(
      tr2i(
        @symcore.mul([
          @symcore.function("sin", [x]),
          @symcore.pow(@symcore.function("cos", [x]), @symcore.int(-1)),
        ]),
      ),
    ),
    content="(call tan sym:x)",
  )
  inspect(
    @symprint.debug_repr(
      tr3(@symcore.function("sin", [@symcore.mul([@symcore.int(-1), x])])),
    ),
    content="(* -1 (call sin sym:x))",
  )
  inspect(
    @symprint.debug_repr(
      tr4(
        @symcore.function("sin", [
          @symcore.mul([@symcore.rational_from_ints(1, 6), pi]),
        ]),
      ),
    ),
    content="1/2",
  )
  inspect(
    @symprint.debug_repr(
      tr8(
        @symcore.mul([
          @symcore.function("sin", [x]),
          @symcore.function("cos", [y]),
        ]),
      ),
    ),
    content="(+ (* -1/2 (call sin (+ (* -1 sym:x) sym:y))) (* 1/2 (call sin (+ sym:x sym:y))))",
  )
  inspect(
    @symprint.debug_repr(tr10(@symcore.function("sin", [@symcore.add([x, y])]))),
    content="(+ (* (call cos sym:x) (call sin sym:y)) (* (call cos sym:y) (call sin sym:x)))",
  )
  assert_true(
    tr111(@symcore.pow(@symcore.function("tan", [x]), @symcore.int(-2))) !=
    @symcore.pow(@symcore.function("tan", [x]), @symcore.int(-2)),
  )
  assert_true(
    tr22(@symcore.pow(@symcore.function("cot", [x]), @symcore.int(2))) !=
    @symcore.pow(@symcore.function("cot", [x]), @symcore.int(2)),
  )
  assert_true(
    trpower(@symcore.pow(@symcore.function("sin", [x]), @symcore.int(4))) !=
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(4)),
  )
  assert_true(
    trmorrie(
      @symcore.mul([
        @symcore.function("cos", [x]),
        @symcore.function("cos", [@symcore.mul([@symcore.int(2), x])]),
        @symcore.function("cos", [@symcore.mul([@symcore.int(4), x])]),
      ]),
    ) !=
    @symcore.mul([
      @symcore.function("cos", [x]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(2), x])]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(4), x])]),
    ]),
  )
  let ft = futrig(
    @symcore.add([
      @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
      @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
    ]),
  )
  assert_true(ft != @symcore.int(0))
}
