///|
fn assert_srepr_parity(
  _label : String,
  ours : @symcore.Expr,
  oracle : String,
) -> Unit raise {
  let ours_srepr = expr_srepr(ours)
  assert_eq(ours_srepr, oracle)
}

///|
test "symsimplify simplify parity basic" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let exprs = [
    @symcore.add([x, x]),
    @symcore.add([x, @symcore.mul([@symcore.int(2), x])]),
    @symcore.mul([x, x, y]),
    @symcore.pow(@symcore.pow(x, @symcore.int(2)), @symcore.int(3)),
    @symcore.add([
      @symcore.function("exp", [@symcore.int(0)]),
      @symcore.function("log", [@symcore.int(1)]),
    ]),
  ]
  for expr in exprs {
    let ours = simplify(expr)
    let oracle = simplify_srepr(expr)
    assert_srepr_parity("simplify", ours, oracle)
  }
}

///|
test "symsimplify simplify parity composite heuristics" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)

  let rational_trig = @symcore.mul([
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
  assert_srepr_parity(
    "simplify",
    simplify(rational_trig),
    simplify_srepr(rational_trig),
  )

  let exp_trig = @symcore.add([
    @symcore.function("exp", [@symcore.mul([i, x])]),
    @symcore.function("exp", [@symcore.mul([@symcore.int(-1), i, x])]),
  ])
  assert_srepr_parity("simplify", simplify(exp_trig), simplify_srepr(exp_trig))
}

///|
test "symsimplify simplify parity special heuristics" {
  let x = @symcore.Expr::Symbol("x")
  let exprs = [
    @symcore.add([
      @symcore.function("log", [x]),
      @symcore.function("log", [@symcore.int(2)]),
    ]),
    @symcore.function("gamma", [@symcore.int(6)]),
    @symcore.function("KroneckerDelta", [@symcore.int(2), @symcore.int(3)]),
    @symcore.function("besselj", [@symcore.int(0), @symcore.int(0)]),
  ]
  for expr in exprs {
    assert_srepr_parity("simplify", simplify(expr), simplify_srepr(expr))
  }
  let radical = @symcore.function("sqrt", [
    @symcore.add([
      @symcore.int(3),
      @symcore.mul([
        @symcore.int(2),
        @symcore.function("sqrt", [@symcore.int(2)]),
      ]),
    ]),
  ])
  assert_true(sqrtdenest_equivalent(radical, simplify(radical)))
}

///|
test "symsimplify powsimp parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let exprs = [
    @symcore.mul([x, x, y]),
    @symcore.mul([
      @symcore.pow(x, @symcore.int(2)),
      @symcore.pow(x, @symcore.int(3)),
    ]),
    @symcore.pow(@symcore.pow(x, @symcore.int(2)), @symcore.int(3)),
  ]
  for expr in exprs {
    let ours = powsimp(expr)
    let oracle = powsimp_srepr(expr)
    assert_srepr_parity("powsimp", ours, oracle)
  }
}

///|
test "symsimplify trigsimp parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
  ])
  let ours = trigsimp(expr)
  let oracle = trigsimp_srepr(expr)
  assert_srepr_parity("trigsimp", ours, oracle)
}

///|
test "symsimplify signsimp parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([@symcore.mul([@symcore.int(-1), x]), x])
  let ours = signsimp(expr)
  let oracle = signsimp_srepr(expr)
  assert_srepr_parity("signsimp", ours, oracle)
}

///|
test "symsimplify radsimp parity" {
  let x = @symcore.Expr::Symbol("x")
  let exprs = [@symcore.pow(@symcore.function("sqrt", [x]), @symcore.int(-1))]
  for expr in exprs {
    let ours = radsimp(expr)
    assert_true(radsimp_equivalent(expr, ours))
  }
}

///|
test "symsimplify ratsimp parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let exprs = [
    @symcore.add([
      @symcore.pow(x, @symcore.int(-1)),
      @symcore.pow(y, @symcore.int(-1)),
    ]),
    @symcore.add([
      @symcore.mul([@symcore.int(2), @symcore.pow(x, @symcore.int(-1))]),
      @symcore.pow(x, @symcore.int(-1)),
    ]),
  ]
  for expr in exprs {
    let ours = ratsimp(expr)
    assert_true(ratsimp_equivalent(expr, ours))
  }
}

