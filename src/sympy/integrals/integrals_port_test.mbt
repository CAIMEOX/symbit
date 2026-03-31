///|
fn py_locals() -> String {
  "{'sqrt': sympy.sqrt, 'exp': sympy.exp, 'exp_polar': sympy.exp_polar, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'acoth': sympy.acoth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'arg': sympy.arg, 're': sympy.re, 'Ei': sympy.Ei, 'expint': sympy.expint, 'E1': sympy.E1, 'Si': sympy.Si, 'Ci': sympy.Ci, 'Shi': sympy.Shi, 'Chi': sympy.Chi, 'erf': sympy.erf, 'erfc': sympy.erfc, 'fresnels': sympy.fresnels, 'fresnelc': sympy.fresnelc, 'besselj': sympy.besselj, 'bessely': sympy.bessely, 'besselk': sympy.besselk, 'besseli': sympy.besseli, 'gamma': sympy.gamma, 'lowergamma': sympy.lowergamma, 'uppergamma': sympy.uppergamma, 'Abs': sympy.Abs, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'Tuple': sympy.Tuple, 'And': sympy.And, 'Or': sympy.Or, 'Not': sympy.Not, 'Eq': sympy.Eq, 'Min': sympy.Min, 'Max': sympy.Max, 'Lt': sympy.Lt, 'Le': sympy.Le, 'Gt': sympy.Gt, 'Ge': sympy.Ge, 'Derivative': sympy.Derivative, 'Subs': sympy.Subs, 'LaplaceTransform': sympy.LaplaceTransform, 'Matrix': sympy.Matrix}"
}

///|
fn python_string_literal(value : String) -> String {
  "'" +
  value
  .replace(old="\\", new="\\\\")
  .replace(old="'", new="\\'")
  .replace(old="\n", new="\\n") +
  "'"
}

///|
fn py_function_call(name : String, args : Array[Expr]) -> String {
  let rendered = args.map(py_expr).join(", ")
  let known = [
    "sqrt", "exp", "exp_polar", "sin", "cos", "tan", "cot", "sec", "csc", "sinh",
    "cosh", "tanh", "coth", "acoth", "log", "atan", "atanh", "asin", "asinh", "arg",
    "re", "Ei", "expint", "E1", "Si", "Ci", "Shi", "Chi", "erf", "erfc", "fresnels",
    "fresnelc", "besselj", "bessely", "besselk", "besseli", "gamma", "lowergamma",
    "uppergamma", "Abs", "DiracDelta", "Heaviside", "SingularityFunction", "Piecewise",
    "Tuple", "And", "Or", "Not", "Eq", "Ne", "Min", "Max", "Lt", "Le", "Gt", "Ge",
    "Derivative", "Subs", "LaplaceTransform", "InverseLaplaceTransform", "MellinTransform",
    "InverseMellinTransform", "FourierTransform", "InverseFourierTransform", "SineTransform",
    "InverseSineTransform", "CosineTransform", "InverseCosineTransform", "HankelTransform",
    "InverseHankelTransform", "Integral", "Matrix", "meijerg", "gamma", "lerchphi",
  ]
  if known.contains(name) {
    "sympy." + name + "(" + rendered + ")"
  } else {
    "sympy.Function(" + python_string_literal(name) + ")(" + rendered + ")"
  }
}

///|
fn py_expr(expr : Expr) -> String {
  match expr {
    @symcore.Expr::Add(args) =>
      "sympy.Add(" + args.map(py_expr).join(", ") + ")"
    @symcore.Expr::Mul(args) =>
      "sympy.Mul(" + args.map(py_expr).join(", ") + ")"
    @symcore.Expr::Pow(base, exp) =>
      "sympy.Pow(" + py_expr(base) + ", " + py_expr(exp) + ")"
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
    @symcore.Expr::Function("InverseLaplaceTransform", [inner, var_s, var_t]) =>
      "sympy.InverseLaplaceTransform(" +
      py_expr(inner) +
      ", " +
      py_expr(var_s) +
      ", " +
      py_expr(var_t) +
      ", 0)"
    @symcore.Expr::Function(
      "InverseLaplaceTransform",
      [inner, var_s, var_t, @symcore.Expr::Symbol("_None")]
    ) =>
      "sympy.InverseLaplaceTransform(" +
      py_expr(inner) +
      ", " +
      py_expr(var_s) +
      ", " +
      py_expr(var_t) +
      ", None)"
    @symcore.Expr::Function("DiracDelta", [arg]) =>
      "sympy.DiracDelta(" + py_expr(arg) + ")"
    @symcore.Expr::Function("DiracDelta", [arg, order]) =>
      "sympy.DiracDelta(" + py_expr(arg) + ", " + py_expr(order) + ")"
    @symcore.Expr::UndefinedFunction(name) =>
      "sympy.Function(" + python_string_literal(name) + ")"
    @symcore.Expr::Apply(head, [inner, var_s, var_t]) =>
      match @symcore.function_head_name(head) {
        Some("InverseLaplaceTransform") =>
          "sympy.InverseLaplaceTransform(" +
          py_expr(inner) +
          ", " +
          py_expr(var_s) +
          ", " +
          py_expr(var_t) +
          ", 0)"
        Some(name) => py_function_call(name, [inner, var_s, var_t])
        None =>
          py_expr(head) +
          "(" +
          [inner, var_s, var_t].map(py_expr).join(", ") +
          ")"
      }
    @symcore.Expr::Apply(
      head,
      [inner, var_s, var_t, @symcore.Expr::Symbol("_None")]
    ) =>
      match @symcore.function_head_name(head) {
        Some("InverseLaplaceTransform") =>
          "sympy.InverseLaplaceTransform(" +
          py_expr(inner) +
          ", " +
          py_expr(var_s) +
          ", " +
          py_expr(var_t) +
          ", None)"
        Some(name) =>
          py_function_call(name, [
            inner,
            var_s,
            var_t,
            @symcore.Expr::Symbol("_None"),
          ])
        None =>
          py_expr(head) +
          "(" +
          [inner, var_s, var_t, @symcore.Expr::Symbol("_None")]
          .map(py_expr)
          .join(", ") +
          ")"
      }
    @symcore.Expr::Apply(head, args) =>
      match @symcore.function_head_name(head) {
        Some(name) => py_function_call(name, args)
        None => py_expr(head) + "(" + args.map(py_expr).join(", ") + ")"
      }
    @symcore.Expr::Function(name, args) => py_function_call(name, args)
    _ =>
      match @symcore.tuple_items(expr) {
        Some(args) => "sympy.Tuple(" + args.map(py_expr).join(", ") + ")"
        None =>
          match @symcore.relational_parts(expr) {
            Some((@symcore.RelOp::Eq, lhs, rhs)) =>
              "sympy.Eq(" + py_expr(lhs) + ", " + py_expr(rhs) + ")"
            Some((@symcore.RelOp::Ne, lhs, rhs)) =>
              "sympy.Ne(" + py_expr(lhs) + ", " + py_expr(rhs) + ")"
            Some((@symcore.RelOp::Lt, lhs, rhs)) =>
              "sympy.Lt(" + py_expr(lhs) + ", " + py_expr(rhs) + ")"
            Some((@symcore.RelOp::Le, lhs, rhs)) =>
              "sympy.Le(" + py_expr(lhs) + ", " + py_expr(rhs) + ")"
            Some((@symcore.RelOp::Gt, lhs, rhs)) =>
              "sympy.Gt(" + py_expr(lhs) + ", " + py_expr(rhs) + ")"
            Some((@symcore.RelOp::Ge, lhs, rhs)) =>
              "sympy.Ge(" + py_expr(lhs) + ", " + py_expr(rhs) + ")"
            None =>
              match @symcore.derivative_parts(expr) {
                Some((inner, deriv_args)) => {
                  let pieces : Array[String] = [py_expr(inner)]
                  let pair_count = deriv_args.length() / 2
                  for i in 0..<pair_count {
                    let wrt = deriv_args[i * 2]
                    let order_idx = i * 2 + 1
                    if order_idx < deriv_args.length() {
                      match deriv_args[order_idx] {
                        @symcore.Expr::Number(n) if n.is_integral() => {
                          let order_int = n.numerator().to_int()
                          if order_int == 1 {
                            pieces.push(py_expr(wrt))
                          } else if order_int > 1 {
                            pieces.push(
                              "(" +
                              py_expr(wrt) +
                              ", " +
                              py_expr(deriv_args[order_idx]) +
                              ")",
                            )
                          } else {
                            pieces.push(py_expr(wrt))
                            pieces.push(py_expr(deriv_args[order_idx]))
                          }
                        }
                        _ => {
                          pieces.push(py_expr(wrt))
                          pieces.push(py_expr(deriv_args[order_idx]))
                        }
                      }
                    } else {
                      pieces.push(py_expr(wrt))
                    }
                  }
                  "sympy.Derivative(" + pieces.join(", ") + ")"
                }
                None =>
                  match @symcore.subs_parts(expr) {
                    Some((inner, variable, value)) =>
                      "sympy.Subs(" +
                      py_expr(inner) +
                      ", " +
                      py_expr(variable) +
                      ", " +
                      py_expr(value) +
                      ")"
                    None =>
                      match @symcore.lambda_parts(expr) {
                        Some((vars, body)) =>
                          "sympy.Lambda(" +
                          py_expr(vars) +
                          ", " +
                          py_expr(body) +
                          ")"
                        None =>
                          match @symcore.bool_value(expr) {
                            Some(true) => "True"
                            Some(false) => "False"
                            None =>
                              "sympy.sympify('" +
                              @symprint.to_string(expr) +
                              "', locals=" +
                              py_locals() +
                              ")"
                          }
                      }
                  }
              }
          }
      }
  }
}

///|
fn py_src_expr(text : String) -> String {
  "sympy.sympify('" + text + "', locals=" + py_locals() + ")"
}

///|
fn py_matrix_expr(mat : @symmatrices.Matrix) -> String {
  py_src_expr(mat.to_string())
}

