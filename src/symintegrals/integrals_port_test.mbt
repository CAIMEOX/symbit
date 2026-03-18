///|
fn py_locals() -> String {
  "{'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'Ei': sympy.Ei, 'expint': sympy.expint, 'E1': sympy.E1, 'Si': sympy.Si, 'Ci': sympy.Ci, 'Shi': sympy.Shi, 'Chi': sympy.Chi, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'Tuple': sympy.Tuple, 'And': sympy.And, 'Or': sympy.Or, 'Not': sympy.Not, 'Min': sympy.Min, 'Max': sympy.Max, 'Lt': sympy.Lt, 'Le': sympy.Le, 'Gt': sympy.Gt, 'Ge': sympy.Ge, 'Derivative': sympy.Derivative, 'Subs': sympy.Subs, 'LaplaceTransform': sympy.LaplaceTransform}"
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
    ("x*sin(x)", x * @symelem.sin(x)),
    ("x*cos(x)", x * @symelem.cos(x)),
    ("sinh(x)", @symelem.sinh(x)),
    ("cosh(x)", @symelem.cosh(x)),
    ("x*sinh(x)", x * @symelem.sinh(x)),
    ("x*cosh(x)", x * @symelem.cosh(x)),
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
  let a = @symcore.symbol("a")
  let third = try! @symcore.rational_from_ints(1, 3)
  let two_thirds = try! @symcore.rational_from_ints(2, 3)
  let three_halves = try! @symcore.rational_from_ints(3, 2)
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

  let shifted_ft = doit(
    fourier_transform(
      @symelem.exp(@symcore.int(-1) * ((x - @symcore.int(1)) ^ @symcore.int(2))),
      x,
      k,
    ),
  )
  let shifted_ft_oracle = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(sympy.simplify(sympy.expand(((" +
    py_expr(shifted_ft) +
    ") - (sympy.fourier_transform(sympy.exp(-(sympy.Symbol('x') - 1)**2), sympy.Symbol('x'), sympy.Symbol('k')))).rewrite(sympy.exp))))",
  )
  inspect(shifted_ft_oracle, content="0")

  let shifted_ift = doit(inverse_fourier_transform(shifted_ft, k, x))
  let shifted_ift_oracle = try! @sympy_integrals.integrals_eval_str(
    "sympy.sstr(sympy.simplify(sympy.expand(((" +
    py_expr(shifted_ift) +
    ") - (sympy.exp(-(sympy.Symbol('x') - 1)**2))).rewrite(sympy.exp))))",
  )
  inspect(shifted_ift_oracle, content="0")

  let half_line_ft = doit(
    fourier_transform(
      @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x),
      x,
      k,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_ft) +
      ") - sympy.fourier_transform(sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let half_line_ift = doit(inverse_fourier_transform(half_line_ft, k, x))
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_ift) +
      ") - (sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))))",
    ),
    content="0",
  )

  let half_line_x_ft = doit(
    fourier_transform(
      x * @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x),
      x,
      k,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_x_ft) +
      ") - sympy.fourier_transform(sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let half_line_x_ift = doit(inverse_fourier_transform(half_line_x_ft, k, x))
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_x_ift) +
      ") - (sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))))",
    ),
    content="0",
  )

  let half_line_sin_ft = doit(
    fourier_transform(
      @symelem.exp(@symcore.int(-2) * x) *
      @symelem.sin(@symcore.int(3) * x) *
      @symspec.heaviside(x),
      x,
      k,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_sin_ft) +
      ") - sympy.fourier_transform(sympy.exp(-2*sympy.Symbol('x'))*sympy.sin(3*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let half_line_sin_ift = doit(
    inverse_fourier_transform(half_line_sin_ft, k, x),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_sin_ift) +
      ") - (sympy.exp(-2*sympy.Symbol('x'))*sympy.sin(3*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))))",
    ),
    content="0",
  )

  let abs_decay_ft = doit(
    fourier_transform(@symelem.exp(@symcore.int(-2) * @symelem.abs(x)), x, k),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(abs_decay_ft) +
      ") - sympy.fourier_transform(sympy.exp(-2*sympy.Abs(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let abs_decay_ift = doit(inverse_fourier_transform(abs_decay_ft, k, x))
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(abs_decay_ift) +
      ") - sympy.exp(-2*sympy.Abs(sympy.Symbol('x')))))",
    ),
    content="0",
  )

  let box_window_ft = doit(
    fourier_transform(
      @symspec.heaviside(@symcore.int(1) - @symelem.abs(@symcore.int(2) * x)),
      x,
      k,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(box_window_ft) +
      ") - sympy.fourier_transform(sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let box_window_ift = doit(inverse_fourier_transform(box_window_ft, k, x))
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(box_window_ift) +
      ") - sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x')))))",
    ),
    content="0",
  )

  let triangle_window_ft = doit(
    fourier_transform(
      @symspec.heaviside(@symcore.int(1) - @symelem.abs(@symcore.int(2) * x)) *
      (@symcore.int(1) - @symelem.abs(@symcore.int(2) * x)),
      x,
      k,
    ),
  )
  let triangle_samples = ["sympy.Integer(1)", "sympy.Integer(2)"]
  for sample in triangle_samples {
    inspect(
      try! @sympy_integrals.integrals_eval_str(
        "sympy.sstr(sympy.simplify(((" +
        py_expr(triangle_window_ft) +
        ").subs(sympy.Symbol('k'), " +
        sample +
        ")) - (sympy.fourier_transform(sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x')))*(1 - sympy.Abs(2*sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k')).subs(sympy.Symbol('k'), " +
        sample +
        "))))",
      ),
      content="0",
    )
  }
  let triangle_window_ift = doit(
    inverse_fourier_transform(triangle_window_ft, k, x),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(triangle_window_ift) +
      ") - (sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x')))*(1 - sympy.Abs(2*sympy.Symbol('x'))))))",
    ),
    content="0",
  )
  let direct_sinc_box_ift = doit(
    inverse_fourier_transform(
      two_thirds * @symelem.sinc(k * (three_halves ^ @symcore.int(-1))),
      k,
      x,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(direct_sinc_box_ift) +
      ") - sympy.Heaviside(1 - sympy.Abs(3*sympy.Symbol('x')))))",
    ),
    content="0",
  )
  let direct_sinc_triangle_ift = doit(
    inverse_fourier_transform(
      third * (@symelem.sinc(k * third) ^ @symcore.int(2)),
      k,
      x,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(direct_sinc_triangle_ift) +
      ") - (sympy.Heaviside(1 - sympy.Abs(3*sympy.Symbol('x')))*(1 - sympy.Abs(3*sympy.Symbol('x'))))))",
    ),
    content="0",
  )
  let direct_symbolic_sinc_box_ift = doit(
    inverse_fourier_transform(
      (a ^ @symcore.int(-1)) * @symelem.sinc(k * (a ^ @symcore.int(-1))),
      k,
      x,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(direct_symbolic_sinc_box_ift) +
      ") - sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('a')*sympy.Symbol('x')))))",
    ),
    content="0",
  )
  let direct_symbolic_sinc_triangle_ift = doit(
    inverse_fourier_transform(
      (a ^ @symcore.int(-1)) *
      (@symelem.sinc(k * (a ^ @symcore.int(-1))) ^ @symcore.int(2)),
      k,
      x,
    ),
  )
  inspect(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(direct_symbolic_sinc_triangle_ift) +
      ") - (sympy.Heaviside(1 - sympy.Abs(sympy.Symbol('a')*sympy.Symbol('x')))*(1 - sympy.Abs(sympy.Symbol('a')*sympy.Symbol('x'))))))",
    ),
    content="0",
  )

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
    (
      "1/(s**2 - 1)",
      inverse_laplace_transform(
        ((@symcore.symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
        @symcore.int(-1),
        s,
        x,
      ),
    ),
    (
      "s/(s**2 - 1)",
      inverse_laplace_transform(
        @symcore.symbol("s") *
        (
          ((@symcore.symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
          @symcore.int(-1)
        ),
        s,
        x,
      ),
    ),
    (
      "1/((s + 1)*(s + 2))",
      inverse_laplace_transform(
        (
          (@symcore.symbol("s") + @symcore.int(1)) *
          (@symcore.symbol("s") + @symcore.int(2))
        ) ^
        @symcore.int(-1),
        s,
        x,
      ),
    ),
    (
      "s/((s + 1)*(s + 2))",
      inverse_laplace_transform(
        @symcore.symbol("s") *
        (
          (
            (@symcore.symbol("s") + @symcore.int(1)) *
            (@symcore.symbol("s") + @symcore.int(2))
          ) ^
          @symcore.int(-1)
        ),
        s,
        x,
      ),
    ),
    (
      "1/(s**2 + 1)**2",
      inverse_laplace_transform(
        ((@symcore.symbol("s") ^ @symcore.int(2)) + @symcore.int(1)) ^
        @symcore.int(-2),
        s,
        x,
      ),
    ),
    (
      "s/(s**2 + 1)**2",
      inverse_laplace_transform(
        @symcore.symbol("s") *
        (
          ((@symcore.symbol("s") ^ @symcore.int(2)) + @symcore.int(1)) ^
          @symcore.int(-2)
        ),
        s,
        x,
      ),
    ),
    (
      "1/(s**2 - 1)**2",
      inverse_laplace_transform(
        ((@symcore.symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
        @symcore.int(-2),
        s,
        x,
      ),
    ),
    (
      "s/(s**2 - 1)**2",
      inverse_laplace_transform(
        @symcore.symbol("s") *
        (
          ((@symcore.symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
          @symcore.int(-2)
        ),
        s,
        x,
      ),
    ),
    (
      "1/((s + 1)**2 - 4)",
      inverse_laplace_transform(
        (
          ((@symcore.symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
          @symcore.int(4)
        ) ^
        @symcore.int(-1),
        s,
        x,
      ),
    ),
    (
      "(s + 1)/((s + 1)**2 - 4)",
      inverse_laplace_transform(
        (@symcore.symbol("s") + @symcore.int(1)) *
        (
          (
            ((@symcore.symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
            @symcore.int(4)
          ) ^
          @symcore.int(-1)
        ),
        s,
        x,
      ),
    ),
    (
      "1/((s + 1)**2 - 4)**2",
      inverse_laplace_transform(
        (
          ((@symcore.symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
          @symcore.int(4)
        ) ^
        @symcore.int(-2),
        s,
        x,
      ),
    ),
    (
      "s/((s + 1)**2 - 4)**2",
      inverse_laplace_transform(
        @symcore.symbol("s") *
        (
          (
            ((@symcore.symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
            @symcore.int(4)
          ) ^
          @symcore.int(-2)
        ),
        s,
        x,
      ),
    ),
    (
      "1/((s + 1)**2 + 4)**2",
      inverse_laplace_transform(
        (
          ((@symcore.symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) +
          @symcore.int(4)
        ) ^
        @symcore.int(-2),
        s,
        x,
      ),
    ),
    (
      "s/((s + 1)**2 + 4)**2",
      inverse_laplace_transform(
        @symcore.symbol("s") *
        (
          (
            ((@symcore.symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) +
            @symcore.int(4)
          ) ^
          @symcore.int(-2)
        ),
        s,
        x,
      ),
    ),
  ]
  for item in inverse_lp_cases {
    let ours = doit(item.1)
    let oracle = try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify(sympy.trigsimp(sympy.expand(((" +
      py_expr(ours) +
      ") - (sympy.inverse_laplace_transform(sympy.sympify('" +
      item.0 +
      "', locals={'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'And': sympy.And, 'Le': sympy.Le}), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True))).rewrite(sympy.exp)))))",
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
  let a = @symcore.symbol("a")
  let m = @symcore.symbol("m")
  let nu = @symcore.symbol("nu")
  let half = try! @symcore.rational_from_ints(1, 2)

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
  let sine_half_power = doit(
    sine_transform(@symelem.sqrt(x) ^ @symcore.int(-1), x, k),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sine_half_power) +
      ") - sympy.sine_transform(1/sympy.sqrt(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_sine_half_power = doit(
    inverse_sine_transform(@symelem.sqrt(k) ^ @symcore.int(-1), k, x),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inverse_sine_half_power) +
      ") - 1/sympy.sqrt(sympy.Symbol('x'))))",
    ),
    "0",
  )
  let sine_three_halves = doit(
    sine_transform(@symelem.sqrt(x) ^ @symcore.int(-1) ^ @symcore.int(3), x, k),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sine_three_halves) +
      ") - sympy.sine_transform((1/sympy.sqrt(sympy.Symbol('x')))**3, sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let sine_log_over_x = doit(
    sine_transform(@symelem.log(x) * (x ^ @symcore.int(-1)), x, k),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sine_log_over_x) +
      ") - sympy.sine_transform(sympy.log(sympy.Symbol('x'))/sympy.Symbol('x'), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let sine_gaussian = doit(
    sine_transform(
      x * @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2))),
      x,
      k,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sine_gaussian) +
      ") - sympy.sine_transform(sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_sine_gaussian = doit(inverse_sine_transform(sine_gaussian, k, x))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inverse_sine_gaussian) +
      ") - sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x')**2)))",
    ),
    "0",
  )
  let sine_power = doit(sine_transform(x ^ (@symcore.int(-1) * a), x, k))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sine_power) +
      ") - sympy.sine_transform(sympy.Symbol('x')**(-sympy.Symbol('a')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_sine_power = doit(inverse_sine_transform(sine_power, k, x))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inverse_sine_power) +
      ") - sympy.Symbol('x')**(-sympy.Symbol('a'))))",
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
  let inv_cosine_linear = doit(inverse_cosine_transform(ours_cosine, k, x))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_cosine_linear) +
      ") - sympy.exp(-2*sympy.Symbol('x'))))",
    ),
    "0",
  )
  let cosine_half_power = doit(
    cosine_transform(@symelem.sqrt(x) ^ @symcore.int(-1), x, k),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_half_power) +
      ") - sympy.cosine_transform(1/sympy.sqrt(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inv_cosine_half_power = doit(
    inverse_cosine_transform(@symelem.sqrt(k) ^ @symcore.int(-1), k, x),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_cosine_half_power) +
      ") - 1/sympy.sqrt(sympy.Symbol('x'))))",
    ),
    "0",
  )
  let cosine_power = doit(cosine_transform(x ^ (@symcore.int(-1) * a), x, k))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_power) +
      ") - sympy.cosine_transform(sympy.Symbol('x')**(-sympy.Symbol('a')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_cosine_power = doit(inverse_cosine_transform(cosine_power, k, x))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inverse_cosine_power) +
      ") - sympy.Symbol('x')**(-sympy.Symbol('a'))))",
    ),
    "0",
  )
  let cosine_recip_quadratic = doit(
    cosine_transform(
      ((x ^ @symcore.int(2)) + @symcore.int(4)) ^ @symcore.int(-1),
      x,
      k,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_recip_quadratic) +
      ") - sympy.cosine_transform(1/(sympy.Symbol('x')**2 + 4), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inv_cosine_recip_quadratic = doit(
    inverse_cosine_transform(cosine_recip_quadratic, k, x),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_cosine_recip_quadratic) +
      ") - 1/(sympy.Symbol('x')**2 + 4)))",
    ),
    "0",
  )
  let cosine_shifted_recip = doit(
    cosine_transform((x + @symcore.int(2)) ^ @symcore.int(-1), x, k),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_shifted_recip) +
      ") - sympy.cosine_transform(1/(sympy.Symbol('x') + 2), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_cosine_shifted_recip = doit(
    inverse_cosine_transform(
      @symelem.sqrt(@symcore.int(2)) *
      @symspec.meijerg(
        [half, @symcore.int(0)],
        [],
        [half, @symcore.int(0), @symcore.int(0)],
        [half],
        k ^ @symcore.int(2),
      ) *
      ((@symcore.int(2) * @symcore.symbol("pi")) ^ @symcore.int(-1)),
      k,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inverse_cosine_shifted_recip) +
      ") - 1/(sympy.Symbol('x') + 2)))",
    ),
    "0",
  )
  let cosine_sqrt_recip = doit(
    cosine_transform(
      @symelem.sqrt((x ^ @symcore.int(2)) + @symcore.int(4)) ^ @symcore.int(-1),
      x,
      k,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_sqrt_recip) +
      ") - sympy.cosine_transform(1/sympy.sqrt(sympy.Symbol('x')**2 + 4), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_cosine_sqrt_recip = doit(
    inverse_cosine_transform(
      @symelem.sqrt(@symcore.int(2)) *
      @symspec.meijerg(
        [half],
        [],
        [@symcore.int(0), @symcore.int(0)],
        [half],
        k ^ @symcore.int(2),
      ) *
      (
        (@symcore.int(2) * @symelem.sqrt(@symcore.symbol("pi"))) ^
        @symcore.int(-1)
      ),
      k,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inverse_cosine_sqrt_recip) +
      ") - 1/(sympy.Symbol('x')*sympy.sqrt(4/sympy.Symbol('x')**2 + 1))))",
    ),
    "0",
  )
  let cosine_sqrt_decay = doit(
    cosine_transform(
      @symelem.exp(@symcore.int(-2) * @symelem.sqrt(x)) *
      @symelem.cos(@symcore.int(2) * @symelem.sqrt(x)),
      x,
      k,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_sqrt_decay) +
      ") - sympy.cosine_transform(sympy.exp(-2*sympy.sqrt(sympy.Symbol('x')))*sympy.cos(2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))))",
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
  let inv_hankel_linear = doit(
    inverse_hankel_transform(ours_hankel, k, r, @symcore.int(1)),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_hankel_linear) +
      ") - sympy.Symbol('r')*sympy.exp(-2*sympy.Symbol('r'))))",
    ),
    "0",
  )
  let hankel_recip = doit(
    hankel_transform(r ^ @symcore.int(-1), r, k, @symcore.int(0)),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(hankel_recip) +
      ") - sympy.hankel_transform(1/sympy.Symbol('r'), sympy.Symbol('r'), sympy.Symbol('k'), 0)))",
    ),
    "0",
  )
  let inv_hankel_recip = doit(
    inverse_hankel_transform(k ^ @symcore.int(-1), k, r, @symcore.int(0)),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_hankel_recip) +
      ") - 1/sympy.Symbol('r'))) ",
    ),
    "0",
  )
  let hankel_power_zero = doit(
    hankel_transform(r ^ (@symcore.int(-1) * m), r, k, @symcore.int(0)),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(hankel_power_zero) +
      ") - sympy.hankel_transform(sympy.Symbol('r')**(-sympy.Symbol('m')), sympy.Symbol('r'), sympy.Symbol('k'), 0)))",
    ),
    "0",
  )
  let inv_hankel_power_zero = doit(
    inverse_hankel_transform(hankel_power_zero, k, r, @symcore.int(0)),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_hankel_power_zero) +
      ") - sympy.Symbol('r')**(-sympy.Symbol('m'))))",
    ),
    "0",
  )
  let hankel_power_generic = doit(
    hankel_transform(r ^ (@symcore.int(-1) * m), r, k, nu),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(hankel_power_generic) +
      ") - sympy.hankel_transform(sympy.Symbol('r')**(-sympy.Symbol('m')), sympy.Symbol('r'), sympy.Symbol('k'), sympy.Symbol('nu'))))",
    ),
    "0",
  )
  let inv_hankel_power_generic = doit(
    inverse_hankel_transform(hankel_power_generic, k, r, nu),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_hankel_power_generic) +
      ") - sympy.Symbol('r')**(-sympy.Symbol('m'))))",
    ),
    "0",
  )
  let hankel_exp_generic = doit(
    hankel_transform(
      (r ^ nu) * @symelem.exp(@symcore.int(-1) * a * r),
      r,
      k,
      nu,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(hankel_exp_generic) +
      ") - sympy.hankel_transform(sympy.Symbol('r')**sympy.Symbol('nu')*sympy.exp(-sympy.Symbol('a')*sympy.Symbol('r')), sympy.Symbol('r'), sympy.Symbol('k'), sympy.Symbol('nu'))))",
    ),
    "0",
  )
  let inv_hankel_exp_generic = doit(
    inverse_hankel_transform(hankel_exp_generic, k, r, nu),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_hankel_exp_generic) +
      ") - (sympy.Symbol('r')**sympy.Symbol('nu')*sympy.exp(-sympy.Symbol('a')*sympy.Symbol('r')))))",
    ),
    "0",
  )

  let cosine_gaussian = doit(
    cosine_transform(
      @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2))),
      x,
      k,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_gaussian) +
      ") - sympy.cosine_transform(sympy.exp(-2*sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inv_cosine_gaussian = doit(
    inverse_cosine_transform(cosine_gaussian, k, x),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_cosine_gaussian) +
      ") - sympy.exp(-2*sympy.Symbol('x')**2)))",
    ),
    "0",
  )

  let hankel_gaussian = doit(
    hankel_transform(
      @symelem.exp(@symcore.int(-2) * (r ^ @symcore.int(2))),
      r,
      k,
      @symcore.int(0),
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(hankel_gaussian) +
      ") - sympy.hankel_transform(sympy.exp(-2*sympy.Symbol('r')**2), sympy.Symbol('r'), sympy.Symbol('k'), 0)))",
    ),
    "0",
  )
  let inv_hankel_gaussian = doit(
    inverse_hankel_transform(hankel_gaussian, k, r, @symcore.int(0)),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_hankel_gaussian) +
      ") - sympy.exp(-2*sympy.Symbol('r')**2)))",
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
  let neg_half = try! @symcore.rational_from_ints(-1, 2)
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(" + py_expr(deriv2_eval) + ")",
    ),
    try! @sympy_integrals.integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.laplace_transform(sympy.Derivative(sympy.Function('f')(x), (x, 2)), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
  )

  let ci_laplace = doit(laplace_transform(@symspec.ci(x), x, s))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ci_laplace) +
      ") - sympy.laplace_transform(sympy.Ci(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )

  let e1_laplace = doit(laplace_transform(@symspec.e1(x), x, s))
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(e1_laplace) +
      ") - sympy.laplace_transform(sympy.E1(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )

  let expint2_laplace = doit(
    laplace_transform(@symspec.expint(@symcore.int(2), x), x, s),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(expint2_laplace) +
      ") - sympy.laplace_transform(sympy.expint(2, sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )

  let ci_inverse = doit(
    inverse_laplace_transform(
      neg_half *
      @symelem.log(@symcore.int(1) + (s ^ @symcore.int(2))) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ci_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.Ci(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let e1_inverse = doit(
    inverse_laplace_transform(
      @symelem.log(s + @symcore.int(1)) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(e1_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.E1(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let expint2_inverse = doit(
    inverse_laplace_transform(
      (s - @symelem.log(s + @symcore.int(1))) * (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(expint2_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.expint(2, sympy.Symbol('x')))))",
    ),
    "0",
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

  let shifted_quad_inverse = doit(
    inverse_laplace_transform(
      (((s + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(4)) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(shifted_quad_inverse) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') + 1)**2 + 4), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let shifted_quad_num_inverse = doit(
    inverse_laplace_transform(
      (s + @symcore.int(1)) *
      (
        (((s + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(4)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    try! @sympy_integrals.integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(shifted_quad_num_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s') + 1)/((sympy.Symbol('s') + 1)**2 + 4), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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