///|
test "symsimplify sqrtdenest parity" {
  let exprs = [
    @symcore.function("sqrt", [
      @symcore.add([
        @symcore.int(3),
        @symcore.mul([
          @symcore.int(2),
          @symcore.function("sqrt", [@symcore.int(2)]),
        ]),
      ]),
    ]),
    @symcore.function("sqrt", [
      @symcore.add([
        @symcore.int(5),
        @symcore.mul([
          @symcore.int(2),
          @symcore.function("sqrt", [@symcore.int(6)]),
        ]),
      ]),
    ]),
  ]
  for expr in exprs {
    let ours = sqrtdenest(expr)
    assert_true(sqrtdenest_equivalent(expr, ours))
  }
}

///|
test "symsimplify combsimp parity" {
  let exprs = [
    @symcore.mul([
      @symcore.function("factorial", [@symcore.int(6)]),
      @symcore.pow(
        @symcore.function("factorial", [@symcore.int(5)]),
        @symcore.int(-1),
      ),
    ]),
    @symcore.function("binomial", [@symcore.int(6), @symcore.int(2)]),
    @symcore.function("gamma", [@symcore.int(6)]),
  ]
  for expr in exprs {
    let ours = combsimp(expr)
    assert_true(combsimp_equivalent(expr, ours))
  }
}

///|
test "symsimplify hyperexpand parity" {
  let x = @symcore.Expr::Symbol("x")
  let exprs = [
    @symcore.function("hyper", [
      @symcore.function("Tuple", []),
      @symcore.function("Tuple", []),
      x,
    ]),
    @symcore.function("hyper", [
      @symcore.function("Tuple", [@symcore.int(1)]),
      @symcore.function("Tuple", [@symcore.int(1)]),
      x,
    ]),
  ]
  for expr in exprs {
    let ours = hyperexpand(expr)
    assert_true(hyperexpand_equivalent(expr, ours))
  }
}

///|
test "symsimplify powdenest parity" {
  let x = @symcore.Expr::Symbol("x")
  let exprs = [
    @symcore.pow(@symcore.pow(x, @symcore.int(2)), @symcore.int(3)),
    @symcore.function("exp", [
      @symcore.mul([@symcore.int(2), @symcore.function("log", [x])]),
    ]),
  ]
  for expr in exprs {
    let ours = powdenest(expr)
    assert_true(powdenest_equivalent(expr, ours))
  }
}

///|
test "symsimplify exptrigsimp parity" {
  let x = @symcore.Expr::Symbol("x")
  let exprs = [
    @symcore.add([
      @symcore.function("exp", [@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), x])]),
      @symcore.function("exp", [
        @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), x]),
      ]),
    ]),
    @symcore.add([
      @symcore.function("cos", [x]),
      @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), @symcore.function("sin", [x])]),
    ]),
  ]
  for expr in exprs {
    let ours = exptrigsimp(expr)
    assert_true(exptrigsimp_equivalent(expr, ours))
  }
}

///|
test "symsimplify gammasimp/logcombine parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr1 = @symcore.function("gamma", [@symcore.add([x, @symcore.int(1)])])
  let ours1 = gammasimp(expr1)
  assert_true(gammasimp_equivalent(expr1, ours1))

  let expr2 = @symcore.add([
    @symcore.function("log", [x]),
    @symcore.function("log", [@symcore.int(2)]),
  ])
  let ours2 = logcombine(expr2)
  assert_true(logcombine_equivalent(expr2, ours2))
}

///|
test "symsimplify separatevars/hyper parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let k = @symcore.Expr::Symbol("k")

  let sep_expr = @symcore.pow(@symcore.mul([x, y]), @symcore.int(2))
  let ours_sep = separatevars(sep_expr)
  let oracle_sep = separatevars_srepr(sep_expr)
  assert_srepr_parity("separatevars", ours_sep, oracle_sep)

  let h_expr = @symcore.function("factorial", [k])
  let ours_h = hypersimp(h_expr, k)
  let oracle_h = hypersimp_srepr(h_expr, k)
  assert_srepr_parity("hypersimp", ours_h, oracle_h)

  let h2_expr = h_expr
  let ours_sim = hypersimilar(h_expr, h2_expr, k)
  let oracle_sim = hypersimilar_bool(h_expr, h2_expr, k)
  assert_eq(ours_sim, oracle_sim)
}

