///|
pub enum RelOp {
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
}

///|
pub enum ExprForm {
  Number(@symnum.BigRational)
  Float(Float)
  ComplexFloat(ComplexFloat)
  Symbol(String)
  Boolean(Bool)
  Add(Array[Expr])
  Mul(Array[Expr])
  Pow(Expr, Expr)
  Tuple(Array[Expr])
  Relational(RelOp, Expr, Expr)
  Derivative(Expr, Array[Expr])
  Subs(Expr, Expr, Expr)
  Lambda(Expr, Expr)
  Applied(String, Array[Expr])
}

///|
pub fn true_() -> Expr {
  symbol("True")
}

///|
pub fn false_() -> Expr {
  symbol("False")
}

///|
pub fn bool_expr(value : Bool) -> Expr {
  if value {
    true_()
  } else {
    false_()
  }
}

///|
pub fn tuple_expr(items : Array[Expr]) -> Expr {
  raw_function("Tuple", items)
}

///|
pub fn eq(lhs : Expr, rhs : Expr) -> Expr {
  raw_function("Eq", [lhs, rhs])
}

///|
pub fn ne(lhs : Expr, rhs : Expr) -> Expr {
  raw_function("Ne", [lhs, rhs])
}

///|
pub fn lt(lhs : Expr, rhs : Expr) -> Expr {
  raw_function("Lt", [lhs, rhs])
}

///|
pub fn le(lhs : Expr, rhs : Expr) -> Expr {
  raw_function("Le", [lhs, rhs])
}

///|
pub fn gt(lhs : Expr, rhs : Expr) -> Expr {
  raw_function("Gt", [lhs, rhs])
}

///|
pub fn ge(lhs : Expr, rhs : Expr) -> Expr {
  raw_function("Ge", [lhs, rhs])
}

///|
pub fn derivative(expr : Expr, wrt : Expr, order? : Expr = int(1)) -> Expr {
  if order == int(1) {
    raw_function("Derivative", [expr, wrt])
  } else {
    raw_function("Derivative", [expr, wrt, order])
  }
}

///|
pub fn subs_expr(expr : Expr, variable : Expr, value : Expr) -> Expr {
  raw_function("Subs", [expr, variable, value])
}

///|
pub fn lambda_expr(vars : Expr, body : Expr) -> Expr {
  raw_function("Lambda", [vars, body])
}

///|
pub fn expr_form(expr : Expr) -> ExprForm {
  match expr {
    Expr::Number(n) => ExprForm::Number(n)
    Expr::Float(f) => ExprForm::Float(f)
    Expr::ComplexFloat(z) => ExprForm::ComplexFloat(z)
    Expr::Symbol("True") => ExprForm::Boolean(true)
    Expr::Symbol("False") => ExprForm::Boolean(false)
    Expr::Symbol(name) => ExprForm::Symbol(name)
    Expr::Add(args) => ExprForm::Add(args)
    Expr::Mul(args) => ExprForm::Mul(args)
    Expr::Pow(base, exp) => ExprForm::Pow(base, exp)
    Expr::Function("Tuple", args) => ExprForm::Tuple(args)
    Expr::Function("Eq", [lhs, rhs]) =>
      ExprForm::Relational(RelOp::Eq, lhs, rhs)
    Expr::Function("Ne", [lhs, rhs]) =>
      ExprForm::Relational(RelOp::Ne, lhs, rhs)
    Expr::Function("Lt", [lhs, rhs]) =>
      ExprForm::Relational(RelOp::Lt, lhs, rhs)
    Expr::Function("Le", [lhs, rhs]) =>
      ExprForm::Relational(RelOp::Le, lhs, rhs)
    Expr::Function("Gt", [lhs, rhs]) =>
      ExprForm::Relational(RelOp::Gt, lhs, rhs)
    Expr::Function("Ge", [lhs, rhs]) =>
      ExprForm::Relational(RelOp::Ge, lhs, rhs)
    Expr::Function("Derivative", [inner, wrt]) =>
      ExprForm::Derivative(inner, [wrt, int(1)])
    Expr::Function("Derivative", [inner, wrt, order]) =>
      ExprForm::Derivative(inner, [wrt, order])
    Expr::Function("Subs", [inner, variable, value]) =>
      ExprForm::Subs(inner, variable, value)
    Expr::Function("Lambda", [vars, body]) => ExprForm::Lambda(vars, body)
    Expr::Function(name, args) => ExprForm::Applied(name, args)
  }
}

