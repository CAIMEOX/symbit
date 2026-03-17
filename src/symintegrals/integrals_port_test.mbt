///|
fn py_locals() -> String {
  "{'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'Tuple': sympy.Tuple, 'And': sympy.And, 'Or': sympy.Or, 'Not': sympy.Not, 'Min': sympy.Min, 'Max': sympy.Max, 'Lt': sympy.Lt, 'Le': sympy.Le, 'Gt': sympy.Gt, 'Ge': sympy.Ge, 'Derivative': sympy.Derivative, 'Subs': sympy.Subs, 'LaplaceTransform': sympy.LaplaceTransform}"
}

///|
fn py_expr(expr : Expr) -> String {
  match expr {
    @symcore.Expr::Function("Piecewise", args) => {
      let items : Array[String] = []
      let mut i = 0
      while i + 1 < args.length() {
        items.push("(" + py_expr(args[i]) + ", " + py_expr(args[i + 1]) + ")")
        i += 2
      }
      "sympy.Piecewise(" + items.join(", ") + ")"
    }
    @symcore.Expr::Function("And", args) =>
      "sympy.And(" + args.map(py_expr).join(", ") + ")"
    @symcore.Expr::Function("Le", [lhs, rhs]) =>
      "sympy.Le(" + py_expr(lhs) + ", " + py_expr(rhs) + ")"
    @symcore.Expr::Function("InverseLaplaceTransform", [inner, var_s, var_t]) =>
      "sympy.InverseLaplaceTransform(" +
      py_expr(inner) +
      ", " +
      py_expr(var_s) +
      ", " +
      py_expr(var_t) +
      ", 0)"
    @symcore.Expr::Symbol("True") => "True"
    _ =>
      "sympy.sympify('" +
      @symprint.to_string(expr) +
      "', locals=" +
      py_locals() +
      ")"
  }
}

///|
fn py_src_expr(text : String) -> String {
  "sympy.sympify('" + text + "', locals=" + py_locals() + ")"
}

