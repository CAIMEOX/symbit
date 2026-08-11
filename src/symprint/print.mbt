///|
/// Render an expression into the default human-readable pretty string form.
///
/// - Does: Prints an expression using the standard readable textual printer.
/// - Input: A `@symcore.Expr`.
/// - Returns: A `String`.
/// - Limits: The output is readable text, not a lossless serialization format.
pub fn pretty_string(expr : Expr) -> String {
  format_expr(expr, 0)
}

///|
fn exact_one_expr(expr : Expr) -> Bool {
  match @symcore.exact_number_num_den(expr) {
    Some((num, den)) => num.compare(1N) == 0 && den.compare(1N) == 0
    None => false
  }
}

///|
fn exact_positive_expr(expr : Expr) -> Bool {
  match @symcore.exact_number_num_den(expr) {
    Some((num, _)) => num.compare(0N) > 0
    None => false
  }
}

///|
fn exact_abs_expr(expr : Expr) -> Expr {
  match @symcore.exact_number_num_den(expr) {
    Some((num, den)) if num.compare(0N) < 0 => {
      let value = @symnum.BigRational::new(-num, den) catch {
        _ => abort("exact_abs_expr: invalid denominator")
      }
      Number(value)
    }
    _ => expr
  }
}

///|
fn split_negative_addend(expr : Expr) -> Expr? {
  match @symcore.expr_form(expr) {
    Number(_) =>
      match @symcore.exact_number_num_den(expr) {
        Some((num, _)) if num.compare(0N) < 0 => Some(exact_abs_expr(expr))
        _ => None
      }
    Mul(args) => {
      for i in 0..<args.length() {
        match @symcore.exact_number_num_den(args[i]) {
          Some((num, _)) if num.compare(0N) < 0 => {
            let rebuilt : Array[Expr] = []
            for j in 0..<args.length() {
              if i == j {
                let flipped = exact_abs_expr(args[j])
                if !(args.length() > 1 && exact_one_expr(flipped)) {
                  rebuilt.push(flipped)
                }
              } else {
                rebuilt.push(args[j])
              }
            }
            return Some(
              match rebuilt.length() {
                0 => @symcore.int(1)
                1 => rebuilt[0]
                _ => @symcore.mul(rebuilt)
              },
            )
          }
          _ => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
fn exact_positive_denominator_pow(base : Expr, exp : Expr) -> Expr? {
  match @symcore.exact_number_num_den(exp) {
    Some((num, den)) if num.compare(0N) < 0 => {
      let positive = @symnum.BigRational::new(-num, den) catch {
        _ => abort("exact_positive_denominator_pow: invalid denominator")
      }
      if positive.is_one() {
        Some(base)
      } else {
        Some(@symcore.raw_pow(base, Number(positive)))
      }
    }
    _ => None
  }
}

///|
fn exp_negative_power_numerator(base : Expr, exp : Expr) -> Expr? {
  match @symcore.exact_number_num_den(exp) {
    Some((num, den)) if num.compare(0N) < 0 => {
      let positive = @symnum.BigRational::new(-num, den) catch {
        _ => abort("exp_negative_power_numerator: invalid exponent")
      }
      let coeff = Expr::Number(-positive)
      match base {
        Apply(FunctionHead("exp"), [arg]) =>
          Some(@symcore.function("exp", [@symcore.mul([coeff, arg])]))
        Pow(Apply(FunctionHead("exp"), [arg]), inner_exp) =>
          Some(
            @symcore.function("exp", [@symcore.mul([coeff, inner_exp, arg])]),
          )
        _ => None
      }
    }
    _ => None
  }
}

///|
fn format_mul(expr : Expr, args : Array[Expr], parent_prec : Int) -> String {
  let prec = precedence(expr)
  let numerators : Array[Expr] = []
  let denominators : Array[Expr] = []
  let mut sign = ""
  for arg in args {
    match @symcore.expr_form(arg) {
      Pow(base, exp) =>
        match exp_negative_power_numerator(base, exp) {
          Some(num) => numerators.push(num)
          None =>
            match exact_positive_denominator_pow(base, exp) {
              Some(den) => denominators.push(den)
              None => numerators.push(arg)
            }
        }
      _ =>
        match @symcore.exact_number_num_den(arg) {
          Some((num, den)) => {
            let abs_num = if num.compare(0N) < 0 { -num } else { num }
            if num.compare(0N) < 0 {
              sign = if sign == "" { "-" } else { "" }
            }
            if den.compare(1N) != 0 {
              numerators.push(@symcore.int(abs_num.to_int()))
              denominators.push(@symcore.int(den.to_int()))
            } else {
              numerators.push(exact_abs_expr(arg))
            }
          }
          None => numerators.push(arg)
        }
    }
  }

  if numerators.is_empty() {
    numerators.push(@symcore.int(1))
  }

  if numerators.length() > 1 {
    let filtered : Array[Expr] = []
    for child in numerators {
      if !exact_one_expr(child) {
        filtered.push(child)
      }
    }
    if !filtered.is_empty() {
      numerators.clear()
      for child in filtered {
        numerators.push(child)
      }
    }
  }

  let numerator_text = numerators
    .map(child => format_expr(child, prec))
    .join("*")
  let body = if denominators.is_empty() {
    sign + numerator_text
  } else if denominators.length() == 1 {
    let denom = denominators[0]
    let denom_text_raw = format_expr(denom, prec)
    let denom_text = match @symcore.expr_form(denom) {
      Mul(_) | Add(_) => "(" + denom_text_raw + ")"
      _ => denom_text_raw
    }
    sign + numerator_text + "/" + denom_text
  } else {
    let denom_text = denominators
      .map(child => format_expr(child, prec))
      .join("*")
    sign + numerator_text + "/(" + denom_text + ")"
  }
  if prec < parent_prec {
    "(" + body + ")"
  } else {
    body
  }
}

///|
fn format_expr(expr : Expr, parent_prec : Int) -> String {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => {
      let rendered = args.map(child => format_expr(child, 0)).join(", ")
      let body = "\{name}(\{rendered})"
      return if 5 < parent_prec { "(\{body})" } else { body }
    }
    None => ()
  }
  let prec = precedence(expr)
  let body = match @symcore.expr_form(expr) {
    Number(n) => Show::to_string(n)
    Float(f) => Show::to_string(f)
    ComplexFloat(z) =>
      if @symnum.is_zero(z.to_mpc().imag) || parent_prec == 0 {
        Show::to_string(z)
      } else {
        "(\{Show::to_string(z)})"
      }
    NumberSymbol(kind) => @symcore.number_symbol_name(kind)
    Symbol(name) => name
    Dummy(name, _) => @symcore.dummy_display_name(name)
    Wild(name, _, _) => @symcore.wild_display_name(name)
    WildFunction(name, _) => @symcore.wild_display_name(name)
    IdentityFunction => "Lambda(_x, _x)"
    FunctionHead(name) => @symcore.standalone_function_head_display_name(name)
    UndefinedFunction(name) => name
    Boolean(true) => "True"
    Boolean(false) => "False"
    Add(args) =>
      if args.is_empty() {
        "0"
      } else if args.length() == 2 {
        match split_negative_addend(args[0]) {
          Some(positive0) if split_negative_addend(args[1]) is None =>
            format_expr(args[1], prec) + " - " + format_expr(positive0, prec)
          _ => {
            let rendered : Array[String] = []
            rendered.push(format_expr(args[0], prec))
            for i in 1..<args.length() {
              match split_negative_addend(args[i]) {
                Some(positive) =>
                  rendered.push("- " + format_expr(positive, prec))
                None => rendered.push("+ " + format_expr(args[i], prec))
              }
            }
            rendered.join(" ")
          }
        }
      } else {
        let rendered : Array[String] = []
        rendered.push(format_expr(args[0], prec))
        for i in 1..<args.length() {
          match split_negative_addend(args[i]) {
            Some(positive) => rendered.push("- " + format_expr(positive, prec))
            None => rendered.push("+ " + format_expr(args[i], prec))
          }
        }
        rendered.join(" ")
      }
    Mul(args) => return format_mul(expr, args, parent_prec)
    Pow(base, exp) => {
      let base_str = format_expr(base, prec)
      let exp_str = format_expr(exp, prec)
      let wrapped_base = match @symcore.expr_form(base) {
        Pow(_, _) => "(\{base_str})"
        Number(n) if !n.is_integral() || n.numerator() < BigInt::from_int(0) =>
          "(\{base_str})"
        Float(f) if @symnum.mpf_sign(f.to_mpf()) < 0 => "(\{base_str})"
        ComplexFloat(_) => "(\{base_str})"
        _ => base_str
      }
      let wrapped_exp = match @symcore.expr_form(exp) {
        Number(n) if !n.is_integral() => "(\{exp_str})"
        Float(_) | ComplexFloat(_) => "(\{exp_str})"
        _ => exp_str
      }
      "\{wrapped_base}**\{wrapped_exp}"
    }
    Mod(lhs, rhs) => "Mod(\{format_expr(lhs, 0)}, \{format_expr(rhs, 0)})"
    Tuple(args) => {
      let rendered = args.map(child => format_expr(child, 0)).join(", ")
      if args.length() == 1 {
        "(\{rendered},)"
      } else {
        "(\{rendered})"
      }
    }
    Dict(items) => {
      let rendered : Array[String] = []
      for item in @symcore.sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push("\{format_expr(key, 0)}: \{format_expr(value, 0)}")
      }
      let joined = rendered.join(", ")
      "{\{joined}}"
    }
    Relational(op, lhs, rhs) =>
      match op {
        Eq => "Eq(\{format_expr(lhs, 0)}, \{format_expr(rhs, 0)})"
        Ne => "Ne(\{format_expr(lhs, 0)}, \{format_expr(rhs, 0)})"
        Lt => "\{format_expr(lhs, prec)} < \{format_expr(rhs, prec)}"
        Le => "\{format_expr(lhs, prec)} <= \{format_expr(rhs, prec)}"
        Gt => "\{format_expr(lhs, prec)} > \{format_expr(rhs, prec)}"
        Ge => "\{format_expr(lhs, prec)} >= \{format_expr(rhs, prec)}"
      }
    Derivative(inner, deriv_args) => {
      let rendered = derivative_call_args(inner, deriv_args)
        .map(child => format_expr(child, 0))
        .join(", ")
      "Derivative(\{rendered})"
    }
    Subs(inner, variable, value) =>
      "Subs(\{format_expr(inner, 0)}, \{format_expr(variable, 0)}, \{format_expr(value, 0)})"
    Lambda(vars, body) =>
      "Lambda(\{format_expr(vars, 0)}, \{format_expr(body, 0)})"
    Apply(head, args) => {
      let rendered = args.map(child => format_expr(child, 0)).join(", ")
      "\{format_expr(head, prec)}(\{rendered})"
    }
  }
  if prec < parent_prec {
    "(\{body})"
  } else {
    body
  }
}

///|
fn precedence(expr : Expr) -> Int {
  match @symcore.expr_form(expr) {
    Relational(_, _, _) => 1
    Add(_) => 2
    Mul(_) => 3
    Pow(_, _) => 4
    Mod(_, _) => 4
    _ => 5
  }
}
