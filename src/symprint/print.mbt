///|
pub fn debug_repr(expr : Expr) -> String {
  match expr {
    Expr::Number(n) => n.to_string()
    Expr::Float(f) => f.to_string()
    Expr::ComplexFloat(z) => z.to_string()
    Expr::Symbol(name) => "sym:\{name}"
    Expr::Add(args) => wrap_variadic("+", args)
    Expr::Mul(args) => wrap_variadic("*", args)
    Expr::Pow(base, exp) => "(^ \{debug_repr(base)} \{debug_repr(exp)})"
    Expr::Function(name, args) => {
      let rendered_args = args.map(debug_repr)
      let suffix = if rendered_args.is_empty() {
        ""
      } else {
        " " + rendered_args.join(" ")
      }
      "(call \{name}\{suffix})"
    }
  }
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
  let body = match expr {
    Expr::Number(n) => n.to_string()
    Expr::Float(f) => f.to_string()
    Expr::ComplexFloat(z) =>
      if @symnum.is_zero(z.to_mpc().imag) || parent_prec == 0 {
        z.to_string()
      } else {
        "(\{z.to_string()})"
      }
    Expr::Symbol(name) => name
    Expr::Add(args) => args.map(child => format_expr(child, prec)).join(" + ")
    Expr::Mul(args) => args.map(child => format_expr(child, prec)).join("*")
    Expr::Pow(base, exp) => {
      let base_str = format_expr(base, prec)
      let exp_str = format_expr(exp, prec)
      let wrapped_base = match base {
        Expr::Pow(_, _) => "(\{base_str})"
        Expr::Number(n) if !n.is_integral() ||
          n.numerator().op_lt(BigInt::from_int(0)) => "(\{base_str})"
        Expr::Float(f) if @symnum.mpf_sign(f.to_mpf()) < 0 => "(\{base_str})"
        Expr::ComplexFloat(_) => "(\{base_str})"
        _ => base_str
      }
      let wrapped_exp = match exp {
        Expr::Number(n) if !n.is_integral() => "(\{exp_str})"
        Expr::Float(_) | Expr::ComplexFloat(_) => "(\{exp_str})"
        _ => exp_str
      }
      "\{wrapped_base}**\{wrapped_exp}"
    }
    Expr::Function(name, args) =>
      match (name, args) {
        ("Lt", [lhs, rhs]) =>
          "\{format_expr(lhs, prec)} < \{format_expr(rhs, prec)}"
        ("Le", [lhs, rhs]) =>
          "\{format_expr(lhs, prec)} <= \{format_expr(rhs, prec)}"
        ("Gt", [lhs, rhs]) =>
          "\{format_expr(lhs, prec)} > \{format_expr(rhs, prec)}"
        ("Ge", [lhs, rhs]) =>
          "\{format_expr(lhs, prec)} >= \{format_expr(rhs, prec)}"
        _ => {
          let rendered = args.map(child => format_expr(child, prec)).join(", ")
          "\{name}(\{rendered})"
        }
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
  match expr {
    Expr::Add(_) => 1
    Expr::Mul(_) => 2
    Expr::Pow(_, _) => 3
    _ => 4
  }
}
