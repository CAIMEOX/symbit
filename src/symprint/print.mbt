///|
fn ordinary_application_name_args(expr : Expr) -> (String, Array[Expr])? {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match head {
        @symcore.Expr::FunctionHead(name)
        | @symcore.Expr::UndefinedFunction(name) => Some((name, args))
        _ => None
      }
    None => None
  }
}

///|
fn derivative_call_args(inner : Expr, deriv_args : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = [inner]
  let pair_count = deriv_args.length() / 2
  for i in 0..<pair_count {
    let wrt = deriv_args[i * 2]
    let order = deriv_args[i * 2 + 1]
    match order {
      @symcore.Expr::Number(n) if n == @symnum.BigRational::one() =>
        out.push(wrt)
      _ => out.push(@symcore.Expr::Tuple([wrt, order]))
    }
  }
  out
}

///|
pub fn debug_repr(expr : Expr) -> String {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return wrap_call(name, args)
    None => ()
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(n) => n.to_string()
    @symcore.ExprForm::Float(f) => f.to_string()
    @symcore.ExprForm::ComplexFloat(z) => z.to_string()
    @symcore.ExprForm::NumberSymbol(kind) =>
      "const:\{@symcore.number_symbol_name(kind)}"
    @symcore.ExprForm::Symbol(name) => "sym:\{name}"
    @symcore.ExprForm::Dummy(name, id) =>
      "dummy:\{@symcore.dummy_display_name(name)}#\{id}"
    @symcore.ExprForm::Wild(name, _, _) =>
      "wild:\{@symcore.wild_display_name(name)}"
    @symcore.ExprForm::WildFunction(name, _) =>
      "wild_function:\{@symcore.wild_display_name(name)}"
    @symcore.ExprForm::IdentityFunction => "(call IdentityFunction)"
    @symcore.ExprForm::FunctionHead(name) => "fhead:\{name}"
    @symcore.ExprForm::UndefinedFunction(name) => "ufunc:\{name}"
    @symcore.ExprForm::Boolean(true) => "sym:True"
    @symcore.ExprForm::Boolean(false) => "sym:False"
    @symcore.ExprForm::Add(args) => wrap_variadic("+", args)
    @symcore.ExprForm::Mul(args) => wrap_variadic("*", args)
    @symcore.ExprForm::Pow(base, exp) =>
      "(^ \{debug_repr(base)} \{debug_repr(exp)})"
    @symcore.ExprForm::Mod(lhs, rhs) => wrap_call("Mod", [lhs, rhs])
    @symcore.ExprForm::Tuple(args) => wrap_call("Tuple", args)
    @symcore.ExprForm::Dict(items) => {
      let args : Array[Expr] = []
      for item in items {
        let (key, value) = item
        args.push(@symcore.Expr::Tuple([key, value]))
      }
      wrap_call("Dict", args)
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) => {
      let name = match op {
        @symcore.RelOp::Eq => "Eq"
        @symcore.RelOp::Ne => "Ne"
        @symcore.RelOp::Lt => "Lt"
        @symcore.RelOp::Le => "Le"
        @symcore.RelOp::Gt => "Gt"
        @symcore.RelOp::Ge => "Ge"
      }
      wrap_call(name, [lhs, rhs])
    }
    @symcore.ExprForm::Derivative(inner, deriv_args) =>
      wrap_call("Derivative", derivative_call_args(inner, deriv_args))
    @symcore.ExprForm::Subs(inner, variable, value) =>
      wrap_call("Subs", [inner, variable, value])
    @symcore.ExprForm::Lambda(vars, body) => wrap_call("Lambda", [vars, body])
    @symcore.ExprForm::Apply(head, args) =>
      match @symcore.function_head_name(head) {
        Some(name) => wrap_call(name, args)
        None => wrap_apply(head, args)
      }
  }
}

///|
fn wrap_call(name : String, args : Array[Expr]) -> String {
  let rendered_args = args.map(debug_repr)
  let suffix = if rendered_args.is_empty() {
    ""
  } else {
    " " + rendered_args.join(" ")
  }
  "(call \{name}\{suffix})"
}

///|
fn wrap_variadic(head : String, args : Array[Expr]) -> String {
  if args.is_empty() {
    "(\{head})"
  } else {
    let rendered = args.map(debug_repr).join(" ")
    "(\{head} \{rendered})"
  }
}

///|
fn wrap_apply(head : Expr, args : Array[Expr]) -> String {
  let rendered_args = args.map(debug_repr)
  let suffix = if rendered_args.is_empty() {
    ""
  } else {
    " " + rendered_args.join(" ")
  }
  "(apply \{debug_repr(head)}\{suffix})"
}

///|
pub fn to_string(expr : Expr) -> String {
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
      @symcore.Expr::Number(value)
    }
    _ => expr
  }
}

