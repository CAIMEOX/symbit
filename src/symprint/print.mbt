///|
pub fn debug_repr(expr : @symcore.Expr) -> String {
  match expr {
    @symcore.Expr::Number(n) => n.to_string()
    @symcore.Expr::Symbol(name) => "sym:\{name}"
    @symcore.Expr::Add(args) => wrap_variadic("+", args)
    @symcore.Expr::Mul(args) => wrap_variadic("*", args)
    @symcore.Expr::Pow(base, exp) =>
      "(^ \{debug_repr(base)} \{debug_repr(exp)})"
    @symcore.Expr::Function(name, args) => {
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
fn wrap_variadic(head : String, args : Array[@symcore.Expr]) -> String {
  if args.is_empty() {
    "(\{head})"
  } else {
    let rendered = args.map(debug_repr).join(" ")
    "(\{head} \{rendered})"
  }
}

///|
pub fn to_string(expr : @symcore.Expr) -> String {
  format_expr(expr, 0)
}

///|
fn format_expr(expr : @symcore.Expr, parent_prec : Int) -> String {
  let prec = precedence(expr)
  let body = match expr {
    @symcore.Expr::Number(n) => n.to_string()
    @symcore.Expr::Symbol(name) => name
    @symcore.Expr::Add(args) =>
      args.map(child => format_expr(child, prec)).join(" + ")
    @symcore.Expr::Mul(args) =>
      args.map(child => format_expr(child, prec)).join("*")
    @symcore.Expr::Pow(base, exp) => {
      let base_str = format_expr(base, prec)
      let exp_str = format_expr(exp, prec)
      let wrapped_base = match base {
        @symcore.Expr::Pow(_, _) => "(\{base_str})"
        @symcore.Expr::Number(n) if !n.is_integral() ||
          n.numerator().op_lt(BigInt::from_int(0)) => "(\{base_str})"
        _ => base_str
      }
      let wrapped_exp = match exp {
        @symcore.Expr::Number(n) if !n.is_integral() => "(\{exp_str})"
        _ => exp_str
      }
      "\{wrapped_base}**\{wrapped_exp}"
    }
    @symcore.Expr::Function(name, args) => {
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
fn precedence(expr : @symcore.Expr) -> Int {
  match expr {
    @symcore.Expr::Add(_) => 1
    @symcore.Expr::Mul(_) => 2
    @symcore.Expr::Pow(_, _) => 3
    _ => 4
  }
}