///|
test "symsimplify fu parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
  ])
  let ours = fu(expr)
  assert_true(fu_equivalent(expr, ours))
}

///|
test "symsimplify compat simplify parity" {
  let x = @symcore.Expr::Symbol("x")

  let kd_expr = @symcore.add([
    @symcore.function("KroneckerDelta", [@symcore.int(2), @symcore.int(3)]),
    x,
  ])
  let kd_ours = kroneckersimp(kd_expr)
  assert_true(kroneckersimp_equivalent(kd_expr, kd_ours))

  let bj_expr = @symcore.function("besselj", [@symcore.int(2), @symcore.int(0)])
  let bj_ours = besselsimp(bj_expr)
  assert_true(besselsimp_equivalent(bj_expr, bj_ours))

  let ns_expr = @symcore.add([
    @symcore.rational_from_ints(1, 3),
    @symcore.rational_from_ints(1, 6),
  ])
  let ns_ours = nsimplify(ns_expr)
  assert_true(nsimplify_equivalent(ns_expr, ns_ours))

  let rm_expr = x
  let basis = [
    @symcore.add([@symcore.pow(x, @symcore.int(2)), @symcore.int(1)]),
  ]
  let gens = [x]
  let rm_ours = ratsimpmodprime(rm_expr, basis~, gens~)
  assert_true(ratsimpmodprime_equivalent(rm_expr, basis, gens, rm_ours))
}

///|
test "symsimplify compat simplify advanced parity" {
  let a = @symcore.Expr::Symbol("a")
  let golden = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::GoldenRatio)
  let i = @symcore.Expr::Symbol("i")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let x = @symcore.Expr::Symbol("x")
  let z = @symcore.Expr::Symbol("z")
  let half = @symcore.rational_from_ints(1, 2)
  let minus_half = @symcore.rational_from_ints(-1, 2)

  let kd_cancel_expr = @symcore.add([
    @symcore.int(1),
    @symcore.mul([
      @symcore.function("KroneckerDelta", [@symcore.int(0), i]),
      @symcore.function("KroneckerDelta", [@symcore.int(1), i]),
    ]),
  ])
  let kd_cancel_ours = kroneckersimp(kd_cancel_expr)
  assert_true(kroneckersimp_equivalent(kd_cancel_expr, kd_cancel_ours))

  let bj_half_expr = @symcore.function("besselj", [half, z])
  let bj_half_ours = besselsimp(bj_half_expr)
  assert_true(besselsimp_equivalent(bj_half_expr, bj_half_ours))

  let bi_half_expr = @symcore.function("besseli", [minus_half, z])
  let bi_half_ours = besselsimp(bi_half_expr)
  assert_true(besselsimp_equivalent(bi_half_expr, bi_half_ours))

  let recurrence_expr = @symcore.add([
    @symcore.function("besselj", [@symcore.add([a, @symcore.int(-1)]), x]),
    @symcore.function("besselj", [@symcore.add([a, @symcore.int(1)]), x]),
    @symcore.mul([
      @symcore.int(-2),
      a,
      @symcore.function("besselj", [a, x]),
      @symcore.pow(x, @symcore.int(-1)),
    ]),
  ])
  let recurrence_ours = besselsimp(recurrence_expr)
  assert_true(besselsimp_equivalent(recurrence_expr, recurrence_ours))

  let exact_ns_expr = @symcore.add([
    @symcore.pow(@symcore.int(27), @symcore.rational_from_ints(1, 3)),
    @symcore.pow(@symcore.int(16), @symcore.rational_from_ints(-1, 2)),
  ])
  let exact_ns_ours = nsimplify(exact_ns_expr)
  assert_true(nsimplify_equivalent(exact_ns_expr, exact_ns_ours))

  let trig_ns_expr = @symcore.add([
    @symcore.function("sin", [
      @symcore.mul([pi, @symcore.rational_from_ints(1, 6)]),
    ]),
    @symcore.function("cos", [
      @symcore.mul([pi, @symcore.rational_from_ints(1, 3)]),
    ]),
    @symcore.function("sqrt", [@symcore.int(4)]),
  ])
  let trig_ns_ours = nsimplify(trig_ns_expr)
  assert_true(nsimplify_equivalent(trig_ns_expr, trig_ns_ours))

  let golden_expr = @symcore.add([
    @symcore.function("sqrt", [@symcore.int(5)]),
    @symcore.int(-1),
  ])
  let golden_ours = nsimplify(golden_expr, constants=[golden])
  assert_true(
    nsimplify_equivalent_with_constants(golden_expr, [golden], golden_ours),
  )
}