///|
test "symintegrals parity core indefinite families" {
  let x = @symcore.Expr::Symbol("x")
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
    (
      "exp(x)**(1 + I)",
      @symcore.pow(
        @symelem.exp(x),
        @symcore.add([
          @symcore.int(1),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
        ]),
      ),
    ),
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
    let oracle = integrals_eval_str(
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
test "symintegrals parity Laplace helper utilities" {
  let t = @symcore.Expr::Symbol("t")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let y_t = @symcore.raw_function("y", [t])
  let deep_expr = @symelem.exp((t + a) * (t + b)) +
    @symspec.besselj(
      @symcore.int(2),
      @symelem.exp((t + a) * (t + b) - (t ^ @symcore.int(2))),
    )
  let deep_collected = @symintegrals._laplace_deep_collect(deep_expr, t)
  inspect(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(" +
      py_expr(deep_collected) +
      " - sympy.integrals.laplace._laplace_deep_collect(sympy.exp((sympy.Symbol('t') + sympy.Symbol('a'))*(sympy.Symbol('t') + sympy.Symbol('b'))) + sympy.besselj(2, sympy.exp((sympy.Symbol('t') + sympy.Symbol('a'))*(sympy.Symbol('t') + sympy.Symbol('b')) - sympy.Symbol('t')**2)), sympy.Symbol('t'))))",
    ),
    content="0",
  )

  let mut third_deriv = y_t
  for _ in 0..<3 {
    third_deriv = @symcalculus.diff(third_deriv, t)
  }
  let transformed = laplace_transform_eval(third_deriv, t, s, noconds=true)
  let correspondence : Map[String, String] = {}
  correspondence["y"] = "Y"
  let transformed_named = @symintegrals.laplace_correspondence(
    transformed, correspondence,
  )
  let initial_conds : Map[String, Array[Expr]] = {}
  initial_conds["y"] = [
    @symcore.int(2),
    @symcore.int(4),
    @symcore.int(8),
    @symcore.int(16),
    @symcore.int(32),
  ]
  let with_ics = @symintegrals.laplace_initial_conds(
    transformed_named, t, initial_conds,
  )
  inspect(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(" +
      py_expr(with_ics) +
      " - sympy.integrals.laplace.laplace_initial_conds(sympy.integrals.laplace.laplace_correspondence(sympy.laplace_transform(sympy.diff(sympy.Function('y')(sympy.Symbol('t')), (sympy.Symbol('t'), 3)), sympy.Symbol('t'), sympy.Symbol('s'), noconds=True), {sympy.Function('y'): sympy.Function('Y')}), sympy.Symbol('t'), {sympy.Function('y'): [2, 4, 8, 16, 32]})))",
    ),
    content="0",
  )

  let inverse_named = @symintegrals.laplace_correspondence(
    inverse_laplace_transform(@symcore.raw_function("Y", [s]), s, t),
    correspondence,
  )
  inspect(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(" +
      py_expr(inverse_named) +
      " - sympy.integrals.laplace.laplace_correspondence(sympy.inverse_laplace_transform(sympy.Function('Y')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')), {sympy.Function('y'): sympy.Function('Y')})))",
    ),
    content="0",
  )
}

///|
test "symintegrals parity definite delta and singularity paths" {
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let delta_expr = @symspec.dirac_delta(x - @symcore.int(2)) * x
  inspect(
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let t = @symcore.Expr::Symbol("t")
  let c = @symgeometry.curve(
    [@symelem.exp(t) + @symcore.int(1), @symelem.exp(t) + @symcore.int(-1)],
    t,
    @symcore.int(0),
    @symelem.log(@symcore.int(2)),
  )
  inspect(
    integrals_eval_str(
      "(lambda x, y, t: sympy.sstr(sympy.simplify((" +
      py_expr(line_integrate(x + y, c, [x, y])) +
      ") - sympy.line_integrate(x + y, sympy.Curve([sympy.exp(t) + 1, sympy.exp(t) - 1], (t, 0, sympy.log(2))), [x, y]))))(sympy.Symbol('x'), sympy.Symbol('y'), sympy.Symbol('t'))",
    ),
    content="0",
  )
  inspect(
    integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.simplify((" +
      py_expr(heurisch_wrapper(x * @symelem.exp(x), "x")) +
      ") - sympy.integrals.heurisch.heurisch_wrapper(x*sympy.exp(x), x))))(sympy.Symbol('x'))",
    ),
    content="0",
  )
}

///|
test "symintegrals parity transforms forward/inverse family" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let k = @symcore.Expr::Symbol("k")

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
    (
      "exp((-1/2 - I/3)*x)",
      @symelem.exp(
        @symcore.mul([
          @symcore.add([
            @symcore.rational_from_ints(-1, 2),
            @symcore.mul([
              @symcore.rational_from_ints(-1, 3),
              @symcore.Expr::NumberSymbol(
                @symcore.NumberSymbolKind::ImaginaryUnit,
              ),
            ]),
          ]),
          x,
        ]),
      ),
    ),
  ]
  for item in lp_cases {
    let ours = doit(laplace_transform(item.1, x, s))
    let oracle = integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours) +
      ") - (sympy.laplace_transform(sympy.sympify('" +
      item.0 +
      "', locals={'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'And': sympy.And, 'Le': sympy.Le}), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))))",
    )
    inspect(oracle, content="0")
  }

  let ft = @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(2)))
  let a = @symcore.Expr::Symbol("a")
  let third = @symcore.rational_from_ints(1, 3)
  let two_thirds = @symcore.rational_from_ints(2, 3)
  let three_halves = @symcore.rational_from_ints(3, 2)
  let ours_ft = doit(fourier_transform(ft, x, k))
  let oracle_ft = integrals_eval_str(
    "sympy.sstr(sympy.simplify((" +
    py_expr(ours_ft) +
    ") - (sympy.fourier_transform(sympy.exp(-sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('k')))))",
  )
  inspect(oracle_ft, content="0")

  let ours_ift = doit(inverse_fourier_transform(ours_ft, k, x))
  let oracle_ift = integrals_eval_str(
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
  let shifted_ft_oracle = integrals_eval_str(
    "sympy.sstr(sympy.simplify(sympy.expand(((" +
    py_expr(shifted_ft) +
    ") - (sympy.fourier_transform(sympy.exp(-(sympy.Symbol('x') - 1)**2), sympy.Symbol('x'), sympy.Symbol('k')))).rewrite(sympy.exp))))",
  )
  inspect(shifted_ft_oracle, content="0")

  let shifted_ift = doit(inverse_fourier_transform(shifted_ft, k, x))
  let shifted_ift_oracle = integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_ft) +
      ") - sympy.fourier_transform(sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let half_line_ift = doit(inverse_fourier_transform(half_line_ft, k, x))
  inspect(
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(half_line_x_ft) +
      ") - sympy.fourier_transform(sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let half_line_x_ift = doit(inverse_fourier_transform(half_line_x_ft, k, x))
  inspect(
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(abs_decay_ft) +
      ") - sympy.fourier_transform(sympy.exp(-2*sympy.Abs(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let abs_decay_ift = doit(inverse_fourier_transform(abs_decay_ft, k, x))
  inspect(
    integrals_eval_str("sympy.sstr(" + py_expr(abs_decay_ift) + ")"),
    content=integrals_eval_str(
      "sympy.sstr(sympy.exp(-2*sympy.Abs(sympy.Symbol('x'))))",
    ),
  )

  let box_window_ft = doit(
    fourier_transform(
      @symspec.heaviside(@symcore.int(1) - @symelem.abs(@symcore.int(2) * x)),
      x,
      k,
    ),
  )
  inspect(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(box_window_ft) +
      ") - sympy.fourier_transform(sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    content="0",
  )
  let box_window_ift = doit(inverse_fourier_transform(box_window_ft, k, x))
  inspect(
    integrals_eval_str("sympy.sstr(" + py_expr(box_window_ift) + ")"),
    content=integrals_eval_str(
      "sympy.sstr(sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x'))))",
    ),
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
      integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(direct_symbolic_sinc_triangle_ift) +
      ") - (sympy.Heaviside(1 - sympy.Abs(sympy.Symbol('a')*sympy.Symbol('x')))*(1 - sympy.Abs(sympy.Symbol('a')*sympy.Symbol('x'))))))",
    ),
    content="0",
  )

  let inverse_lp_cases : Array[(String, Expr)] = [
    (
      "1/s",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") ^ @symcore.int(-1),
        s,
        x,
      ),
    ),
    (
      "s/(s**2 + 4)",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") *
        (
          ((@symcore.Expr::Symbol("s") ^ @symcore.int(2)) + @symcore.int(4)) ^
          @symcore.int(-1)
        ),
        s,
        x,
      ),
    ),
    (
      "1/(s**2 - 1)",
      inverse_laplace_transform(
        ((@symcore.Expr::Symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
        @symcore.int(-1),
        s,
        x,
      ),
    ),
    (
      "s/(s**2 - 1)",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") *
        (
          ((@symcore.Expr::Symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
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
          (@symcore.Expr::Symbol("s") + @symcore.int(1)) *
          (@symcore.Expr::Symbol("s") + @symcore.int(2))
        ) ^
        @symcore.int(-1),
        s,
        x,
      ),
    ),
    (
      "s/((s + 1)*(s + 2))",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") *
        (
          (
            (@symcore.Expr::Symbol("s") + @symcore.int(1)) *
            (@symcore.Expr::Symbol("s") + @symcore.int(2))
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
        ((@symcore.Expr::Symbol("s") ^ @symcore.int(2)) + @symcore.int(1)) ^
        @symcore.int(-2),
        s,
        x,
      ),
    ),
    (
      "s/(s**2 + 1)**2",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") *
        (
          ((@symcore.Expr::Symbol("s") ^ @symcore.int(2)) + @symcore.int(1)) ^
          @symcore.int(-2)
        ),
        s,
        x,
      ),
    ),
    (
      "1/(s**2 - 1)**2",
      inverse_laplace_transform(
        ((@symcore.Expr::Symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
        @symcore.int(-2),
        s,
        x,
      ),
    ),
    (
      "s/(s**2 - 1)**2",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") *
        (
          ((@symcore.Expr::Symbol("s") ^ @symcore.int(2)) - @symcore.int(1)) ^
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
          ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
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
        (@symcore.Expr::Symbol("s") + @symcore.int(1)) *
        (
          (
            ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
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
          ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
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
        @symcore.Expr::Symbol("s") *
        (
          (
            ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) -
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
          ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) +
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
        @symcore.Expr::Symbol("s") *
        (
          (
            ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(2)) +
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
    let oracle = integrals_eval_str(
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
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let bp = @symcore.Expr::Symbol("bp")
  let rho = @symcore.Expr::Symbol("rho")
  let f_of_x = @symcore.raw_function("f", [x])
  let half = @symcore.rational_from_ints(1, 2)

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
    inspect(
      integrals_eval_str(
        "sympy.sstr(sympy.expand_mul((" +
        py_expr(ours) +
        ") - (" +
        item.1 +
        ")))",
      ),
      content="0",
    )
  }

  let exp_inv = do_mellin_doit(
    @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(-1))),
    x,
    s,
  ).unwrap()
  let inv_exp_oracle = integrals_eval_str(
    "sympy.sstr(sympy.simplify((" +
    py_expr(exp_inv) +
    ") - (sympy.mellin_transform(sympy.exp(-sympy.Symbol('x') ** -1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))))",
  )
  inspect(inv_exp_oracle, content="0")

  let shifted_power_mellin = mellin_transform_eval(
    (x + @symcore.int(1)) ^ (@symcore.int(-1) * rho),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(shifted_power_mellin) +
      ")[0]) - sympy.mellin_transform((1 + sympy.Symbol('x'))**(-sympy.Symbol('rho')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(shifted_power_mellin) + ")[1])[0])",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(shifted_power_mellin) + ")[1])[1])",
    ),
    "re(rho)",
  )

  let difference_quotient_mellin = mellin_transform_eval(
    ((x ^ a) - (bp ^ a)) * ((x - bp) ^ @symcore.int(-1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(difference_quotient_mellin) +
      ")[0]) - sympy.mellin_transform((sympy.Symbol('x')**sympy.Symbol('a') - sympy.Symbol('bp')**sympy.Symbol('a'))/(sympy.Symbol('x') - sympy.Symbol('bp')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(difference_quotient_mellin) + ")[1])[0])",
    ),
    "Max(0, -re(a))",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(difference_quotient_mellin) + ")[1])[1])",
    ),
    "Min(1, 1 - re(a))",
  )

  let sqrt_shift = @symelem.sqrt(x + (bp ^ @symcore.int(2))) + bp
  let sqrt_shift_mellin = mellin_transform_eval(sqrt_shift ^ a, x, s)
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(sympy.simplify((((" +
      py_expr(sqrt_shift_mellin) +
      ")[0]).subs(sympy.Symbol('bp'), bp) - sympy.mellin_transform((sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a'), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))))(sympy.Symbol('bp', positive=True))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_mellin) +
      ")[1])[0]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_mellin) +
      ")[1])[1]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
    ),
    "-re(a)/2",
  )

  let sqrt_shift_recip_mellin = mellin_transform_eval(
    (sqrt_shift ^ a) *
    (@symelem.sqrt(x + (bp ^ @symcore.int(2))) ^ @symcore.int(-1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(sympy.simplify((((" +
      py_expr(sqrt_shift_recip_mellin) +
      ")[0]).subs(sympy.Symbol('bp'), bp) - sympy.mellin_transform((sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a')/sympy.sqrt(sympy.Symbol('x') + bp**2), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))))(sympy.Symbol('bp', positive=True))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_recip_mellin) +
      ")[1])[0]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_recip_mellin) +
      ")[1])[1]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
    ),
    "1/2 - re(a)/2",
  )

  let left_beta_mellin = mellin_transform_eval(
    ((@symcore.int(1) - x) ^ (b - @symcore.int(1))) *
    @symspec.heaviside(@symcore.int(1) - x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(left_beta_mellin) +
      ")[0]) - sympy.mellin_transform((1 - sympy.Symbol('x'))**(sympy.Symbol('b') - 1)*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(left_beta_mellin) + ")[1])[0])",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(left_beta_mellin) + ")[1])[1])",
    ),
    "oo",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(left_beta_mellin) + ")[2])"),
    integrals_eval_str(
      "sympy.sstr(sympy.mellin_transform((1 - sympy.Symbol('x'))**(sympy.Symbol('b') - 1)*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'))[2])",
    ),
  )

  let right_beta_mellin = mellin_transform_eval(
    ((x - @symcore.int(1)) ^ (b - @symcore.int(1))) *
    @symspec.heaviside(x - @symcore.int(1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(right_beta_mellin) +
      ")[0]) - sympy.mellin_transform((sympy.Symbol('x') - 1)**(sympy.Symbol('b') - 1)*sympy.Heaviside(sympy.Symbol('x') - 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(right_beta_mellin) + ")[1])[0])",
    ),
    "-oo",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(right_beta_mellin) + ")[1])[1])",
    ),
    "1 - re(b)",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(right_beta_mellin) + ")[2])"),
    integrals_eval_str(
      "sympy.sstr(sympy.mellin_transform((sympy.Symbol('x') - 1)**(sympy.Symbol('b') - 1)*sympy.Heaviside(sympy.Symbol('x') - 1), sympy.Symbol('x'), sympy.Symbol('s'))[2])",
    ),
  )

  let erf_sqrt_mellin = mellin_transform_eval(
    @symspec.erf(@symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(erf_sqrt_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.erf(sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(erf_sqrt_mellin) + ")[1])[0])"),
    "-1/2",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(erf_sqrt_mellin) + ")[1])[1])"),
    "0",
  )

  let abs_one_minus_mellin = mellin_transform_eval(
    @symelem.abs(@symcore.int(1) - x) ^ (@symcore.int(-1) * rho),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(abs_one_minus_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.Abs(1 - sympy.Symbol('x'))**(-sympy.Symbol('rho')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(abs_one_minus_mellin) + ")[1])[0])",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(abs_one_minus_mellin) + ")[1])[1])",
    ),
    "re(rho)",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(abs_one_minus_mellin) + ")[2])"),
    integrals_eval_str(
      "sympy.sstr(sympy.mellin_transform(sympy.Abs(1 - sympy.Symbol('x'))**(-sympy.Symbol('rho')), sympy.Symbol('x'), sympy.Symbol('s'))[2])",
    ),
  )

  let log_left_mellin = mellin_transform_eval(
    (@symelem.log(x) ^ @symcore.int(4)) *
    @symspec.heaviside(@symcore.int(1) - x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_left_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.log(sympy.Symbol('x'))**4*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(log_left_mellin) + ")[1])[0])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(log_left_mellin) + ")[1])[1])"),
    "oo",
  )

  let log_right_mellin = mellin_transform_eval(
    (@symelem.log(x) ^ @symcore.int(3)) *
    @symspec.heaviside(x - @symcore.int(1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_right_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.log(sympy.Symbol('x'))**3*sympy.Heaviside(sympy.Symbol('x') - 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_right_mellin) + ")[1])[0])",
    ),
    "-oo",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_right_mellin) + ")[1])[1])",
    ),
    "0",
  )

  let log_one_plus_mellin = mellin_transform_eval(
    @symelem.log(x + @symcore.int(1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_one_plus_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.log(sympy.Symbol('x') + 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_one_plus_mellin) + ")[1])[0])",
    ),
    "-1",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_one_plus_mellin) + ")[1])[1])",
    ),
    "0",
  )

  let log_one_plus_inverse_mellin = mellin_transform_eval(
    @symelem.log((x ^ @symcore.int(-1)) + @symcore.int(1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_one_plus_inverse_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.log(1/sympy.Symbol('x') + 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_one_plus_inverse_mellin) + ")[1])[0])",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_one_plus_inverse_mellin) + ")[1])[1])",
    ),
    "1",
  )

  let log_abs_left_mellin = mellin_transform_eval(
    @symelem.log(@symelem.abs(@symcore.int(1) - x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_abs_left_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.log(sympy.Abs(1 - sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_abs_left_mellin) + ")[1])[0])",
    ),
    "-1",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_abs_left_mellin) + ")[1])[1])",
    ),
    "0",
  )

  let log_abs_inverse_mellin = mellin_transform_eval(
    @symelem.log(@symelem.abs(@symcore.int(1) - (x ^ @symcore.int(-1)))),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_abs_inverse_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.log(sympy.Abs(1 - 1/sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_abs_inverse_mellin) + ")[1])[0])",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(log_abs_inverse_mellin) + ")[1])[1])",
    ),
    "1",
  )

  let e1_mellin = mellin_transform_eval(@symspec.e1(x), x, s)
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(e1_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.E1(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(e1_mellin) + ")[1])[0])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(e1_mellin) + ")[1])[1])"),
    "oo",
  )

  let expint2_mellin = mellin_transform_eval(
    @symspec.expint(@symcore.int(2), x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(expint2_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.expint(2, sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(expint2_mellin) + ")[1])[0])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(expint2_mellin) + ")[1])[1])"),
    "oo",
  )

  let si_mellin = mellin_transform_eval(@symspec.si(x), x, s)
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(si_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.Si(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(si_mellin) + ")[1])[0])"),
    "-1",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(si_mellin) + ")[1])[1])"),
    "0",
  )

  let ci_sqrt_mellin = mellin_transform_eval(
    @symspec.ci(@symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(ci_sqrt_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.Ci(sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(ci_sqrt_mellin) + ")[1])[0])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(ci_sqrt_mellin) + ")[1])[1])"),
    "1",
  )

  let besselj_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symcore.int(2) * @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(besselj_mellin) + ")[1])[0])"),
    "-re(a)/2",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(besselj_mellin) + ")[1])[1])"),
    "3/4",
  )

  let bessely_mellin = mellin_transform_eval(
    @symspec.bessely(a, @symcore.int(2) * @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(bessely_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.bessely(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(bessely_mellin) + ")[1])[0])"),
    "Max(-re(a)/2, re(a)/2)",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(bessely_mellin) + ")[1])[1])"),
    "3/4",
  )

  let besselk_mellin = mellin_transform_eval(
    @symspec.besselk(a, @symcore.int(2) * @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselk_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselk(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(besselk_mellin) + ")[1])[0])"),
    "Max(-re(a)/2, re(a)/2)",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(((" + py_expr(besselk_mellin) + ")[1])[1])"),
    "oo",
  )

  let besseli_besselk_mellin = mellin_transform_eval(
    @symspec.besseli(a, @symelem.sqrt(x)) *
    @symspec.besselk(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besseli_besselk_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besseli(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besseli_besselk_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.besseli(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besseli_besselk_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let besselj_sq_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) ^ @symcore.int(2),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_sq_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))**2, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_sq_mellin) + ")[1])[0])",
    ),
    "-re(a)",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_sq_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let besselj_neg_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.besselj(@symcore.int(-1) * a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_neg_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(-sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_neg_mellin) + ")[1])[0])",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_neg_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let besselj_bessely_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.bessely(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_bessely_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_bessely_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_bessely_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let besselj_adjacent_mellin = mellin_transform_eval(
    @symspec.besselj(a - @symcore.int(1), @symelem.sqrt(x)) *
    @symspec.besselj(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_adjacent_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselj(sympy.Symbol('a') - 1, sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_adjacent_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a') - 1, sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_adjacent_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let besselj_general_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.besselj(b, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_general_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_general_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_general_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let besselj_bessely_general_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.bessely(b, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj_bessely_general_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_bessely_general_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besselj_bessely_general_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let besseli_besselk_general_mellin = mellin_transform_eval(
    @symspec.besseli(b, @symelem.sqrt(x)) *
    @symspec.besselk(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besseli_besselk_general_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.besseli(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besseli_besselk_general_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.besseli(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(besseli_besselk_general_mellin) + ")[1])[1])",
    ),
    "1/2",
  )

  let sin_besselj_mellin = mellin_transform_eval(
    @symelem.sin(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_besselj_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(sin_besselj_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(sin_besselj_mellin) + ")[1])[1])",
    ),
    "1/4",
  )

  let cos_besselj_mellin = mellin_transform_eval(
    @symelem.cos(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(cos_besselj_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(cos_besselj_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(cos_besselj_mellin) + ")[1])[1])",
    ),
    "1/4",
  )

  let sin_bessely_mellin = mellin_transform_eval(
    @symelem.sin(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_bessely_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(sin_bessely_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(sin_bessely_mellin) + ")[1])[1])",
    ),
    "1/4",
  )

  let cos_bessely_mellin = mellin_transform_eval(
    @symelem.cos(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(cos_bessely_mellin) +
      ")[0]) - sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(cos_bessely_mellin) + ")[1])[0])",
    ),
    integrals_eval_str(
      "sympy.sstr((sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(cos_bessely_mellin) + ")[1])[1])",
    ),
    "1/4",
  )

  let generic_mellin = mellin_transform_eval(f_of_x, x, s)
  assert_eq(
    integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.mellin_transform(sympy.Function('f')(x), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(generic_mellin) + ")"),
  )

  let partial_generic_mellin = mellin_transform_eval(
    f_of_x + @symelem.exp(@symcore.int(-1) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(partial_generic_mellin) +
      ")[0]) - (sympy.MellinTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')) + sympy.mellin_transform(sympy.exp(-sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(partial_generic_mellin) + ")[1])[0])",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" + py_expr(partial_generic_mellin) + ")[1])[1])",
    ),
    "oo",
  )

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
        let inv = integrals_eval_str(
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

  let e1_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) * (s ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  let gamma_shift_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s - @symcore.int(1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(gamma_shift_inverse) +
      ") - (sympy.exp(-sympy.Symbol('x'))/sympy.Symbol('x'))))",
    ),
    "0",
  )

  let gamma_sum_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) + @symspec.gamma(s - @symcore.int(1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(gamma_sum_inverse) +
      ") - ((sympy.Symbol('x') + 1)*sympy.exp(-sympy.Symbol('x'))/sympy.Symbol('x'))))",
    ),
    "0",
  )

  let beta_left_inverse = do_inverse_mellin_doit(
    @symspec.gamma(b) *
    @symspec.gamma(s) *
    (@symspec.gamma(s + b) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(beta_left_inverse) +
      ") - (((1 - sympy.Symbol('x'))**(sympy.Symbol('b') - 1))*sympy.Heaviside(1 - sympy.Symbol('x')))))",
    ),
    "0",
  )

  let beta_right_inverse = do_inverse_mellin_doit(
    @symspec.gamma(b) *
    @symspec.gamma(@symcore.int(1) - b - s) *
    (@symspec.gamma(@symcore.int(1) - s) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(beta_right_inverse) +
      ") - (((sympy.Symbol('x') - 1)**(sympy.Symbol('b') - 1))*sympy.Heaviside(sympy.Symbol('x') - 1))))",
    ),
    "0",
  )

  let shifted_power_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) *
    @symspec.gamma(rho - s) *
    (@symspec.gamma(rho) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(shifted_power_inverse) +
      ") - ((1 + sympy.Symbol('x'))**(-sympy.Symbol('rho')))))",
    ),
    "0",
  )

  let difference_quotient_inverse = do_inverse_mellin_doit(
    (bp ^ (a + s - @symcore.int(1))) *
    @symelem.sin(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * a) *
    @symspec.gamma(s) *
    @symspec.gamma(a + s) *
    @symspec.gamma(@symcore.int(1) - s) *
    @symspec.gamma(@symcore.int(1) - a - s) *
    (
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(difference_quotient_inverse) +
      ") - ((sympy.Symbol('x')**sympy.Symbol('a') - sympy.Symbol('bp')**sympy.Symbol('a'))/(sympy.Symbol('x') - sympy.Symbol('bp')))))",
    ),
    "0",
  )

  let sqrt_shift_inverse = do_inverse_mellin_doit(
    @symcore.int(-1) *
    a *
    (@symcore.int(2) ^ (a + @symcore.int(2) * s)) *
    (bp ^ (a + @symcore.int(2) * s)) *
    @symspec.gamma(s) *
    @symspec.gamma(@symcore.int(-1) * (a + @symcore.int(2) * s)) *
    (@symspec.gamma(@symcore.int(1) - a - s) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_shift_inverse) +
      ").subs(sympy.Symbol('bp'), bp) - (sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a'))))(sympy.Symbol('bp', positive=True))",
    ),
    "0",
  )

  let sqrt_shift_recip_inverse = do_inverse_mellin_doit(
    (@symcore.int(2) ^ (a + @symcore.int(2) * s)) *
    (bp ^ (a + @symcore.int(2) * s - @symcore.int(1))) *
    @symspec.gamma(s) *
    @symspec.gamma(@symcore.int(1) - a - @symcore.int(2) * s) *
    (@symspec.gamma(@symcore.int(1) - a - s) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "(lambda bp: sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_shift_recip_inverse) +
      ").subs(sympy.Symbol('bp'), bp) - ((sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a')/sympy.sqrt(sympy.Symbol('x') + bp**2)))))(sympy.Symbol('bp', positive=True))",
    ),
    "0",
  )

  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(e1_inverse) +
      ") - sympy.E1(sympy.Symbol('x'))))",
    ),
    "0",
  )

  let expint2_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(expint2_inverse) +
      ") - sympy.expint(2, sympy.Symbol('x'))))",
    ),
    "0",
  )

  let si_inverse = do_inverse_mellin_doit(
    @symcore.int(-1) *
    (
      (@symcore.int(2) ^ s) *
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) *
        @symspec.gamma((s + @symcore.int(1)) * half)
      )
    ) *
    (
      (@symcore.int(2) * (s * @symspec.gamma(@symcore.int(1) - s * half))) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(si_inverse) +
      ") - sympy.Si(sympy.Symbol('x'))))",
    ),
    "0",
  )

  let ci_sqrt_inverse = do_inverse_mellin_doit(
    @symcore.int(-1) *
    (
      (@symcore.int(2) ^ (@symcore.int(2) * s - @symcore.int(1))) *
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) *
        @symspec.gamma(s)
      )
    ) *
    ((s * @symspec.gamma(half - s)) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ci_sqrt_inverse) +
      ") - sympy.Ci(sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let erf_sqrt_inverse = do_inverse_mellin_doit(
    @symcore.int(-1) *
    @symspec.gamma(s + half) *
    (
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) *
        s
      ) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(erf_sqrt_inverse) +
      ") - sympy.erf(sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let log_left_inverse = do_inverse_mellin_doit(
    @symcore.int(24) * (s ^ @symcore.int(-5)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_left_inverse) +
      ") - (sympy.log(sympy.Symbol('x'))**4*sympy.Heaviside(1 - sympy.Symbol('x')))))",
    ),
    "0",
  )

  let log_right_inverse = do_inverse_mellin_doit(
    @symcore.int(6) * (s ^ @symcore.int(-4)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_right_inverse) +
      ") - (sympy.log(sympy.Symbol('x'))**3*sympy.Heaviside(sympy.Symbol('x') - 1))))",
    ),
    "0",
  )

  let log_quadratic_inverse = do_inverse_mellin_doit(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    (
      (
        s *
        @symelem.sin(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s * half,
        )
      ) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_quadratic_inverse) +
      ") - sympy.log(sympy.Symbol('x')**2 + 1)))",
    ),
    "0",
  )

  let sec_inverse = do_inverse_mellin_doit(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    (
      @symelem.cos(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
      ) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sec_inverse) +
      ") - (sympy.sqrt(sympy.Symbol('x'))/(sympy.Symbol('x') + 1))))",
    ),
    "0",
  )

  let log_piecewise_inverse = do_inverse_mellin_doit(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    (
      (
        s *
        @symelem.sin(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
        )
      ) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_piecewise_inverse) +
      ") - ((sympy.log(1 + sympy.Symbol('x'))*sympy.Heaviside(1 - sympy.Symbol('x'))) + (sympy.log(1 + sympy.Symbol('x')**-1)*sympy.Heaviside(sympy.Symbol('x') - 1)))))",
    ),
    "0",
  )

  let sqrt_piecewise_inverse = do_inverse_mellin_doit(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    (
      (
        s *
        @symelem.sin(
          @symcore.int(2) *
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
          s,
        )
      ) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_piecewise_inverse) +
      ") - ((sympy.log(1 + sympy.sqrt(sympy.Symbol('x')))*sympy.Heaviside(1 - sympy.Symbol('x'))) + (sympy.log(1 + sympy.sqrt(sympy.Symbol('x'))**-1)*sympy.Heaviside(sympy.Symbol('x') - 1)))))",
    ),
    "0",
  )

  let tan_piecewise_inverse = do_inverse_mellin_doit(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    (
      (
        s *
        @symelem.tan(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
        )
      ) ^
      @symcore.int(-1)
    ),
    s,
    x,
  ).unwrap()
  let tan_piecewise_target = "((sympy.log(1 - sympy.Symbol('x'))*sympy.Heaviside(1 - sympy.Symbol('x'))) + (sympy.log(sympy.Symbol('x') - 1)*sympy.Heaviside(sympy.Symbol('x') - 1)))"
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(tan_piecewise_inverse) +
      ") - " +
      tan_piecewise_target +
      "))",
    ),
    "0",
  )

  let cot_piecewise_inverse = do_inverse_mellin_doit(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    @symelem.cot(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s) *
    (s ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cot_piecewise_inverse) +
      ") - " +
      tan_piecewise_target +
      "))",
    ),
    "0",
  )

  let besselj_input = @symspec.gamma(s + a * half) *
    (@symspec.gamma(@symcore.int(1) - s + a * half) ^ @symcore.int(-1))
  let besselj_inverse_opt = do_inverse_mellin_doit(besselj_input, s, x)
  assert_true(besselj_inverse_opt is Some(_))
  let besselj_inverse = besselj_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(besselj_inverse) +
      ") - sympy.besselj(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let bessely_input = @symcore.int(-1) *
    (
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
      @symcore.int(-1)
    ) *
    @symelem.cos(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (a * half - s),
    ) *
    @symspec.gamma(s - a * half) *
    @symspec.gamma(s + a * half)
  let bessely_inverse_opt = do_inverse_mellin_doit(bessely_input, s, x)
  assert_true(bessely_inverse_opt is Some(_))
  let bessely_inverse = bessely_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(bessely_inverse) +
      ") - sympy.bessely(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let besselk_input = half *
    @symspec.gamma(s - a * half) *
    @symspec.gamma(s + a * half)
  let besselk_inverse_opt = do_inverse_mellin_doit(besselk_input, s, x)
  assert_true(besselk_inverse_opt is Some(_))
  let besselk_inverse = besselk_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(besselk_inverse) +
      ") - sympy.besselk(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let sin_besselj_input = (@symcore.int(2) ^ a) *
    @symspec.gamma(half - @symcore.int(2) * s) *
    @symspec.gamma(s + (a + @symcore.int(1)) * half) *
    (@symspec.gamma(@symcore.int(1) - s - a * half) ^ @symcore.int(-1)) *
    (
      @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s + a) ^
      @symcore.int(-1)
    )
  let sin_besselj_inverse_opt = do_inverse_mellin_doit(sin_besselj_input, s, x)
  assert_true(sin_besselj_inverse_opt is Some(_))
  let sin_besselj_inverse = sin_besselj_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sin_besselj_inverse) +
      ") - sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let cos_besselj_input = (@symcore.int(2) ^ a) *
    @symspec.gamma(a * half + s) *
    @symspec.gamma(half - @symcore.int(2) * s) *
    (@symspec.gamma(half - s - a * half) ^ @symcore.int(-1)) *
    (
      @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s + a) ^
      @symcore.int(-1)
    )
  let cos_besselj_inverse_opt = do_inverse_mellin_doit(cos_besselj_input, s, x)
  assert_true(cos_besselj_inverse_opt is Some(_))
  let cos_besselj_inverse = cos_besselj_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cos_besselj_inverse) +
      ") - sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let sin_bessely_input = @symcore.int(-1) *
    (
      @symelem.sqrt(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)) ^
      @symcore.int(-1)
    ) *
    (@symcore.int(4) ^ s) *
    @symelem.sin(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (a * half - s),
    ) *
    @symspec.gamma(half - @symcore.int(2) * s) *
    @symspec.gamma((@symcore.int(1) - a) * half + s) *
    @symspec.gamma((@symcore.int(1) + a) * half + s) *
    (@symspec.gamma(@symcore.int(1) - s - a * half) ^ @symcore.int(-1)) *
    (@symspec.gamma(@symcore.int(1) - s + a * half) ^ @symcore.int(-1))
  let sin_bessely_inverse_opt = do_inverse_mellin_doit(sin_bessely_input, s, x)
  assert_true(sin_bessely_inverse_opt is Some(_))
  let sin_bessely_inverse = sin_bessely_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sin_bessely_inverse) +
      ") - sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let cos_bessely_input = @symcore.int(-1) *
    (
      @symelem.sqrt(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)) ^
      @symcore.int(-1)
    ) *
    (@symcore.int(4) ^ s) *
    @symelem.cos(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (a * half - s),
    ) *
    @symspec.gamma(s - a * half) *
    @symspec.gamma(s + a * half) *
    @symspec.gamma(half - @symcore.int(2) * s) *
    (@symspec.gamma(half - s - a * half) ^ @symcore.int(-1)) *
    (@symspec.gamma(half - s + a * half) ^ @symcore.int(-1))
  let cos_bessely_inverse_opt = do_inverse_mellin_doit(cos_bessely_input, s, x)
  assert_true(cos_bessely_inverse_opt is Some(_))
  let cos_bessely_inverse = cos_bessely_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cos_bessely_inverse) +
      ") - sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let besselj_sq_input = (
      @symelem.sqrt(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)) ^
      @symcore.int(-1)
    ) *
    @symspec.gamma(a + s) *
    @symspec.gamma(half - s) *
    (@symspec.gamma(@symcore.int(1) - s) ^ @symcore.int(-1)) *
    (@symspec.gamma(@symcore.int(1) + a - s) ^ @symcore.int(-1))
  let besselj_sq_inverse_opt = do_inverse_mellin_doit(besselj_sq_input, s, x)
  assert_true(besselj_sq_inverse_opt is Some(_))
  let besselj_sq_inverse = besselj_sq_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(besselj_sq_inverse) +
      ") - sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))**2))",
    ),
    "0",
  )

  let besselj_pm_input = (
      @symelem.sqrt(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)) ^
      @symcore.int(-1)
    ) *
    @symspec.gamma(s) *
    @symspec.gamma(half - s) *
    (@symspec.gamma(@symcore.int(1) - s - a) ^ @symcore.int(-1)) *
    (@symspec.gamma(@symcore.int(1) + a - s) ^ @symcore.int(-1))
  let besselj_pm_inverse_opt = do_inverse_mellin_doit(besselj_pm_input, s, x)
  assert_true(besselj_pm_inverse_opt is Some(_))
  let besselj_pm_inverse = besselj_pm_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(besselj_pm_inverse) +
      ") - sympy.besselj(-sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let besselj_ab_input = (@symcore.int(4) ^ s) *
    @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s) *
    @symspec.gamma((a + b) * half + s) *
    (@symspec.gamma(@symcore.int(1) + (b - a) * half - s) ^ @symcore.int(-1)) *
    (@symspec.gamma(@symcore.int(1) + (a - b) * half - s) ^ @symcore.int(-1)) *
    (@symspec.gamma(@symcore.int(1) + (a + b) * half - s) ^ @symcore.int(-1))
  let besselj_ab_inverse_opt = do_inverse_mellin_doit(besselj_ab_input, s, x)
  assert_true(besselj_ab_inverse_opt is Some(_))
  let besselj_ab_inverse = besselj_ab_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(besselj_ab_inverse) +
      ") - sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let besselj_bessely_input = @symcore.int(-1) *
    (
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
      @symcore.int(-1)
    ) *
    (@symcore.int(4) ^ s) *
    @symelem.cos(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      ((a - b) * half + s),
    ) *
    @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s) *
    @symspec.gamma((a - b) * half + s) *
    @symspec.gamma((a + b) * half + s) *
    (@symspec.gamma(@symcore.int(1) + (a - b) * half - s) ^ @symcore.int(-1)) *
    (@symspec.gamma(@symcore.int(1) + (a + b) * half - s) ^ @symcore.int(-1))
  let besselj_bessely_inverse_opt = do_inverse_mellin_doit(
    besselj_bessely_input, s, x,
  )
  assert_true(besselj_bessely_inverse_opt is Some(_))
  let besselj_bessely_inverse = besselj_bessely_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(besselj_bessely_inverse) +
      ") - sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let besselj_bessely_same_input = @symcore.int(-1) *
    (
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
      @symcore.int(-1)
    ) *
    (
      @symelem.sqrt(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)) ^
      @symcore.int(-1)
    ) *
    @symelem.cos(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s) *
    @symspec.gamma(s) *
    @symspec.gamma(a + s) *
    @symspec.gamma(half - s) *
    (@symspec.gamma(@symcore.int(1) + a - s) ^ @symcore.int(-1))
  let besselj_bessely_same_inverse_opt = do_inverse_mellin_doit(
    besselj_bessely_same_input, s, x,
  )
  assert_true(besselj_bessely_same_inverse_opt is Some(_))
  let besselj_bessely_same_inverse = besselj_bessely_same_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(besselj_bessely_same_inverse) +
      ") - sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let exp_subst_input = @symcore.function("factorial", [
      s * (a ^ @symcore.int(-1)),
    ]) *
    (b ^ (@symcore.int(-1) * s * (a ^ @symcore.int(-1)))) *
    (s ^ @symcore.int(-1))
  let exp_subst_inverse_opt = do_inverse_mellin_doit(exp_subst_input, s, x)
  assert_true(exp_subst_inverse_opt is Some(_))
  let exp_subst_inverse = exp_subst_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(exp_subst_inverse) +
      ") - sympy.exp(-sympy.Symbol('b')*sympy.Symbol('x')**sympy.Symbol('a'))))",
    ),
    "0",
  )

  let xpow_exp_subst_input = @symcore.function("factorial", [
      a * (b ^ @symcore.int(-1)) + s * (b ^ @symcore.int(-1)),
    ]) *
    ((a + s) ^ @symcore.int(-1))
  let xpow_exp_subst_inverse_opt = do_inverse_mellin_doit(
    xpow_exp_subst_input, s, x,
  )
  assert_true(xpow_exp_subst_inverse_opt is Some(_))
  let xpow_exp_subst_inverse = xpow_exp_subst_inverse_opt.unwrap()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(xpow_exp_subst_inverse) +
      ") - (sympy.Symbol('x')**sympy.Symbol('a')*sympy.exp(-sympy.Symbol('x')**sympy.Symbol('b')))))",
    ),
    "0",
  )
}

