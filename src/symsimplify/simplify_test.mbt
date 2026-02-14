///|
test "symsimplify basic algebra rules" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  inspect(
    @symprint.debug_repr(simplify(@symcore.add([x, x]))),
    content="(* 2 sym:x)",
  )
  inspect(
    @symprint.debug_repr(simplify(@symcore.add([x, @symcore.mul([@symcore.int(2), x])]))),
    content="(* 3 sym:x)",
  )
  inspect(
    @symprint.debug_repr(powsimp(@symcore.mul([x, x, y]))),
    content="(* (^ sym:x 2) sym:y)",
  )
}

///|
test "symsimplify function identities" {
  let x = @symcore.symbol("x")
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
test "symsimplify numeric power denest" {
  let x = @symcore.symbol("x")
  let expr = @symcore.pow(@symcore.pow(x, @symcore.int(2)), @symcore.int(3))
  inspect(@symprint.debug_repr(simplify(expr)), content="(^ sym:x 6)")
  let num = @symcore.pow(@symcore.int(2), @symcore.int(3))
  inspect(@symprint.debug_repr(simplify(num)), content="8")
}

///|
test "symsimplify fraction numer denom collect basics" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.mul([@symcore.int(2), @symcore.pow(x, @symcore.int(-1)), y])
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
  inspect(@symprint.debug_repr(collected), content="(+ (* 2 sym:x) (* 3 (^ sym:x 2)) sym:y)")
}

///|
test "symsimplify advanced rewrites basics" {
  let x = @symcore.symbol("x")
  let k = @symcore.symbol("k")
  let pd = powdenest(@symcore.pow(@symcore.pow(x, @symcore.int(2)), @symcore.int(3)))
  inspect(@symprint.debug_repr(pd), content="(^ sym:x 6)")
  let ee = exptrigsimp(
    @symcore.add([
      @symcore.function("exp", [@symcore.mul([@symcore.symbol("I"), x])]),
      @symcore.function("exp", [@symcore.mul([@symcore.int(-1), @symcore.symbol("I"), x])]),
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
  let x = @symcore.symbol("x")
  let k0 = kroneckersimp(@symcore.function("KroneckerDelta", [@symcore.int(2), @symcore.int(3)]))
  inspect(@symprint.debug_repr(k0), content="0")
  let k1 = kroneckersimp(@symcore.function("KroneckerDelta", [x, x]))
  inspect(@symprint.debug_repr(k1), content="1")

  let j0 = besselsimp(@symcore.function("besselj", [@symcore.int(0), @symcore.int(0)]))
  inspect(@symprint.debug_repr(j0), content="1")
  let j2 = besselsimp(@symcore.function("besselj", [@symcore.int(2), @symcore.int(0)]))
  inspect(@symprint.debug_repr(j2), content="0")

  let n = nsimplify(
    @symcore.add([
      try! @symcore.rational_from_ints(1, 3),
      try! @symcore.rational_from_ints(1, 6),
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

  let split = split_surds(@symcore.add([
    @symcore.function("sqrt", [@symcore.int(2)]),
    @symcore.function("sqrt", [@symcore.int(8)]),
  ]))
  inspect(@symprint.debug_repr(split.0), content="2")
}

///|
test "symsimplify traversal/cse_opts basics" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.add([y, @symcore.mul([@symcore.int(-1), x])])
  ignore(sub_post(sub_pre(expr)))

  let nested = @symcore.function("sin", [@symcore.add([x, x])])
  let used = use(nested, node => simplify(node), level=1)
  inspect(@symprint.debug_repr(used), content="(call sin (* 2 sym:x))")
}

///|
test "symsimplify fu rules smoke" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let pi = @symcore.symbol("pi")

  inspect(@symprint.debug_repr(tr1(@symcore.function("sec", [x]))), content="(^ (call cos sym:x) -1)")
  inspect(
    @symprint.debug_repr(tr2(@symcore.function("tan", [x]))),
    content="(* (^ (call cos sym:x) -1) (call sin sym:x))",
  )
  inspect(
    @symprint.debug_repr(tr2i(@symcore.mul([
      @symcore.function("sin", [x]),
      @symcore.pow(@symcore.function("cos", [x]), @symcore.int(-1)),
    ]))),
    content="(call tan sym:x)",
  )
  inspect(
    @symprint.debug_repr(tr3(@symcore.function("sin", [@symcore.mul([@symcore.int(-1), x])]))),
    content="(* -1 (call sin sym:x))",
  )
  inspect(
    @symprint.debug_repr(tr4(@symcore.function("sin", [@symcore.mul([try! @symcore.rational_from_ints(1, 6), pi])]))),
    content="1/2",
  )
  inspect(
    @symprint.debug_repr(tr8(@symcore.mul([@symcore.function("sin", [x]), @symcore.function("cos", [y])]))),
    content="(+ (* -1/2 (call sin (+ (* -1 sym:x) sym:y))) (* 1/2 (call sin (+ sym:x sym:y))))",
  )
  inspect(
    @symprint.debug_repr(tr10(@symcore.function("sin", [@symcore.add([x, y])]))),
    content="(+ (* (call cos sym:x) (call sin sym:y)) (* (call cos sym:y) (call sin sym:x)))",
  )
  assert_true(tr111(@symcore.pow(@symcore.function("tan", [x]), @symcore.int(-2))) != @symcore.pow(@symcore.function("tan", [x]), @symcore.int(-2)))
  assert_true(tr22(@symcore.pow(@symcore.function("cot", [x]), @symcore.int(2))) != @symcore.pow(@symcore.function("cot", [x]), @symcore.int(2)))
  assert_true(trpower(@symcore.pow(@symcore.function("sin", [x]), @symcore.int(4))) != @symcore.pow(@symcore.function("sin", [x]), @symcore.int(4)))
  assert_true(
    trmorrie(@symcore.mul([
      @symcore.function("cos", [x]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(2), x])]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(4), x])]),
    ])) != @symcore.mul([
      @symcore.function("cos", [x]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(2), x])]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(4), x])]),
    ]),
  )
  let ft = futrig(@symcore.add([
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
  ]))
  assert_true(ft != @symcore.int(0))
}