///|
pub fn is_true(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Boolean(value) => value
    _ => false
  }
}

///|
pub fn is_false(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Boolean(value) => !value
    _ => false
  }
}

///|
pub fn args(expr : Expr) -> Array[Expr] {
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::Symbol(_)
    | ExprForm::Boolean(_) => []
    ExprForm::Add(items)
    | ExprForm::Mul(items)
    | ExprForm::Tuple(items)
    | ExprForm::Applied(_, items) => items.copy()
    ExprForm::Pow(base, exp) => [base, exp]
    ExprForm::Relational(_, lhs, rhs) => [lhs, rhs]
    ExprForm::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = [inner]
      for arg in deriv_args {
        out.push(arg)
      }
      out
    }
    ExprForm::Subs(inner, variable, value) => [inner, variable, value]
    ExprForm::Lambda(vars, body) => [vars, body]
  }
}

///|
fn remove_bound_symbol(out : Map[String, Expr], expr : Expr) -> Unit {
  match expr_form(expr) {
    ExprForm::Symbol(name) => ignore(out.remove(name))
    ExprForm::Tuple(items) =>
      for item in items {
        remove_bound_symbol(out, item)
      }
    _ => ()
  }
}

///|
fn free_symbol_map(expr : Expr, out : Map[String, Expr]) -> Unit {
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::Boolean(_) => ()
    ExprForm::Symbol(name) => out.set(name, expr)
    ExprForm::Add(items)
    | ExprForm::Mul(items)
    | ExprForm::Tuple(items)
    | ExprForm::Applied(_, items) =>
      for item in items {
        free_symbol_map(item, out)
      }
    ExprForm::Pow(base, exp) => {
      free_symbol_map(base, out)
      free_symbol_map(exp, out)
    }
    ExprForm::Relational(_, lhs, rhs) => {
      free_symbol_map(lhs, out)
      free_symbol_map(rhs, out)
    }
    ExprForm::Derivative(inner, deriv_args) => {
      free_symbol_map(inner, out)
      if deriv_args.length() >= 1 {
        let bound = deriv_args[0]
        match expr_form(bound) {
          ExprForm::Symbol(name) => ignore(out.remove(name))
          _ => free_symbol_map(bound, out)
        }
      }
      if deriv_args.length() >= 2 {
        free_symbol_map(deriv_args[1], out)
      }
    }
    ExprForm::Subs(inner, variable, value) => {
      free_symbol_map(inner, out)
      free_symbol_map(value, out)
      remove_bound_symbol(out, variable)
    }
    ExprForm::Lambda(vars, body) => {
      free_symbol_map(body, out)
      remove_bound_symbol(out, vars)
    }
  }
}

///|
pub fn free_symbols(expr : Expr) -> Array[Expr] {
  let out : Map[String, Expr] = {}
  free_symbol_map(expr, out)
  let names : Array[String] = []
  for name in out.keys() {
    names.push(name)
  }
  names.sort()
  let symbols : Array[Expr] = []
  for name in names {
    match out.get(name) {
      Some(value) => symbols.push(value)
      None => ()
    }
  }
  symbols
}

///|
pub fn has(expr : Expr, needle : Expr) -> Bool {
  if expr == needle {
    return true
  }
  for child in args(expr) {
    if has(child, needle) {
      return true
    }
  }
  false
}
