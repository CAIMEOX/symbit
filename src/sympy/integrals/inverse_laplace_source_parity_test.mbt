///|

///|
test "symintegrals parity inverse Laplace SymPy source frontdoor cases" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let k = @symcore.Expr::Symbol("k")

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))
  @symassume.add_global_assumption(@symassume.q_positive(c))
  @symassume.add_global_assumption(@symassume.q_positive(k))

  let symbolic_quadratic_inverse = doit(
    inverse_laplace_transform(
      (a * (s ^ @symcore.int(2)) + b * s + c) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_quadratic_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True), sympy.Symbol('c'): sympy.Symbol('c', positive=True)}) - sympy.inverse_laplace_transform(1/(sympy.Symbol('a', positive=True)*sympy.Symbol('s')**2 + sympy.Symbol('b', positive=True)*sympy.Symbol('s') + sympy.Symbol('c', positive=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let bateman_532_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(k * s) ^ @symcore.int(-1)) *
      ((c * s - a) ^ @symcore.int(-1)) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(bateman_532_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('c'): sympy.Symbol('c', positive=True), sympy.Symbol('k'): sympy.Symbol('k', positive=True)}) - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('k', positive=True)*sympy.Symbol('s'))*(sympy.Symbol('c', positive=True)*sympy.Symbol('s') - sympy.Symbol('a', positive=True))*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_positive_scale_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(b * s) + a) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_positive_scale_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('b', positive=True)*sympy.Symbol('s')) + sympy.Symbol('a', positive=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let bateman_537_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(b * s) + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let bateman_538_inverse = doit(
    inverse_laplace_transform(
      (a ^ @symcore.int(2)) *
      ((@symelem.sqrt(s) + a) ^ @symcore.int(-1)) *
      (s ^ @symcore.rational_from_ints(-3, 2)),
      s,
      x,
    ),
  )
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(bateman_537_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('b', positive=True)*sympy.Symbol('s')) + sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(bateman_538_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.Symbol('a', positive=True)**2/((sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))*sympy.Symbol('s')**sympy.Rational(3, 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let unassumed_sqrt_linear_scale_object = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(b * s) + a) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(unassumed_sqrt_linear_scale_object) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(1/(sympy.sqrt(sympy.Symbol('b')*sympy.Symbol('s')) + sympy.Symbol('a')), sympy.Symbol('s'), sympy.Symbol('x'), None).doit())",
    ),
  )
}

///|
test "symintegrals parity inverse Laplace quadratic source sign branches" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  let trig_branch = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(2)) + (a ^ @symcore.int(2))) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(trig_branch) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')**2 + sympy.Symbol('a', positive=True)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_negative(b))
  let hyperbolic_branch = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(2)) + b) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(hyperbolic_branch) +
      ").xreplace({sympy.Symbol('b'): sympy.Symbol('b', negative=True)}) - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')**2 + sympy.Symbol('b', negative=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  @symassume.add_global_assumption(@symassume.q_negative(b))
  let negative_square_branch = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(2)) - (b ^ @symcore.int(2))) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(negative_square_branch) +
      ").xreplace({sympy.Symbol('b'): sympy.Symbol('b', negative=True)}) - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')**2 - sympy.Symbol('b', negative=True)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
fn inverse_laplace_positive_abck_zero_check(
  checks : Array[String],
  ours : Expr,
  target : String,
) -> Unit {
  checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(ours) +
    ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True), sympy.Symbol('c'): sympy.Symbol('c', positive=True), sympy.Symbol('k'): sympy.Symbol('k', positive=True)}) - (" +
    target +
    ")))",
  )
}

