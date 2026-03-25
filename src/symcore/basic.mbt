///|
pub enum NumberSymbolKind {
  ImaginaryUnit
  Pi
  Exp1
  EulerGamma
  GoldenRatio
  Catalan
  Infinity
  NegativeInfinity
  ComplexInfinity
  NaN
}

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
  NumberSymbol(NumberSymbolKind)
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
pub fn number_symbol_name(kind : NumberSymbolKind) -> String {
  match kind {
    NumberSymbolKind::ImaginaryUnit => "I"
    NumberSymbolKind::Pi => "pi"
    NumberSymbolKind::Exp1 => "E"
    NumberSymbolKind::EulerGamma => "EulerGamma"
    NumberSymbolKind::GoldenRatio => "GoldenRatio"
    NumberSymbolKind::Catalan => "Catalan"
    NumberSymbolKind::Infinity => "oo"
    NumberSymbolKind::NegativeInfinity => "-oo"
    NumberSymbolKind::ComplexInfinity => "zoo"
    NumberSymbolKind::NaN => "nan"
  }
}

///|
pub fn dummy_display_name(name : String) -> String {
  if name.has_prefix("_") {
    name
  } else {
    "_\{name}"
  }
}

///|
pub fn wild_display_name(name : String) -> String {
  if name.has_suffix("_") {
    name
  } else {
    "\{name}_"
  }
}

///|
pub fn number_symbol_kind_from_name(name : String) -> NumberSymbolKind? {
  match name {
    "I" => Some(NumberSymbolKind::ImaginaryUnit)
    "pi" | "Pi" => Some(NumberSymbolKind::Pi)
    "E" => Some(NumberSymbolKind::Exp1)
    "EulerGamma" => Some(NumberSymbolKind::EulerGamma)
    "GoldenRatio" => Some(NumberSymbolKind::GoldenRatio)
    "Catalan" => Some(NumberSymbolKind::Catalan)
    "oo" => Some(NumberSymbolKind::Infinity)
    "-oo" => Some(NumberSymbolKind::NegativeInfinity)
    "zoo" => Some(NumberSymbolKind::ComplexInfinity)
    "nan" | "NaN" => Some(NumberSymbolKind::NaN)
    _ => None
  }
}

///|
pub fn number_symbol(kind : NumberSymbolKind) -> Expr {
  Expr::NumberSymbol(kind)
}

///|
pub fn imag_unit() -> Expr {
  number_symbol(NumberSymbolKind::ImaginaryUnit)
}

///|
pub fn pi() -> Expr {
  number_symbol(NumberSymbolKind::Pi)
}

///|
pub fn exp1() -> Expr {
  number_symbol(NumberSymbolKind::Exp1)
}

///|
pub fn euler_gamma() -> Expr {
  number_symbol(NumberSymbolKind::EulerGamma)
}

///|
pub fn golden_ratio() -> Expr {
  number_symbol(NumberSymbolKind::GoldenRatio)
}

///|
pub fn catalan() -> Expr {
  number_symbol(NumberSymbolKind::Catalan)
}

///|
pub fn oo() -> Expr {
  number_symbol(NumberSymbolKind::Infinity)
}

///|
pub fn neg_oo() -> Expr {
  number_symbol(NumberSymbolKind::NegativeInfinity)
}

///|
pub fn zoo() -> Expr {
  number_symbol(NumberSymbolKind::ComplexInfinity)
}

///|
pub fn nan_expr() -> Expr {
  number_symbol(NumberSymbolKind::NaN)
}

///|
pub fn true_() -> Expr {
  Expr::Boolean(true)
}

///|
pub fn false_() -> Expr {
  Expr::Boolean(false)
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
  Expr::Tuple(items.map(item => item))
}

///|
pub fn eq(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Relational(RelOp::Eq, lhs, rhs)
}

///|
pub fn ne(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Relational(RelOp::Ne, lhs, rhs)
}

///|
pub fn lt(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Relational(RelOp::Lt, lhs, rhs)
}

///|
pub fn le(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Relational(RelOp::Le, lhs, rhs)
}

///|
pub fn gt(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Relational(RelOp::Gt, lhs, rhs)
}

