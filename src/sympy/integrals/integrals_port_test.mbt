///|
fn py_locals() -> String {
  "__symbit_locals"
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
    "re", "im", "polar_lift", "Ei", "expint", "E1", "Si", "Ci", "Shi", "Chi", "erf",
    "erfc", "fresnels", "fresnelc", "besselj", "bessely", "besselk", "besseli", "gamma",
    "lowergamma", "uppergamma", "Abs", "DiracDelta", "Heaviside", "SingularityFunction",
    "Piecewise", "Tuple", "And", "Or", "Not", "Eq", "Ne", "Min", "Max", "Lt", "Le",
    "Gt", "Ge", "Derivative", "Subs", "LaplaceTransform", "InverseLaplaceTransform",
    "MellinTransform", "InverseMellinTransform", "FourierTransform", "InverseFourierTransform",
    "SineTransform", "InverseSineTransform", "CosineTransform", "InverseCosineTransform",
    "HankelTransform", "InverseHankelTransform", "Integral", "Matrix", "meijerg",
    "gamma", "lerchphi",
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
    @symcore.Expr::Number(n) if n.is_integral() =>
      "sympy.Integer(" + n.numerator().to_string() + ")"
    @symcore.Expr::Number(n) =>
      "sympy.Rational(" +
      n.numerator().to_string() +
      ", " +
      n.denominator().to_string() +
      ")"
    @symcore.Expr::NumberSymbol(kind) =>
      match kind {
        @symcore.NumberSymbolKind::ImaginaryUnit => "sympy.I"
        @symcore.NumberSymbolKind::Pi => "sympy.pi"
        @symcore.NumberSymbolKind::Exp1 => "sympy.E"
        @symcore.NumberSymbolKind::EulerGamma => "sympy.EulerGamma"
        @symcore.NumberSymbolKind::GoldenRatio => "sympy.GoldenRatio"
        @symcore.NumberSymbolKind::Catalan => "sympy.Catalan"
        @symcore.NumberSymbolKind::Infinity => "sympy.oo"
        @symcore.NumberSymbolKind::NegativeInfinity => "-sympy.oo"
        @symcore.NumberSymbolKind::ComplexInfinity => "sympy.zoo"
        @symcore.NumberSymbolKind::NaN => "sympy.nan"
      }
    @symcore.Expr::Symbol(name) =>
      "__symbit_symbol(" + python_string_literal(name) + ")"
    @symcore.Expr::Boolean(true) => "True"
    @symcore.Expr::Boolean(false) => "False"
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
        Some("Piecewise") => {
          let items : Array[String] = []
          let mut i = 0
          while i + 1 < args.length() {
            items.push(
              "(" + py_expr(args[i]) + ", " + py_expr(args[i + 1]) + ")",
            )
            i += 2
          }
          "sympy.Piecewise(" + items.join(", ") + ")"
        }
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
                              @symprint.pretty_string(expr) +
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
fn integrals_eval_zero_batch(checks : Array[String]) -> Array[String] raise {
  if checks.is_empty() {
    []
  } else {
    integrals_eval_str("chr(31).join([" + checks.join(", ") + "])")
    .split("\u001f")
    .to_array()
    .map(s => s.to_owned())
  }
}

///|
fn inspect_zero_batches(
  checks : Array[String],
  chunk_size? : Int = 8,
) -> Unit raise {
  let size = if chunk_size <= 0 { 1 } else { chunk_size }
  let mut start = 0
  while start < checks.length() {
    let chunk : Array[String] = []
    let end = if start + size < checks.length() {
      start + size
    } else {
      checks.length()
    }
    for i in start..<end {
      chunk.push(
        "(lambda __v: '0' if __v == '0' else " +
        python_string_literal("check " + i.to_string() + ": ") +
        " + __v)(" +
        checks[i] +
        ")",
      )
    }
    for oracle in integrals_eval_zero_batch(chunk) {
      inspect(oracle, content="0")
    }
    start = end
  }
}

///|
fn py_zero_if_equal(code : String, expected : String) -> String {
  "(lambda __v: '0' if __v == " +
  python_string_literal(expected) +
  " else __v)(" +
  code +
  ")"
}

///|
fn py_zero_if_equal_code(lhs : String, rhs : String) -> String {
  "(lambda __l, __r: '0' if __l == __r else (__l + ' != ' + __r))(" +
  lhs +
  ", " +
  rhs +
  ")"
}

///|
fn push_mellin_info_checks(
  checks : Array[String],
  ours : Expr,
  target : String,
  lower : String,
  upper : String,
) -> Unit {
  let ours_py = py_expr(ours)
  checks.push(
    "sympy.sstr(sympy.simplify(((" + ours_py + ")[0]) - (" + target + ")))",
  )
  checks.push(py_zero_if_equal("sympy.sstr(((" + ours_py + ")[1])[0])", lower))
  checks.push(py_zero_if_equal("sympy.sstr(((" + ours_py + ")[1])[1])", upper))
}

///|
fn push_mellin_info_checks_with_lower_code(
  checks : Array[String],
  ours : Expr,
  target : String,
  lower_code : String,
  upper : String,
) -> Unit {
  let ours_py = py_expr(ours)
  checks.push(
    "sympy.sstr(sympy.simplify(((" + ours_py + ")[0]) - (" + target + ")))",
  )
  checks.push(
    py_zero_if_equal_code("sympy.sstr(((" + ours_py + ")[1])[0])", lower_code),
  )
  checks.push(py_zero_if_equal("sympy.sstr(((" + ours_py + ")[1])[1])", upper))
}

///|
fn push_simplify_zero_check(
  checks : Array[String],
  ours : Expr,
  target : String,
) -> Unit {
  checks.push(
    "sympy.sstr(sympy.simplify((" + py_expr(ours) + ") - (" + target + ")))",
  )
}

///|
fn py_matrix_expr(mat : @symmatrices.Matrix) -> String {
  py_src_expr(mat.to_string())
}

///|
test "symintegrals parity meijer inversion source shift rules" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )

  guard @symintegrals.meijerint_inversion(
      @symelem.exp(@symcore.int(2) * s),
      s,
      t,
    )
    is Some(positive_shift) else {
    fail("expected positive pure exp shift")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(positive_shift) +
      ") - sympy.integrals.meijerint.meijerint_inversion(sympy.exp(2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t'))))",
    ),
    "0",
  )

  guard @symintegrals.meijerint_inversion(
      @symcore.int(3) * @symelem.exp(@symcore.int(2) * s),
      s,
      t,
    )
    is Some(scaled_positive_shift) else {
    fail("expected scaled positive pure exp shift")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_positive_shift) +
      ") - sympy.integrals.meijerint.meijerint_inversion(3*sympy.exp(2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t'))))",
    ),
    "0",
  )

  guard @symintegrals.meijerint_inversion(
      @symelem.exp(s) * @symelem.exp(@symcore.int(2) * s),
      s,
      t,
    )
    is Some(combined_exp_shift) else {
    fail("expected combined exp shift")
  }
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(combined_exp_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp(sympy.Symbol('s'))*sympy.exp(2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
  )

  guard @symintegrals.meijerint_inversion(
      @symelem.exp(s) * (s ^ @symcore.int(-1)),
      s,
      t,
    )
    is Some(advanced_unit_step) else {
    fail("expected shifted exp(s)/s inversion")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(advanced_unit_step) +
      ") - sympy.integrals.meijerint.meijerint_inversion(sympy.exp(sympy.Symbol('s'))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('t'))))",
    ),
    "0",
  )

  guard @symintegrals.meijerint_inversion(
      @symelem.exp(@symcore.int(2) * s) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      t,
    )
    is Some(advanced_shifted_pole) else {
    fail("expected shifted exp(2*s)/(s + 1) inversion")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(advanced_shifted_pole) +
      ") - sympy.integrals.meijerint.meijerint_inversion(sympy.exp(2*sympy.Symbol('s'))/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('t'))))",
    ),
    "0",
  )

  match
    @symintegrals.meijerint_inversion(
      @symelem.exp(s) *
      (s + @symcore.int(1)) *
      (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected shifted additive numerator rejection")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp(sympy.Symbol('s'))*(sympy.Symbol('s') + 1)/(sympy.Symbol('s')**2 + 1), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  match @symintegrals.meijerint_inversion(@symelem.exp(imag * s), s, t) {
    None => ()
    Some(_) => fail("expected explicit non-real shift rejection")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp(sympy.I*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  let z = @symcore.Expr::Symbol("z")
  guard @symintegrals.meijerint_inversion(@symelem.exp(z * s), s, t)
    is Some(symbolic_shift) else {
    fail("expected symbolic shift Piecewise")
  }
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(symbolic_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp(sympy.Symbol('z')*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
  )

  guard @symintegrals.meijerint_inversion(
      @symelem.exp(@symcore.int(2) * s) * @symelem.exp(z * s),
      s,
      t,
    )
    is Some(symbolic_product_shift) else {
    fail("expected symbolic product shift Piecewise")
  }
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(symbolic_product_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp(2*sympy.Symbol('s'))*sympy.exp(sympy.Symbol('z')*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
  )

  match
    @symintegrals.meijerint_inversion(
      @symelem.exp(s) * @symelem.exp(imag * s),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected combined non-real shift rejection")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp(sympy.Symbol('s'))*sympy.exp(sympy.I*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  match
    @symintegrals.meijerint_inversion(
      @symelem.exp(s) + @symelem.exp(@symcore.int(2) * s),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected source-dependent Add rejection")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp(sympy.Symbol('s')) + sympy.exp(2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  match
    @symintegrals.meijerint_inversion(
      (s ^ @symcore.int(-1)) + ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected rational Add rejection")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(1/sympy.Symbol('s') + 1/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  guard @symintegrals.meijerint_inversion(
      @symelem.exp((z + @symcore.int(2)) * s),
      s,
      t,
    )
    is Some(symbolic_real_offset_shift) else {
    fail("expected symbolic real-offset shift Piecewise")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(symbolic_real_offset_shift) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp((sympy.Symbol('z') + 2)*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
  )

  guard @symintegrals.meijerint_inversion(
      @symelem.exp((imag * z + @symcore.int(2)) * s),
      s,
      t,
    )
    is Some(symbolic_imag_offset_shift) else {
    fail("expected symbolic imaginary-offset shift Piecewise")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(symbolic_imag_offset_shift) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.exp((sympy.I*sympy.Symbol('z') + 2)*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
  )

  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let sqrt_kernel = @symelem.sqrt(pi) *
    (@symelem.sqrt(z) ^ @symcore.int(-1)) *
    @symelem.exp(@symcore.int(-2) * @symelem.sqrt(z) * @symelem.sqrt(s))
  guard @symintegrals.meijerint_inversion(sqrt_kernel, s, t)
    is Some(sqrt_kernel_conditional) else {
    fail("expected conditional sqrt kernel Piecewise")
  }
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(sqrt_kernel_conditional) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(sympy.sqrt(sympy.pi)*sympy.exp(-2*sympy.sqrt(sympy.Symbol('z'))*sympy.sqrt(sympy.Symbol('s')))/sympy.sqrt(sympy.Symbol('z')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
  )
}

///|
test "symintegrals parity meijer inversion source antecedent edge rules" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")

  match
    @symintegrals.meijerint_inversion(@symelem.sqrt(s) ^ @symcore.int(-1), s, t) {
    None => ()
    Some(_) => fail("expected SymPy meijerint_inversion to reject 1/sqrt(s)")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(1/sympy.sqrt(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  match
    @symintegrals.meijerint_inversion(
      @symelem.sqrt(s + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      t,
    ) {
    None => ()
    Some(_) =>
      fail("expected SymPy meijerint_inversion to reject 1/sqrt(s + 1)")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(1/sympy.sqrt(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  match
    @symintegrals.meijerint_inversion(
      (@symelem.sqrt(s) + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      t,
    ) {
    None => ()
    Some(_) =>
      fail("expected SymPy meijerint_inversion to reject 1/(sqrt(s) + 1)")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(1/(sympy.sqrt(sympy.Symbol('s')) + 1), sympy.Symbol('s'), sympy.Symbol('t')))",
    ),
    "None",
  )

  guard @symintegrals.meijerint_inversion(
      s ^ @symcore.rational_from_ints(-3, 2),
      s,
      t,
    )
    is Some(three_half_power) else {
    fail("expected SymPy meijerint_inversion to accept s**(-3/2)")
  }
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(three_half_power) +
      ") - sympy.integrals.meijerint.meijerint_inversion(sympy.Symbol('s')**sympy.Rational(-3, 2), sympy.Symbol('s'), sympy.Symbol('t'))))",
    ),
    "0",
  )

  let base_power_cases : Array[(String, Expr, String)] = [
    ("2**s", @symcore.int(2) ^ s, "2**sympy.Symbol('s')"),
    (
      "2**(-s)",
      @symcore.int(2) ^ (@symcore.int(-1) * s),
      "2**(-sympy.Symbol('s'))",
    ),
    (
      "2**s/s",
      (@symcore.int(2) ^ s) * (s ^ @symcore.int(-1)),
      "2**sympy.Symbol('s')/sympy.Symbol('s')",
    ),
    (
      "2**(-s)/s",
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) * (s ^ @symcore.int(-1)),
      "2**(-sympy.Symbol('s'))/sympy.Symbol('s')",
    ),
    (
      "2**s/(s + 1)",
      (@symcore.int(2) ^ s) * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      "2**sympy.Symbol('s')/(sympy.Symbol('s') + 1)",
    ),
    (
      "2**(-s)/(s + 1)",
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      "2**(-sympy.Symbol('s'))/(sympy.Symbol('s') + 1)",
    ),
  ]
  for item in base_power_cases {
    match @symintegrals.meijerint_inversion(item.1, s, t) {
      None => ()
      Some(_) => fail("expected SymPy meijerint_inversion to reject " + item.0)
    }
    assert_eq(
      integrals_eval_str(
        "sympy.sstr(sympy.integrals.meijerint.meijerint_inversion(" +
        item.2 +
        ", sympy.Symbol('s'), sympy.Symbol('t')))",
      ),
      "None",
    )
  }
}

///|
test "symintegrals parity inverse Laplace frontdoor remains broader than meijer inversion" {
  let s = @symcore.Expr::Symbol("s")
  let x = @symcore.Expr::Symbol("x")

  let reciprocal_sqrt_s = doit(
    inverse_laplace_transform(@symelem.sqrt(s) ^ @symcore.int(-1), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_s) +
      ") - sympy.inverse_laplace_transform(1/sympy.sqrt(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_shifted = doit(
    inverse_laplace_transform(
      @symelem.sqrt(s + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_shifted) +
      ") - sympy.inverse_laplace_transform(1/sympy.sqrt(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_sqrt_plus_const = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_sqrt_plus_const) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s')) + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let reciprocal_s_sqrt_shifted = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) *
      (@symelem.sqrt(s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_s_sqrt_shifted) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*sympy.sqrt(sympy.Symbol('s') + 1)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
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
  let checks : Array[String] = []
  for item in cases {
    let ours = integrate(item.1, limits=[integral_limit([x])])
    checks.push(
      "(lambda x: sympy.sstr(sympy.trigsimp(sympy.simplify((" +
      py_expr(ours) +
      ") - sympy.integrate(" +
      py_src_expr(item.0) +
      ", x)))))(sympy.Symbol('x'))",
    )
  }
  let oracle_results = integrals_eval_str(
      "chr(31).join([" + checks.join(", ") + "])",
    )
    .split("\u001f")
    .to_array()
    .map(s => s.to_owned())
  for oracle in oracle_results {
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
  let delta_parts = expand_dirac_delta(
    @symcore.int(3) * @symspec.dirac_delta(x),
  )
  match delta_parts.get(@symspec.dirac_delta(x)) {
    Some(_) =>
      inspect(
        integrals_eval_str(
          "sympy.sstr(sympy.integrals.laplace.expand_dirac_delta(3*sympy.DiracDelta(sympy.Symbol('x')))[1][sympy.DiracDelta(sympy.Symbol('x'))])",
        ),
        content="3",
      )
    None => fail("expected expanded DiracDelta coefficient")
  }
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
  let lp_checks : Array[String] = []
  for item in lp_cases {
    let ours = doit(laplace_transform(item.1, x, s))
    lp_checks.push(
      "sympy.sstr(sympy.simplify((" +
      py_expr(ours) +
      ") - (sympy.laplace_transform(sympy.sympify('" +
      item.0 +
      "', locals={'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'And': sympy.And, 'Le': sympy.Le}), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))))",
    )
  }
  let lp_oracles = integrals_eval_str(
      "chr(31).join([" + lp_checks.join(", ") + "])",
    )
    .split("\u001f")
    .to_array()
    .map(s => s.to_owned())
  for oracle in lp_oracles {
    inspect(oracle, content="0")
  }

  let ft = @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(2)))
  let a = @symcore.Expr::Symbol("a")
  let third = @symcore.rational_from_ints(1, 3)
  let two_thirds = @symcore.rational_from_ints(2, 3)
  let three_halves = @symcore.rational_from_ints(3, 2)
  let fourier_checks : Array[String] = []
  let ours_ft = doit(fourier_transform(ft, x, k))
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(ours_ft) +
    ") - (sympy.fourier_transform(sympy.exp(-sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('k')))))",
  )

  let ours_ift = doit(inverse_fourier_transform(ours_ft, k, x))
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(ours_ift) +
    ") - (sympy.exp(-sympy.Symbol('x')**2))))",
  )

  let shifted_ft = doit(
    fourier_transform(
      @symelem.exp(@symcore.int(-1) * ((x - @symcore.int(1)) ^ @symcore.int(2))),
      x,
      k,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify(sympy.expand(((" +
    py_expr(shifted_ft) +
    ") - (sympy.fourier_transform(sympy.exp(-(sympy.Symbol('x') - 1)**2), sympy.Symbol('x'), sympy.Symbol('k')))).rewrite(sympy.exp))))",
  )

  let shifted_ift = doit(inverse_fourier_transform(shifted_ft, k, x))
  fourier_checks.push(
    "sympy.sstr(sympy.simplify(sympy.expand(((" +
    py_expr(shifted_ift) +
    ") - (sympy.exp(-(sympy.Symbol('x') - 1)**2))).rewrite(sympy.exp))))",
  )

  let half_line_ft = doit(
    fourier_transform(
      @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x),
      x,
      k,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(half_line_ft) +
    ") - sympy.fourier_transform(sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
  )
  let half_line_ift = doit(inverse_fourier_transform(half_line_ft, k, x))
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(half_line_ift) +
    ") - (sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))))",
  )

  let half_line_x_ft = doit(
    fourier_transform(
      x * @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x),
      x,
      k,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(half_line_x_ft) +
    ") - sympy.fourier_transform(sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
  )
  let half_line_x_ift = doit(inverse_fourier_transform(half_line_x_ft, k, x))
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(half_line_x_ift) +
    ") - (sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))))",
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
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(half_line_sin_ft) +
    ") - sympy.fourier_transform(sympy.exp(-2*sympy.Symbol('x'))*sympy.sin(3*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))))",
  )
  let half_line_sin_ift = doit(
    inverse_fourier_transform(half_line_sin_ft, k, x),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(half_line_sin_ift) +
    ") - (sympy.exp(-2*sympy.Symbol('x'))*sympy.sin(3*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')))))",
  )

  let abs_decay_ft = doit(
    fourier_transform(@symelem.exp(@symcore.int(-2) * @symelem.abs(x)), x, k),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(abs_decay_ft) +
    ") - sympy.fourier_transform(sympy.exp(-2*sympy.Abs(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))))",
  )
  let abs_decay_ift = doit(inverse_fourier_transform(abs_decay_ft, k, x))
  fourier_checks.push(
    "('0' if sympy.sstr(" +
    py_expr(abs_decay_ift) +
    ") == sympy.sstr(sympy.exp(-2*sympy.Abs(sympy.Symbol('x')))) else sympy.sstr(" +
    py_expr(abs_decay_ift) +
    "))",
  )

  let box_window_ft = doit(
    fourier_transform(
      @symspec.heaviside(@symcore.int(1) - @symelem.abs(@symcore.int(2) * x)),
      x,
      k,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(box_window_ft) +
    ") - sympy.fourier_transform(sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))))",
  )
  let box_window_ift = doit(inverse_fourier_transform(box_window_ft, k, x))
  fourier_checks.push(
    "('0' if sympy.sstr(" +
    py_expr(box_window_ift) +
    ") == sympy.sstr(sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x')))) else sympy.sstr(" +
    py_expr(box_window_ift) +
    "))",
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
    fourier_checks.push(
      "sympy.sstr(sympy.simplify(((" +
      py_expr(triangle_window_ft) +
      ").subs(sympy.Symbol('k'), " +
      sample +
      ")) - (sympy.fourier_transform(sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x')))*(1 - sympy.Abs(2*sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k')).subs(sympy.Symbol('k'), " +
      sample +
      "))))",
    )
  }
  let triangle_window_ift = doit(
    inverse_fourier_transform(triangle_window_ft, k, x),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(triangle_window_ift) +
    ") - (sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('x')))*(1 - sympy.Abs(2*sympy.Symbol('x'))))))",
  )
  let direct_sinc_box_ift = doit(
    inverse_fourier_transform(
      two_thirds * @symelem.sinc(k * (three_halves ^ @symcore.int(-1))),
      k,
      x,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(direct_sinc_box_ift) +
    ") - sympy.Heaviside(1 - sympy.Abs(3*sympy.Symbol('x')))))",
  )
  let direct_sinc_triangle_ift = doit(
    inverse_fourier_transform(
      third * (@symelem.sinc(k * third) ^ @symcore.int(2)),
      k,
      x,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(direct_sinc_triangle_ift) +
    ") - (sympy.Heaviside(1 - sympy.Abs(3*sympy.Symbol('x')))*(1 - sympy.Abs(3*sympy.Symbol('x'))))))",
  )
  let direct_symbolic_sinc_box_ift = doit(
    inverse_fourier_transform(
      (a ^ @symcore.int(-1)) * @symelem.sinc(k * (a ^ @symcore.int(-1))),
      k,
      x,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(direct_symbolic_sinc_box_ift) +
    ") - sympy.Heaviside(1 - sympy.Abs(2*sympy.Symbol('a')*sympy.Symbol('x')))))",
  )
  let direct_symbolic_sinc_triangle_ift = doit(
    inverse_fourier_transform(
      (a ^ @symcore.int(-1)) *
      (@symelem.sinc(k * (a ^ @symcore.int(-1))) ^ @symcore.int(2)),
      k,
      x,
    ),
  )
  fourier_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(direct_symbolic_sinc_triangle_ift) +
    ") - (sympy.Heaviside(1 - sympy.Abs(sympy.Symbol('a')*sympy.Symbol('x')))*(1 - sympy.Abs(sympy.Symbol('a')*sympy.Symbol('x'))))))",
  )
  for oracle in integrals_eval_zero_batch(fourier_checks) {
    inspect(oracle, content="0")
  }

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
      "s/(s + 1)",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") *
        ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(-1)),
        s,
        x,
      ),
    ),
    (
      "s/(s + 1)**2",
      inverse_laplace_transform(
        @symcore.Expr::Symbol("s") *
        ((@symcore.Expr::Symbol("s") + @symcore.int(1)) ^ @symcore.int(-2)),
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
  let inverse_lp_checks : Array[String] = []
  for item in inverse_lp_cases {
    let ours = doit(item.1)
    inverse_lp_checks.push(
      "sympy.sstr(sympy.simplify(sympy.trigsimp(sympy.expand(((" +
      py_expr(ours) +
      ") - (sympy.inverse_laplace_transform(sympy.sympify('" +
      item.0 +
      "', locals={'sqrt': sympy.sqrt, 'exp': sympy.exp, 'sin': sympy.sin, 'cos': sympy.cos, 'tan': sympy.tan, 'cot': sympy.cot, 'sec': sympy.sec, 'csc': sympy.csc, 'sinh': sympy.sinh, 'cosh': sympy.cosh, 'tanh': sympy.tanh, 'coth': sympy.coth, 'log': sympy.log, 'atan': sympy.atan, 'atanh': sympy.atanh, 'asin': sympy.asin, 'asinh': sympy.asinh, 'DiracDelta': sympy.DiracDelta, 'Heaviside': sympy.Heaviside, 'SingularityFunction': sympy.SingularityFunction, 'Piecewise': sympy.Piecewise, 'And': sympy.And, 'Le': sympy.Le}), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True))).rewrite(sympy.exp)))))",
    )
  }
  let inverse_lp_oracles = integrals_eval_str(
      "chr(31).join([" + inverse_lp_checks.join(", ") + "])",
    )
    .split("\u001f")
    .to_array()
    .map(s => s.to_owned())
  for oracle in inverse_lp_oracles {
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

  let mellin_checks : Array[String] = []
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
    mellin_checks.push(
      "sympy.sstr(sympy.expand_mul((" + py_expr(ours) + ") - (" + item.1 + ")))",
    )
  }

  let exp_inv = do_mellin_doit(
    @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(-1))),
    x,
    s,
  ).unwrap()
  mellin_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(exp_inv) +
    ") - (sympy.mellin_transform(sympy.exp(-sympy.Symbol('x') ** -1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True))))",
  )

  let shifted_power_mellin = mellin_transform_eval(
    (x + @symcore.int(1)) ^ (@symcore.int(-1) * rho),
    x,
    s,
  )
  mellin_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(shifted_power_mellin) +
    ")[0]) - sympy.mellin_transform((1 + sympy.Symbol('x'))**(-sympy.Symbol('rho')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(shifted_power_mellin) + ")[1])[0])",
      "0",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(shifted_power_mellin) + ")[1])[1])",
      "re(rho)",
    ),
  )

  let difference_quotient_mellin = mellin_transform_eval(
    ((x ^ a) - (bp ^ a)) * ((x - bp) ^ @symcore.int(-1)),
    x,
    s,
  )
  mellin_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(difference_quotient_mellin) +
    ")[0]) - sympy.mellin_transform((sympy.Symbol('x')**sympy.Symbol('a') - sympy.Symbol('bp')**sympy.Symbol('a'))/(sympy.Symbol('x') - sympy.Symbol('bp')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(difference_quotient_mellin) + ")[1])[0])",
      "Max(0, -re(a))",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(difference_quotient_mellin) + ")[1])[1])",
      "Min(1, 1 - re(a))",
    ),
  )

  let sqrt_shift = @symelem.sqrt(x + (bp ^ @symcore.int(2))) + bp
  let sqrt_shift_mellin = mellin_transform_eval(sqrt_shift ^ a, x, s)
  mellin_checks.push(
    "(lambda bp: sympy.sstr(sympy.simplify((((" +
    py_expr(sqrt_shift_mellin) +
    ")[0]).subs(sympy.Symbol('bp'), bp) - sympy.mellin_transform((sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a'), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))))(sympy.Symbol('bp', positive=True))",
  )
  mellin_checks.push(
    py_zero_if_equal(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_mellin) +
      ")[1])[0]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
      "0",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_mellin) +
      ")[1])[1]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
      "-re(a)/2",
    ),
  )

  let sqrt_shift_recip_mellin = mellin_transform_eval(
    (sqrt_shift ^ a) *
    (@symelem.sqrt(x + (bp ^ @symcore.int(2))) ^ @symcore.int(-1)),
    x,
    s,
  )
  mellin_checks.push(
    "(lambda bp: sympy.sstr(sympy.simplify((((" +
    py_expr(sqrt_shift_recip_mellin) +
    ")[0]).subs(sympy.Symbol('bp'), bp) - sympy.mellin_transform((sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a')/sympy.sqrt(sympy.Symbol('x') + bp**2), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))))(sympy.Symbol('bp', positive=True))",
  )
  mellin_checks.push(
    py_zero_if_equal(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_recip_mellin) +
      ")[1])[0]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
      "0",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal(
      "(lambda bp: sympy.sstr(((((" +
      py_expr(sqrt_shift_recip_mellin) +
      ")[1])[1]).subs(sympy.Symbol('bp'), bp))))(sympy.Symbol('bp', positive=True))",
      "1/2 - re(a)/2",
    ),
  )

  let left_beta_mellin = mellin_transform_eval(
    ((@symcore.int(1) - x) ^ (b - @symcore.int(1))) *
    @symspec.heaviside(@symcore.int(1) - x),
    x,
    s,
  )
  mellin_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(left_beta_mellin) +
    ")[0]) - sympy.mellin_transform((1 - sympy.Symbol('x'))**(sympy.Symbol('b') - 1)*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(left_beta_mellin) + ")[1])[0])",
      "0",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(left_beta_mellin) + ")[1])[1])",
      "oo",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal_code(
      "sympy.sstr((" + py_expr(left_beta_mellin) + ")[2])",
      "sympy.sstr(sympy.mellin_transform((1 - sympy.Symbol('x'))**(sympy.Symbol('b') - 1)*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'))[2])",
    ),
  )

  let right_beta_mellin = mellin_transform_eval(
    ((x - @symcore.int(1)) ^ (b - @symcore.int(1))) *
    @symspec.heaviside(x - @symcore.int(1)),
    x,
    s,
  )
  mellin_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(right_beta_mellin) +
    ")[0]) - sympy.mellin_transform((sympy.Symbol('x') - 1)**(sympy.Symbol('b') - 1)*sympy.Heaviside(sympy.Symbol('x') - 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(right_beta_mellin) + ")[1])[0])",
      "-oo",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(right_beta_mellin) + ")[1])[1])",
      "1 - re(b)",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal_code(
      "sympy.sstr((" + py_expr(right_beta_mellin) + ")[2])",
      "sympy.sstr(sympy.mellin_transform((sympy.Symbol('x') - 1)**(sympy.Symbol('b') - 1)*sympy.Heaviside(sympy.Symbol('x') - 1), sympy.Symbol('x'), sympy.Symbol('s'))[2])",
    ),
  )

  let erf_sqrt_mellin = mellin_transform_eval(
    @symspec.erf(@symelem.sqrt(x)),
    x,
    s,
  )
  mellin_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(erf_sqrt_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.erf(sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(erf_sqrt_mellin) + ")[1])[0])",
      "-1/2",
    ),
  )
  mellin_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(erf_sqrt_mellin) + ")[1])[1])",
      "0",
    ),
  )
  for oracle in integrals_eval_zero_batch(mellin_checks) {
    inspect(oracle, content="0")
  }
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
  let mellin_log_checks : Array[String] = []
  let log_left_mellin = mellin_transform_eval(
    (@symelem.log(x) ^ @symcore.int(4)) *
    @symspec.heaviside(@symcore.int(1) - x),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(log_left_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.log(sympy.Symbol('x'))**4*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_left_mellin) + ")[1])[0])",
      "0",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_left_mellin) + ")[1])[1])",
      "oo",
    ),
  )

  let log_right_mellin = mellin_transform_eval(
    (@symelem.log(x) ^ @symcore.int(3)) *
    @symspec.heaviside(x - @symcore.int(1)),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(log_right_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.log(sympy.Symbol('x'))**3*sympy.Heaviside(sympy.Symbol('x') - 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_right_mellin) + ")[1])[0])",
      "-oo",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_right_mellin) + ")[1])[1])",
      "0",
    ),
  )

  let log_one_plus_mellin = mellin_transform_eval(
    @symelem.log(x + @symcore.int(1)),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(log_one_plus_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.log(sympy.Symbol('x') + 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_one_plus_mellin) + ")[1])[0])",
      "-1",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_one_plus_mellin) + ")[1])[1])",
      "0",
    ),
  )

  let log_one_plus_inverse_mellin = mellin_transform_eval(
    @symelem.log((x ^ @symcore.int(-1)) + @symcore.int(1)),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(log_one_plus_inverse_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.log(1/sympy.Symbol('x') + 1), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_one_plus_inverse_mellin) + ")[1])[0])",
      "0",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_one_plus_inverse_mellin) + ")[1])[1])",
      "1",
    ),
  )

  let log_abs_left_mellin = mellin_transform_eval(
    @symelem.log(@symelem.abs(@symcore.int(1) - x)),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(log_abs_left_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.log(sympy.Abs(1 - sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_abs_left_mellin) + ")[1])[0])",
      "-1",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_abs_left_mellin) + ")[1])[1])",
      "0",
    ),
  )

  let log_abs_inverse_mellin = mellin_transform_eval(
    @symelem.log(@symelem.abs(@symcore.int(1) - (x ^ @symcore.int(-1)))),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(log_abs_inverse_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.log(sympy.Abs(1 - 1/sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_abs_inverse_mellin) + ")[1])[0])",
      "0",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(log_abs_inverse_mellin) + ")[1])[1])",
      "1",
    ),
  )

  let e1_mellin = mellin_transform_eval(@symspec.e1(x), x, s)
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(e1_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.E1(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal("sympy.sstr(((" + py_expr(e1_mellin) + ")[1])[0])", "0"),
  )
  mellin_log_checks.push(
    py_zero_if_equal("sympy.sstr(((" + py_expr(e1_mellin) + ")[1])[1])", "oo"),
  )

  let expint2_mellin = mellin_transform_eval(
    @symspec.expint(@symcore.int(2), x),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(expint2_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.expint(2, sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(expint2_mellin) + ")[1])[0])",
      "0",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(expint2_mellin) + ")[1])[1])",
      "oo",
    ),
  )

  let si_mellin = mellin_transform_eval(@symspec.si(x), x, s)
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(si_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.Si(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal("sympy.sstr(((" + py_expr(si_mellin) + ")[1])[0])", "-1"),
  )
  mellin_log_checks.push(
    py_zero_if_equal("sympy.sstr(((" + py_expr(si_mellin) + ")[1])[1])", "0"),
  )

  let ci_sqrt_mellin = mellin_transform_eval(
    @symspec.ci(@symelem.sqrt(x)),
    x,
    s,
  )
  mellin_log_checks.push(
    "sympy.sstr(sympy.simplify(((" +
    py_expr(ci_sqrt_mellin) +
    ")[0]) - sympy.mellin_transform(sympy.Ci(sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)))",
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(ci_sqrt_mellin) + ")[1])[0])",
      "0",
    ),
  )
  mellin_log_checks.push(
    py_zero_if_equal(
      "sympy.sstr(((" + py_expr(ci_sqrt_mellin) + ")[1])[1])",
      "1",
    ),
  )
  for oracle in integrals_eval_zero_batch(mellin_log_checks) {
    inspect(oracle, content="0")
  }
  let mellin_bessel_checks : Array[String] = []
  let besselj_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symcore.int(2) * @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks(
    mellin_bessel_checks, besselj_mellin, "sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "-re(a)/2", "3/4",
  )

  let bessely_mellin = mellin_transform_eval(
    @symspec.bessely(a, @symcore.int(2) * @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks(
    mellin_bessel_checks, bessely_mellin, "sympy.mellin_transform(sympy.bessely(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "Max(-re(a)/2, re(a)/2)", "3/4",
  )

  let besselk_mellin = mellin_transform_eval(
    @symspec.besselk(a, @symcore.int(2) * @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks(
    mellin_bessel_checks, besselk_mellin, "sympy.mellin_transform(sympy.besselk(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "Max(-re(a)/2, re(a)/2)", "oo",
  )

  let besseli_besselk_mellin = mellin_transform_eval(
    @symspec.besseli(a, @symelem.sqrt(x)) *
    @symspec.besselk(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, besseli_besselk_mellin, "sympy.mellin_transform(sympy.besseli(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.besseli(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/2",
  )

  let besselj_sq_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) ^ @symcore.int(2),
    x,
    s,
  )
  push_mellin_info_checks(
    mellin_bessel_checks, besselj_sq_mellin, "sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))**2, sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "-re(a)", "1/2",
  )

  let besselj_neg_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.besselj(@symcore.int(-1) * a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks(
    mellin_bessel_checks, besselj_neg_mellin, "sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(-sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "0", "1/2",
  )

  let besselj_bessely_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.bessely(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, besselj_bessely_mellin, "sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/2",
  )

  let besselj_adjacent_mellin = mellin_transform_eval(
    @symspec.besselj(a - @symcore.int(1), @symelem.sqrt(x)) *
    @symspec.besselj(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, besselj_adjacent_mellin, "sympy.mellin_transform(sympy.besselj(sympy.Symbol('a') - 1, sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a') - 1, sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/2",
  )

  let besselj_general_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.besselj(b, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, besselj_general_mellin, "sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/2",
  )

  let besselj_bessely_general_mellin = mellin_transform_eval(
    @symspec.besselj(a, @symelem.sqrt(x)) *
    @symspec.bessely(b, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, besselj_bessely_general_mellin, "sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/2",
  )

  let besseli_besselk_general_mellin = mellin_transform_eval(
    @symspec.besseli(b, @symelem.sqrt(x)) *
    @symspec.besselk(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, besseli_besselk_general_mellin, "sympy.mellin_transform(sympy.besseli(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.besseli(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselk(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/2",
  )

  let sin_besselj_mellin = mellin_transform_eval(
    @symelem.sin(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, sin_besselj_mellin, "sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/4",
  )

  let cos_besselj_mellin = mellin_transform_eval(
    @symelem.cos(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, cos_besselj_mellin, "sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/4",
  )

  let sin_bessely_mellin = mellin_transform_eval(
    @symelem.sin(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, sin_bessely_mellin, "sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/4",
  )

  let cos_bessely_mellin = mellin_transform_eval(
    @symelem.cos(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
    x,
    s,
  )
  push_mellin_info_checks_with_lower_code(
    mellin_bessel_checks, cos_bessely_mellin, "sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "sympy.sstr((sympy.mellin_transform(sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('s'))[1])[0])",
    "1/4",
  )

  let generic_mellin = mellin_transform_eval(f_of_x, x, s)
  mellin_bessel_checks.push(
    py_zero_if_equal_code(
      "(lambda x: sympy.sstr(sympy.mellin_transform(sympy.Function('f')(x), x, sympy.Symbol('s'))))(sympy.Symbol('x'))",
      "sympy.sstr(" + py_expr(generic_mellin) + ")",
    ),
  )

  let partial_generic_mellin = mellin_transform_eval(
    f_of_x + @symelem.exp(@symcore.int(-1) * x),
    x,
    s,
  )
  push_mellin_info_checks(
    mellin_bessel_checks, partial_generic_mellin, "sympy.MellinTransform(sympy.Function('f')(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')) + sympy.mellin_transform(sympy.exp(-sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s'), noconds=True)",
    "0", "oo",
  )
  for oracle in integrals_eval_zero_batch(mellin_bessel_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity inverse Mellin families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")

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
  let inverse_mellin_checks : Array[String] = []
  for item in imt_cases {
    match do_inverse_mellin_doit(item.0, s, x) {
      Some(ours) =>
        inverse_mellin_checks.push(
          "sympy.sstr(sympy.simplify((" +
          py_expr(ours) +
          ") - (" +
          item.1 +
          ")))",
        )
      None =>
        inverse_mellin_checks.push(
          py_zero_if_equal(
            python_string_literal(@symprint.pretty_string(item.0)),
            "NONE",
          ),
        )
    }
  }
  for oracle in integrals_eval_zero_batch(inverse_mellin_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity inverse Mellin special families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let bp = @symcore.Expr::Symbol("bp")
  let rho = @symcore.Expr::Symbol("rho")
  let inverse_algebraic_checks : Array[String] = []

  let gamma_shift_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s - @symcore.int(1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_algebraic_checks, gamma_shift_inverse, "sympy.exp(-sympy.Symbol('x'))/sympy.Symbol('x')",
  )

  let gamma_sum_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) + @symspec.gamma(s - @symcore.int(1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_algebraic_checks, gamma_sum_inverse, "(sympy.Symbol('x') + 1)*sympy.exp(-sympy.Symbol('x'))/sympy.Symbol('x')",
  )

  let beta_left_inverse = do_inverse_mellin_doit(
    @symspec.gamma(b) *
    @symspec.gamma(s) *
    (@symspec.gamma(s + b) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_algebraic_checks, beta_left_inverse, "((1 - sympy.Symbol('x'))**(sympy.Symbol('b') - 1))*sympy.Heaviside(1 - sympy.Symbol('x'))",
  )

  let beta_right_inverse = do_inverse_mellin_doit(
    @symspec.gamma(b) *
    @symspec.gamma(@symcore.int(1) - b - s) *
    (@symspec.gamma(@symcore.int(1) - s) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_algebraic_checks, beta_right_inverse, "((sympy.Symbol('x') - 1)**(sympy.Symbol('b') - 1))*sympy.Heaviside(sympy.Symbol('x') - 1)",
  )

  let shifted_power_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) *
    @symspec.gamma(rho - s) *
    (@symspec.gamma(rho) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_algebraic_checks, shifted_power_inverse, "(1 + sympy.Symbol('x'))**(-sympy.Symbol('rho'))",
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
  push_simplify_zero_check(
    inverse_algebraic_checks, difference_quotient_inverse, "(sympy.Symbol('x')**sympy.Symbol('a') - sympy.Symbol('bp')**sympy.Symbol('a'))/(sympy.Symbol('x') - sympy.Symbol('bp'))",
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
  inverse_algebraic_checks.push(
    "(lambda bp: sympy.sstr(sympy.simplify((" +
    py_expr(sqrt_shift_inverse) +
    ").subs(sympy.Symbol('bp'), bp) - (sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a'))))(sympy.Symbol('bp', positive=True))",
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
  inverse_algebraic_checks.push(
    "(lambda bp: sympy.sstr(sympy.simplify((" +
    py_expr(sqrt_shift_recip_inverse) +
    ").subs(sympy.Symbol('bp'), bp) - ((sympy.sqrt(sympy.Symbol('x') + bp**2) + bp)**sympy.Symbol('a')/sympy.sqrt(sympy.Symbol('x') + bp**2)))))(sympy.Symbol('bp', positive=True))",
  )
  for oracle in integrals_eval_zero_batch(inverse_algebraic_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity inverse Mellin named special families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let half = @symcore.rational_from_ints(1, 2)
  let inverse_named_checks : Array[String] = []

  let e1_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) * (s ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_named_checks, e1_inverse, "sympy.E1(sympy.Symbol('x'))",
  )

  let expint2_inverse = do_inverse_mellin_doit(
    @symspec.gamma(s) * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_named_checks, expint2_inverse, "sympy.expint(2, sympy.Symbol('x'))",
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
  push_simplify_zero_check(
    inverse_named_checks, si_inverse, "sympy.Si(sympy.Symbol('x'))",
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
  push_simplify_zero_check(
    inverse_named_checks, ci_sqrt_inverse, "sympy.Ci(sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_named_checks, erf_sqrt_inverse, "sympy.erf(sympy.sqrt(sympy.Symbol('x')))",
  )
  for oracle in integrals_eval_zero_batch(inverse_named_checks) {
    inspect(oracle, content="0")
  }

  let inverse_log_checks : Array[String] = []
  let log_left_inverse = do_inverse_mellin_doit(
    @symcore.int(24) * (s ^ @symcore.int(-5)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_log_checks, log_left_inverse, "sympy.log(sympy.Symbol('x'))**4*sympy.Heaviside(1 - sympy.Symbol('x'))",
  )

  let log_right_inverse = do_inverse_mellin_doit(
    @symcore.int(6) * (s ^ @symcore.int(-4)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_log_checks, log_right_inverse, "sympy.log(sympy.Symbol('x'))**3*sympy.Heaviside(sympy.Symbol('x') - 1)",
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
  push_simplify_zero_check(
    inverse_log_checks, log_quadratic_inverse, "sympy.log(sympy.Symbol('x')**2 + 1)",
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
  push_simplify_zero_check(
    inverse_log_checks, sec_inverse, "sympy.sqrt(sympy.Symbol('x'))/(sympy.Symbol('x') + 1)",
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
  push_simplify_zero_check(
    inverse_log_checks, log_piecewise_inverse, "(sympy.log(1 + sympy.Symbol('x'))*sympy.Heaviside(1 - sympy.Symbol('x'))) + (sympy.log(1 + sympy.Symbol('x')**-1)*sympy.Heaviside(sympy.Symbol('x') - 1))",
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
  push_simplify_zero_check(
    inverse_log_checks, sqrt_piecewise_inverse, "(sympy.log(1 + sympy.sqrt(sympy.Symbol('x')))*sympy.Heaviside(1 - sympy.Symbol('x'))) + (sympy.log(1 + sympy.sqrt(sympy.Symbol('x'))**-1)*sympy.Heaviside(sympy.Symbol('x') - 1))",
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
  push_simplify_zero_check(
    inverse_log_checks, tan_piecewise_inverse, tan_piecewise_target,
  )

  let cot_piecewise_inverse = do_inverse_mellin_doit(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    @symelem.cot(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s) *
    (s ^ @symcore.int(-1)),
    s,
    x,
  ).unwrap()
  push_simplify_zero_check(
    inverse_log_checks, cot_piecewise_inverse, tan_piecewise_target,
  )
  for oracle in integrals_eval_zero_batch(inverse_log_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity inverse Mellin Bessel families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let half = @symcore.rational_from_ints(1, 2)
  let inverse_bessel_checks : Array[String] = []

  let besselj_input = @symspec.gamma(s + a * half) *
    (@symspec.gamma(@symcore.int(1) - s + a * half) ^ @symcore.int(-1))
  let besselj_inverse_opt = do_inverse_mellin_doit(besselj_input, s, x)
  assert_true(besselj_inverse_opt is Some(_))
  let besselj_inverse = besselj_inverse_opt.unwrap()
  push_simplify_zero_check(
    inverse_bessel_checks, besselj_inverse, "sympy.besselj(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, bessely_inverse, "sympy.bessely(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x')))",
  )

  let besselk_input = half *
    @symspec.gamma(s - a * half) *
    @symspec.gamma(s + a * half)
  let besselk_inverse_opt = do_inverse_mellin_doit(besselk_input, s, x)
  assert_true(besselk_inverse_opt is Some(_))
  let besselk_inverse = besselk_inverse_opt.unwrap()
  push_simplify_zero_check(
    inverse_bessel_checks, besselk_inverse, "sympy.besselk(sympy.Symbol('a'), 2*sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, sin_besselj_inverse, "sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, cos_besselj_inverse, "sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, sin_bessely_inverse, "sympy.sin(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, cos_bessely_inverse, "sympy.cos(sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, besselj_sq_inverse, "sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))**2",
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
  push_simplify_zero_check(
    inverse_bessel_checks, besselj_pm_inverse, "sympy.besselj(-sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, besselj_ab_inverse, "sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.besselj(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, besselj_bessely_inverse, "sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('b'), sympy.sqrt(sympy.Symbol('x')))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, besselj_bessely_same_inverse, "sympy.besselj(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))*sympy.bessely(sympy.Symbol('a'), sympy.sqrt(sympy.Symbol('x')))",
  )

  let exp_subst_input = @symcore.function("factorial", [
      s * (a ^ @symcore.int(-1)),
    ]) *
    (b ^ (@symcore.int(-1) * s * (a ^ @symcore.int(-1)))) *
    (s ^ @symcore.int(-1))
  let exp_subst_inverse_opt = do_inverse_mellin_doit(exp_subst_input, s, x)
  assert_true(exp_subst_inverse_opt is Some(_))
  let exp_subst_inverse = exp_subst_inverse_opt.unwrap()
  push_simplify_zero_check(
    inverse_bessel_checks, exp_subst_inverse, "sympy.exp(-sympy.Symbol('b')*sympy.Symbol('x')**sympy.Symbol('a'))",
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
  push_simplify_zero_check(
    inverse_bessel_checks, xpow_exp_subst_inverse, "sympy.Symbol('x')**sympy.Symbol('a')*sympy.exp(-sympy.Symbol('x')**sympy.Symbol('b'))",
  )
  for oracle in integrals_eval_zero_batch(inverse_bessel_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity transform conditions and auxiliary stage 5 families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let k = @symcore.Expr::Symbol("k")
  let a = @symcore.Expr::Symbol("a")
  let stage5_checks : Array[String] = []

  let ours_laplace = laplace_transform_eval(
    @symelem.exp(@symcore.int(2) * x),
    x,
    s,
  )
  stage5_checks.push(
    py_zero_if_equal_code(
      "sympy.sstr(" + py_expr(ours_laplace) + ")",
      "sympy.sstr(sympy.laplace_transform(sympy.exp(2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )

  let ours_mellin = mellin_transform_eval(
    x * @symspec.heaviside(@symcore.int(1) - x),
    x,
    s,
  )
  stage5_checks.push(
    py_zero_if_equal_code(
      "sympy.sstr(" + py_expr(ours_mellin) + ")",
      "sympy.sstr(sympy.mellin_transform(sympy.Symbol('x')*sympy.Heaviside(1 - sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('s')))",
    ),
  )

  let ours_sine = sine_transform_eval(@symelem.exp(@symcore.int(-2) * x), x, k)
  push_simplify_zero_check(
    stage5_checks, ours_sine, "sympy.sine_transform(sympy.exp(-2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let sine_half_power = doit(
    sine_transform(@symelem.sqrt(x) ^ @symcore.int(-1), x, k),
  )
  push_simplify_zero_check(
    stage5_checks, sine_half_power, "sympy.sine_transform(1/sympy.sqrt(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let inverse_sine_half_power = doit(
    inverse_sine_transform(@symelem.sqrt(k) ^ @symcore.int(-1), k, x),
  )
  push_simplify_zero_check(
    stage5_checks, inverse_sine_half_power, "1/sympy.sqrt(sympy.Symbol('x'))",
  )
  let sine_three_halves = doit(
    sine_transform(@symelem.sqrt(x) ^ @symcore.int(-1) ^ @symcore.int(3), x, k),
  )
  push_simplify_zero_check(
    stage5_checks, sine_three_halves, "sympy.sine_transform((1/sympy.sqrt(sympy.Symbol('x')))**3, sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let sine_log_over_x = doit(
    sine_transform(@symelem.log(x) * (x ^ @symcore.int(-1)), x, k),
  )
  push_simplify_zero_check(
    stage5_checks, sine_log_over_x, "sympy.sine_transform(sympy.log(sympy.Symbol('x'))/sympy.Symbol('x'), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let sine_gaussian = doit(
    sine_transform(
      x * @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2))),
      x,
      k,
    ),
  )
  push_simplify_zero_check(
    stage5_checks, sine_gaussian, "sympy.sine_transform(sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x')**2), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let inverse_sine_gaussian = doit(inverse_sine_transform(sine_gaussian, k, x))
  push_simplify_zero_check(
    stage5_checks, inverse_sine_gaussian, "sympy.Symbol('x')*sympy.exp(-2*sympy.Symbol('x')**2)",
  )
  let sine_power = doit(sine_transform(x ^ (@symcore.int(-1) * a), x, k))
  push_simplify_zero_check(
    stage5_checks, sine_power, "sympy.sine_transform(sympy.Symbol('x')**(-sympy.Symbol('a')), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let inverse_sine_power = doit(inverse_sine_transform(sine_power, k, x))
  push_simplify_zero_check(
    stage5_checks, inverse_sine_power, "sympy.Symbol('x')**(-sympy.Symbol('a'))",
  )
  for oracle in integrals_eval_zero_batch(stage5_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity cosine transform stage 5 families" {
  let x = @symcore.Expr::Symbol("x")
  let k = @symcore.Expr::Symbol("k")
  let a = @symcore.Expr::Symbol("a")
  let half = @symcore.rational_from_ints(1, 2)
  let cosine_checks : Array[String] = []

  let ours_cosine = cosine_transform_eval(
    @symelem.exp(@symcore.int(-2) * x),
    x,
    k,
  )
  push_simplify_zero_check(
    cosine_checks, ours_cosine, "sympy.cosine_transform(sympy.exp(-2*sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let inv_cosine_linear = doit(inverse_cosine_transform(ours_cosine, k, x))
  push_simplify_zero_check(
    cosine_checks, inv_cosine_linear, "sympy.exp(-2*sympy.Symbol('x'))",
  )
  let cosine_half_power = doit(
    cosine_transform(@symelem.sqrt(x) ^ @symcore.int(-1), x, k),
  )
  push_simplify_zero_check(
    cosine_checks, cosine_half_power, "sympy.cosine_transform(1/sympy.sqrt(sympy.Symbol('x')), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let inv_cosine_half_power = doit(
    inverse_cosine_transform(@symelem.sqrt(k) ^ @symcore.int(-1), k, x),
  )
  push_simplify_zero_check(
    cosine_checks, inv_cosine_half_power, "1/sympy.sqrt(sympy.Symbol('x'))",
  )
  let cosine_power = doit(cosine_transform(x ^ (@symcore.int(-1) * a), x, k))
  push_simplify_zero_check(
    cosine_checks, cosine_power, "sympy.cosine_transform(sympy.Symbol('x')**(-sympy.Symbol('a')), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let inverse_cosine_power = doit(inverse_cosine_transform(cosine_power, k, x))
  push_simplify_zero_check(
    cosine_checks, inverse_cosine_power, "sympy.Symbol('x')**(-sympy.Symbol('a'))",
  )
  let cosine_recip_quadratic = doit(
    cosine_transform(
      ((x ^ @symcore.int(2)) + @symcore.int(4)) ^ @symcore.int(-1),
      x,
      k,
    ),
  )
  push_simplify_zero_check(
    cosine_checks, cosine_recip_quadratic, "sympy.cosine_transform(1/(sympy.Symbol('x')**2 + 4), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  let inv_cosine_recip_quadratic = doit(
    inverse_cosine_transform(cosine_recip_quadratic, k, x),
  )
  push_simplify_zero_check(
    cosine_checks, inv_cosine_recip_quadratic, "1/(sympy.Symbol('x')**2 + 4)",
  )
  let cosine_shifted_recip = doit(
    cosine_transform((x + @symcore.int(2)) ^ @symcore.int(-1), x, k),
  )
  push_simplify_zero_check(
    cosine_checks, cosine_shifted_recip, "sympy.cosine_transform(1/(sympy.Symbol('x') + 2), sympy.Symbol('x'), sympy.Symbol('k'))",
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
  push_simplify_zero_check(
    cosine_checks, inverse_cosine_shifted_recip, "1/(sympy.Symbol('x') + 2)",
  )
  let cosine_sqrt_recip = doit(
    cosine_transform(
      @symelem.sqrt((x ^ @symcore.int(2)) + @symcore.int(4)) ^ @symcore.int(-1),
      x,
      k,
    ),
  )
  push_simplify_zero_check(
    cosine_checks, cosine_sqrt_recip, "sympy.cosine_transform(1/sympy.sqrt(sympy.Symbol('x')**2 + 4), sympy.Symbol('x'), sympy.Symbol('k'))",
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
  push_simplify_zero_check(
    cosine_checks, inverse_cosine_sqrt_recip, "1/(sympy.Symbol('x')*sympy.sqrt(4/sympy.Symbol('x')**2 + 1))",
  )
  let cosine_sqrt_decay = doit(
    cosine_transform(
      @symelem.exp(@symcore.int(-2) * @symelem.sqrt(x)) *
      @symelem.cos(@symcore.int(2) * @symelem.sqrt(x)),
      x,
      k,
    ),
  )
  push_simplify_zero_check(
    cosine_checks, cosine_sqrt_decay, "sympy.cosine_transform(sympy.exp(-2*sympy.sqrt(sympy.Symbol('x')))*sympy.cos(2*sympy.sqrt(sympy.Symbol('x'))), sympy.Symbol('x'), sympy.Symbol('k'))",
  )
  for oracle in integrals_eval_zero_batch(cosine_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity Hankel transform stage 5 families" {
  let r = @symcore.Expr::Symbol("r")
  let k = @symcore.Expr::Symbol("k")
  let a = @symcore.Expr::Symbol("a")
  let m = @symcore.Expr::Symbol("m")
  let nu = @symcore.Expr::Symbol("nu")
  let hankel_checks : Array[String] = []

  let ours_hankel = hankel_transform_eval(
    r * @symelem.exp(@symcore.int(-2) * r),
    r,
    k,
    @symcore.int(1),
  )
  push_simplify_zero_check(
    hankel_checks, ours_hankel, "sympy.hankel_transform(sympy.Symbol('r')*sympy.exp(-2*sympy.Symbol('r')), sympy.Symbol('r'), sympy.Symbol('k'), 1)",
  )
  let inv_hankel_linear = doit(
    inverse_hankel_transform(ours_hankel, k, r, @symcore.int(1)),
  )
  push_simplify_zero_check(
    hankel_checks, inv_hankel_linear, "sympy.Symbol('r')*sympy.exp(-2*sympy.Symbol('r'))",
  )
  let hankel_recip = doit(
    hankel_transform(r ^ @symcore.int(-1), r, k, @symcore.int(0)),
  )
  push_simplify_zero_check(
    hankel_checks, hankel_recip, "sympy.hankel_transform(1/sympy.Symbol('r'), sympy.Symbol('r'), sympy.Symbol('k'), 0)",
  )
  let inv_hankel_recip = doit(
    inverse_hankel_transform(k ^ @symcore.int(-1), k, r, @symcore.int(0)),
  )
  push_simplify_zero_check(
    hankel_checks, inv_hankel_recip, "1/sympy.Symbol('r')",
  )
  let hankel_power_zero = doit(
    hankel_transform(r ^ (@symcore.int(-1) * m), r, k, @symcore.int(0)),
  )
  push_simplify_zero_check(
    hankel_checks, hankel_power_zero, "sympy.hankel_transform(sympy.Symbol('r')**(-sympy.Symbol('m')), sympy.Symbol('r'), sympy.Symbol('k'), 0)",
  )
  let inv_hankel_power_zero = doit(
    inverse_hankel_transform(hankel_power_zero, k, r, @symcore.int(0)),
  )
  push_simplify_zero_check(
    hankel_checks, inv_hankel_power_zero, "sympy.Symbol('r')**(-sympy.Symbol('m'))",
  )
  let hankel_power_generic = doit(
    hankel_transform(r ^ (@symcore.int(-1) * m), r, k, nu),
  )
  push_simplify_zero_check(
    hankel_checks, hankel_power_generic, "sympy.hankel_transform(sympy.Symbol('r')**(-sympy.Symbol('m')), sympy.Symbol('r'), sympy.Symbol('k'), sympy.Symbol('nu'))",
  )
  let inv_hankel_power_generic = doit(
    inverse_hankel_transform(hankel_power_generic, k, r, nu),
  )
  push_simplify_zero_check(
    hankel_checks, inv_hankel_power_generic, "sympy.Symbol('r')**(-sympy.Symbol('m'))",
  )
  let hankel_exp_generic = doit(
    hankel_transform(
      (r ^ nu) * @symelem.exp(@symcore.int(-1) * a * r),
      r,
      k,
      nu,
    ),
  )
  push_simplify_zero_check(
    hankel_checks, hankel_exp_generic, "sympy.hankel_transform(sympy.Symbol('r')**sympy.Symbol('nu')*sympy.exp(-sympy.Symbol('a')*sympy.Symbol('r')), sympy.Symbol('r'), sympy.Symbol('k'), sympy.Symbol('nu'))",
  )
  let inv_hankel_exp_generic = doit(
    inverse_hankel_transform(hankel_exp_generic, k, r, nu),
  )
  push_simplify_zero_check(
    hankel_checks, inv_hankel_exp_generic, "sympy.Symbol('r')**sympy.Symbol('nu')*sympy.exp(-sympy.Symbol('a')*sympy.Symbol('r'))",
  )
  for oracle in integrals_eval_zero_batch(hankel_checks) {
    inspect(oracle, content="0")
  }
}

///|
test "symintegrals parity Gaussian transform stage 5 families" {
  let x = @symcore.Expr::Symbol("x")
  let r = @symcore.Expr::Symbol("r")
  let k = @symcore.Expr::Symbol("k")

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
}

///|
test "symintegrals parity Laplace special function forward rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
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
}

///|
test "symintegrals parity Laplace trig gaussian and hyperbolic forward rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
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
}

///|
test "symintegrals parity Laplace gaussian forward rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
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
}

///|
test "symintegrals parity Laplace periodic power forward rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")

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
}

///|
test "symintegrals parity Laplace sine-square quotient forward rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")

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
}

///|
test "symintegrals parity Laplace erf Bessel and Fresnel forward rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")

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
}

///|
test "symintegrals parity inverse Laplace named special families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let neg_half = @symcore.rational_from_ints(-1, 2)
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
    integrals_eval_str("sympy.sstr(" + py_expr(log_one_plus_inverse) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(-sympy.exp(sympy.Symbol('s')/sympy.Symbol('a'))*sympy.Ei(-sympy.Symbol('s')/sympy.Symbol('a'))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
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
}

///|
test "symintegrals parity inverse Laplace delay and sqrt elementary families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")

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

  let delayed_delta_inverse = doit(
    inverse_laplace_transform(@symelem.exp(@symcore.int(-1) * s), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_delta_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let offset_delayed_delta_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(1) + @symcore.int(-1) * s),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(offset_delayed_delta_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.exp(1 - sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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

  let b = @symcore.Expr::Symbol("b")
  let scaled_symbolic_power_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(2) * s + @symcore.int(4)) ^ (@symcore.int(-1) * b),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_symbolic_power_inverse) +
      ") - sympy.inverse_laplace_transform((2*sympy.Symbol('s') + 4)**(-sympy.Symbol('b')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_symbolic_lowergamma_inverse = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) *
      ((@symcore.int(2) * s + @symcore.int(4)) ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_symbolic_lowergamma_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*(2*sympy.Symbol('s') + 4)**sympy.Symbol('b')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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

  let reciprocal_scaled_sqrt_sum_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(3) * (s ^ @symcore.int(2)) + @symcore.int(12)) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_scaled_sqrt_sum_inverse) +
      ") - sympy.inverse_laplace_transform(1/sympy.sqrt(3*sympy.Symbol('s')**2 + 12), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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

  let reciprocal_scaled_sqrt_diff_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(3) * (s ^ @symcore.int(2)) - @symcore.int(12)) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_scaled_sqrt_diff_inverse) +
      ") - sympy.inverse_laplace_transform(1/sympy.sqrt(3*sympy.Symbol('s')**2 - 12), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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

  let raw_scaled_sqrt_linear_plus_const_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(raw_scaled_sqrt_linear_plus_const_inverse) +
      ") - sympy.inverse_laplace_transform(1/(3*sympy.sqrt(sympy.Symbol('s')) + 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sqrt_linear_negative_const_object = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(sqrt_linear_negative_const_object) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(1/(sympy.sqrt(sympy.Symbol('s')) - 2), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let a = @symcore.Expr::Symbol("a")
  let sqrt_linear_symbolic_const_object = doit(
    inverse_laplace_transform((@symelem.sqrt(s) + a) ^ @symcore.int(-1), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(sqrt_linear_symbolic_const_object) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(1/(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let scaled_sqrt_linear_plus_const_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(2) *
      (
        (@symelem.sqrt(@symcore.int(3) * s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_linear_plus_const_inverse) +
      ") - sympy.inverse_laplace_transform(2/(sympy.sqrt(3*sympy.Symbol('s')) + 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let sqrt_times_scaled_sqrt_linear_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
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
      py_expr(sqrt_times_scaled_sqrt_linear_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(5*sympy.Symbol('s'))*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let helper_rejected_negative_sqrt_fallback = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(helper_rejected_negative_sqrt_fallback) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) - 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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

  let scaled_reciprocal_sqrt_shifted_linear_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s + @symcore.int(15)) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_reciprocal_sqrt_shifted_linear_inverse) +
      ") - sympy.inverse_laplace_transform(1/((3*sympy.Symbol('s') + 3)*sympy.sqrt(5*sympy.Symbol('s') + 15)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let unit_scaled_sqrt_over_s_inverse = doit(
    inverse_laplace_transform(
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
      py_expr(unit_scaled_sqrt_over_s_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let numerator_scaled_s_over_sqrt_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(7) *
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
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
      py_expr(numerator_scaled_s_over_sqrt_inverse) +
      ") - sympy.inverse_laplace_transform(7/(2*sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace mixed sqrt parameter families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")

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

  let scaled_sqrt_linear_over_s_three_halves_inverse = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
      (@symelem.sqrt(@symcore.int(2) * s) ^ @symcore.int(-1)) *
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
      py_expr(scaled_sqrt_linear_over_s_three_halves_inverse) +
      ") - sympy.inverse_laplace_transform(1/(2*sympy.Symbol('s')*sympy.sqrt(2*sympy.Symbol('s'))*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
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

  let scaled_sqrt_ratio_general_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(6) * @symelem.sqrt(s) + @symcore.int(-4)) *
      ((@symcore.int(5) * s) ^ @symcore.int(-1)) *
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
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_ratio_general_inverse) +
      ") - sympy.inverse_laplace_transform((6*sympy.sqrt(sympy.Symbol('s')) - 4)/(5*sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace mixed sqrt shifted families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")

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

  let scaled_mixed_sqrt_shifted_linear_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(5) * s) *
      ((@symcore.int(7) * s + @symcore.int(-14)) ^ @symcore.int(-1)) *
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
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_mixed_sqrt_shifted_linear_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(5*sympy.Symbol('s'))/((7*sympy.Symbol('s') - 14)*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
    ),
    "0",
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
}

///|
test "symintegrals parity inverse Laplace sqrt power and ratio families" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")

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

  let scaled_sqrt_linear_squared_over_s_inverse = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-2)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_linear_squared_over_s_inverse) +
      ") - sympy.inverse_laplace_transform(1/(2*sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let scaled_sqrt_linear_squared_over_sqrt_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-2)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_linear_squared_over_sqrt_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(5*sympy.Symbol('s'))*(3*sympy.sqrt(sympy.Symbol('s')) + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let scaled_sqrt_over_sqrt_linear_cubed_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(5) * s) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-3)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_over_sqrt_linear_cubed_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(5*sympy.Symbol('s'))/(3*sympy.sqrt(sympy.Symbol('s')) + 2)**3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let scaled_sqrt_linear_cubed_over_sqrt_inverse = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-3)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_linear_cubed_over_sqrt_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.sqrt(5*sympy.Symbol('s'))*(3*sympy.sqrt(sympy.Symbol('s')) + 2)**3), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let scaled_sqrt_linear_squared_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_linear_squared_inverse) +
      ") - sympy.inverse_laplace_transform(1/(3*sympy.sqrt(sympy.Symbol('s')) + 2)**2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
    ),
    "0",
  )

  let scaled_sqrt_linear_cubed_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_linear_cubed_inverse) +
      ") - sympy.inverse_laplace_transform(1/(3*sympy.sqrt(sympy.Symbol('s')) + 2)**3, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
    ),
    "0",
  )

  let scaled_sqrt_linear_quartic_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(5) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-4)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_linear_quartic_inverse) +
      ") - sympy.inverse_laplace_transform(5/(3*sympy.sqrt(sympy.Symbol('s')) + 2)**4, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let scaled_shifted_sqrt_over_linear_inverse = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(5) * s + @symcore.int(10)) *
      ((@symcore.int(3) * s + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_shifted_sqrt_over_linear_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(5*sympy.Symbol('s') + 10)/(3*sympy.Symbol('s') + 3), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let scaled_sqrt_ratio_squared_general_inverse = doit(
    inverse_laplace_transform(
      (
        (@symcore.int(6) * @symelem.sqrt(s) + @symcore.int(-4)) ^
        @symcore.int(2)
      ) *
      ((@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-2)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_ratio_squared_general_inverse) +
      ") - sympy.inverse_laplace_transform((6*sympy.sqrt(sympy.Symbol('s')) - 4)**2/(5*sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
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

  let scaled_sqrt_ratio_cubed_general_inverse = doit(
    inverse_laplace_transform(
      (
        (@symcore.int(6) * @symelem.sqrt(s) + @symcore.int(-4)) ^
        @symcore.int(3)
      ) *
      ((@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-3)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_sqrt_ratio_cubed_general_inverse) +
      ") - sympy.inverse_laplace_transform((6*sympy.sqrt(sympy.Symbol('s')) - 4)**3/(5*sympy.Symbol('s')*(3*sympy.sqrt(sympy.Symbol('s')) + 2)**3), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace irrational factor sorting" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")

  let root_then_linear = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s + @symcore.int(3)) ^ @symcore.int(-1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let linear_then_root = doit(
    inverse_laplace_transform(
      ((s + @symcore.int(1)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(root_then_linear) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') + 1)*sympy.sqrt(sympy.Symbol('s') + 3)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(linear_then_root) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') + 1)*sympy.sqrt(sympy.Symbol('s') + 3)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let sorted_three_poles = doit(
    inverse_laplace_transform(
      ((s - @symcore.int(2)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reordered_three_poles = doit(
    inverse_laplace_transform(
      ((@symelem.sqrt(s) + @symcore.int(3)) ^ @symcore.int(-1)) *
      ((s - @symcore.int(2)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sorted_three_poles) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') - 2)*sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + 3)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reordered_three_poles) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') - 2)*sympy.sqrt(sympy.Symbol('s'))*(sympy.sqrt(sympy.Symbol('s')) + 3)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_three_poles = doit(
    inverse_laplace_transform(
      ((@symcore.int(9) * s + @symcore.int(-1)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
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
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_three_poles) +
      ") - sympy.inverse_laplace_transform(1/((9*sympy.Symbol('s') - 1)*sympy.sqrt(5*sympy.Symbol('s'))*(3*sympy.sqrt(sympy.Symbol('s')) + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
    ),
    "0",
  )

  let scaled_s_linear_three_poles = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(-6)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.factor_terms(sympy.simplify(sympy.expand((" +
      py_expr(scaled_s_linear_three_poles) +
      ") - sympy.inverse_laplace_transform(1/(2*sympy.Symbol('s')*(3*sympy.Symbol('s') - 6)*sympy.sqrt(5*sympy.Symbol('s'))), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))))",
    ),
    "0",
  )
}

///|
test "symintegrals parity inverse Laplace correspondence and object rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let q = @symcore.Expr::Symbol("q")
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
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

  let scaled_ilt_roundtrip = doit(
    inverse_laplace_transform(
      @symcore.int(2) * laplace_transform(f_t, t, s),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_ilt_roundtrip) +
      ") - sympy.InverseLaplaceTransform(2*sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('t')), sympy.Symbol('t'), sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit()))",
    ),
    "0",
  )

  let f_s = @symcore.raw_function("f", [s])
  let wrong_inner_frequency_dependent = doit(
    inverse_laplace_transform(laplace_transform(f_s, s, q), s, t),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(wrong_inner_frequency_dependent) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('q')), sympy.Symbol('s'), sympy.Symbol('t'), 0).doit())",
    ),
  )

  let wrong_inner_frequency_independent = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, q), s, t),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(wrong_inner_frequency_independent) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.LaplaceTransform(sympy.Function('f')(sympy.Symbol('t')), sympy.Symbol('t'), sympy.Symbol('q')), sympy.Symbol('s'), sympy.Symbol('t'), 0).doit())",
    ),
  )

  let k = @symcore.Expr::Symbol("k")
  let u = @symcore.Expr::Symbol("u")
  let f_big_of_s = @symcore.raw_function("F", [s])
  let generic_fdict : Map[String, String] = { "f": "F" }

  let generic_delay = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symelem.exp(@symcore.int(-2) * s) * f_big_of_s,
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_delay) + ")"),
    integrals_eval_str("sympy.sstr(sympy.Function('f')(sympy.Symbol('x') - 2))"),
  )

  let generic_shift = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        k * @symcore.raw_function("F", [s - @symcore.int(2)]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.Symbol('k')*sympy.exp(-2*sympy.Symbol('x'))*sympy.Function('f')(sympy.Symbol('x')))",
    ),
  )

  let generic_complex_frequency_shift = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.raw_function("F", [s - @symcore.int(1) - imag]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(generic_complex_frequency_shift) +
      ") - (sympy.exp((-1 - sympy.I)*sympy.Symbol('x'))*sympy.Function('f')(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let generic_negative_real_frequency_shift = doit(
    inverse_laplace_transform(
      @symcore.raw_function("F", [s + @symcore.int(1) - imag]),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(generic_negative_real_frequency_shift) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s') + 1 - sympy.I), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let generic_applied_undef_square = doit(
    inverse_laplace_transform(k * (f_big_of_s ^ @symcore.int(2)), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(generic_applied_undef_square) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Symbol('k')*sympy.Function('F')(sympy.Symbol('s'))**2, sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let generic_applied_undef_product = doit(
    inverse_laplace_transform(f_big_of_s * @symelem.sin(s), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(generic_applied_undef_product) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s'))*sympy.sin(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let reciprocal_frequency_diff = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative(s ^ @symcore.int(-1), [s]),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_frequency_diff) +
      ") - sympy.InverseLaplaceTransform(sympy.Derivative(1/sympy.Symbol('s'), sympy.Symbol('s'), evaluate=False), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit()))",
    ),
    "0",
  )

  let scaled_generic_diff = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.int(2) * @symcore.raw_function("Derivative", [f_big_of_s, s]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(scaled_generic_diff) + ")"),
    integrals_eval_str(
      "sympy.sstr(-2*sympy.Symbol('x')*sympy.Function('f')(sympy.Symbol('x')))",
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

  let ni = @symcore.Expr::Symbol("ni")
  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_integer(ni))
  let symbolic_integer_frequency_diff = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.Expr::Derivative(f_big_of_s, [s, ni]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_integer_frequency_diff) +
      ").xreplace({sympy.Symbol('ni'): sympy.Symbol('ni', integer=True)}) - ((-sympy.Symbol('x'))**sympy.Symbol('ni', integer=True)*sympy.Function('f')(sympy.Symbol('x')))))",
    ),
    "0",
  )

  let generic_mixed_source_diff = @symcore.raw_function("Derivative", [
    f_big_of_s, s, u,
  ])
  let generic_mixed_source_inverse = doit(
    inverse_laplace_transform(generic_mixed_source_diff, s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(generic_mixed_source_inverse) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Derivative(sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('u')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let generic_other_var_diff = @symcore.raw_function("Derivative", [
    f_big_of_s, u,
  ])
  let generic_other_var_inverse = doit(
    inverse_laplace_transform(generic_other_var_diff, s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_other_var_inverse) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Derivative(sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('u')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let unknown_nested_source = @symelem.sin(f_big_of_s)
  let unknown_nested_inverse = doit(
    inverse_laplace_transform(unknown_nested_source, s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(unknown_nested_inverse) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.sin(sympy.Function('F')(sympy.Symbol('s'))), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let unknown_exp_source_over_pole = @symelem.exp(f_big_of_s) *
    ((s + @symcore.int(1)) ^ @symcore.int(-1))
  let unknown_exp_source_inverse = doit(
    inverse_laplace_transform(unknown_exp_source_over_pole, s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(unknown_exp_source_inverse) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(sympy.Function('F')(sympy.Symbol('s')))/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let f_of_u = @symcore.raw_function("F", [u])
  let independent_unknown_factor_inverse = doit(
    inverse_laplace_transform(
      f_of_u * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(independent_unknown_factor_inverse) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('u'))/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let generic_expanded_sum = doit(
    inverse_laplace_transform((s + @symcore.int(1)) * f_big_of_s, s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_expanded_sum) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0) + sympy.Derivative(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0), sympy.Symbol('x')))",
    ),
  )

  let generic_additive_expanded_terms = doit(
    inverse_laplace_transform(
      (s + @symcore.int(1)) * f_big_of_s + (s + @symcore.int(2)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(generic_additive_expanded_terms) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform((sympy.Symbol('s') + 1)*sympy.Function('F')(sympy.Symbol('s')) + (sympy.Symbol('s') + 2)*sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let generic_expanded_power = doit(
    inverse_laplace_transform(
      ((s + @symcore.int(1)) ^ @symcore.int(2)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_expanded_power) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0) + 2*sympy.Derivative(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0), sympy.Symbol('x')) + sympy.Derivative(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0), (sympy.Symbol('x'), 2)))",
    ),
  )

  let generic_expanded_product = doit(
    inverse_laplace_transform(
      (s + @symcore.int(1)) * (s + @symcore.int(2)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_expanded_product) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform((sympy.Symbol('s') + 1)*(sympy.Symbol('s') + 2)*sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let generic_expanded_cubic = doit(
    inverse_laplace_transform(
      ((s + @symcore.int(1)) ^ @symcore.int(3)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(generic_expanded_cubic) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform((sympy.Symbol('s') + 1)**3*sympy.Function('F')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )
}

///|
test "symintegrals parity inverse Laplace symbolic kernel rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")

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

  let symbolic_shifted_single_power_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(3) * ((s + a) ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_shifted_single_power_inverse) +
      ") - (3*sympy.Symbol('x')**(sympy.Symbol('b') - 1)*sympy.exp(-sympy.Symbol('a')*sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x'))/sympy.gamma(sympy.Symbol('b')))))",
    ),
    "0",
  )

  let symbolic_shifted_time_diff_inverse = doit(
    inverse_laplace_transform(s * ((s + a) ^ (@symcore.int(-1) * b)), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_shifted_time_diff_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('s')*(sympy.Symbol('s') + sympy.Symbol('a'))**(-sympy.Symbol('b')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let np = @symcore.Expr::Symbol("np")
  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(np))
  @symassume.add_global_assumption(@symassume.q_integer(np))
  let symbolic_integer_time_diff_inverse = doit(
    inverse_laplace_transform(
      (s ^ np) * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let symbolic_integer_unknown_time_diff_inverse = doit(
    inverse_laplace_transform((s ^ np) * @symcore.raw_function("f", [s]), s, x),
  )
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_integer_time_diff_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('s')**sympy.Symbol('np', positive=True, integer=True)/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_integer_unknown_time_diff_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('s')**sympy.Symbol('np', positive=True, integer=True)*sympy.Function('f')(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let shifted_power_frequency_diff_inverse = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative((s + @symcore.int(1)) ^ @symcore.int(-2), [s]),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(shifted_power_frequency_diff_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Derivative((sympy.Symbol('s') + 1)**(-2), sympy.Symbol('s'), evaluate=False), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let symbolic_shifted_frequency_diff_inverse = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative((s + a) ^ (@symcore.int(-1) * b), [s]),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_shifted_frequency_diff_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Derivative((sympy.Symbol('s') + sympy.Symbol('a'))**(-sympy.Symbol('b')), sympy.Symbol('s'), evaluate=False), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let symbolic_shifted_power_inverse = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) * ((s + a) ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_shifted_power_inverse) +
      ") - (sympy.Heaviside(sympy.Symbol('x'))*sympy.lowergamma(sympy.Symbol('b'), sympy.Symbol('a')*sympy.Symbol('x'))/(sympy.Symbol('a')**sympy.Symbol('b')*sympy.gamma(sympy.Symbol('b'))))))",
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
      "sympy.sstr(" + py_expr(delayed_symbolic_power_inverse) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(-sympy.Symbol('a')*sympy.Symbol('s'))/sympy.Symbol('s')**sympy.Symbol('b'), sympy.Symbol('s'), sympy.Symbol('x'), 0))",
    ),
  )

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))
  let delayed_positive_symbolic_power_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let delayed_scaled_positive_symbolic_power_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-2) * a * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let delayed_product_positive_symbolic_power_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * b * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let sqrt_linear_positive_const_inverse = doit(
    inverse_laplace_transform((@symelem.sqrt(s) + a) ^ @symcore.int(-1), s, x),
  )
  @symassume.clear_global_assumptions()
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_positive_symbolic_power_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('a', positive=True)*sympy.Symbol('s'))/sympy.Symbol('s')**sympy.Symbol('b', positive=True), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_product_positive_symbolic_power_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(-sympy.Symbol('a', positive=True)*sympy.Symbol('b', positive=True)*sympy.Symbol('s'))/sympy.Symbol('s')**sympy.Symbol('b', positive=True), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(delayed_scaled_positive_symbolic_power_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True), sympy.Symbol('b'): sympy.Symbol('b', positive=True)}) - sympy.inverse_laplace_transform(sympy.exp(-2*sympy.Symbol('a', positive=True)*sympy.Symbol('s'))/sympy.Symbol('s')**sympy.Symbol('b', positive=True), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_linear_positive_const_inverse) +
      ").xreplace({sympy.Symbol('a'): sympy.Symbol('a', positive=True)}) - sympy.inverse_laplace_transform(1/(sympy.sqrt(sympy.Symbol('s')) + sympy.Symbol('a', positive=True)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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
}

///|
test "symintegrals parity inverse Laplace delta matrix and time-diff rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")

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

  let constant_delta_inverse = doit(inverse_laplace_transform(a, s, x))
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(constant_delta_inverse) +
      ") - sympy.InverseLaplaceTransform(sympy.Symbol('a'), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit()))",
    ),
    "0",
  )

  let reciprocal_simple_inverse = doit(
    inverse_laplace_transform(a * (s ^ @symcore.int(-1)), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(reciprocal_simple_inverse) +
      ") - sympy.InverseLaplaceTransform(sympy.Symbol('a')/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit()))",
    ),
    "0",
  )

  let reciprocal_public_default = @symintegrals.inverse_laplace_transform_eval(
    a * (s ^ @symcore.int(-1)),
    s,
    x,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(reciprocal_public_default) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.inverse_laplace_transform(sympy.Symbol('a')/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x')))",
    ),
  )

  let reciprocal_public_with_conditions = @symintegrals.inverse_laplace_transform_eval(
    a * (s ^ @symcore.int(-1)),
    s,
    x,
    noconds=false,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(reciprocal_public_with_conditions) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.inverse_laplace_transform(sympy.Symbol('a')/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=False))",
    ),
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

  let sparse_polynomial_delta_inverse = doit(
    inverse_laplace_transform((s ^ @symcore.int(4)) + @symcore.int(2), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sparse_polynomial_delta_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('s')**4 + 2, sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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
    integrals_eval_str("sympy.sstr(" + py_expr(delayed_bessel_inverse) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(-sympy.Symbol('a')*sympy.Symbol('s'))/sympy.sqrt(sympy.Symbol('s')**2 + 1), sympy.Symbol('s'), sympy.Symbol('x'), 0))",
    ),
  )

  let delayed_numeric_bessel_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-2) * s) *
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
      py_expr(delayed_numeric_bessel_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.exp(-2*sympy.Symbol('s'))/sympy.sqrt(sympy.Symbol('s')**2 + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
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
}

///|
test "symintegrals parity inverse Laplace object and shift edge rules" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let f_of_s = @symcore.raw_function("f", [s])
  let t = @symcore.Expr::Symbol("t")
  let f_t = @symcore.raw_function("f", [t])

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

  let positive_shift_product_object = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(positive_shift_product_object) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(2*sympy.Symbol('s'))/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let positive_shift_scaled_object = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(1)) * @symelem.exp(@symcore.int(2) * s),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(positive_shift_scaled_object) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.E*sympy.exp(2*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let positive_shift_offset_delta = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(positive_shift_offset_delta) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(2*sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let positive_shift_offset_product = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(" +
      py_expr(positive_shift_offset_product) +
      "))",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(sympy.InverseLaplaceTransform(sympy.exp(2*sympy.Symbol('s') + 1)/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit()))",
    ),
  )

  let positive_shift_offset_double_pole = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(positive_shift_offset_double_pole) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(2*sympy.Symbol('s') + 1)/sympy.Symbol('s')**2, sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let positive_shift_offset_shifted_double_pole = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(" +
      py_expr(positive_shift_offset_shifted_double_pole) +
      "))",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.simplify(sympy.InverseLaplaceTransform(sympy.exp(2*sympy.Symbol('s') + 1)/(sympy.Symbol('s') + 1)**2, sympy.Symbol('s'), sympy.Symbol('x'), 0).doit()))",
    ),
  )

  let positive_shift_offset_triple_pole = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      (s ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(positive_shift_offset_triple_pole) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.exp(2*sympy.Symbol('s') + 1)/sympy.Symbol('s')**3, sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
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
    noconds=false,
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

  let known_frequency_shift = doit(
    inverse_laplace_transform(@symelem.sin(s - @symcore.int(2)), s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(known_frequency_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.sin(sympy.Symbol('s') - 2), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let known_frequency_shift_noconds = @symintegrals.inverse_laplace_transform_eval(
    @symelem.sin(s - @symcore.int(2)),
    s,
    x,
    noconds=false,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(known_frequency_shift_noconds) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.inverse_laplace_transform(sympy.sin(sympy.Symbol('s') - 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=False))",
    ),
  )

  let gamma_frequency_shift = doit(
    inverse_laplace_transform(@symspec.gamma(s - @symcore.int(1)), s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(gamma_frequency_shift) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.gamma(sympy.Symbol('s') - 1), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let positive_arg_shift_object = doit(
    inverse_laplace_transform(@symelem.sin(s + @symcore.int(2)), s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(positive_arg_shift_object) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.sin(sympy.Symbol('s') + 2), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let unknown_arg_shift_source = @symcore.raw_function("F", [s - a])
  let unknown_arg_shift_object = doit(
    inverse_laplace_transform(unknown_arg_shift_source, s, x),
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(unknown_arg_shift_object) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.Function('F')(sympy.Symbol('s') - sympy.Symbol('a')), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
    ),
  )

  let binary_frequency_shift_object = doit(
    inverse_laplace_transform(
      @symspec.besselj(@symcore.int(0), s - @symcore.int(1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(binary_frequency_shift_object) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.InverseLaplaceTransform(sympy.besselj(0, sympy.Symbol('s') - 1), sympy.Symbol('s'), sympy.Symbol('x'), 0).doit())",
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

  let exp_normalized_inverse = doit(
    inverse_laplace_transform(
      (
        (s ^ @symcore.int(2)) * @symelem.exp(@symcore.int(2) * s) +
        @symcore.int(4) * @symelem.exp(s) +
        @symcore.int(-4)
      ) *
      @symelem.exp(@symcore.int(-2) * s) *
      (s ^ @symcore.int(-1)) *
      (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(exp_normalized_inverse) +
      ") - (sympy.cos(sympy.Symbol('x'))*sympy.Heaviside(sympy.Symbol('x')) + 4*sympy.cos(sympy.Symbol('x') - 2)*sympy.Heaviside(sympy.Symbol('x') - 2) - 4*sympy.cos(sympy.Symbol('x') - 1)*sympy.Heaviside(sympy.Symbol('x') - 1) - 4*sympy.Heaviside(sympy.Symbol('x') - 2) + 4*sympy.Heaviside(sympy.Symbol('x') - 1))))",
    ),
    "0",
  )

  let improper_quadratic_remainder_inverse = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(2)) + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(improper_quadratic_remainder_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s')**2 + 1)/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let three_linear_apart_inverse = doit(
    inverse_laplace_transform(
      (s * (s + @symcore.int(1)) * (s + @symcore.int(2))) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(three_linear_apart_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*(sympy.Symbol('s') + 1)*(sympy.Symbol('s') + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let four_linear_apart_inverse = doit(
    inverse_laplace_transform(
      (
        s *
        (s + @symcore.int(1)) *
        (s + @symcore.int(2)) *
        (s + @symcore.int(3))
      ) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(four_linear_apart_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')*(sympy.Symbol('s') + 1)*(sympy.Symbol('s') + 2)*(sympy.Symbol('s') + 3)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let repeated_linear_apart_inverse = doit(
    inverse_laplace_transform(
      (((s + @symcore.int(1)) ^ @symcore.int(2)) * (s + @symcore.int(2))) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(repeated_linear_apart_inverse) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') + 1)**2*(sympy.Symbol('s') + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let repeated_linear_cubic_apart_inverse = doit(
    inverse_laplace_transform(
      (((s + @symcore.int(1)) ^ @symcore.int(3)) * (s + @symcore.int(2))) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(repeated_linear_cubic_apart_inverse) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') + 1)**3*(sympy.Symbol('s') + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let repeated_linear_cubic_numerator_inverse = doit(
    inverse_laplace_transform(
      (
        (s ^ @symcore.int(3)) +
        @symcore.int(2) * (s ^ @symcore.int(2)) +
        @symcore.int(3) * s +
        @symcore.int(5)
      ) *
      (
        (((s + @symcore.int(1)) ^ @symcore.int(3)) * (s + @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(repeated_linear_cubic_numerator_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s')**3 + 2*sympy.Symbol('s')**2 + 3*sympy.Symbol('s') + 5)/((sympy.Symbol('s') + 1)**3*(sympy.Symbol('s') + 2)), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let repeated_linear_frequency_diff_inverse = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative(
        (((s + @symcore.int(1)) ^ @symcore.int(3)) * (s + @symcore.int(2))) ^
        @symcore.int(-1),
        [s],
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(repeated_linear_frequency_diff_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Derivative(1/((sympy.Symbol('s') + 1)**3*(sympy.Symbol('s') + 2)), sympy.Symbol('s'), evaluate=False), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let double_repeated_linear_apart_inverse = doit(
    inverse_laplace_transform(
      (
        ((s + @symcore.int(1)) ^ @symcore.int(2)) *
        ((s + @symcore.int(2)) ^ @symcore.int(2))
      ) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(double_repeated_linear_apart_inverse) +
      ") - sympy.inverse_laplace_transform(1/((sympy.Symbol('s') + 1)**2*(sympy.Symbol('s') + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let double_repeated_linear_numerator_apart_inverse = doit(
    inverse_laplace_transform(
      (s + @symcore.int(3)) *
      (
        (
          ((s + @symcore.int(1)) ^ @symcore.int(2)) *
          ((s + @symcore.int(2)) ^ @symcore.int(2))
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(double_repeated_linear_numerator_apart_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s') + 3)/((sympy.Symbol('s') + 1)**2*(sympy.Symbol('s') + 2)**2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let quadratic_repeated_root_den = (s ^ @symcore.int(2)) +
    @symcore.int(2) * s +
    @symcore.int(1)
  let quadratic_repeated_root_inverse = doit(
    inverse_laplace_transform(
      quadratic_repeated_root_den ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(quadratic_repeated_root_inverse) +
      ") - sympy.inverse_laplace_transform(1/(sympy.Symbol('s')**2 + 2*sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let quadratic_repeated_root_numerator_inverse = doit(
    inverse_laplace_transform(
      (s + @symcore.int(3)) * (quadratic_repeated_root_den ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(quadratic_repeated_root_numerator_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s') + 3)/(sympy.Symbol('s')**2 + 2*sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_quadratic_repeated_root_inverse = doit(
    inverse_laplace_transform(
      (s + @symcore.int(3)) *
      (
        (
          @symcore.int(2) * (s ^ @symcore.int(2)) +
          @symcore.int(4) * s +
          @symcore.int(2)
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_quadratic_repeated_root_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s') + 3)/(2*sympy.Symbol('s')**2 + 4*sympy.Symbol('s') + 2), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_linear_lead_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(1) *
      ((@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_linear_lead_inverse) +
      ") - sympy.inverse_laplace_transform(1/(2*sympy.Symbol('s') + 4), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_linear_improper_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * s + @symcore.int(5)) *
      ((@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_linear_improper_inverse) +
      ") - sympy.inverse_laplace_transform((3*sympy.Symbol('s') + 5)/(2*sympy.Symbol('s') + 4), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_distinct_quadratic_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * s + @symcore.int(5)) *
      (
        (
          @symcore.int(2) * (s ^ @symcore.int(2)) +
          @symcore.int(4) * s +
          @symcore.int(10)
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_distinct_quadratic_inverse) +
      ") - sympy.inverse_laplace_transform((3*sympy.Symbol('s') + 5)/(2*sympy.Symbol('s')**2 + 4*sympy.Symbol('s') + 10), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let improper_linear_inverse = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(2)) + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(improper_linear_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s')**2 + 1)/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let improper_quadratic_inverse = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(3)) + @symcore.int(2) * s + @symcore.int(1)) *
      (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(improper_quadratic_inverse) +
      ") - sympy.inverse_laplace_transform((sympy.Symbol('s')**3 + 2*sympy.Symbol('s') + 1)/(sympy.Symbol('s')**2 + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let gamma_mellin_fallback_inverse = doit(
    inverse_laplace_transform(@symspec.gamma(s), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(gamma_mellin_fallback_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.gamma(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let gamma_shift_mellin_fallback_inverse = doit(
    inverse_laplace_transform(@symspec.gamma(s + @symcore.int(1)), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(gamma_shift_mellin_fallback_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.gamma(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_gamma_mellin_fallback_inverse = doit(
    inverse_laplace_transform(@symcore.int(2) * @symspec.gamma(s), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_gamma_mellin_fallback_inverse) +
      ") - sympy.inverse_laplace_transform(2*sympy.gamma(sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let symbolic_scaled_gamma_shift_inverse = doit(
    inverse_laplace_transform(a * @symspec.gamma(s + @symcore.int(1)), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(symbolic_scaled_gamma_shift_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.Symbol('a')*sympy.gamma(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let gamma_minus_i_mellin_fallback_inverse = doit(
    inverse_laplace_transform(@symspec.gamma(s - imag), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(gamma_minus_i_mellin_fallback_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.gamma(sympy.Symbol('s') - sympy.I), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let gamma_plus_i_mellin_fallback_inverse = doit(
    inverse_laplace_transform(@symspec.gamma(s + imag), s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(gamma_plus_i_mellin_fallback_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.gamma(sympy.Symbol('s') + sympy.I), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let z = @symcore.Expr::Symbol("z")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let sqrt_kernel = @symelem.sqrt(pi) *
    (@symelem.sqrt(z) ^ @symcore.int(-1)) *
    @symelem.exp(@symcore.int(-2) * @symelem.sqrt(z) * @symelem.sqrt(s))
  let sqrt_kernel_public_inverse = doit(
    inverse_laplace_transform(sqrt_kernel, s, x),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(sqrt_kernel_public_inverse) +
      ") - sympy.inverse_laplace_transform(sympy.sqrt(sympy.pi)*sympy.exp(-2*sympy.sqrt(sympy.Symbol('z'))*sympy.sqrt(sympy.Symbol('s')))/sympy.sqrt(sympy.Symbol('z')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_mellin_left_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_mellin_left_inverse) +
      ") - sympy.inverse_laplace_transform(2**(-sympy.Symbol('s'))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_mellin_denominator_inverse = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) ^ s) * s) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_mellin_denominator_inverse) +
      ") - sympy.inverse_laplace_transform(1/(2**sympy.Symbol('s')*sympy.Symbol('s')), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let scaled_mellin_right_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(2) ^ s) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_mellin_right_inverse) +
      ") - sympy.inverse_laplace_transform(2**sympy.Symbol('s')/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
  )

  let symbolic_base_mellin_right = @symintegrals.inverse_laplace_transform_eval(
    (a ^ s) * (s ^ @symcore.int(-1)),
    s,
    x,
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(" + py_expr(symbolic_base_mellin_right) + ")",
    ),
    integrals_eval_str(
      "sympy.sstr(sympy.inverse_laplace_transform(sympy.Symbol('a')**sympy.Symbol('s')/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True))",
    ),
  )

  let symbolic_base_mellin_left = @symintegrals.inverse_laplace_transform_eval(
    (a ^ (@symcore.int(-1) * s)) * (s ^ @symcore.int(-1)),
    s,
    x,
  )
  assert_eq(
    integrals_eval_str("sympy.sstr(" + py_expr(symbolic_base_mellin_left) + ")"),
    integrals_eval_str(
      "sympy.sstr(sympy.inverse_laplace_transform(sympy.Symbol('a')**(-sympy.Symbol('s'))/sympy.Symbol('s'), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True))",
    ),
  )

  let scaled_mellin_shift_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    integrals_eval_str(
      "sympy.sstr(sympy.simplify((" +
      py_expr(scaled_mellin_shift_inverse) +
      ") - sympy.inverse_laplace_transform(2**(-sympy.Symbol('s'))/(sympy.Symbol('s') + 1), sympy.Symbol('s'), sympy.Symbol('x'), noconds=True)))",
    ),
    "0",
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
  let square_checks : Array[String] = []
  let ours_xy = polytope_integrate(square, x * y, vars=[x, y])
  push_simplify_zero_check(
    square_checks, ours_xy, "__import__('sympy.integrals.intpoly', fromlist=['polytope_integrate']).polytope_integrate(sympy.Polygon(sympy.Point(0, 0), sympy.Point(0, 1), sympy.Point(1, 1), sympy.Point(1, 0)), sympy.Symbol('x')*sympy.Symbol('y'))",
  )
  let ours_x2y = polytope_integrate(square, (x ^ @symcore.int(2)) * y, vars=[
    x, y,
  ])
  push_simplify_zero_check(
    square_checks, ours_x2y, "__import__('sympy.integrals.intpoly', fromlist=['polytope_integrate']).polytope_integrate(sympy.Polygon(sympy.Point(0, 0), sympy.Point(0, 1), sympy.Point(1, 1), sympy.Point(1, 0)), sympy.Symbol('x')**2*sympy.Symbol('y'))",
  )
  inspect_zero_batches(square_checks)
}

///|
test "symintegrals parity intpoly helper functions" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let helper_checks : Array[String] = []
  let (coeff, monom) = strip(@symcore.int(3) * x * y)
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['strip']).strip(3*sympy.Symbol('x')*sympy.Symbol('y'))[0])",
      @symprint.pretty_string(coeff),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['strip']).strip(3*sympy.Symbol('x')*sympy.Symbol('y'))[1])",
      @symprint.pretty_string(monom),
    ),
  )

  let x2 = x ^ @symcore.int(2)
  let x3 = x ^ @symcore.int(3)
  let y2 = y ^ @symcore.int(2)
  let y5 = y ^ @symcore.int(5)
  let decomposed = decompose(x2 + x * y + x + y + x3 * y2 + y5)
  assert_true(decomposed.length() == 3)
  assert_true(decomposed[0].0 == 1)
  helper_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(decomposed[0].1) +
    ") - (__import__('sympy.integrals.intpoly', fromlist=['decompose']).decompose(sympy.Symbol('x')**2 + sympy.Symbol('x')*sympy.Symbol('y') + sympy.Symbol('x') + sympy.Symbol('y') + sympy.Symbol('x')**3*sympy.Symbol('y')**2 + sympy.Symbol('y')**5)[1])))",
  )
  assert_true(decomposed[2].0 == 5)
  helper_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(decomposed[2].1) +
    ") - (__import__('sympy.integrals.intpoly', fromlist=['decompose']).decompose(sympy.Symbol('x')**2 + sympy.Symbol('x')*sympy.Symbol('y') + sympy.Symbol('x') + sympy.Symbol('y') + sympy.Symbol('x')**3*sympy.Symbol('y')**2 + sympy.Symbol('y')**5)[5])))",
  )

  let point = @symgeometry.point2d(@symcore.int(2), @symcore.int(7))
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['norm']).norm(sympy.Point(2, 7)))",
      @symprint.pretty_string(norm(point)),
    ),
  )

  let cross = cross_product(
    @symgeometry.point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    @symgeometry.point3d(@symcore.int(1), @symcore.int(0), @symcore.int(0)),
    @symgeometry.point3d(@symcore.int(0), @symcore.int(1), @symcore.int(0)),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['cross_product']).cross_product((0, 0, 0), (1, 0, 0), (0, 1, 0)))",
      "[" + cross.map(@symprint.pretty_string).join(", ") + "]",
    ),
  )

  let distance = distance_to_side(
    @symgeometry.point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    @symgeometry.segment(
      @symgeometry.point3d(@symcore.int(0), @symcore.int(0), @symcore.int(1)),
      @symgeometry.point3d(@symcore.int(0), @symcore.int(1), @symcore.int(0)),
    ),
    @symgeometry.point3d(@symcore.int(1), @symcore.int(0), @symcore.int(0)),
  )
  helper_checks.push(
    "sympy.sstr(sympy.simplify((" +
    py_expr(distance) +
    ") - (__import__('sympy.integrals.intpoly', fromlist=['distance_to_side']).distance_to_side((0, 0, 0), [(0, 0, 1), (0, 1, 0)], (1, 0, 0)))))",
  )

  let hit = intersection(
    @symgeometry.segment(
      @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
      @symgeometry.point2d(@symcore.int(3), @symcore.int(5)),
    ),
    @symgeometry.segment(
      @symgeometry.point2d(@symcore.int(2), @symcore.int(0)),
      @symgeometry.point2d(@symcore.int(2), @symcore.int(5)),
    ),
    "segment2D",
  )
  guard hit is Some(point) else {
    fail("expected a unique segment intersection")
  }
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['intersection']).intersection(sympy.Segment2D(sympy.Point(1, 1), sympy.Point(3, 5)), sympy.Segment2D(sympy.Point(2, 0), sympy.Point(2, 5)), 'segment2D'))",
      "(" +
      @symprint.pretty_string(point.x()) +
      ", " +
      @symprint.pretty_string(point.y()) +
      ")",
    ),
  )

  let vertex_text = if is_vertex(point) { "True" } else { "False" }
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['is_vertex']).is_vertex(sympy.Point(2, 7)))",
      vertex_text,
    ),
  )

  let terms = gradient_terms(binomial_power=2)
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(len(__import__('sympy.integrals.intpoly', fromlist=['gradient_terms']).gradient_terms(2)))",
      terms.length().to_string(),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['gradient_terms']).gradient_terms(2)[1][0])",
      @symprint.pretty_string(terms[1][0]),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['gradient_terms']).gradient_terms(2)[5][0])",
      @symprint.pretty_string(terms[5][0]),
    ),
  )
  inspect_zero_batches(helper_checks, chunk_size=4)
}

///|
test "symintegrals parity intpoly geometry helper functions" {
  let helper_checks : Array[String] = []
  let square = match
    @symgeometry.polygon([
      @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(0)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
      @symgeometry.point2d(@symcore.int(0), @symcore.int(1)),
    ]) {
    @symgeometry.GeometryEntity::Polygon(poly) => poly
    _ => fail("expected polygon from helper square vertices")
  }
  let params = hyperplane_parameters(square)
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['hyperplane_parameters']).hyperplane_parameters(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)))[1][0][0])",
      @symprint.pretty_string(params[1].0[0]),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['hyperplane_parameters']).hyperplane_parameters(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)))[1][1])",
      @symprint.pretty_string(params[1].1),
    ),
  )
  inspect_zero_batches(helper_checks, chunk_size=2)
}

///|
test "symintegrals parity intpoly point selection helpers" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let helper_checks : Array[String] = []
  let sorted_points = point_sort([
    @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
    @symgeometry.point2d(@symcore.int(1), @symcore.int(0)),
    @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
  ])
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['point_sort']).point_sort([sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1)])[0].x)",
      @symprint.pretty_string(sorted_points[0].x()),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['point_sort']).point_sort([sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1)])[0].y)",
      @symprint.pretty_string(sorted_points[0].y()),
    ),
  )

  let best = best_origin(
    [@symcore.int(2), @symcore.int(1)],
    @symcore.int(3),
    @symgeometry.segment(
      @symgeometry.point2d(@symcore.int(0), @symcore.int(3)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
    ),
    (x ^ @symcore.int(3)) * (y ^ @symcore.int(7)),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['best_origin']).best_origin((sympy.Integer(2), sympy.Integer(1)), sympy.Integer(3), sympy.Segment2D(sympy.Point(0, 3), sympy.Point(1, 1)), sympy.Symbol('x')**3*sympy.Symbol('y')**7)[0])",
      @symprint.pretty_string(best.x()),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['best_origin']).best_origin((sympy.Integer(2), sympy.Integer(1)), sympy.Integer(3), sympy.Segment2D(sympy.Point(0, 3), sympy.Point(1, 1)), sympy.Symbol('x')**3*sympy.Symbol('y')**7)[1])",
      @symprint.pretty_string(best.y()),
    ),
  )
  inspect_zero_batches(helper_checks, chunk_size=4)
}

///|
test "symintegrals parity intpoly 2d reduction helpers" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let helper_checks : Array[String] = []
  let square = match
    @symgeometry.polygon([
      @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(0)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
      @symgeometry.point2d(@symcore.int(0), @symcore.int(1)),
    ]) {
    @symgeometry.GeometryEntity::Polygon(poly) => poly
    _ => fail("expected polygon from helper square vertices")
  }
  let params = hyperplane_parameters(square)
  let facets = square.sides()
  let left = left_integral2D(
    facets.length(),
    0,
    facets,
    facets[0].p1(),
    @symcore.int(1),
    [x, y],
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['left_integral2D']).left_integral2D(4, 0, sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)).sides, sympy.Point(0, 0), 1, (sympy.Symbol('x'), sympy.Symbol('y'))))",
      @symprint.pretty_string(left),
    ),
  )
  let reduced = integration_reduction(
    facets,
    0,
    params[0].0,
    params[0].1,
    @symcore.int(1),
    [x, y],
    0,
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['integration_reduction', 'hyperplane_parameters']).integration_reduction(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)).sides, 0, __import__('sympy.integrals.intpoly', fromlist=['hyperplane_parameters']).hyperplane_parameters(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)))[0][0], __import__('sympy.integrals.intpoly', fromlist=['hyperplane_parameters']).hyperplane_parameters(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)))[0][1], 1, (sympy.Symbol('x'), sympy.Symbol('y')), 0))",
      @symprint.pretty_string(reduced),
    ),
  )
  let dynamic = integration_reduction_dynamic(
    facets,
    0,
    params[0].0,
    params[0].1,
    x,
    1,
    [x, y],
    1,
    0,
    1,
    facets[0].p1(),
    [
      [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(1)],
      [y, @symcore.int(0), @symcore.int(1), @symcore.rational_from_ints(1, 2)],
      [x, @symcore.int(1), @symcore.int(0), @symcore.int(0)],
    ],
    3,
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['integration_reduction_dynamic', 'hyperplane_parameters']).integration_reduction_dynamic(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)).sides, 0, __import__('sympy.integrals.intpoly', fromlist=['hyperplane_parameters']).hyperplane_parameters(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)))[0][0], __import__('sympy.integrals.intpoly', fromlist=['hyperplane_parameters']).hyperplane_parameters(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)))[0][1], sympy.Symbol('x'), 1, (sympy.Symbol('x'), sympy.Symbol('y')), 1, 0, 1, sympy.Point(0, 0), [[0, 0, 0, 0], [1, 0, 0, 1], [sympy.Symbol('y'), 0, 1, sympy.Rational(1, 2)], [sympy.Symbol('x'), 1, 0, 0]], 3))",
      @symprint.pretty_string(dynamic),
    ),
  )
  let main_value = main_integrate(x * y, facets, params)
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['main_integrate', 'hyperplane_parameters']).main_integrate(sympy.Symbol('x')*sympy.Symbol('y'), sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)).sides, __import__('sympy.integrals.intpoly', fromlist=['hyperplane_parameters']).hyperplane_parameters(sympy.Polygon(sympy.Point(0, 0), sympy.Point(1, 0), sympy.Point(1, 1), sympy.Point(0, 1)))))",
      @symprint.pretty_string(main_value),
    ),
  )

  assert_true(plot_polytope(square).series().length() == 4)
  assert_true(plot_polynomial(x * y).series().length() == 1)
  inspect_zero_batches(helper_checks, chunk_size=2)
}