///|
test "symintegrals parity transform conditions and auxiliary stage 5 families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let k = @symcore.Expr::Symbol("k")
  let r = @symcore.Expr::Symbol("r")
  let a = @symcore.Expr::Symbol("a")
  let m = @symcore.Expr::Symbol("m")
  let nu = @symcore.Expr::Symbol("nu")
  let half = @symcore.rational_from_ints(1, 2)

  let ours_laplace = laplace_transform_eval(
    @symelem.exp(@symcore.int(2) * x),
    x,
    s,
  )
  let ours_laplace_txt = integrals_eval_str(
    "sympy.sstr(" + py_expr(ours_laplace) + ")",
  )
  let sympy_laplace_txt = integrals_eval_str(
    "sympy.sstr(sympy.laplace_transform(sympy.exp(2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
  )
  assert_eq(ours_laplace_txt, sympy_laplace_txt)

  let ours_mellin = mellin_transform_eval(
    x * @symspec.heaviside(@symcore.int(1) - x),
    x,
    s,
  )
  let ours_mellin_txt = integrals_eval_str(
    "sympy.sstr(" + py_expr(ours_mellin) + ")",
  )
  let sympy_mellin_txt = integrals_eval_str(
    "sympy.sstr(sympy.mellin_transform(sympy.Symbol('x')*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
  )
  assert_eq(ours_mellin_txt, sympy_mellin_txt)

  let ours_sine = sine_transform_eval(@symelem.exp(@symcore.int(-2) * x), x, k)
  assert_eq(
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sine_gaussian) +
      ") - sympy.sine_transform(sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_sine_gaussian = doit(inverse_sine_transform(sine_gaussian, k, x))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inverse_sine_gaussian) +
      ") - sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x')**2)))",
    ),
    "0",
  )
  let sine_power = doit(sine_transform(x ^ (@symcore.int(-1) * a), x, k))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sine_power) +
      ") - sympy.sine_transform(sympy.Symbol('x')**(-sympy.Symbol('a')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_sine_power = doit(inverse_sine_transform(sine_power, k, x))
  assert_eq(
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_cosine) +
      ") - sympy.cosine_transform(sympy.exp(-2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inv_cosine_linear = doit(inverse_cosine_transform(ours_cosine, k, x))
  assert_eq(
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_cosine_half_power) +
      ") - 1/sympy.sqrt(sympy.Symbol('x'))))",
    ),
    "0",
  )
  let cosine_power = doit(cosine_transform(x ^ (@symcore.int(-1) * a), x, k))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(cosine_power) +
      ") - sympy.cosine_transform(sympy.Symbol('x')**(-sympy.Symbol('a')), sympy.Symbol('x'), sympy.Symbol('k'))))",
    ),
    "0",
  )
  let inverse_cosine_power = doit(inverse_cosine_transform(cosine_power, k, x))
  assert_eq(
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
      (
        (
          @symcore.int(2) *
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
        ) ^
        @symcore.int(-1)
      ),
      k,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
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
    integrals_eval_str(
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
        (
          @symcore.int(2) *
          @symelem.sqrt(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          )
        ) ^
        @symcore.int(-1)
      ),
      k,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(inv_hankel_gaussian) +
      ") - sympy.exp(-2*sympy.Symbol('r')**2)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity Laplace shift, delta, derivative, and inverse-delay rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let np = @symcore.Expr::Symbol("np")
  let y = @symcore.Expr::Symbol("y")
  let f_of_x = @symcore.raw_function("f", [x])
  let g_of_x = @symcore.raw_function("g", [x])

  let delta_eval = laplace_transform_eval(
    @symspec.dirac_delta(x - @symcore.int(2)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(delta_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.DiracDelta(sympy.Symbol('x') - 2), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )
  let delta_scaled_eval = laplace_transform_eval(
    @symspec.dirac_delta(x * @symcore.rational_from_ints(1, 42)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(delta_scaled_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.DiracDelta(sympy.Symbol('x')/42), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )
  let delta_quadratic_eval = laplace_transform_eval(
    @symspec.dirac_delta((x ^ @symcore.int(2)) - @symcore.int(1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(delta_quadratic_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.DiracDelta(sympy.Symbol('x')**2 - 1), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )
  let delta_product_eval = laplace_transform_eval(
    @symspec.dirac_delta(x * (@symcore.int(1) - x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(delta_product_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.DiracDelta(sympy.Symbol('x')*(1 - sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )

  let heaviside_eval = laplace_transform_eval(
    @symspec.heaviside(x - @symcore.int(2)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(heaviside_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(sympy.Symbol('x') - 2), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )
  let singularity_delta_eval = laplace_transform_eval(
    @symspec.singularity_function(x, a, @symcore.int(-1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(singularity_delta_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.exp(-sympy.Symbol('a')*sympy.Symbol('s')), 0, True))",
    ),
  )
  let singularity_zero_eval = laplace_transform_eval(
    @symspec.singularity_function(x, a, @symcore.int(0)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(singularity_zero_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.exp(-sympy.Symbol('a')*sympy.Symbol('s'))/sympy.Symbol('s'), 0, True))",
    ),
  )
  let singularity_linear_eval = laplace_transform_eval(
    @symspec.singularity_function(x, a, @symcore.int(1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(singularity_linear_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.exp(-sympy.Symbol('a')*sympy.Symbol('s'))/sympy.Symbol('s')**2, 0, True))",
    ),
  )
  let singularity_symbolic_eval = laplace_transform_eval(
    @symspec.singularity_function(x, a, y),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(singularity_symbolic_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.LaplaceTransform(sympy.SingularityFunction(sympy.Symbol('x'), sympy.Symbol('a'), sympy.Symbol('y')), sympy.Symbol('x'), sympy.Symbol('s')), -sympy.oo, True))",
    ),
  )
  let delta_exp_pos_eval = laplace_transform_eval(
    @symspec.dirac_delta(
      @symcore.int(2) * x - @symcore.int(2) * @symelem.exp(a),
    ),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(delta_exp_pos_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.exp(-sympy.Symbol('s')*sympy.exp(sympy.Symbol('a')))/2, -sympy.oo, True))",
    ),
  )
  let delta_exp_neg_eval = laplace_transform_eval(
    @symspec.dirac_delta(
      @symcore.int(-2) * x + @symcore.int(2) * @symelem.exp(a),
    ),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(delta_exp_neg_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.exp(-sympy.Symbol('s')*sympy.exp(sympy.Symbol('a')))/2, -sympy.oo, True))",
    ),
  )

  let shifted_poly_eval = laplace_transform_eval(
    (x - @symcore.int(2)) * @symspec.heaviside(x - @symcore.int(2)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(shifted_poly_eval) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform((sympy.Symbol('x') - 2)*sympy.Heaviside(sympy.Symbol('x') - 2), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )
  let square_piecewise_eval = laplace_transform_eval(
    @symcore.raw_function("Piecewise", [
      @symcore.int(0),
      @symcore.function("Le", [x, @symcore.int(0)]),
      @symcore.int(1),
      @symcore.function("Le", [x, @symcore.int(1)]),
      @symcore.int(0),
      @symcore.Expr::Boolean(true),
    ]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(square_piecewise_eval) +
      ")[0]) - sympy.laplace_transform(sympy.Piecewise((0, sympy.Symbol('x') <= 0), (1, sympy.Symbol('x') <= 1), (0, True)), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  let triangle_piecewise_eval = laplace_transform_eval(
    @symcore.raw_function("Piecewise", [
      @symcore.int(0),
      @symcore.function("Le", [x, @symcore.int(0)]),
      x,
      @symcore.function("Le", [x, @symcore.int(1)]),
      @symcore.int(2) - x,
      @symcore.function("Le", [x, @symcore.int(2)]),
      @symcore.int(0),
      @symcore.Expr::Boolean(true),
    ]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(triangle_piecewise_eval) +
      ")[0]) - sympy.laplace_transform(sympy.Piecewise((0, sympy.Symbol('x') <= 0), (sympy.Symbol('x'), sympy.Symbol('x') <= 1), (2 - sympy.Symbol('x'), sympy.Symbol('x') <= 2), (0, True)), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  let middle_piecewise_eval = laplace_transform_eval(
    a *
    @symcore.raw_function("Piecewise", [
      @symcore.int(1),
      @symcore.function("And", [
        @symcore.function("Gt", [x, @symcore.int(1)]),
        @symcore.function("Le", [x, @symcore.int(3)]),
      ]),
      @symcore.int(2),
      @symcore.Expr::Boolean(true),
    ]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(middle_piecewise_eval) +
      ")[0]) - sympy.laplace_transform(sympy.Symbol('a')*sympy.Piecewise((1, sympy.And(sympy.Symbol('x') > 1, sympy.Symbol('x') <= 3)), (2, True)), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )

  let deriv1_eval = laplace_transform_eval(
    @symcore.raw_function("Derivative", [f_of_x, x]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(deriv1_eval) + ")"),
    integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.laplace_transform(sympy.Derivative(sympy.Function('f')(x), x), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
  )

  let deriv2_eval = laplace_transform_eval(
    @symcore.raw_function("Derivative", [f_of_x, x, @symcore.int(2)]),
    x,
    s,
  )
  let neg_half = @symcore.rational_from_ints(-1, 2)
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(deriv2_eval) + ")"),
    integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.laplace_transform(sympy.Derivative(sympy.Function('f')(x), (x, 2)), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
  )

  let generic_eval = laplace_transform_eval(f_of_x, x, s)
  assert_eq(
    integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.laplace_transform(sympy.Function('f')(x), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(generic_eval) + ")"),
  )

  let scaled_generic_eval = laplace_transform_eval(a * f_of_x, x, s)
  assert_eq(
    integrals_eval_str(
      "(lambda x: sympy.sstr(sympy.laplace_transform(sympy.Symbol('a')*sympy.Function('f')(x), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(scaled_generic_eval) + ")"),
  )

  let shifted_generic_eval = laplace_transform_eval(
    @symelem.exp(a * (x * @symcore.int(-1))) * f_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('a') + sympy.Symbol('s')), -sympy.re(sympy.Symbol('a')) - sympy.oo, True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(shifted_generic_eval) + ")"),
  )

  let neg_heaviside_generic_eval = laplace_transform_eval(
    a *
    @symspec.heaviside(x + @symcore.int(1)) *
    @symcore.raw_function("f", [x + @symcore.int(1)]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Symbol('a')*sympy.Heaviside(sympy.Symbol('x') + 1)*sympy.Function('f')(sympy.Symbol('x') + 1), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str(
      "sympy.sstr(" + py_expr(neg_heaviside_generic_eval) + ")",
    ),
  )

  let pos_heaviside_generic_eval = laplace_transform_eval(
    a *
    @symspec.heaviside(x - @symcore.int(1)) *
    @symcore.raw_function("f", [x - @symcore.int(1)]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Symbol('a')*sympy.Heaviside(sympy.Symbol('x') - 1)*sympy.Function('f')(sympy.Symbol('x') - 1), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str(
      "sympy.sstr(" + py_expr(pos_heaviside_generic_eval) + ")",
    ),
  )

  let scaled_arg_generic_eval = laplace_transform_eval(
    b * @symcore.raw_function("f", [x * (a ^ @symcore.int(-1))]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Symbol('b')*sympy.Function('f')(sympy.Symbol('x')/sympy.Symbol('a')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(scaled_arg_generic_eval) + ")"),
  )

  let scaled_numeric_generic_eval = laplace_transform_eval(
    b * @symcore.raw_function("f", [@symcore.int(2) * x]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Symbol('b')*sympy.Function('f')(2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str(
      "sympy.sstr(" + py_expr(scaled_numeric_generic_eval) + ")",
    ),
  )

  let scaled_numeric_sum_eval = laplace_transform_eval(
    a * @symcore.raw_function("f", [@symcore.int(2) * x]) +
    @symcore.raw_function("g", [@symcore.int(3) * x]),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Symbol('a')*sympy.Function('f')(2*sympy.Symbol('x')) + sympy.Function('g')(3*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(scaled_numeric_sum_eval) + ")"),
  )

  let heaviside_pos_affine_eval = laplace_transform_eval(
    @symspec.heaviside(@symcore.int(2) * x - @symcore.int(4)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(2*sympy.Symbol('x') - 4), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(heaviside_pos_affine_eval) + ")"),
  )

  let heaviside_pos_past_zero_eval = laplace_transform_eval(
    @symspec.heaviside(@symcore.int(2) * x + @symcore.int(4)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(2*sympy.Symbol('x') + 4), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str(
      "sympy.sstr(" + py_expr(heaviside_pos_past_zero_eval) + ")",
    ),
  )

  let heaviside_neg_affine_eval = laplace_transform_eval(
    @symspec.heaviside(@symcore.int(-2) * x + @symcore.int(4)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(-2*sympy.Symbol('x') + 4), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(heaviside_neg_affine_eval) + ")"),
  )

  let lower_window_generic_eval = laplace_transform_eval(
    @symspec.heaviside(@symcore.int(2) * x - @symcore.int(4)) * g_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(2*sympy.Symbol('x') - 4)*sympy.Function('g')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(lower_window_generic_eval) + ")"),
  )

  let upper_window_generic_eval = laplace_transform_eval(
    @symspec.heaviside(@symcore.int(-1) * x + @symcore.int(2)) * g_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(-sympy.Symbol('x') + 2)*sympy.Function('g')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(upper_window_generic_eval) + ")"),
  )

  let upper_window_zero_eval = laplace_transform_eval(
    @symspec.heaviside(@symcore.int(-1) * x - @symcore.int(2)) * g_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.Heaviside(-sympy.Symbol('x') - 2)*sympy.Function('g')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(upper_window_zero_eval) + ")"),
  )

  let x_generic_eval = laplace_transform_eval(x * f_of_x, x, s)
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(-sympy.Derivative(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')), sympy.Symbol('s')), -sympy.oo, True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(x_generic_eval) + ")"),
  )
  let xn_generic_eval = laplace_transform_eval((x ^ np) * g_of_x, x, s)
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple((-1)**sympy.Symbol('np')*sympy.Derivative(sympy.LaplaceTransform(sympy.Function('g')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('np')), -sympy.oo, True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(xn_generic_eval) + ")"),
  )

  let external_exp_generic_eval = laplace_transform_eval(
    @symelem.exp(@symcore.int(-1) * @symcore.raw_function("f", [y]) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.exp(-sympy.Function('f')(sympy.Symbol('y'))*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(external_exp_generic_eval) + ")"),
  )

  let poly_generic_eval = laplace_transform_eval(
    (a * (x ^ @symcore.int(2)) + b * x + c) * f_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.Symbol('a')*sympy.Derivative(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')), (sympy.Symbol('s'), 2)) - sympy.Symbol('b')*sympy.Derivative(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')), sympy.Symbol('s')) + sympy.Symbol('c')*sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')), -sympy.oo, True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(poly_generic_eval) + ")"),
  )

  let sinh_generic_eval = laplace_transform_eval(
    @symelem.sinh(a * x) * f_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), -sympy.Symbol('a') + sympy.Symbol('s'))/2 - sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('a') + sympy.Symbol('s'))/2, sympy.Max(-sympy.re(sympy.Symbol('a')) - sympy.oo, sympy.re(sympy.Symbol('a')) - sympy.oo), True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(sinh_generic_eval) + ")"),
  )

  let cosh_generic_eval = laplace_transform_eval(
    @symelem.cosh(a * x) * f_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), -sympy.Symbol('a') + sympy.Symbol('s'))/2 + sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('a') + sympy.Symbol('s'))/2, sympy.Max(-sympy.re(sympy.Symbol('a')) - sympy.oo, sympy.re(sympy.Symbol('a')) - sympy.oo), True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(cosh_generic_eval) + ")"),
  )

  let sin_generic_eval = laplace_transform_eval(
    @symelem.sin(a * x) * f_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.I*(-sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), -sympy.I*sympy.Symbol('a') + sympy.Symbol('s')) + sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.I*sympy.Symbol('a') + sympy.Symbol('s')))/2, sympy.Max(-sympy.im(sympy.Symbol('a')) - sympy.oo, sympy.im(sympy.Symbol('a')) - sympy.oo), True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(sin_generic_eval) + ")"),
  )

  let cos_generic_eval = laplace_transform_eval(
    @symelem.cos(a * x) * f_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), -sympy.I*sympy.Symbol('a') + sympy.Symbol('s'))/2 + sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.I*sympy.Symbol('a') + sympy.Symbol('s'))/2, sympy.Max(-sympy.im(sympy.Symbol('a')) - sympy.oo, sympy.im(sympy.Symbol('a')) - sympy.oo), True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(cos_generic_eval) + ")"),
  )

  let sin_sq_generic_eval = laplace_transform_eval(
    (@symelem.sin(a * x + b) ^ @symcore.int(2)) * f_of_x,
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Tuple(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'))/2 - sympy.exp(2*sympy.I*sympy.Symbol('b'))*sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), -2*sympy.I*sympy.Symbol('a') + sympy.Symbol('s'))/4 - sympy.exp(-2*sympy.I*sympy.Symbol('b'))*sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), 2*sympy.I*sympy.Symbol('a') + sympy.Symbol('s'))/4, -sympy.oo, True))",
    ),
    integrals_eval_str("sympy.sstr(" + py_expr(sin_sq_generic_eval) + ")"),
  )

  let mt = @symmatrices.matrix([
    [@symelem.exp(x), x * @symelem.exp(@symcore.int(-1) * x)],
    [x * @symelem.exp(@symcore.int(-1) * x), @symelem.exp(x)],
  ]) catch {
    _ => fail("matrix lt failed")
  }
  let (matrix_laplace, matrix_plane, matrix_cond) = @symintegrals.laplace_transform_matrix_result(
    mt, x, s,
  ) catch {
    _ => fail("matrix lt result failed")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" +
      py_matrix_expr(matrix_laplace) +
      ") - sympy.Matrix([[1/(sympy.Symbol('s') - 1), (sympy.Symbol('s') + 1)**(-2)], [(sympy.Symbol('s') + 1)**(-2), 1/(sympy.Symbol('s') - 1)]])).equals(sympy.zeros(2)))",
    ),
    "True",
  )
  inspect(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(" +
      py_expr(matrix_plane) +
      " - sympy.Integer(1)))",
    ),
    content="0",
  )
  inspect(
    integrals_eval_str("sympy.sstr(" + py_expr(matrix_cond) + ")"),
    content="True",
  )

  let ci_laplace = doit(laplace_transform(@symspec.ci(x), x, s))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ci_laplace) +
      ") - sympy.laplace_transform(sympy.Ci(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )

  let si_laplace = doit(laplace_transform(@symspec.si(x), x, s))
  for sample in ["sympy.Integer(2)", "sympy.Integer(3)"] {
    assert_eq(
      integrals_eval_str(
        "sympy.sstr(sympy.Abs(sympy.N(((" +
        py_expr(si_laplace) +
        ").subs(sympy.Symbol('s'), " +
        sample +
        ")) - (sympy.laplace_transform(sympy.Si(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True).subs(sympy.Symbol('s'), " +
        sample +
        ")), 50)) < sympy.Float('1e-40'))",
      ),
      "True",
    )
  }

  let shi_laplace = laplace_transform_eval(@symspec.shi(x), x, s)
  for sample in ["sympy.Integer(2)", "sympy.Integer(3)"] {
    assert_eq(
      integrals_eval_str(
        "sympy.sstr(sympy.Abs(sympy.N(((" +
        py_expr(shi_laplace) +
        ")[0]).subs(sympy.Symbol('s'), " +
        sample +
        ") - (sympy.laplace_transform(sympy.Shi(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True).subs(sympy.Symbol('s'), " +
        sample +
        ")), 50)) < sympy.Float('1e-40'))",
      ),
      "True",
    )
  }
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(shi_laplace) + ")[1])"),
    "-oo",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(shi_laplace) + ")[2])"),
    "s**2 > 1",
  )

  let chi_laplace = laplace_transform_eval(@symspec.chi(x), x, s)
  for sample in ["sympy.Integer(2)", "sympy.Integer(3)"] {
    assert_eq(
      integrals_eval_str(
        "sympy.sstr(sympy.Abs(sympy.N(((" +
        py_expr(chi_laplace) +
        ")[0]).subs(sympy.Symbol('s'), " +
        sample +
        ") - (sympy.laplace_transform(sympy.Chi(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True).subs(sympy.Symbol('s'), " +
        sample +
        ")), 50)) < sympy.Float('1e-40'))",
      ),
      "True",
    )
  }
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(chi_laplace) + ")[1])"),
    "-oo",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(chi_laplace) + ")[2])"),
    "s**2 > 1",
  )

  let e1_laplace = doit(laplace_transform(@symspec.e1(x), x, s))
  assert_eq(
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(expint2_laplace) +
      ") - sympy.laplace_transform(sympy.expint(2, sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  let expinta_laplace = laplace_transform_eval(@symspec.expint(a, x), x, s)
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(expinta_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.expint(sympy.Symbol('a'), sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), simplify=True, noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(expinta_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(expinta_laplace) + ")[2])"),
    "re(a) > 0",
  )
  let power_laplace = laplace_transform_eval(x ^ a, x, s)
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(power_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.Symbol('x')**sympy.Symbol('a'), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(power_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(power_laplace) + ")[2])"),
    "re(a) > -1",
  )
  let damped_power_laplace = laplace_transform_eval(
    @symelem.exp(@symcore.int(-1) * b * x) * (x ^ a),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(damped_power_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.exp(-sympy.Symbol('b')*sympy.Symbol('x'))*sympy.Symbol('x')**sympy.Symbol('a'), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(damped_power_laplace) + ")[1])"),
    "-re(b)",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(damped_power_laplace) + ")[2])"),
    "re(a) > -1",
  )

  let log_laplace = laplace_transform_eval(@symelem.log(x), x, s)
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.log(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_laplace) + ")[2])"),
    "True",
  )

  let log_one_plus_laplace = laplace_transform_eval(
    @symelem.log(@symcore.int(1) + @symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_one_plus_laplace) + ")[0])"),
    integrals_eval_str(
      "sympy.sstr(sympy.laplace_transform(sympy.log(1 + 2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))",
    ),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_one_plus_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_one_plus_laplace) + ")[2])"),
    "True",
  )

  let log_shifted_laplace = laplace_transform_eval(@symelem.log(x + a), x, s)
  for
    sample in [
      ("sympy.Integer(2)", "sympy.Integer(3)"),
      ("sympy.Integer(5)", "sympy.Integer(2)"),
    ] {
    assert_eq(
      integrals_eval_str(
        "sympy.sstr(sympy.Abs(sympy.N(((" +
        py_expr(log_shifted_laplace) +
        ")[0]).subs({sympy.Symbol('a'): " +
        sample.0 +
        ", sympy.Symbol('s'): " +
        sample.1 +
        "}) - sympy.laplace_transform(sympy.log(sympy.Symbol('x') + " +
        sample.0 +
        "), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True).subs(sympy.Symbol('s'), " +
        sample.1 +
        "), 50)) < sympy.Float('1e-40'))",
      ),
      "True",
    )
  }
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_shifted_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_shifted_laplace) + ")[2])"),
    "True",
  )

  let log_square_laplace = laplace_transform_eval(
    @symelem.log(x) ^ @symcore.int(2),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(log_square_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.log(sympy.Symbol('x'))**2, sympy.Symbol('x'), sympy.Symbol('s'), simplify=True, noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_square_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(log_square_laplace) + ")[2])"),
    "True",
  )

  let sin_over_x_laplace = laplace_transform_eval(
    @symelem.sin(a * x) * (x ^ @symcore.int(-1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_over_x_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sin(sympy.Symbol('a')*sympy.Symbol('x'))/sympy.Symbol('x'), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sin_over_x_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sin_over_x_laplace) + ")[2])"),
    "True",
  )

  let sinh_over_x_laplace = laplace_transform_eval(
    @symelem.sinh(a * x) * (x ^ @symcore.int(-1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sinh_over_x_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sinh(sympy.Symbol('a')*sympy.Symbol('x'))/sympy.Symbol('x'), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sinh_over_x_laplace) + ")[1])"),
    "Abs(re(a))",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sinh_over_x_laplace) + ")[2])"),
    "True",
  )

  let gaussian_laplace = laplace_transform_eval(
    @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2))),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(gaussian_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.exp(-2*sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(gaussian_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(gaussian_laplace) + ")[2])"),
    "True",
  )
  let x_gaussian_laplace = laplace_transform_eval(
    x * @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2))),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(x_gaussian_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(x_gaussian_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(x_gaussian_laplace) + ")[2])"),
    "True",
  )
  let x2_gaussian_laplace = laplace_transform_eval(
    (x ^ @symcore.int(2)) *
    @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(2))),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(x2_gaussian_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.Symbol('x')**2*sympy.exp(-sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(x2_gaussian_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(x2_gaussian_laplace) + ")[2])"),
    "True",
  )

  let sin_sq_phase_laplace = laplace_transform_eval(
    @symelem.sin(a * x + b) ^ @symcore.int(2),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_sq_phase_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sin(sympy.Symbol('a')*sympy.Symbol('x') + sympy.Symbol('b'))**2, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sin_sq_phase_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sin_sq_phase_laplace) + ")[2])"),
    "True",
  )
  let cos_sq_laplace = laplace_transform_eval(
    @symelem.cos(@symcore.int(2) * x) ^ @symcore.int(2),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(cos_sq_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.cos(2*sympy.Symbol('x'))**2, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(cos_sq_laplace) + ")[1])"),
    "0",
  )
  let sinh_sq_laplace = laplace_transform_eval(
    @symelem.sinh(@symcore.int(2) * x) ^ @symcore.int(2),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sinh_sq_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sinh(2*sympy.Symbol('x'))**2, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sinh_sq_laplace) + ")[1])"),
    "4",
  )
  let cosh_sq_laplace = laplace_transform_eval(
    @symelem.cosh(@symcore.int(2) * x) ^ @symcore.int(2),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(cosh_sq_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.cosh(2*sympy.Symbol('x'))**2, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(cosh_sq_laplace) + ")[1])"),
    "4",
  )
  let sin_fourth_laplace = laplace_transform_eval(
    @symelem.sin(@symcore.int(2) * x) ^ @symcore.int(4),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_fourth_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sin(2*sympy.Symbol('x'))**4, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sin_fourth_laplace) + ")[1])"),
    "0",
  )
  let sinh_cosh_laplace = laplace_transform_eval(
    @symelem.sinh(@symcore.int(2) * x) * @symelem.cosh(@symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sinh_cosh_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sinh(2*sympy.Symbol('x'))*sympy.cosh(2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(sinh_cosh_laplace) + ")[1])"),
    "4",
  )
  let sin_cubic_cosh_laplace = laplace_transform_eval(
    (@symelem.sin(@symcore.int(2) * x) ^ @symcore.int(3)) *
    @symelem.cosh(@symcore.int(3) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_cubic_cosh_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sin(2*sympy.Symbol('x'))**3*sympy.cosh(3*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr((" + py_expr(sin_cubic_cosh_laplace) + ")[1])",
    ),
    "3",
  )
  let abs_sin_laplace = laplace_transform_eval(
    @symelem.abs(@symelem.sin(@symcore.int(2) * x)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(abs_sin_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.Abs(sympy.sin(2*sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(abs_sin_laplace) + ")[1])"),
    "0",
  )
  let sin_sq_over_x_laplace = laplace_transform_eval(
    (@symelem.sin(@symcore.int(2) * x) ^ @symcore.int(2)) *
    (x ^ @symcore.int(-1)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_sq_over_x_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sin(2*sympy.Symbol('x'))**2/sympy.Symbol('x'), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr((" + py_expr(sin_sq_over_x_laplace) + ")[1])",
    ),
    "0",
  )
  let sin_sq_over_x2_laplace = laplace_transform_eval(
    (@symelem.sin(@symcore.int(2) * x) ^ @symcore.int(2)) *
    (x ^ @symcore.int(-2)),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(sin_sq_over_x2_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.sin(2*sympy.Symbol('x'))**2/sympy.Symbol('x')**2, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr((" + py_expr(sin_sq_over_x2_laplace) + ")[1])",
    ),
    "0",
  )

  let erf_laplace = laplace_transform_eval(
    @symspec.erf(@symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(erf_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.erf(2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(erf_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(erf_laplace) + ")[2])"),
    "True",
  )

  let besselj0_laplace = laplace_transform_eval(
    @symspec.besselj(@symcore.int(0), @symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselj0_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.besselj(0, 2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  let xbesselj0_laplace = laplace_transform_eval(
    x * @symspec.besselj(@symcore.int(0), @symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(xbesselj0_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.Symbol('x')*sympy.besselj(0, 2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )

  let besseli0_laplace = laplace_transform_eval(
    @symspec.besseli(@symcore.int(0), @symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besseli0_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.besseli(0, 2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(besseli0_laplace) + ")[1])"),
    "2",
  )
  let xbesseli0_laplace = laplace_transform_eval(
    x * @symspec.besseli(@symcore.int(0), @symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(xbesseli0_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.Symbol('x')*sympy.besseli(0, 2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(xbesseli0_laplace) + ")[1])"),
    "2",
  )
  let bessely0_laplace = laplace_transform_eval(
    @symspec.bessely(@symcore.int(0), @symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(bessely0_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.bessely(0, 2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(bessely0_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(bessely0_laplace) + ")[2])"),
    "True",
  )
  let besselk0_laplace = laplace_transform_eval(
    @symspec.besselk(@symcore.int(0), @symcore.int(2) * x),
    x,
    s,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(besselk0_laplace) +
      ")[0]) - sympy.laplace_transform(sympy.besselk(0, 2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(besselk0_laplace) + ")[1])"),
    "-2",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(besselk0_laplace) + ")[2])"),
    "True",
  )

  let fresnels_laplace = laplace_transform_eval(@symspec.fresnels(x), x, s)
  for sample in ["sympy.Integer(2)", "sympy.Integer(3)"] {
    assert_eq(
      integrals_eval_str(
        "sympy.sstr(sympy.Abs(sympy.N(((" +
        py_expr(fresnels_laplace) +
        ")[0]).subs(sympy.Symbol('s'), " +
        sample +
        ") - (sympy.laplace_transform(sympy.fresnels(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True).subs(sympy.Symbol('s'), " +
        sample +
        ")), 50)) < sympy.Float('1e-40'))",
      ),
      "True",
    )
  }
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(fresnels_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(fresnels_laplace) + ")[2])"),
    "True",
  )
  let fresnelc_laplace = laplace_transform_eval(@symspec.fresnelc(x), x, s)
  for sample in ["sympy.Integer(2)", "sympy.Integer(3)"] {
    assert_eq(
      integrals_eval_str(
        "sympy.sstr(sympy.Abs(sympy.N(((" +
        py_expr(fresnelc_laplace) +
        ")[0]).subs(sympy.Symbol('s'), " +
        sample +
        ") - (sympy.laplace_transform(sympy.fresnelc(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True).subs(sympy.Symbol('s'), " +
        sample +
        ")), 50)) < sympy.Float('1e-40'))",
      ),
      "True",
    )
  }
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(fresnelc_laplace) + ")[1])"),
    "0",
  )
  assert_eq(
    integrals_eval_str("sympy.sstr((" + py_expr(fresnelc_laplace) + ")[2])"),
    "True",
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(expint2_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.expint(2, sympy.Symbol('x')))))",
    ),
    "0",
  )

  let log_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(-1) *
      (
        @symelem.log(s) +
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma)
      ) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.log(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let log_one_plus_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(-1) *
      @symelem.exp(s * (a ^ @symcore.int(-1))) *
      @symspec.ei(@symcore.int(-1) * s * (a ^ @symcore.int(-1))) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(log_one_plus_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.log(1 + sympy.Symbol('a')*sympy.Symbol('x')))))",
    ),
    "0",
  )

  let atan_inverse = doit(
    inverse_laplace_transform(@symelem.atan(a * (s ^ @symcore.int(-1))), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(atan_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.sin(sympy.Symbol('a')*sympy.Symbol('x'))/sympy.Symbol('x'))))",
    ),
    "0",
  )

  let sinh_over_x_inverse = doit(
    inverse_laplace_transform(
      @symcore.rational_from_ints(1, 2) *
      @symelem.log((a + s) * ((s - a) ^ @symcore.int(-1))),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sinh_over_x_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.sinh(sympy.Symbol('a')*sympy.Symbol('x'))/sympy.Symbol('x'))))",
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
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
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(shifted_quad_num_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s') + 1)/((sympy.Symbol('s') + 1)**2 + 4), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_sum_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt((s ^ @symcore.int(2)) + @symcore.int(4)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_sum_inverse) +
      ") - sympy.inverse_laplace_transform(1/sympy.sqrt(sympy.Symbol('s')**2 + 4), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_diff_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt((s ^ @symcore.int(2)) - @symcore.int(4)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_diff_inverse) +
      ") - sympy.inverse_laplace_transform(1/sympy.sqrt(sympy.Symbol('s')**2 - 4), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_plus_const_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(3) * s) + @symcore.int(2)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_plus_const_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(3*sympy.Symbol('s')) + 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_times_sqrt_linear_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      (
        (@symelem.sqrt(@symcore.int(5) * s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_times_sqrt_linear_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(5*sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_shifted_linear_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s + @symcore.int(3)) ^ @symcore.int(-1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_shifted_linear_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s') + 3)*(sympy.Symbol('s') + 1)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_shifted_over_s_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s + @symcore.int(1)) ^ @symcore.int(-1)) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_shifted_over_s_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*sympy.sqrt(sympy.Symbol('s') + 1)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_affine_linear_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(-2)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_affine_linear_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(3*sympy.Symbol('s') - 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_affine_linear_over_s_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(-2)) ^ @symcore.int(-1)) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_affine_linear_over_s_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(5*sympy.Symbol('s'))*(3*sympy.Symbol('s') - 2)*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_sqrt_over_s_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(2) *
      (s ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_sqrt_over_s_inverse) +
      ") - sympy.inverse_laplace_transform(2/(sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_over_s_three_halves_inverse = doit(
    inverse_laplace_transform(
      (a ^ @symcore.int(2)) *
      (s ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Abs(sympy.N(((" +
      py_expr(sqrt_linear_over_s_three_halves_inverse) +
      ").subs({sympy.Symbol('a'): sympy.Integer(2), sympy.Symbol('x'): sympy.Integer(1)})) - (sympy.inverse_laplace_transform(2**2/(sympy.Symbol('s')*sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True).subs(sympy.Symbol('x'), sympy.Integer(1))), 50)) < sympy.Float('1e-40'))",
    ),
    "True",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Abs(sympy.N(((" +
      py_expr(sqrt_linear_over_s_three_halves_inverse) +
      ").subs({sympy.Symbol('a'): sympy.Integer(3), sympy.Symbol('x'): sympy.Integer(2)})) - (sympy.inverse_laplace_transform(3**2/(sympy.Symbol('s')*sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + 3)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True).subs(sympy.Symbol('x'), sympy.Integer(2))), 50)) < sympy.Float('1e-40'))",
    ),
    "True",
  )

  let scaled_sqrt_ratio_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(-2)) *
      (s ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_sqrt_ratio_inverse) +
      ") - sympy.inverse_laplace_transform((3*sympy.sqrt(sympy.Symbol('s')) - 2)/(sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let mixed_sqrt_shifted_linear_inverse = doit(
    inverse_laplace_transform(
      (a - b) *
      @symelem.sqrt(s) *
      ((@symelem.sqrt(s) + @symelem.sqrt(a)) ^ @symcore.int(-1)) *
      ((s - b) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Abs(sympy.N(((" +
      py_expr(mixed_sqrt_shifted_linear_inverse) +
      ").subs({sympy.Symbol('a'): sympy.Integer(5), sympy.Symbol('b'): sympy.Integer(2), sympy.Symbol('x'): sympy.Integer(1)})) - (sympy.inverse_laplace_transform((5 - 2)*sympy.sqrt(sympy.Symbol('s'))/((sympy.sqrt(sympy.Symbol('s')) + sympy.sqrt(5))*(sympy.Symbol('s') - 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True).subs(sympy.Symbol('x'), sympy.Integer(1))), 50)) < sympy.Float('1e-40'))",
    ),
    "True",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Abs(sympy.N(((" +
      py_expr(mixed_sqrt_shifted_linear_inverse) +
      ").subs({sympy.Symbol('a'): sympy.Integer(8), sympy.Symbol('b'): sympy.Integer(3), sympy.Symbol('x'): sympy.Integer(2)})) - (sympy.inverse_laplace_transform((8 - 3)*sympy.sqrt(sympy.Symbol('s'))/((sympy.sqrt(sympy.Symbol('s')) + sympy.sqrt(8))*(sympy.Symbol('s') - 3)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True).subs(sympy.Symbol('x'), sympy.Integer(2))), 50)) < sympy.Float('1e-40'))",
    ),
    "True",
  )

  let mixed_recip_sqrt_shifted_linear_inverse = doit(
    inverse_laplace_transform(
      (a - b) *
      @symelem.sqrt(b) *
      ((s - b) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symelem.sqrt(a)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Abs(sympy.N(((" +
      py_expr(mixed_recip_sqrt_shifted_linear_inverse) +
      ").subs({sympy.Symbol('a'): sympy.Integer(5), sympy.Symbol('b'): sympy.Integer(2), sympy.Symbol('x'): sympy.Integer(1)})) - (sympy.inverse_laplace_transform((5 - 2)*sympy.sqrt(2)/((sympy.Symbol('s') - 2)*sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + sympy.sqrt(5))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True).subs(sympy.Symbol('x'), sympy.Integer(1))), 50)) < sympy.Float('1e-40'))",
    ),
    "True",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.Abs(sympy.N(((" +
      py_expr(mixed_recip_sqrt_shifted_linear_inverse) +
      ").subs({sympy.Symbol('a'): sympy.Integer(8), sympy.Symbol('b'): sympy.Integer(3), sympy.Symbol('x'): sympy.Integer(2)})) - (sympy.inverse_laplace_transform((8 - 3)*sympy.sqrt(3)/((sympy.Symbol('s') - 3)*sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + sympy.sqrt(8))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True).subs(sympy.Symbol('x'), sympy.Integer(2))), 50)) < sympy.Float('1e-40'))",
    ),
    "True",
  )

  let sqrt_linear_squared_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_squared_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s')) + 2)**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_squared_over_s_inverse = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_squared_over_s_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*(sympy.sqrt(sympy.Symbol('s')) + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_squared_over_sqrt_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_squared_over_sqrt_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_cubed_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_cubed_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s')) + 2)**3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_over_sqrt_linear_cubed_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt(s) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_over_sqrt_linear_cubed_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(sympy.Symbol('s'))/(sympy.sqrt(sympy.Symbol('s')) + 2)**3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_cubed_over_sqrt_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_cubed_over_sqrt_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + 2)**3), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_quartic_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(3) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-4)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_quartic_inverse) +
      ") - sympy.factor_terms(sympy.inverse_laplace_transform(3/(sympy.sqrt(sympy.Symbol('s')) + 2)**4, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True))))",
    ),
    "0",
  )

  let shifted_sqrt_over_linear_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt(s + @symcore.int(3)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(shifted_sqrt_over_linear_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(sympy.Symbol('s') + 3)/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_sqrt_ratio_squared_inverse = doit(
    inverse_laplace_transform(
      ((@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(2)) *
      (s ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_sqrt_ratio_squared_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.sqrt(sympy.Symbol('s')) - 2)**2/(sympy.Symbol('s')*(sympy.sqrt(sympy.Symbol('s')) + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_sqrt_ratio_cubed_inverse = doit(
    inverse_laplace_transform(
      ((@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(3)) *
      (s ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_sqrt_ratio_cubed_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.sqrt(sympy.Symbol('s')) - 2)**3/(sympy.Symbol('s')*(sympy.sqrt(sympy.Symbol('s')) + 2)**3), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let t = @symcore.Expr::Symbol("t")
  let f_t = @symcore.raw_function("f", [t])
  let ilt_roundtrip = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ilt_roundtrip) +
      ") - (sympy.Function('f')(sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let k = @symcore.Expr::Symbol("k")
  let f_big_of_s = @symcore.raw_function("F", [s])
  let generic_fdict : Map[String, String] = { "f": "F" }

  let generic_delay = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symelem.exp(@symcore.int(-1) * a * s) * f_big_of_s,
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_delay) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Function('f')(sympy.Symbol('x') - sympy.Symbol('a')))",
    ),
  )

  let generic_shift = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(k * @symcore.raw_function("F", [s - a]), s, x),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Symbol('k')*sympy.exp(-sympy.Symbol('a')*sympy.Symbol('x'))*sympy.Function('f')(sympy.Symbol('x')))",
    ),
  )

  let generic_diff3 = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.raw_function("Derivative", [f_big_of_s, s, @symcore.int(3)]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_diff3) + ")"),
    integrals_eval_str(
      "sympy.sstr(-sympy.Symbol('x')**3*sympy.Function('f')(sympy.Symbol('x')))",
    ),
  )

  let generic_diff4 = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.raw_function("Derivative", [f_big_of_s, s, @symcore.int(4)]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_diff4) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Symbol('x')**4*sympy.Function('f')(sympy.Symbol('x')))",
    ),
  )

  let symbolic_power_inverse = doit(
    inverse_laplace_transform(s ^ (@symcore.int(-1) * b), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_power_inverse) +
      ") - (sympy.Symbol('x')**(sympy.Symbol('b') - 1)*sympy.Heaviside(sympy.Symbol('x'))/sympy.gamma(sympy.Symbol('b')))))",
    ),
    "0",
  )

  let delayed_symbolic_power_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_symbolic_power_inverse) +
      ") - (((sympy.Symbol('x') - sympy.Symbol('a'))**(sympy.Symbol('b') - 1))*sympy.Heaviside(sympy.Symbol('x') - sympy.Symbol('a'))/sympy.gamma(sympy.Symbol('b')))))",
    ),
    "0",
  )

  let bessel_i_branch_inverse = doit(
    inverse_laplace_transform(
      (a ^ b) *
      (
        (s + @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2)))) ^
        (@symcore.int(-1) * b)
      ) *
      (
        @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(bessel_i_branch_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.besseli(sympy.Symbol('b'), sympy.Symbol('a')*sympy.Symbol('x')))))",
    ),
    "0",
  )

  let bessel_j_branch_inverse = doit(
    inverse_laplace_transform(
      (a ^ b) *
      (
        (s + @symelem.sqrt((s ^ @symcore.int(2)) + (a ^ @symcore.int(2)))) ^
        (@symcore.int(-1) * b)
      ) *
      (
        @symelem.sqrt((s ^ @symcore.int(2)) + (a ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(bessel_j_branch_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.besselj(sympy.Symbol('b'), sympy.Symbol('a')*sympy.Symbol('x')))))",
    ),
    "0",
  )

  let delayed_constant_inverse = doit(
    inverse_laplace_transform(a * @symelem.exp(@symcore.int(-3) * s), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_constant_inverse) +
      ") - (sympy.Symbol('a')*sympy.DiracDelta(sympy.Symbol('x') - 3))))",
    ),
    "0",
  )

  let polynomial_delta_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(1) +
      @symcore.int(2) * s +
      @symcore.int(3) * (s ^ @symcore.int(2)) +
      @symcore.int(5) * (s ^ @symcore.int(3)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(polynomial_delta_inverse) +
      ") - (sympy.DiracDelta(sympy.Symbol('x')) + 2*sympy.DiracDelta(sympy.Symbol('x'), 1) + 3*sympy.DiracDelta(sympy.Symbol('x'), 2) + 5*sympy.DiracDelta(sympy.Symbol('x'), 3))))",
    ),
    "0",
  )

  let f_of_s = @symcore.raw_function("f", [s])
  let time_diff_inverse = doit(
    inverse_laplace_transform((s ^ @symcore.int(42)) * f_of_s, s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(time_diff_inverse) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Derivative(sympy.InverseLaplaceTransform(sympy.Function('f')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0), (sympy.Symbol('x'), 42)))",
    ),
  )

  let delayed_bessel_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) *
      (
        @symelem.sqrt(@symcore.int(1) + (s ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_bessel_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x') - sympy.Symbol('a'))*sympy.besselj(0, sympy.Symbol('x') - sympy.Symbol('a')))))",
    ),
    "0",
  )

  let eye2 = @symmatrices.eye(2) catch { _ => fail("eye failed") }
  let diagm = @symmatrices.matrix([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(2)],
  ]) catch {
    _ => fail("matrix failed")
  }
  let resolvent = (eye2.scalar_mul(s) - diagm).inv() catch {
    _ => fail("inverse failed")
  }
  let matrix_inverse = @symintegrals.inverse_laplace_transform_matrix(
    resolvent, s, x,
  ) catch {
    _ => fail("matrix ilt failed")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(((" +
      py_matrix_expr(matrix_inverse) +
      ") - sympy.Matrix([[sympy.exp(sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), 0], [0, sympy.exp(2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x'))]])).equals(sympy.zeros(2)))",
    ),
    "True",
  )

  let r = @symcore.Expr::Symbol("r")
  let positive_shift_object = doit(
    inverse_laplace_transform(@symelem.exp(@symcore.int(2) * s), s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(positive_shift_object) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0))",
    ),
  )

  let symbolic_shift_object = doit(
    inverse_laplace_transform(@symelem.exp(r * s), s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(symbolic_shift_object) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(sympy.Symbol('r')*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0))",
    ),
  )

  let symbolic_shift_noconds = @symintegrals.inverse_laplace_transform_eval(
    @symelem.exp(r * s),
    s,
    x,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(symbolic_shift_noconds) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.inverse_laplace_transform(sympy.exp(sympy.Symbol('r')*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=False))",
    ),
  )

  let cos_object = doit(inverse_laplace_transform(@symelem.cos(s), s, x))
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(cos_object) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.cos(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0))",
    ),
  )

  let z = @symcore.Expr::Symbol("z")
  let generic_complex_shift = doit(
    inverse_laplace_transform(@symelem.exp(z * s), s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_complex_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(sympy.Symbol('z')*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0))",
    ),
  )

  let mixed_shift_sum = doit(
    inverse_laplace_transform(
      @symcore.int(2) * @symelem.exp(@symcore.int(3) * s) +
      @symcore.int(-5) * @symelem.exp(@symcore.int(-7) * s),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(mixed_shift_sum) + ")"),
    integrals_eval_str(
      "sympy.sstr(2*sympy.InverseLaplaceTransform(sympy.exp(3*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0) - 5*sympy.DiracDelta(sympy.Symbol('x') - 7))",
    ),
  )

  let additive_time_diff = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(2)) *
      (
        f_of_s +
        (((a ^ @symcore.int(2)) + (s ^ @symcore.int(2))) ^ @symcore.int(-1))
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(additive_time_diff) +
      ") - (sympy.Derivative(sympy.InverseLaplaceTransform(sympy.Function('f')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0), (sympy.Symbol('x'), 2)) + sympy.DiracDelta(sympy.Symbol('x')) - sympy.sqrt(sympy.Symbol('a')**2)*sympy.sin(sympy.Symbol('x')*sympy.sqrt(sympy.Symbol('a')**2))*sympy.Heaviside(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let ilt_wrong = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), x, t),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ilt_wrong) +
      ") - (sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('t')), sympy.Symbol('t'), sympy.Symbol('s'))*sympy.DiracDelta(sympy.Symbol('t')))))",
    ),
    "0",
  )
}

///|
test "symintegrals parity intpoly square moments" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let square = unit_square_polygon()
  let ours_xy = polytope_integrate(square, x * y, vars=[x, y])
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_xy) +
      ") - (__import__('sympy.integrals.intpoly', fromlist=['polytope_integrate']).polytope_integrate(sympy.Polygon(sympy.Point(0, 0), sympy.Point(0, 1), sympy.Point(1, 1), sympy.Point(1, 0)), sympy.Symbol('x')*sympy.Symbol('y')))))",
    ),
    "0",
  )
  let ours_x2y = polytope_integrate(square, (x ^ @symcore.int(2)) * y, vars=[
    x, y,
  ])
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours_x2y) +
      ") - (__import__('sympy.integrals.intpoly', fromlist=['polytope_integrate']).polytope_integrate(sympy.Polygon(sympy.Point(0, 0), sympy.Point(0, 1), sympy.Point(1, 1), sympy.Point(1, 0)), sympy.Symbol('x')**2*sympy.Symbol('y')))))",
    ),
    "0",
  )
}