///|
pub fn ge(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Relational(RelOp::Ge, lhs, rhs)
}

///|
pub fn derivative(expr : Expr, wrt : Expr, order? : Expr = int(1)) -> Expr {
  Expr::Derivative(expr, [wrt, order])
}

///|
pub fn subs_expr(expr : Expr, variable : Expr, value : Expr) -> Expr {
  Expr::Subs(expr, variable, value)
}

///|
pub fn lambda_expr(vars : Expr, body : Expr) -> Expr {
  Expr::Lambda(vars, body)
}

///|
pub fn expr_form(expr : Expr) -> ExprForm {
  match expr {
    Expr::Number(n) => ExprForm::Number(n)
    Expr::Float(f) => ExprForm::Float(f)
    Expr::ComplexFloat(z) => ExprForm::ComplexFloat(z)
    Expr::NumberSymbol(kind) => ExprForm::NumberSymbol(kind)
    Expr::Boolean(value) => ExprForm::Boolean(value)
    Expr::Dummy(name, _) => ExprForm::Symbol(dummy_display_name(name))
    Expr::Wild(name) => ExprForm::Symbol(wild_display_name(name))
    Expr::Symbol("True") => ExprForm::Boolean(true)
    Expr::Symbol("False") => ExprForm::Boolean(false)
    Expr::Symbol(name) =>
      match number_symbol_kind_from_name(name) {
        Some(kind) => ExprForm::NumberSymbol(kind)
        None => ExprForm::Symbol(name)
      }
    Expr::Add(args) => ExprForm::Add(args)
    Expr::Mul(args) => ExprForm::Mul(args)
    Expr::Pow(base, exp) => ExprForm::Pow(base, exp)
    Expr::Tuple(args) => ExprForm::Tuple(args)
    Expr::Relational(op, lhs, rhs) => ExprForm::Relational(op, lhs, rhs)
    Expr::Derivative(inner, deriv_args) =>
      ExprForm::Derivative(inner, deriv_args)
    Expr::Subs(inner, variable, value) => ExprForm::Subs(inner, variable, value)
    Expr::Lambda(vars, body) => ExprForm::Lambda(vars, body)
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
pub fn is_number_atom(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_) => true
    _ => false
  }
}

///|
pub fn is_real_number_atom(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Number(_) | ExprForm::Float(_) => true
    ExprForm::NumberSymbol(kind) =>
      match kind {
        NumberSymbolKind::Pi
        | NumberSymbolKind::Exp1
        | NumberSymbolKind::EulerGamma
        | NumberSymbolKind::GoldenRatio
        | NumberSymbolKind::Catalan => true
        _ => false
      }
    ExprForm::ComplexFloat(z) => @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
pub fn is_complex_number_atom(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::ComplexFloat(_) => true
    _ => false
  }
}

///|
pub fn is_atomic(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_)
    | ExprForm::Symbol(_)
    | ExprForm::Boolean(_) => true
    ExprForm::Applied(_, args) => args.is_empty()
    _ => false
  }
}

///|
pub fn head_name(expr : Expr) -> String {
  match expr_form(expr) {
    ExprForm::Number(_) => "Number"
    ExprForm::Float(_) => "Float"
    ExprForm::ComplexFloat(_) => "ComplexFloat"
    ExprForm::NumberSymbol(kind) => number_symbol_name(kind)
    ExprForm::Symbol(name) => name
    ExprForm::Boolean(true) => "True"
    ExprForm::Boolean(false) => "False"
    ExprForm::Add(_) => "Add"
    ExprForm::Mul(_) => "Mul"
    ExprForm::Pow(_, _) => "Pow"
    ExprForm::Tuple(_) => "Tuple"
    ExprForm::Relational(op, _, _) =>
      match op {
        RelOp::Eq => "Eq"
        RelOp::Ne => "Ne"
        RelOp::Lt => "Lt"
        RelOp::Le => "Le"
        RelOp::Gt => "Gt"
        RelOp::Ge => "Ge"
      }
    ExprForm::Derivative(_, _) => "Derivative"
    ExprForm::Subs(_, _, _) => "Subs"
    ExprForm::Lambda(_, _) => "Lambda"
    ExprForm::Applied(name, _) => name
  }
}