///|
test "symintegrals parity intpoly 3d reduction helpers" {
  let helper_checks : Array[String] = []
  let cube_vertices = [
    @symgeometry.point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    @symgeometry.point3d(@symcore.int(0), @symcore.int(0), @symcore.int(5)),
    @symgeometry.point3d(@symcore.int(0), @symcore.int(5), @symcore.int(0)),
    @symgeometry.point3d(@symcore.int(0), @symcore.int(5), @symcore.int(5)),
    @symgeometry.point3d(@symcore.int(5), @symcore.int(0), @symcore.int(0)),
    @symgeometry.point3d(@symcore.int(5), @symcore.int(0), @symcore.int(5)),
    @symgeometry.point3d(@symcore.int(5), @symcore.int(5), @symcore.int(0)),
    @symgeometry.point3d(@symcore.int(5), @symcore.int(5), @symcore.int(5)),
  ]
  let cube_facets = [
    [2, 6, 7, 3],
    [3, 7, 5, 1],
    [7, 6, 4, 5],
    [1, 5, 4, 0],
    [3, 1, 0, 2],
    [0, 4, 6, 2],
  ]
  let cube_hp = [
    ([@symcore.int(0), @symcore.int(-1), @symcore.int(0)], @symcore.int(-5)),
    ([@symcore.int(0), @symcore.int(0), @symcore.int(-1)], @symcore.int(-5)),
    ([@symcore.int(-1), @symcore.int(0), @symcore.int(0)], @symcore.int(-5)),
    ([@symcore.int(0), @symcore.int(1), @symcore.int(0)], @symcore.int(0)),
    ([@symcore.int(1), @symcore.int(0), @symcore.int(0)], @symcore.int(0)),
    ([@symcore.int(0), @symcore.int(0), @symcore.int(1)], @symcore.int(0)),
  ]
  let cube_edge = @symgeometry.segment(cube_vertices[2], cube_vertices[6])
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['lineseg_integrate']).lineseg_integrate([(0, 5, 0), (5, 5, 0), (5, 5, 5), (0, 5, 5)], 0, [(0, 5, 0), (5, 5, 0)], 1, 0))",
      @symprint.pretty_string(
        lineseg_integrate(
          [
            cube_vertices[2],
            cube_vertices[6],
            cube_vertices[7],
            cube_vertices[3],
          ],
          0,
          cube_edge,
          @symcore.int(1),
          0,
        ),
      ),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['left_integral3D']).left_integral3D([[2, 6, 7, 3], [3, 7, 5, 1], [7, 6, 4, 5], [1, 5, 4, 0], [3, 1, 0, 2], [0, 4, 6, 2]], 3, 1, [(0, 0, 0), (0, 0, 5), (0, 5, 0), (0, 5, 5), (5, 0, 0), (5, 0, 5), (5, 5, 0), (5, 5, 5)], ([0, -1, 0], -5), 0))",
      @symprint.pretty_string(
        left_integral3D(
          cube_facets,
          3,
          @symcore.int(1),
          cube_vertices,
          cube_hp[0],
          0,
        ),
      ),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr(__import__('sympy.integrals.intpoly', fromlist=['polygon_integrate']).polygon_integrate([2, 6, 7, 3], [(0, 1, 0), 5], 0, [[2, 6, 7, 3], [3, 7, 5, 1], [7, 6, 4, 5], [1, 5, 4, 0], [3, 1, 0, 2], [0, 4, 6, 2]], [(0, 0, 0), (0, 0, 5), (0, 5, 0), (0, 5, 5), (5, 0, 0), (5, 0, 5), (5, 5, 0), (5, 5, 5)], 1, 0))",
      @symprint.pretty_string(
        polygon_integrate(
          cube_facets[0],
          ([@symcore.int(0), @symcore.int(1), @symcore.int(0)], @symcore.int(5)),
          0,
          cube_facets,
          cube_vertices,
          @symcore.int(1),
          0,
        ),
      ),
    ),
  )
  helper_checks.push(
    py_zero_if_equal(
      "sympy.sstr((lambda ip, facets, vertices: ip.main_integrate3d(1, facets, vertices, ip.hyperplane_parameters(facets, vertices)))(__import__('sympy.integrals.intpoly', fromlist=['main_integrate3d', 'hyperplane_parameters']), [[2, 6, 7, 3], [3, 7, 5, 1], [7, 6, 4, 5], [1, 5, 4, 0], [3, 1, 0, 2], [0, 4, 6, 2]], [(0, 0, 0), (0, 0, 5), (0, 5, 0), (0, 5, 5), (5, 0, 0), (5, 0, 5), (5, 5, 0), (5, 5, 5)]))",
      @symprint.pretty_string(
        main_integrate3d(@symcore.int(1), cube_facets, cube_vertices, cube_hp),
      ),
    ),
  )
  inspect_zero_batches(helper_checks, chunk_size=4)
}