///|
test "symintegrals parity core indefinite families" {
  let x = @symcore.symbol("x")
  let cases : Array[(String, Expr)] = [
    ("x", x),
    ("exp(2*x)", @symelem.exp(@symcore.int(2) * x)),
    ("sin(3*x)", @symelem.sin(@symcore.int(3) * x)),
    ("1/x", x ^ @symcore.int(-1)),
    (
      "1/(x**2 + 1)",
      ((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1),
    ),
    ("x*exp(x)", x * @symelem.exp(x)),
    ("log(x)", @symelem.log(x)),
    ("tan(2*x)", @symelem.tan(@symcore.int(2) * x)),
    ("sec(x)**2", @symelem.sec(x) ^ @symcore.int(2)),
    ("sin(x)**2", @symelem.sin(x) ^ @symcore.int(2)),
    ("cos(x)**2", @symelem.cos(x) ^ @symcore.int(2)),
    ("sin(x)*cos(x)", @symelem.sin(x) * @symelem.cos(x)),
    ("sinh(2*x)", @symelem.sinh(@symcore.int(2) * x)),
    ("cosh(3*x)", @symelem.cosh(@symcore.int(3) * x)),
    (
      "1/sqrt(1 - x**2)",
      @symelem.sqrt(@symcore.int(1) - (x ^ @symcore.int(2))) ^ @symcore.int(-1),
    ),
    (
      "1/sqrt(x**2 + 1)",
      @symelem.sqrt((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1),
    ),
  ]
  for item in cases {
    let ours = integrate(item.1, limits=[integral_limit([x])])
    let oracle = try! @sympy_integrals.integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.trigsimp(sympy.simplify((" +
      py_expr(ours) +
      ") - sympy.integrate(" +
      py_src_expr(item.0) +
      ", x)))))(sympy.Symbol('x'))",
    )
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity definite delta and singularity paths" {
  let x = @symcore.symbol("x")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let delta_expr = @symspec.dirac_delta(x - @symcore.int(2)) * x
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.simplify((" +
      py_expr(
        integrate(delta_expr, limits=[
          integral_limit([x, @symcore.int(0), @symcore.int(5)]),
        ]),
      ) +
      ") - sympy.integrate(sympy.DiracDelta(x - 2)*x, (x, 0, 5)))))(sympy.Symbol('x'))",
    ),
    content="0",
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x, a: sympy.sstr(sympy.simplify((" +
      py_expr(
        integrate(@symspec.singularity_function(x, a, @symcore.int(0)), limits=[
          integral_limit([x]),
        ]),
      ) +
      ") - sympy.integrate(sympy.SingularityFunction(x, a, 0), x))))(sympy.Symbol('x'), sympy.Symbol('a'))",
    ),
    content="0",
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x, a, b: sympy.sstr(sympy.simplify((" +
      py_expr(
        integrate(@symspec.dirac_delta(x - a) * x, limits=[
          integral_limit([x, @symcore.int(0), b]),
        ]),
      ) +
      ") - sympy.integrate(sympy.DiracDelta(x - a)*x, (x, 0, b)))))(sympy.Symbol('x'), sympy.Symbol('a'), sympy.Symbol('b'))",
    ),
    content="0",
  )
}

///|
test "symintegrals parity line_integrate and heurisch wrapper" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let t = @symcore.symbol("t")
  let c = try! @symgeometry.curve(
    [@symelem.exp(t) + @symcore.int(1), @symelem.exp(t) + @symcore.int(-1)],
    t,
    @symcore.int(0),
    @symelem.log(@symcore.int(2)),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x, y, t: sympy.sstr(sympy.simplify((" +
      py_expr(try! line_integrate(x + y, c, [x, y])) +
      ") - sympy.line_integrate(x + y, sympy.Curve([sympy.exp(t) + 1, sympy.exp(t) - 1], (t, 0, sympy.log(2))), [x, y]))))(sympy.Symbol('x'), sympy.Symbol('y'), sympy.Symbol('t'))",
    ),
    content="0",
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.simplify((" +
      py_expr(heurisch_wrapper(x * @symelem.exp(x), "x")) +
      ") - sympy.integrals.heurisch.heurisch_wrapper(x*sympy.exp(x), x))))(sympy.Symbol('x'))",
    ),
    content="0",
  )
}

///|
test "symintegrals parity transforms forward/inverse family" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
  let k = @symcore.symbol("k")

  let lp_cases : Array[(String, Expr)] = [
    ("1", @symcore.int(1)),
    ("x", x),
    ("exp(2*x)", @symelem.exp(@symcore.int(2) * x)),
    ("sin(x)", @symelem.sin(x)),
    ("cos(x)", @symelem.cos(x)),
    ("1/(x + 1)", (x + @symcore.int(1)) ^ @symcore.int(-1)),
  ]
  for item in lp_cases {
    let ours = doit(laplace_transform(item.1, x, s))
    let oracle = try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours) +
      ") - (sympy.laplace_transform(sympy.sympify('" +
      item.0 +
      "', locals={'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'And': sympy.And, 'Le': sympy.Le}), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))))",
    )
    inspect(oracle, content="0")
  }

  let ft = @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(2)))
  let ours_ft = doit(fourier_transform(ft, x, k))
  let oracle_ft = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(sympy.simplify((" +
    py_expr(ours_ft) +
    ") - (sympy.fourier_transform(sympy.exp(-sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('k')))))",
  )
  inspect(oracle_ft, content="0")

  let ours_ift = doit(inverse_fourier_transform(ours_ft, k, x))
  let oracle_ift = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(sympy.simplify((" +
    py_expr(ours_ift) +
    ") - (sympy.exp(-sympy.Symbol('x')**2))))",
  )
  inspect(oracle_ift, content="0")

  let inverse_lp_cases : Array[(String, Expr)] = [
    (
      "1/s",
      inverse_laplace_transform(@symcore.symbol("s") ^ @symcore.int(-1), s, x),
    ),
    (
      "s/(s**2 + 4)",
      inverse_laplace_transform(
        @symcore.symbol("s") *
        (
          ((@symcore.symbol("s") ^ @symcore.int(2)) + @symcore.int(4)) ^
          @symcore.int(-1)
        ),
        s,
        x,
      ),
    ),
  ]
  for item in inverse_lp_cases {
    let ours = doit(item.1)
    let oracle = try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours) +
      ") - (sympy.inverse_laplace_transform(sympy.sympify('" +
      item.0 +
      "', locals={'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'And': sympy.And, 'Le': sympy.Le}), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True))))",
    )
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity Mellin forward and inverse" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")

  let mt_cases : Array[(Expr, String)] = [
    (
      @symelem.exp(x),
      "sympy.mellin_transform(sympy.exp(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    ),
    (
      (x ^ @symcore.int(1)) * @symspec.heaviside(@symcore.int(1) - x),
      "sympy.mellin_transform(sympy.Symbol('x')*sympy.Heaviside(1-sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    ),
    (
      (x ^ @symcore.int(1)) * @symspec.heaviside(x - @symcore.int(1)),
      "sympy.mellin_transform(sympy.Symbol('x')*sympy.Heaviside(sympy.Symbol('x')-1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    ),
  ]
  for item in mt_cases {
    let ours = do_mellin_doit(item.0, x, s).unwrap()
    let oracle = try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" + py_expr(ours) + ") - (" + item.1 + ")))",
    )
    inspect(oracle, content="0")
  }

  let exp_inv = do_mellin_doit(
    @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(-1))),
    x,
    s,
  ).unwrap()
  let inv_exp_oracle = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(sympy.simplify((" +
    py_expr(exp_inv) +
    ") - (sympy.mellin_transform(sympy.exp(-sympy.Symbol('x') ** -1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))))",
  )
  inspect(inv_exp_oracle, content="0")

  let imt_cases : Array[(Expr, String)] = [
    (
      @symspec.gamma(s),
      "sympy.inverse_mellin_transform(sympy.gamma(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), (0, sympy.oo), noconds=True)",
    ),
    (
      @symspec.gamma(s * @symcore.int(-1)),
      "sympy.inverse_mellin_transform(sympy.gamma(-sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), (-sympy.oo, 0), noconds=True)",
    ),
    (
      s ^ @symcore.int(-1),
      "sympy.inverse_mellin_transform(1/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), (None, sympy.oo), noconds=True)",
    ),
    (
      @symcore.int(-1) * (s ^ @symcore.int(-1)),
      "sympy.inverse_mellin_transform(-1/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), (-sympy.oo, None), noconds=True)",
    ),
  ]
  for item in imt_cases {
    match do_inverse_mellin_doit(item.0, s, x) {
      Some(ours) => {
        let inv = try! @sympy_integrals.integrals_eval_str(
          "sympy.sstr(sympy.simplify((" +
          py_expr(ours) +
          ") - (" +
          item.1 +
          ")))",
        )
        inspect(inv, content="0")
      }
      None => inspect(@symprint.to_string(item.0), content="NONE")
    }
  }
}

///|
test "symintegrals parity transform conditions and auxiliary stage 5 families" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
  let k = @symcore.symbol("k")
  let r = @symcore.symbol("r")

  let ours_laplace = laplace_transform_eval(
    @symelem.exp(@symcore.int(2) * x),
    x,
    s,
  )
  let ours_laplace_txt = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(" + py_expr(ours_laplace) + ")",
  )
  let sympy_laplace_txt = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(sympy.laplace_transform(sympy.exp(2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
  )
  assert_eq(ours_laplace_txt, sympy_laplace_txt)

  let ours_mellin = mellin_transform_eval(
    x * @symspec.heaviside(@symcore.int(1) - x),
    x,
    s,
  )
  let ours_mellin_txt = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(" + py_expr(ours_mellin) + ")",
  )
  let sympy_mellin_txt = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(sympy.mellin_transform(sympy.Symbol('x')*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
  )
  assert_eq(ours_mellin_txt, sympy_mellin_txt)

  let ours_sine = sine_transform_eval(@symelem.exp(@symcore.int(-2) * x), x, k)
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_sine) +
      ") - sympy.sine_transform(sympy.exp(-2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let ours_cosine = cosine_transform_eval(
    @symelem.exp(@symcore.int(-2) * x),
    x,
    k,
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_cosine) +
      ") - sympy.cosine_transform(sympy.exp(-2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let ours_hankel = hankel_transform_eval(
    r * @symelem.exp(@symcore.int(-2) * r),
    r,
    k,
    @symcore.int(1),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_hankel) +
      ") - sympy.hankel_transform(sympy.Symbol('r')*sympy.exp(-2*sympy.Symbol('r')), sympy.Symbol('r'), sympy.Symbol('k'), 1)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity Laplace shift, delta, derivative, and inverse-delay rules" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
  let f_of_x = @symcore.raw_function("f", [x])

  let delta_eval = laplace_transform_eval(
    @symspec.dirac_delta(x - @symcore.int(2)),
    x,
    s,
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(" + py_expr(delta_eval) + ")",
    ),
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.DiracDelta(sympy.Symbol('x') - 2), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )

  let heaviside_eval = laplace_transform_eval(
    @symspec.heaviside(x - @symcore.int(2)),
    x,
    s,
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(" + py_expr(heaviside_eval) + ")",
    ),
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(sympy.Symbol('x') - 2), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )

  let shifted_poly_eval = laplace_transform_eval(
    (x - @symcore.int(2)) * @symspec.heaviside(x - @symcore.int(2)),
    x,
    s,
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(" + py_expr(shifted_poly_eval) + ")",
    ),
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform((sympy.Symbol('x') - 2)*sympy.Heaviside(sympy.Symbol('x') - 2), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )

  let deriv1_eval = laplace_transform_eval(
    @symcore.raw_function("Derivative", [f_of_x, x]),
    x,
    s,
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(" + py_expr(deriv1_eval) + ")",
    ),
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.laplace_transform(sympy.Derivative(sympy.Function('f')(x), x), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
  )

  let deriv2_eval = laplace_transform_eval(
    @symcore.raw_function("Derivative", [f_of_x, x, @symcore.int(2)]),
    x,
    s,
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(" + py_expr(deriv2_eval) + ")",
    ),
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.laplace_transform(sympy.Derivative(sympy.Function('f')(x), (x, 2)), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
  )

  let delayed_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-2) * s) *
      ((s + @symcore.int(1)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.exp(-2*sympy.Symbol('s'))/(sympy.Symbol('s') + 1)**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let linear_power_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-3),
      s,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(linear_power_inverse) +
      ") - sympy.inverse_laplace_transform((2*sympy.Symbol('s') + 4)**-3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity intpoly square moments" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let square = unit_square_polygon()
  let ours_xy = try! polytope_integrate(square, x * y, vars=[x, y])
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_xy) +
      ") - (__import__('sympy.integrals.intpoly', fromlist=['polytope_integrate']).polytope_integrate(sympy.Polygon(sympy.Point(0, 0), sympy.Point(0, 1), sympy.Point(1, 1), sympy.Point(1, 0)), sympy.Symbol('x')*sympy.Symbol('y')))))",
    ),
    "0",
  )
  let ours_x2y = try! polytope_integrate(square, (x ^ @symcore.int(2)) * y, vars=[
    x, y,
  ])
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_x2y) +
      ") - (__import__('sympy.integrals.intpoly', fromlist=['polytope_integrate']).polytope_integrate(sympy.Polygon(sympy.Point(0, 0), sympy.Point(0, 1), sympy.Point(1, 1), sympy.Point(1, 0)), sympy.Symbol('x')**2*sympy.Symbol('y')))))",
    ),
    "0",
  )
}