///|
fn split_negative_addend(expr : Expr) -> Expr? {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_) =>
      match @symcore.exact_number_num_den(expr) {
        Some((num, _)) if num.compare(0N) < 0 => Some(exact_abs_expr(expr))
        _ => None
      }
    @symcore.ExprForm::Mul(args) => {
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
            return Some(match rebuilt.length() {
              0 => @symcore.int(1)
              1 => rebuilt[0]
              _ => @symcore.mul(rebuilt)
            })
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
        Some(@symcore.raw_pow(base, @symcore.Expr::Number(positive)))
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
      @symcore.ExprForm::Pow(base, exp) =>
        match exact_positive_denominator_pow(base, exp) {
          Some(den) => denominators.push(den)
          None => numerators.push(arg)
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
      @symcore.ExprForm::Mul(_) | @symcore.ExprForm::Add(_) => "(" + denom_text_raw + ")"
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
    @symcore.ExprForm::Number(n) => n.to_string()
    @symcore.ExprForm::Float(f) => f.to_string()
    @symcore.ExprForm::ComplexFloat(z) =>
      if @symnum.is_zero(z.to_mpc().imag) || parent_prec == 0 {
        z.to_string()
      } else {
        "(\{z.to_string()})"
      }
    @symcore.ExprForm::NumberSymbol(kind) => @symcore.number_symbol_name(kind)
    @symcore.ExprForm::Symbol(name) => name
    @symcore.ExprForm::Dummy(name, _) => @symcore.dummy_display_name(name)
    @symcore.ExprForm::Wild(name, _, _) => @symcore.wild_display_name(name)
    @symcore.ExprForm::WildFunction(name, _) => @symcore.wild_display_name(name)
    @symcore.ExprForm::IdentityFunction => "Lambda(_x, _x)"
    @symcore.ExprForm::FunctionHead(name) =>
      @symcore.standalone_function_head_display_name(name)
    @symcore.ExprForm::UndefinedFunction(name) => name
    @symcore.ExprForm::Boolean(true) => "True"
    @symcore.ExprForm::Boolean(false) => "False"
    @symcore.ExprForm::Add(args) => {
      if args.is_empty() {
        "0"
      } else if args.length() == 2 {
        match split_negative_addend(args[0]) {
          Some(positive0) if exact_positive_expr(args[1]) =>
            format_expr(args[1], prec) + " - " + format_expr(positive0, prec)
          _ => {
            let rendered : Array[String] = []
            rendered.push(format_expr(args[0], prec))
            for i in 1..<args.length() {
              match split_negative_addend(args[i]) {
                Some(positive) =>
                  rendered.push("- " + format_expr(positive, prec))
                None =>
                  rendered.push("+ " + format_expr(args[i], prec))
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
            Some(positive) =>
              rendered.push("- " + format_expr(positive, prec))
            None =>
              rendered.push("+ " + format_expr(args[i], prec))
          }
        }
        rendered.join(" ")
      }
    }
    @symcore.ExprForm::Mul(args) => return format_mul(expr, args, parent_prec)
    @symcore.ExprForm::Pow(base, exp) => {
      let base_str = format_expr(base, prec)
      let exp_str = format_expr(exp, prec)
      let wrapped_base = match @symcore.expr_form(base) {
        @symcore.ExprForm::Pow(_, _) => "(\{base_str})"
        @symcore.ExprForm::Number(n) if !n.is_integral() ||
          n.numerator().op_lt(BigInt::from_int(0)) => "(\{base_str})"
        @symcore.ExprForm::Float(f) if @symnum.mpf_sign(f.to_mpf()) < 0 =>
          "(\{base_str})"
        @symcore.ExprForm::ComplexFloat(_) => "(\{base_str})"
        _ => base_str
      }
      let wrapped_exp = match @symcore.expr_form(exp) {
        @symcore.ExprForm::Number(n) if !n.is_integral() => "(\{exp_str})"
        @symcore.ExprForm::Float(_) | @symcore.ExprForm::ComplexFloat(_) =>
          "(\{exp_str})"
        _ => exp_str
      }
      "\{wrapped_base}**\{wrapped_exp}"
    }
    @symcore.ExprForm::Mod(lhs, rhs) =>
      "Mod(\{format_expr(lhs, 0)}, \{format_expr(rhs, 0)})"
    @symcore.ExprForm::Tuple(args) => {
      let rendered = args.map(child => format_expr(child, 0)).join(", ")
      if args.length() == 1 {
        "(\{rendered},)"
      } else {
        "(\{rendered})"
      }
    }
    @symcore.ExprForm::Dict(items) => {
      let rendered : Array[String] = []
      for item in @symcore.sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push("\{format_expr(key, 0)}: \{format_expr(value, 0)}")
      }
      let joined = rendered.join(", ")
      "{\{joined}}"
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      match op {
        @symcore.RelOp::Eq =>
          "Eq(\{format_expr(lhs, 0)}, \{format_expr(rhs, 0)})"
        @symcore.RelOp::Ne =>
          "Ne(\{format_expr(lhs, 0)}, \{format_expr(rhs, 0)})"
        @symcore.RelOp::Lt =>
          "\{format_expr(lhs, prec)} < \{format_expr(rhs, prec)}"
        @symcore.RelOp::Le =>
          "\{format_expr(lhs, prec)} <= \{format_expr(rhs, prec)}"
        @symcore.RelOp::Gt =>
          "\{format_expr(lhs, prec)} > \{format_expr(rhs, prec)}"
        @symcore.RelOp::Ge =>
          "\{format_expr(lhs, prec)} >= \{format_expr(rhs, prec)}"
      }
    @symcore.ExprForm::Derivative(inner, deriv_args) => {
      let rendered = derivative_call_args(inner, deriv_args)
        .map(child => format_expr(child, 0))
        .join(", ")
      "Derivative(\{rendered})"
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      "Subs(\{format_expr(inner, 0)}, \{format_expr(variable, 0)}, \{format_expr(value, 0)})"
    @symcore.ExprForm::Lambda(vars, body) =>
      "Lambda(\{format_expr(vars, 0)}, \{format_expr(body, 0)})"
    @symcore.ExprForm::Apply(head, args) => {
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
    @symcore.ExprForm::Relational(_, _, _) => 1
    @symcore.ExprForm::Add(_) => 2
    @symcore.ExprForm::Mul(_) => 3
    @symcore.ExprForm::Pow(_, _) => 4
    @symcore.ExprForm::Mod(_, _) => 4
    _ => 5
  }
}