///|
test "symsimplify cse_opts parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.add([y, @symcore.mul([@symcore.int(-1), x])])

  let pre = sub_pre(expr)
  assert_true(sub_pre_equivalent(expr, pre))

  let post = sub_post(pre)
  assert_true(sub_post_equivalent(pre, post))
}

///|
test "symsimplify radsimp extras parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")

  let s_expr = @symcore.add([
    @symcore.mul([@symcore.int(2), @symcore.function("sqrt", [x])]),
    @symcore.mul([@symcore.int(3), @symcore.function("sqrt", [x])]),
    y,
  ])
  let s_ours = collect_sqrt(s_expr)
  assert_true(collect_sqrt_equivalent(s_expr, s_ours))

  let a_expr = @symcore.add([
    @symcore.mul([@symcore.int(2), @symcore.function("Abs", [x])]),
    @symcore.function("Abs", [x]),
    y,
  ])
  let a_ours = collect_abs(a_expr)
  assert_true(collect_abs_equivalent(a_expr, a_ours))

  let frac_expr = @symcore.mul([
    @symcore.add([x, @symcore.int(1)]),
    @symcore.pow(@symcore.add([x, @symcore.int(2)]), @symcore.int(-1)),
  ])
  let fe_ours = fraction_expand(frac_expr)
  assert_true(fraction_expand_equivalent(frac_expr, fe_ours))

  let ne_ours = numer_expand(frac_expr)
  assert_true(numer_expand_equivalent(frac_expr, ne_ours))

  let de_ours = denom_expand(frac_expr)
  assert_true(denom_expand_equivalent(frac_expr, de_ours))
}