///|
test "symintegrals parity inverse Laplace symbolic Bateman irrational paths" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let k = @symcore.Expr::Symbol("k")

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))
  @symassume.add_global_assumption(@symassume.q_positive(c))
  @symassume.add_global_assumption(@symassume.q_positive(k))

  let bateman_531 = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(k * s) ^ @symcore.int(-1)) *
      ((c * s - a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let bateman_535 = doit(
    inverse_laplace_transform(
      a *
      (s ^ @symcore.int(-1)) *
      ((b * @symelem.sqrt(s) + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let bateman_5310 = doit(
    inverse_laplace_transform((@symelem.sqrt(s) + a) ^ @symcore.int(-2), s, x),
  )
  let bateman_5311 = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) * ((@symelem.sqrt(s) + a) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let bateman_5312 = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + a) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let bateman_5313 = doit(
    inverse_laplace_transform((@symelem.sqrt(s) + a) ^ @symcore.int(-3), s, x),
  )
  let bateman_5317 = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) - a) *
      (s ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  @symassume.clear_global_assumptions()

  let bateman_checks : Array[String] = []
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_531, "sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('k', positive=True)*sympy.Symbol('s'))*(sympy.Symbol('c', positive=True)*sympy.Symbol('s') - sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_535, "sympy.inverse_laplace_transform(sympy.Symbol('a', positive=True)/(sympy.Symbol('s')*(sympy.Symbol('b', positive=True)*sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5310, "sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5311, "sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5312, "sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5313, "sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5317, "sympy.inverse_laplace_transform((sympy.sqrt(sympy.Symbol('s')) - sympy.Symbol('a', positive=True))/(sympy.Symbol('s')*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  for oracle in integrals_eval_zero_batch(bateman_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity inverse Laplace remaining Bateman irrational paths" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))

  let sqrt_s = @symelem.sqrt(s)
  let bateman_5306 = doit(
    inverse_laplace_transform(
      sqrt_s * ((s - b) ^ @symcore.int(-1)) * ((sqrt_s + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let bateman_5309 = doit(
    inverse_laplace_transform(
      (sqrt_s ^ @symcore.int(-1)) *
      ((s - b) ^ @symcore.int(-1)) *
      ((sqrt_s + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let bateman_5314 = doit(
    inverse_laplace_transform(sqrt_s * ((sqrt_s + a) ^ @symcore.int(-3)), s, x),
  )
  let bateman_5315 = doit(
    inverse_laplace_transform(
      (sqrt_s ^ @symcore.int(-1)) * ((sqrt_s + a) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  let bateman_5316 = doit(
    inverse_laplace_transform((sqrt_s + a) ^ @symcore.int(-4), s, x),
  )
  let bateman_5318 = doit(
    inverse_laplace_transform(
      ((sqrt_s - a) ^ @symcore.int(2)) *
      (s ^ @symcore.int(-1)) *
      ((sqrt_s + a) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let bateman_5319 = doit(
    inverse_laplace_transform(
      ((sqrt_s - a) ^ @symcore.int(3)) *
      (s ^ @symcore.int(-1)) *
      ((sqrt_s + a) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  let bateman_5322 = doit(
    inverse_laplace_transform(
      @symelem.sqrt(s + b) * ((s + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let bateman_5323 = doit(
    inverse_laplace_transform(
      ((s + a) ^ @symcore.int(-1)) * (@symelem.sqrt(s + b) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  @symassume.clear_global_assumptions()

  let bateman_checks : Array[String] = []
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5306, "sympy.inverse_laplace_transform(sympy.sqrt(sympy.Symbol('s'))/((sympy.Symbol('s') - sympy.Symbol('b', positive=True))*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5309, "sympy.inverse_laplace_transform(1/((sympy.Symbol('s') - sympy.Symbol('b', positive=True))*sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5314, "sympy.inverse_laplace_transform(sympy.sqrt(sympy.Symbol('s'))/(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5315, "sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**3), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5316, "sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**4, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5318, "sympy.inverse_laplace_transform((sympy.sqrt(sympy.Symbol('s')) - sympy.Symbol('a', positive=True))**2/(sympy.Symbol('s')*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5319, "sympy.inverse_laplace_transform((sympy.sqrt(sympy.Symbol('s')) - sympy.Symbol('a', positive=True))**3/(sympy.Symbol('s')*(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True))**3), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5322, "sympy.inverse_laplace_transform(sympy.sqrt(sympy.Symbol('s') + sympy.Symbol('b', positive=True))/(sympy.Symbol('s') + sympy.Symbol('a', positive=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  inverse_laplace_positive_abck_zero_check(
    bateman_checks, bateman_5323, "sympy.inverse_laplace_transform(1/((sympy.Symbol('s') + sympy.Symbol('a', positive=True))*sympy.sqrt(sympy.Symbol('s') + sympy.Symbol('b', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)",
  )
  for oracle in integrals_eval_zero_batch(bateman_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity inverse Laplace positive-parameter fallback paths" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))

  let generic_frequency_shift = doit(
    inverse_laplace_transform(@symcore.raw_function("F", [s - a]), s, x),
  )
  let positive_base_right = doit(
    inverse_laplace_transform((a ^ s) * (s ^ @symcore.int(-1)), s, x),
  )
  let positive_base_left_shift = doit(
    inverse_laplace_transform(
      (a ^ (@symcore.int(-1) * s)) * ((s + b) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let delayed_shifted_linear = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) * ((s + b) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let delayed_besselj = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) *
      (
        @symelem.sqrt((s ^ @symcore.int(2)) + @symcore.int(1)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let delayed_besseli = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) *
      (
        @symelem.sqrt((s ^ @symcore.int(2)) - @symcore.int(1)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let log_shifted_e1 = doit(
    inverse_laplace_transform(
      @symelem.log(s + a) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let log_scaled_shifted_e1 = doit(
    inverse_laplace_transform(
      @symelem.log(@symcore.int(2) * s + a) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let expint2_scaled_ratio = doit(
    inverse_laplace_transform(
      (s - a * @symelem.log((s + a) * (a ^ @symcore.int(-1)))) *
      (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let expint2_scaled_expanded = doit(
    inverse_laplace_transform(
      (s - a * @symelem.log(s + a) + a * @symelem.log(a)) *
      (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let reciprocal_exp_besselj0 = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * (s ^ @symcore.int(-1))) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reciprocal_exp_besseli0 = doit(
    inverse_laplace_transform(
      @symelem.exp(a * (s ^ @symcore.int(-1))) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reciprocal_exp_besselj1 = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * (s ^ @symcore.int(-1))) *
      (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let reciprocal_exp_besseli1 = @symintegrals.inverse_laplace_transform_eval(
    @symelem.exp(a * (s ^ @symcore.int(-1))) * (s ^ @symcore.int(-2)),
    s,
    x,
    noconds=false,
  )
  @symassume.clear_global_assumptions()

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(generic_frequency_shift) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.Function('F')(sympy.Symbol('s') - sympy.Symbol('a', positive=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(positive_base_right) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.Symbol('a', positive=True)**sympy.Symbol('s')/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(positive_base_left_shift) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(sympy.Symbol('a', positive=True)**(-sympy.Symbol('s'))/(sympy.Symbol('s') + sympy.Symbol('b', positive=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_shifted_linear) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('a', positive=True)*sympy.Symbol('s'))/(sympy.Symbol('s') + sympy.Symbol('b', positive=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_besselj) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('a', positive=True)*sympy.Symbol('s'))/sympy.sqrt(sympy.Symbol('s')**2 + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_besseli) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('a', positive=True)*sympy.Symbol('s'))/sympy.sqrt(sympy.Symbol('s')**2 - 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_shifted_e1) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)})).rewrite(sympy.expint).expand() - (sympy.inverse_laplace_transform(sympy.log(sympy.Symbol('s') + sympy.Symbol('a', positive=True))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.expint).expand()))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_scaled_shifted_e1) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)})).rewrite(sympy.expint).expand() - (sympy.inverse_laplace_transform(sympy.log(2*sympy.Symbol('s') + sympy.Symbol('a', positive=True))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.expint).expand()))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr((lambda e: sympy.simplify(e.replace(lambda node: getattr(node, 'func', None) == sympy.expint and len(node.args) == 2 and node.args[0] == 2, lambda node: sympy.exp(-node.args[1]) - node.args[1]*sympy.expint(1, node.args[1])) - (sympy.inverse_laplace_transform((sympy.Symbol('s') - sympy.Symbol('a', positive=True)*sympy.log((sympy.Symbol('s') + sympy.Symbol('a', positive=True))/sympy.Symbol('a', positive=True)))/sympy.Symbol('s')**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.expint).expand()))((" +
      py_expr(expint2_scaled_ratio) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)})))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr((lambda e: sympy.simplify(e.replace(lambda node: getattr(node, 'func', None) == sympy.expint and len(node.args) == 2 and node.args[0] == 2, lambda node: sympy.exp(-node.args[1]) - node.args[1]*sympy.expint(1, node.args[1])) - (sympy.inverse_laplace_transform((sympy.Symbol('s') - sympy.Symbol('a', positive=True)*sympy.log(sympy.Symbol('s') + sympy.Symbol('a', positive=True)) + sympy.Symbol('a', positive=True)*sympy.log(sympy.Symbol('a', positive=True)))/sympy.Symbol('s')**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.expint).expand()))((" +
      py_expr(expint2_scaled_expanded) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)})))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_exp_besselj0) +
      ") - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('a')/sympy.Symbol('s'))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_exp_besseli0) +
      ") - sympy.inverse_laplace_transform(sympy.exp(sympy.Symbol('a')/sympy.Symbol('s'))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_exp_besselj1) +
      ") - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('a')/sympy.Symbol('s'))/sympy.Symbol('s')**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  match @symcore.tuple_items(reciprocal_exp_besseli1) {
    Some([value, cond]) => {
      assert_eq(
        integrals_eval_str(
          "sympy.sstr(sympy.simplify((" +
          py_expr(value) +
          ") - sympy.inverse_laplace_transform(sympy.exp(sympy.Symbol('a')/sympy.Symbol('s'))/sympy.Symbol('s')**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
        ),
        "0",
      )
      assert_eq(integrals_eval_str("sympy.sstr(" + py_expr(cond) + ")"), "True")
    }
    _ =>
      fail("expected Tuple from inverse_laplace_transform_eval noconds=false")
  }
}

///|
test "symintegrals parity inverse Laplace log over power fallback" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")

  let log_over_s = doit(
    inverse_laplace_transform(@symelem.log(s) * (s ^ @symcore.int(-1)), s, x),
  )
  let log_over_s2 = doit(
    inverse_laplace_transform(@symelem.log(s) * (s ^ @symcore.int(-2)), s, x),
  )
  let scaled_log_over_s3 = doit(
    inverse_laplace_transform(
      @symcore.int(3) * @symelem.log(s) * (s ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  let log_square_over_s = doit(
    inverse_laplace_transform(
      (@symelem.log(s) ^ @symcore.int(2)) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let log_square_over_s2 = doit(
    inverse_laplace_transform(
      (@symelem.log(s) ^ @symcore.int(2)) * (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_over_s) +
      ") - sympy.inverse_laplace_transform(sympy.log(sympy.Symbol('s'))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_over_s2) +
      ") - sympy.inverse_laplace_transform(sympy.log(sympy.Symbol('s'))/sympy.Symbol('s')**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_log_over_s3) +
      ") - sympy.inverse_laplace_transform(3*sympy.log(sympy.Symbol('s'))/sympy.Symbol('s')**3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_square_over_s) +
      ") - sympy.inverse_laplace_transform(sympy.log(sympy.Symbol('s'))**2/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_square_over_s2) +
      ") - sympy.inverse_laplace_transform(sympy.log(sympy.Symbol('s'))**2/sympy.Symbol('s')**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace quadratic three-half Bessel kernels" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let neg_three_halves = @symcore.rational_from_ints(-3, 2)
  let plus_quad = (s ^ @symcore.int(2)) + @symcore.int(4)
  let minus_quad = (s ^ @symcore.int(2)) - @symcore.int(4)

  let reciprocal_j = doit(
    inverse_laplace_transform(plus_quad ^ neg_three_halves, s, x),
  )
  let symbol_j = doit(
    inverse_laplace_transform(s * (plus_quad ^ neg_three_halves), s, x),
  )
  let reciprocal_i = doit(
    inverse_laplace_transform(minus_quad ^ neg_three_halves, s, x),
  )
  let symbol_i = doit(
    inverse_laplace_transform(s * (minus_quad ^ neg_three_halves), s, x),
  )

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_j) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s')**2 + 4)**sympy.Rational(-3, 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbol_j) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('s')*(sympy.Symbol('s')**2 + 4)**sympy.Rational(-3, 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_i) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s')**2 - 4)**sympy.Rational(-3, 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbol_i) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('s')*(sympy.Symbol('s')**2 - 4)**sympy.Rational(-3, 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace rational fallback square quadratic kernels" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let d = @symcore.Expr::Symbol("d")

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))
  @symassume.add_global_assumption(@symassume.q_positive(d))

  let symbolic_square_quadratic = doit(
    inverse_laplace_transform(
      (b * (s ^ @symcore.int(2)) + d) *
      (((a ^ @symcore.int(2)) + (s ^ @symcore.int(2))) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  @symassume.clear_global_assumptions()

  let symbol_square_plus = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-2)) *
      (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let symbol_square_minus = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-2)) *
      (((s ^ @symcore.int(2)) - @symcore.int(4)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let square_minus = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(2)) *
      (((s ^ @symcore.int(2)) - @symcore.int(4)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_square_quadratic) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True), sympy.Symbol('d'): sympy.Symbol('d', positive=True)}) - sympy.inverse_laplace_transform((sympy.Symbol('b', positive=True)*sympy.Symbol('s')**2 + sympy.Symbol('d', positive=True))/(sympy.Symbol('a', positive=True)**2 + sympy.Symbol('s')**2)**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbol_square_plus) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')**2*(sympy.Symbol('s')**2 + 1)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(symbol_square_minus) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')**2*(sympy.Symbol('s')**2 - 4)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.exp)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(square_minus) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('s')**2/(sympy.Symbol('s')**2 - 4)**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.exp)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace erf table kernel" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")

  let numeric_kernel = @symelem.exp(
      (s ^ @symcore.int(2)) * @symcore.rational_from_ints(1, 16),
    ) *
    @symspec.erfc(s * @symcore.rational_from_ints(1, 4)) *
    (s ^ @symcore.int(-1))
  let numeric_inverse = doit(inverse_laplace_transform(numeric_kernel, s, x))
  let numeric_inverse_with_conditions = @symintegrals.inverse_laplace_transform_eval(
    numeric_kernel,
    s,
    x,
    noconds=false,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(numeric_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.exp(sympy.Symbol('s')**2/16)*sympy.erfc(sympy.Symbol('s')/4)/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(numeric_inverse_with_conditions) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.inverse_laplace_transform(sympy.exp(sympy.Symbol('s')**2/16)*sympy.erfc(sympy.Symbol('s')/4)/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=False))",
    ),
  )

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  let symbolic_kernel = @symelem.exp(
      (s ^ @symcore.int(2)) *
      ((@symcore.int(4) * (a ^ @symcore.int(2))) ^ @symcore.int(-1)),
    ) *
    @symspec.erfc(s * ((@symcore.int(2) * a) ^ @symcore.int(-1))) *
    (s ^ @symcore.int(-1))
  let symbolic_inverse = doit(inverse_laplace_transform(symbolic_kernel, s, x))
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(sympy.Symbol('s')**2/(4*sympy.Symbol('a', positive=True)**2))*sympy.erfc(sympy.Symbol('s')/(2*sympy.Symbol('a', positive=True)))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace Gaussian erfc fallback kernel" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")

  let numeric_kernel = @symcore.rational_from_ints(1, 4) *
    @symelem.sqrt(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)) *
    @symelem.exp((s ^ @symcore.int(2)) * @symcore.rational_from_ints(1, 16)) *
    @symspec.erfc(s * @symcore.rational_from_ints(1, 4))
  let numeric_inverse = doit(inverse_laplace_transform(numeric_kernel, s, x))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(numeric_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(sympy.pi)*sympy.exp(sympy.Symbol('s')**2/16)*sympy.erfc(sympy.Symbol('s')/4)/4, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  let delayed_numeric_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-2) * s) * numeric_kernel,
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_numeric_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.exp(-2*sympy.Symbol('s'))*sympy.sqrt(sympy.pi)*sympy.exp(sympy.Symbol('s')**2/16)*sympy.erfc(sympy.Symbol('s')/4)/4, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  let symbolic_kernel = @symcore.rational_from_ints(1, 2) *
    @symelem.sqrt(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (a ^ @symcore.int(-1)),
    ) *
    @symelem.exp(
      (s ^ @symcore.int(2)) * ((@symcore.int(4) * a) ^ @symcore.int(-1)),
    ) *
    @symspec.erfc(s * ((@symcore.int(2) * @symelem.sqrt(a)) ^ @symcore.int(-1)))
  let symbolic_inverse = doit(inverse_laplace_transform(symbolic_kernel, s, x))
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.sqrt(sympy.pi)*sympy.exp(sympy.Symbol('s')**2/(4*sympy.Symbol('a', positive=True)))*sympy.erfc(sympy.Symbol('s')/(2*sympy.sqrt(sympy.Symbol('a', positive=True))))/(2*sympy.sqrt(sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace integration sqrt exponential over s" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let kernel = @symelem.exp(@symcore.int(-1) * @symelem.sqrt(s)) *
    (s ^ @symcore.int(-1))
  let value = doit(inverse_laplace_transform(kernel, s, x))

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(value) +
      ") - sympy.inverse_laplace_transform(sympy.exp(-sympy.sqrt(sympy.Symbol('s')))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_exp = @symelem.exp(
    @symcore.int(-2) * @symelem.sqrt(@symcore.int(2) * s),
  )
  let sqrt_den_kernel = @symelem.sqrt(pi) *
    (s ^ @symcore.rational_from_ints(-1, 2)) *
    scaled_exp
  let sqrt_den_value = doit(inverse_laplace_transform(sqrt_den_kernel, s, x))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_den_value) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(sympy.pi)*sympy.exp(-2*sympy.sqrt(2*sympy.Symbol('s')))/sympy.sqrt(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let no_den_kernel = @symelem.sqrt(pi * @symcore.rational_from_ints(1, 2)) *
    scaled_exp
  let no_den_value = doit(inverse_laplace_transform(no_den_kernel, s, x))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(no_den_value) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(sympy.pi/2)*sympy.exp(-2*sympy.sqrt(2*sympy.Symbol('s'))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  let symbolic_kernel = @symelem.exp(@symcore.int(-1) * @symelem.sqrt(a * s)) *
    (s ^ @symcore.int(-1))
  let symbolic_value = doit(inverse_laplace_transform(symbolic_kernel, s, x))
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_value) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(-sympy.sqrt(sympy.Symbol('a', positive=True)*sympy.Symbol('s')))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace source reciprocal sqrt quadratic fast path" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let kernel = @symelem.sqrt(
      @symcore.int(8) + @symcore.int(2) * (s ^ @symcore.int(2)),
    ) ^
    @symcore.int(-1)
  let value = doit(inverse_laplace_transform(kernel, s, x))

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(value) +
      ") - sympy.inverse_laplace_transform(1/sympy.sqrt(2*sympy.Symbol('s')**2 + 8), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace explicit single Meijer G fallback" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")

  let explicit_g_bessel = doit(
    inverse_laplace_transform(
      @symspec.meijerg([@symcore.int(0)], [], [], [], s),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_bessel) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [], [], [], sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_exp = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [@symcore.int(0)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_exp) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [], [0], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_laguerre = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [@symcore.int(2)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_laguerre) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [], [2], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_b1_neg_half = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [@symcore.rational_from_ints(-1, 2)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_b1_neg_half) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [], [sympy.Rational(-1, 2)], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_b1_pos_half = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [@symcore.rational_from_ints(1, 2)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_b1_pos_half) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [], [sympy.Rational(1, 2)], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_b2_neg_half = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [],
        [@symcore.rational_from_ints(-1, 2)],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_b2_neg_half) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [], [], [sympy.Rational(-1, 2)], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_b2_pos_half = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [],
        [@symcore.rational_from_ints(1, 2)],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_b2_pos_half) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [], [], [sympy.Rational(1, 2)], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_a1_neg_half = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.rational_from_ints(-1, 2)],
        [],
        [],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_a1_neg_half) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([sympy.Rational(-1, 2)], [], [], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_a2_zero_b1_one = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [@symcore.int(0)],
        [@symcore.int(1)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_a2_zero_b1_one) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [0], [1], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_a2_pos_half_b1_zero = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [@symcore.rational_from_ints(1, 2)],
        [@symcore.int(0)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_a2_pos_half_b1_zero) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [sympy.Rational(1, 2)], [0], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let explicit_g_a2_neg_half_b1_zero = doit(
    inverse_laplace_transform(
      @symspec.meijerg(
        [@symcore.int(0)],
        [@symcore.rational_from_ints(-1, 2)],
        [@symcore.int(0)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(explicit_g_a2_neg_half_b1_zero) +
      ") - sympy.inverse_laplace_transform(sympy.meijerg([0], [sympy.Rational(-1, 2)], [0], [], 2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace symbolic Bessel branch kernels" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))
  let plus_root = @symelem.sqrt((s ^ @symcore.int(2)) + (a ^ @symcore.int(2)))
  let minus_root = @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2)))
  let besselj_branch = doit(
    inverse_laplace_transform(
      (a ^ b) *
      ((s + plus_root) ^ (@symcore.int(-1) * b)) *
      (plus_root ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let besseli_branch = doit(
    inverse_laplace_transform(
      (a ^ b) *
      ((s + minus_root) ^ (@symcore.int(-1) * b)) *
      (minus_root ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  @symassume.clear_global_assumptions()

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_branch) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)})).rewrite(sympy.exp) - (sympy.inverse_laplace_transform(sympy.Symbol('a', positive=True)**sympy.Symbol('b', positive=True)*(sympy.Symbol('s') + sympy.sqrt(sympy.Symbol('s')**2 + sympy.Symbol('a', positive=True)**2))**(-sympy.Symbol('b', positive=True))/sympy.sqrt(sympy.Symbol('s')**2 + sympy.Symbol('a', positive=True)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.exp)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besseli_branch) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)})).rewrite(sympy.exp) - (sympy.inverse_laplace_transform(sympy.Symbol('a', positive=True)**sympy.Symbol('b', positive=True)*(sympy.Symbol('s') + sympy.sqrt(sympy.Symbol('s')**2 - sympy.Symbol('a', positive=True)**2))**(-sympy.Symbol('b', positive=True))/sympy.sqrt(sympy.Symbol('s')**2 - sympy.Symbol('a', positive=True)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)).rewrite(sympy.exp)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace positive sqrt exponential frontdoor" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  let positive_kernel = @symelem.sqrt(pi * (a ^ @symcore.int(-1))) *
    @symelem.exp(@symcore.int(-2) * @symelem.sqrt(a) * @symelem.sqrt(s))
  let positive_value = doit(inverse_laplace_transform(positive_kernel, s, x))
  @symassume.clear_global_assumptions()
  let expected_value = @symelem.exp(
      @symcore.int(-1) * a * (x ^ @symcore.int(-1)),
    ) *
    @symspec.heaviside(x) *
    (x ^ @symcore.rational_from_ints(-3, 2))
  assert_eq(@symcore.compare_expr(positive_value, expected_value), 0)
}

///|
test "symintegrals parity inverse Laplace conditional sqrt exponential condition" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let b = @symcore.Expr::Symbol("b")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)

  let conditional_kernel = @symelem.sqrt(pi * (b ^ @symcore.int(-1))) *
    @symelem.exp(@symcore.int(-2) * @symelem.sqrt(b) * @symelem.sqrt(s))
  let conditional_value = @symintegrals.inverse_laplace_transform_eval(
    conditional_kernel,
    s,
    x,
    noconds=false,
  )
  match @symcore.tuple_items(conditional_value) {
    Some([value, cond]) => {
      let imag = @symcore.Expr::NumberSymbol(
        @symcore.NumberSymbolKind::ImaginaryUnit,
      )
      let phase = @symcore.int(-1) * @symelem.im(b) * (x ^ @symcore.int(-1))
      let expected_value = @symelem.exp(
          @symcore.int(-1) * @symelem.re(b) * (x ^ @symcore.int(-1)),
        ) *
        (@symelem.cos(phase) + imag * @symelem.sin(phase)) *
        @symspec.heaviside(x) *
        (x ^ @symcore.rational_from_ints(-3, 2))
      assert_eq(@symcore.compare_expr(value, expected_value), 0)
      let quarter_i_pi = imag *
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
        (@symcore.int(4) ^ @symcore.int(-1))
      let polar_b = @symcore.raw_function("polar_lift", [b])
      let polar_root = @symelem.sqrt(polar_b)
      let expected_cond = @symcore.raw_function("And", [
        @symcore.raw_function("Ne", [polar_root, @symcore.int(0)]),
        @symcore.raw_function("Gt", [
          @symelem.re(
            @symelem.exp(@symcore.int(-1) * quarter_i_pi) * polar_root,
          ),
          @symcore.int(0),
        ]),
        @symcore.raw_function("Gt", [
          @symelem.re(@symelem.exp(quarter_i_pi) * polar_root),
          @symcore.int(0),
        ]),
      ])
      assert_eq(@symcore.compare_expr(cond, expected_cond), 0)
    }
    _ => fail("expected value and condition tuple for sqrt exponential kernel")
  }
}

///|
test "symintegrals parity inverse Laplace Chi logarithmic fallback" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")

  let chi_kernel = @symcore.rational_from_ints(-1, 2) *
    @symelem.log((s ^ @symcore.int(2)) - @symcore.int(1)) *
    (s ^ @symcore.int(-1))
  let chi_value = doit(inverse_laplace_transform(chi_kernel, s, x))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr((sympy.simplify((" +
      py_expr(chi_value) +
      ") - sympy.Chi(sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))).rewrite(sympy.expint).expand())",
    ),
    "0",
  )

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  let scaled_chi_kernel = @symcore.rational_from_ints(-1, 2) *
    @symelem.log((s ^ @symcore.int(2)) - (a ^ @symcore.int(2))) *
    (s ^ @symcore.int(-1))
  let scaled_chi_value = doit(
    inverse_laplace_transform(scaled_chi_kernel, s, x),
  )
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr((sympy.simplify(((" +
      py_expr(scaled_chi_value) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)})) - (sympy.Chi(sympy.Symbol('a', positive=True)*sympy.Symbol('x')) - sympy.log(sympy.Symbol('a', positive=True)))*sympy.Heaviside(sympy.Symbol('x')))).rewrite(sympy.expint).expand())",
    ),
    "0",
  )
}
