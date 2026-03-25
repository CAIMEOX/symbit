///|
pub fn children(expr : Expr) -> ArrayView[Expr] {
  match expr {
    Expr::Add(args)
    | Expr::Mul(args)
    | Expr::Tuple(args)
    | Expr::Function(_, args) => args[:]
    Expr::Dict(items) => {
      let out : Array[Expr] = []
      for item in items {
        let (key, value) = item
        out.push(tuple_expr([key, value]))
      }
      out[:]
    }
    Expr::Pow(base, exp) => [base, exp][:]
    Expr::Relational(_, lhs, rhs) => [lhs, rhs][:]
    Expr::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = [inner]
      for arg in deriv_args {
        out.push(arg)
      }
      out[:]
    }
    Expr::Subs(inner, variable, value) => [inner, variable, value][:]
    Expr::Lambda(vars, body) => [vars, body][:]
    _ => [][:]
  }
}

///|
pub fn map_children(expr : Expr, f : (Expr) -> Expr) -> Expr {
  match expr {
    Expr::Add(args) => add(args.map(f))
    Expr::Mul(args) => mul(args.map(f))
    Expr::Pow(base, exp) => pow(f(base), f(exp))
    Expr::Tuple(args) => tuple_expr(args.map(f))
    Expr::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((f(key), f(value)))
      }
      dict_expr(out)
    }
    Expr::Relational(op, lhs, rhs) =>
      match op {
        RelOp::Eq => eq(f(lhs), f(rhs))
        RelOp::Ne => ne(f(lhs), f(rhs))
        RelOp::Lt => lt(f(lhs), f(rhs))
        RelOp::Le => le(f(lhs), f(rhs))
        RelOp::Gt => gt(f(lhs), f(rhs))
        RelOp::Ge => ge(f(lhs), f(rhs))
      }
    Expr::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = []
      for arg in deriv_args {
        out.push(f(arg))
      }
      Expr::Derivative(f(inner), out)
    }
    Expr::Subs(inner, variable, value) =>
      subs_expr(f(inner), f(variable), f(value))
    Expr::Lambda(vars, body) => lambda_expr(f(vars), f(body))
    Expr::Function(name, args) => function(name, args.map(f))
    _ => expr
  }
}

///|
pub fn subst(expr : Expr, env : Map[String, Expr]) -> Expr {
  match expr {
    Expr::Symbol(name) =>
      match env.get(name) {
        Some(value) => value
        None => expr
      }
    Expr::Dummy(_, _) | Expr::Wild(_) => expr
    Expr::Number(_)
    | Expr::Float(_)
    | Expr::ComplexFloat(_)
    | Expr::NumberSymbol(_)
    | Expr::UndefinedFunction(_)
    | Expr::Boolean(_) => expr
    _ => map_children(expr, child => subst(child, env))
  }
}