///|
pub fn tuple_items(expr : Expr) -> Array[Expr]? {
  match expr_form(expr) {
    ExprForm::Tuple(items) => Some(items)
    _ => None
  }
}

///|
pub fn dummy_parts(expr : Expr) -> (String, Int)? {
  match expr {
    Expr::Dummy(name, id) => Some((name, id))
    _ => None
  }
}

///|
pub fn wild_name(expr : Expr) -> String? {
  match expr {
    Expr::Wild(name) => Some(name)
    _ => None
  }
}

///|
pub fn relational_parts(expr : Expr) -> (RelOp, Expr, Expr)? {
  match expr_form(expr) {
    ExprForm::Relational(op, lhs, rhs) => Some((op, lhs, rhs))
    _ => None
  }
}

///|
pub fn derivative_parts(expr : Expr) -> (Expr, Array[Expr])? {
  match expr_form(expr) {
    ExprForm::Derivative(inner, deriv_args) => Some((inner, deriv_args))
    _ => None
  }
}

///|
pub fn subs_parts(expr : Expr) -> (Expr, Expr, Expr)? {
  match expr_form(expr) {
    ExprForm::Subs(inner, variable, value) => Some((inner, variable, value))
    _ => None
  }
}

///|
pub fn lambda_parts(expr : Expr) -> (Expr, Expr)? {
  match expr_form(expr) {
    ExprForm::Lambda(vars, body) => Some((vars, body))
    _ => None
  }
}

///|
pub fn applied_parts(expr : Expr) -> (String, Array[Expr])? {
  match expr_form(expr) {
    ExprForm::Tuple(items) => Some(("Tuple", items))
    ExprForm::Relational(op, lhs, rhs) => {
      let name = match op {
        RelOp::Eq => "Eq"
        RelOp::Ne => "Ne"
        RelOp::Lt => "Lt"
        RelOp::Le => "Le"
        RelOp::Gt => "Gt"
        RelOp::Ge => "Ge"
      }
      Some((name, [lhs, rhs]))
    }
    ExprForm::Derivative(inner, deriv_args) => {
      let args : Array[Expr] = [inner]
      for arg in deriv_args {
        args.push(arg)
      }
      Some(("Derivative", args))
    }
    ExprForm::Subs(inner, variable, value) =>
      Some(("Subs", [inner, variable, value]))
    ExprForm::Lambda(vars, body) => Some(("Lambda", [vars, body]))
    ExprForm::Applied(name, args) => Some((name, args))
    _ => None
  }
}

///|
pub fn args(expr : Expr) -> Array[Expr] {
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_)
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
  match expr {
    Expr::Symbol(name) => ignore(out.remove("sym:\{name}"))
    Expr::Dummy(_, id) => ignore(out.remove("dummy:\{id}"))
    Expr::Wild(name) => ignore(out.remove("wild:\{name}"))
    Expr::Tuple(items) =>
      for item in items {
        remove_bound_symbol(out, item)
      }
    _ =>
      match expr_form(expr) {
        ExprForm::Tuple(items) =>
          for item in items {
            remove_bound_symbol(out, item)
          }
        _ => ()
      }
  }
}

///|
fn free_symbol_map(expr : Expr, out : Map[String, Expr]) -> Unit {
  match expr {
    Expr::Symbol(name) => {
      out.set("sym:\{name}", expr)
      return
    }
    Expr::Dummy(_, id) => {
      out.set("dummy:\{id}", expr)
      return
    }
    Expr::Wild(name) => {
      out.set("wild:\{name}", expr)
      return
    }
    _ => ()
  }
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_)
    | ExprForm::Boolean(_) => ()
    ExprForm::Symbol(name) => out.set("sym:\{name}", expr)
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
      let pair_count = deriv_args.length() / 2
      for i in 0..<pair_count {
        let wrt = deriv_args[i * 2]
        remove_bound_symbol(out, wrt)
        let order_idx = i * 2 + 1
        if order_idx < deriv_args.length() {
          free_symbol_map(deriv_args[order_idx], out)
        }
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
