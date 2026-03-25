///|
pub fn debug_repr(expr : Expr) -> String {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(n) => n.to_string()
    @symcore.ExprForm::Float(f) => f.to_string()
    @symcore.ExprForm::ComplexFloat(z) => z.to_string()
    @symcore.ExprForm::NumberSymbol(kind) =>
      "const:\{@symcore.number_symbol_name(kind)}"
    @symcore.ExprForm::Symbol(name) => "sym:\{name}"
    @symcore.ExprForm::Dummy(name, id) =>
      "dummy:\{@symcore.dummy_display_name(name)}#\{id}"
    @symcore.ExprForm::Wild(name) => "wild:\{@symcore.wild_display_name(name)}"
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
        args.push(@symcore.tuple_expr([key, value]))
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
    @symcore.ExprForm::Derivative(inner, deriv_args) => {
      let call_args : Array[Expr] = [inner]
      for arg in deriv_args {
        call_args.push(arg)
      }
      wrap_call("Derivative", call_args)
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      wrap_call("Subs", [inner, variable, value])
    @symcore.ExprForm::Lambda(vars, body) => wrap_call("Lambda", [vars, body])
    @symcore.ExprForm::AppliedUndef(name, args)
    | @symcore.ExprForm::Applied(name, args) => wrap_call(name, args)
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
pub fn to_string(expr : Expr) -> String {
  format_expr(expr, 0)
}

///|
fn format_expr(expr : Expr, parent_prec : Int) -> String {
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
    @symcore.ExprForm::Wild(name) => @symcore.wild_display_name(name)
    @symcore.ExprForm::UndefinedFunction(name) => name
    @symcore.ExprForm::Boolean(true) => "True"
    @symcore.ExprForm::Boolean(false) => "False"
    @symcore.ExprForm::Add(args) =>
      args.map(child => format_expr(child, prec)).join(" + ")
    @symcore.ExprForm::Mul(args) =>
      args.map(child => format_expr(child, prec)).join("*")
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
      for item in items {
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
      let call_args : Array[Expr] = [inner]
      for arg in deriv_args {
        call_args.push(arg)
      }
      let rendered = call_args.map(child => format_expr(child, 0)).join(", ")
      "Derivative(\{rendered})"
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      "Subs(\{format_expr(inner, 0)}, \{format_expr(variable, 0)}, \{format_expr(value, 0)})"
    @symcore.ExprForm::Lambda(vars, body) =>
      "Lambda(\{format_expr(vars, 0)}, \{format_expr(body, 0)})"
    @symcore.ExprForm::AppliedUndef(name, args)
    | @symcore.ExprForm::Applied(name, args) => {
      let rendered = args.map(child => format_expr(child, prec)).join(", ")
      "\{name}(\{rendered})"
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
