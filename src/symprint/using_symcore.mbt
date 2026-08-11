///|
using @symcore {type Expr}

///|
fn ordinary_application_name_args(expr : Expr) -> (String, Array[Expr])? {
  match @symcore.application_parts(expr) {
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