///|
test "symsimplify fu rules parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let pi6 = @symcore.mul([@symcore.rational_from_ints(1, 6), pi])

  assert_true(
    tr_rule_equivalent("TR0", @symcore.add([x, x]), tr0(@symcore.add([x, x]))),
  )
  assert_true(
    tr_rule_equivalent(
      "TR1",
      @symcore.function("sec", [x]),
      tr1(@symcore.function("sec", [x])),
    ),
  )
  assert_true(
    tr_rule_equivalent(
      "TR2",
      @symcore.function("tan", [x]),
      tr2(@symcore.function("tan", [x])),
    ),
  )
  let tr2i_expr = @symcore.mul([
    @symcore.function("sin", [x]),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(-1)),
  ])
  assert_true(tr_rule_equivalent("TR2i", tr2i_expr, tr2i(tr2i_expr)))

  let tr3_expr = @symcore.function("sin", [@symcore.mul([@symcore.int(-1), x])])
  assert_true(tr_rule_equivalent("TR3", tr3_expr, tr3(tr3_expr)))
  assert_true(
    tr_rule_equivalent(
      "TR4",
      @symcore.function("sin", [pi6]),
      tr4(@symcore.function("sin", [pi6])),
    ),
  )

  let tr5_expr = @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2))
  let tr6_expr = @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2))
  assert_true(tr_rule_equivalent("TR5", tr5_expr, tr5(tr5_expr)))
  assert_true(tr_rule_equivalent("TR6", tr6_expr, tr6(tr6_expr)))
  assert_true(tr_rule_equivalent("TR7", tr6_expr, tr7(tr6_expr)))

  let tr8_expr = @symcore.mul([
    @symcore.function("sin", [x]),
    @symcore.function("cos", [y]),
  ])
  let tr9_expr = @symcore.add([
    @symcore.function("cos", [x]),
    @symcore.function("cos", [y]),
  ])
  assert_true(tr_rule_equivalent("TR8", tr8_expr, tr8(tr8_expr)))
  assert_true(tr_rule_equivalent("TR9", tr9_expr, tr9(tr9_expr)))

  let tr10_expr = @symcore.function("sin", [@symcore.add([x, y])])
  let tr10i_expr = @symcore.add([
    @symcore.mul([@symcore.function("cos", [x]), @symcore.function("cos", [y])]),
    @symcore.mul([@symcore.function("sin", [x]), @symcore.function("sin", [y])]),
  ])
  assert_true(tr_rule_equivalent("TR10", tr10_expr, tr10(tr10_expr)))
  assert_true(tr_rule_equivalent("TR10i", tr10i_expr, tr10i(tr10i_expr)))

  let tr11_expr = @symcore.function("sin", [@symcore.mul([@symcore.int(2), x])])
  let tr12_expr = @symcore.function("tan", [@symcore.add([x, y])])
  let tr12i_expr = @symcore.mul([
    @symcore.add([@symcore.function("tan", [x]), @symcore.function("tan", [y])]),
    @symcore.pow(
      @symcore.add([
        @symcore.int(1),
        @symcore.mul([
          @symcore.int(-1),
          @symcore.function("tan", [x]),
          @symcore.function("tan", [y]),
        ]),
      ]),
      @symcore.int(-1),
    ),
  ])
  assert_true(tr_rule_equivalent("TR11", tr11_expr, tr11(tr11_expr)))
  assert_true(tr_rule_equivalent("TR12", tr12_expr, tr12(tr12_expr)))
  assert_true(tr_rule_equivalent("TR12i", tr12i_expr, tr12i(tr12i_expr)))

  let tr13_expr = @symcore.mul([
    @symcore.function("tan", [x]),
    @symcore.function("tan", [y]),
  ])
  let tr14_expr = @symcore.mul([
    @symcore.add([@symcore.function("cos", [x]), @symcore.int(1)]),
    @symcore.add([@symcore.function("cos", [x]), @symcore.int(-1)]),
  ])
  let tr15_expr = @symcore.pow(@symcore.function("sin", [x]), @symcore.int(-2))
  let tr16_expr = @symcore.pow(@symcore.function("cos", [x]), @symcore.int(-2))
  assert_true(tr_rule_equivalent("TR13", tr13_expr, tr13(tr13_expr)))
  assert_true(tr_rule_equivalent("TR14", tr14_expr, tr14(tr14_expr)))
  assert_true(tr_rule_equivalent("TR15", tr15_expr, tr15(tr15_expr)))
  assert_true(tr_rule_equivalent("TR16", tr16_expr, tr16(tr16_expr)))

  let tr111_expr = @symcore.pow(@symcore.function("tan", [x]), @symcore.int(-2))
  let tr22_expr = @symcore.pow(@symcore.function("tan", [x]), @symcore.int(2))
  let trpower_expr = @symcore.pow(
    @symcore.function("sin", [x]),
    @symcore.int(4),
  )
  let trmorrie_expr = @symcore.mul([
    @symcore.function("cos", [x]),
    @symcore.function("cos", [@symcore.mul([@symcore.int(2), x])]),
    @symcore.function("cos", [@symcore.mul([@symcore.int(4), x])]),
  ])
  assert_true(tr_rule_equivalent("TR111", tr111_expr, tr111(tr111_expr)))
  assert_true(tr_rule_equivalent("TR22", tr22_expr, tr22(tr22_expr)))
  assert_true(
    tr_rule_equivalent("TRpower", trpower_expr, trpower(trpower_expr)),
  )
  assert_true(
    tr_rule_equivalent("TRmorrie", trmorrie_expr, trmorrie(trmorrie_expr)),
  )

  let futrig_expr = @symcore.add([
    @symcore.pow(@symcore.function("sin", [x]), @symcore.int(2)),
    @symcore.pow(@symcore.function("cos", [x]), @symcore.int(2)),
  ])
  assert_true(futrig_equivalent(futrig_expr, futrig(futrig_expr)))
}
