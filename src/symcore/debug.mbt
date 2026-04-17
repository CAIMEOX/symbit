///|
using @debug {trait Debug, type Repr}

///|
fn ordinary_application_name_args(expr : Expr) -> (String, Array[Expr])? {
  match application_parts(expr) {
    Some((head, args)) =>
      match head {
        Expr::FunctionHead(name) | Expr::UndefinedFunction(name) =>
          Some((name, args))
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
      Expr::Number(n) if n == @symnum.BigRational::one() => out.push(wrt)
      _ => out.push(Expr::Tuple([wrt, order]))
    }
  }
  out
}

///|
fn wrap_call_repr(name : String, args : Array[Expr]) -> String {
  let rendered_args = args.map(arg => to_repr(arg).to_string())
  let suffix = if rendered_args.is_empty() {
    ""
  } else {
    " " + rendered_args.join(" ")
  }
  "(call \{name}\{suffix})"
}

///|
fn wrap_variadic_repr(head : String, args : Array[Expr]) -> String {
  if args.is_empty() {
    "(\{head})"
  } else {
    let rendered = args.map(arg => to_repr(arg).to_string()).join(" ")
    "(\{head} \{rendered})"
  }
}

///|
fn wrap_apply_repr(head : Expr, args : Array[Expr]) -> String {
  let rendered_args = args.map(arg => to_repr(arg).to_string())
  let suffix = if rendered_args.is_empty() {
    ""
  } else {
    " " + rendered_args.join(" ")
  }
  "(apply \{to_repr(head).to_string()}\{suffix})"
}

///|
pub impl Debug for Expr with to_repr(self) {
  let rendered = match ordinary_application_name_args(self) {
    Some((name, args)) => wrap_call_repr(name, args)
    None =>
      match expr_form(self) {
        ExprForm::Number(n) => n.to_string()
        ExprForm::Float(f) => f.to_string()
        ExprForm::ComplexFloat(z) => z.to_string()
        ExprForm::NumberSymbol(kind) => "const:\{number_symbol_name(kind)}"
        ExprForm::Symbol(name) => "sym:\{name}"
        ExprForm::Dummy(name, id) => "dummy:\{dummy_display_name(name)}#\{id}"
        ExprForm::Wild(name, _, _) => "wild:\{wild_display_name(name)}"
        ExprForm::WildFunction(name, _) =>
          "wild_function:\{wild_display_name(name)}"
        ExprForm::IdentityFunction => "(call IdentityFunction)"
        ExprForm::FunctionHead(name) => "fhead:\{name}"
        ExprForm::UndefinedFunction(name) => "ufunc:\{name}"
        ExprForm::Boolean(true) => "sym:True"
        ExprForm::Boolean(false) => "sym:False"
        ExprForm::Add(args) => wrap_variadic_repr("+", args)
        ExprForm::Mul(args) => wrap_variadic_repr("*", args)
        ExprForm::Pow(base, exp) =>
          "(^ \{to_repr(base).to_string()} \{to_repr(exp).to_string()})"
        ExprForm::Mod(lhs, rhs) => wrap_call_repr("Mod", [lhs, rhs])
        ExprForm::Tuple(args) => wrap_call_repr("Tuple", args)
        ExprForm::Dict(items) => {
          let args : Array[Expr] = []
          for item in items {
            let (key, value) = item
            args.push(Expr::Tuple([key, value]))
          }
          wrap_call_repr("Dict", args)
        }
        ExprForm::Relational(op, lhs, rhs) => {
          let name = match op {
            RelOp::Eq => "Eq"
            RelOp::Ne => "Ne"
            RelOp::Lt => "Lt"
            RelOp::Le => "Le"
            RelOp::Gt => "Gt"
            RelOp::Ge => "Ge"
          }
          wrap_call_repr(name, [lhs, rhs])
        }
        ExprForm::Derivative(inner, deriv_args) =>
          wrap_call_repr("Derivative", derivative_call_args(inner, deriv_args))
        ExprForm::Subs(inner, variable, value) =>
          wrap_call_repr("Subs", [inner, variable, value])
        ExprForm::Lambda(vars, body) => wrap_call_repr("Lambda", [vars, body])
        ExprForm::Apply(head, args) =>
          match function_head_name(head) {
            Some(name) => wrap_call_repr(name, args)
            None => wrap_apply_repr(head, args)
          }
      }
  }
  Repr::literal(rendered)
}
