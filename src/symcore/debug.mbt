///|
using @debug {trait Debug, type Repr}

///|
fn ordinary_application_name_args(expr : Expr) -> (String, Array[Expr])? {
  match application_parts(expr) {
    Some((head, args)) =>
      match head {
        FunctionHead(name) | UndefinedFunction(name) => Some((name, args))
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
      Number(n) if n == @symnum.BigRational::one() => out.push(wrt)
      _ => out.push(Tuple([wrt, order]))
    }
  }
  out
}

///|
fn wrap_call_repr(name : String, args : Array[Expr]) -> String {
  let rendered_args = args.map(arg => Repr(arg).to_string())
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
    let rendered = args.map(arg => Repr(arg).to_string()).join(" ")
    "(\{head} \{rendered})"
  }
}

///|
fn wrap_apply_repr(head : Expr, args : Array[Expr]) -> String {
  let rendered_args = args.map(arg => Repr(arg).to_string())
  let suffix = if rendered_args.is_empty() {
    ""
  } else {
    " " + rendered_args.join(" ")
  }
  "(apply \{Repr(head).to_string()}\{suffix})"
}

///|
pub impl Debug for Expr with fn to_repr(self) {
  let rendered = match ordinary_application_name_args(self) {
    Some((name, args)) => wrap_call_repr(name, args)
    None =>
      match expr_form(self) {
        Number(n) => Show::to_string(n)
        Float(f) => Show::to_string(f)
        ComplexFloat(z) => Show::to_string(z)
        NumberSymbol(kind) => "const:\{number_symbol_name(kind)}"
        Symbol(name) => "sym:\{name}"
        Dummy(name, id) => "dummy:\{dummy_display_name(name)}#\{id}"
        Wild(name, _, _) => "wild:\{wild_display_name(name)}"
        WildFunction(name, _) => "wild_function:\{wild_display_name(name)}"
        IdentityFunction => "(call IdentityFunction)"
        FunctionHead(name) => "fhead:\{name}"
        UndefinedFunction(name) => "ufunc:\{name}"
        Boolean(true) => "sym:True"
        Boolean(false) => "sym:False"
        Add(args) => wrap_variadic_repr("+", args)
        Mul(args) => wrap_variadic_repr("*", args)
        Pow(base, exp) =>
          "(^ \{Repr(base).to_string()} \{Repr(exp).to_string()})"
        Mod(lhs, rhs) => wrap_call_repr("Mod", [lhs, rhs])
        Tuple(args) => wrap_call_repr("Tuple", args)
        Dict(items) => {
          let args : Array[Expr] = []
          for item in items {
            let (key, value) = item
            args.push(Tuple([key, value]))
          }
          wrap_call_repr("Dict", args)
        }
        Relational(op, lhs, rhs) => {
          let name = match op {
            Eq => "Eq"
            Ne => "Ne"
            Lt => "Lt"
            Le => "Le"
            Gt => "Gt"
            Ge => "Ge"
          }
          wrap_call_repr(name, [lhs, rhs])
        }
        Derivative(inner, deriv_args) =>
          wrap_call_repr("Derivative", derivative_call_args(inner, deriv_args))
        Subs(inner, variable, value) =>
          wrap_call_repr("Subs", [inner, variable, value])
        Lambda(vars, body) => wrap_call_repr("Lambda", [vars, body])
        Apply(head, args) =>
          match function_head_name(head) {
            Some(name) => wrap_call_repr(name, args)
            None => wrap_apply_repr(head, args)
          }
      }
  }
  Repr::literal(rendered)
}
