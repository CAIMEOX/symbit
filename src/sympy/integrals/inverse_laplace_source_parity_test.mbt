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
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(bateman_537_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('b', positive=True)*sympy.Symbol('s')) + sympy.Symbol('a', positive=True))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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
