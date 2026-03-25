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
  Dummy(String, Int)
  Wild(String)
  FunctionHead(String)
  UndefinedFunction(String)
  AppliedUndef(String, Array[Expr])
  Boolean(Bool)
  Add(Array[Expr])
  Mul(Array[Expr])
  Pow(Expr, Expr)
  Mod(Expr, Expr)
  Tuple(Array[Expr])
  Dict(Array[(Expr, Expr)])
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
pub fn dict_expr(items : Array[(Expr, Expr)]) -> Expr {
  Expr::Dict(items.map(item => item))
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
fn is_explicit_derivative_order(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_integral()
    _ => false
  }
}

///|
pub fn canonical_derivative_args(deriv_args : ArrayView[Expr]) -> Array[Expr] {
  if deriv_args.length() == 0 {
    return []
  }
  if deriv_args.length() % 2 == 0 {
    let out : Array[Expr] = []
    for arg in deriv_args {
      out.push(arg)
    }
    return out
  }
  let out : Array[Expr] = []
  for arg in deriv_args {
    out.push(arg)
    out.push(int(1))
  }
  out
}

///|
fn raw_derivative_args(deriv_args : ArrayView[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  let mut i = 0
  while i < deriv_args.length() {
    let wrt = deriv_args[i]
    if i + 1 < deriv_args.length() && is_explicit_derivative_order(deriv_args[i + 1]) {
      out.push(wrt)
      out.push(deriv_args[i + 1])
      i += 2
    } else {
      out.push(wrt)
      out.push(int(1))
      i += 1
    }
  }
  out
}

///|
pub fn raw_derivative(expr : Expr, deriv_args : ArrayView[Expr]) -> Expr {
  Expr::Derivative(expr, raw_derivative_args(deriv_args))
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
    Expr::Dummy(name, id) => ExprForm::Dummy(name, id)
    Expr::Wild(name) => ExprForm::Wild(name)
    Expr::FunctionHead(name) => ExprForm::FunctionHead(name)
    Expr::UndefinedFunction(name) => ExprForm::UndefinedFunction(name)
    Expr::AppliedUndef(name, args) => ExprForm::AppliedUndef(name, args)
    Expr::Symbol(name) => ExprForm::Symbol(name)
    Expr::Add(args) => ExprForm::Add(args)
    Expr::Mul(args) => ExprForm::Mul(args)
    Expr::Pow(base, exp) => ExprForm::Pow(base, exp)
    Expr::Mod(lhs, rhs) => ExprForm::Mod(lhs, rhs)
    Expr::Tuple(args) => ExprForm::Tuple(args)
    Expr::Dict(items) => ExprForm::Dict(items)
    Expr::Relational(op, lhs, rhs) => ExprForm::Relational(op, lhs, rhs)
    Expr::Derivative(inner, deriv_args) =>
      ExprForm::Derivative(inner, canonical_derivative_args(deriv_args))
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
    Expr::Function("Mod", [lhs, rhs]) => ExprForm::Mod(lhs, rhs)
    Expr::Function("Derivative", [inner, wrt]) =>
      ExprForm::Derivative(inner, [wrt, int(1)])
    Expr::Function("Derivative", [inner, wrt, order]) =>
      ExprForm::Derivative(inner, [wrt, order])
    Expr::Function("Subs", [inner, variable, value]) =>
      ExprForm::Subs(inner, variable, value)
    Expr::Function("Lambda", [vars, body]) => ExprForm::Lambda(vars, body)
    Expr::Function("Dict", args) => {
      let items : Array[(Expr, Expr)] = []
      for arg in args {
        match expr_form(arg) {
          ExprForm::Tuple([key, value]) => items.push((key, value))
          _ => return ExprForm::Applied("Dict", args)
        }
      }
      ExprForm::Dict(items)
    }
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
pub fn bool_value(expr : Expr) -> Bool? {
  match expr_form(expr) {
    ExprForm::Boolean(value) => Some(value)
    _ => None
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
pub fn number_symbol_kind(expr : Expr) -> NumberSymbolKind? {
  match expr_form(expr) {
    ExprForm::NumberSymbol(kind) => Some(kind)
    _ => None
  }
}

///|
pub fn is_number_symbol(expr : Expr) -> Bool {
  match number_symbol_kind(expr) {
    Some(_) => true
    None => false
  }
}

///|
pub fn is_infinite(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::NumberSymbol(NumberSymbolKind::Infinity)
    | ExprForm::NumberSymbol(NumberSymbolKind::NegativeInfinity)
    | ExprForm::NumberSymbol(NumberSymbolKind::ComplexInfinity) => true
    _ => false
  }
}

///|
pub fn is_nan(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::NumberSymbol(NumberSymbolKind::NaN) => true
    _ => false
  }
}

///|
pub fn is_zero(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Number(n) => n.is_zero()
    ExprForm::Float(f) => @symnum.is_zero(f.to_mpf())
    ExprForm::ComplexFloat(z) =>
      @symnum.is_zero(z.to_mpc().real) && @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
pub fn is_one(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Number(n) => n.is_one()
    ExprForm::Float(f) => @symnum.mpf_cmp(
        f.to_mpf(),
        Float::from_int(1, prec=f.precision()).to_mpf(),
      ) == 0
    ExprForm::ComplexFloat(z) =>
      @symnum.mpf_cmp(
        z.to_mpc().real,
        Float::from_int(1, prec=z.precision()).to_mpf(),
      ) == 0 &&
      @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
pub fn is_finite_number_atom(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Number(_) => true
    ExprForm::Float(f) => f.is_finite()
    ExprForm::ComplexFloat(z) => z.is_finite()
    ExprForm::NumberSymbol(_) => !is_infinite(expr) && !is_nan(expr)
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
    | ExprForm::Dummy(_, _)
    | ExprForm::Wild(_)
    | ExprForm::FunctionHead(_)
    | ExprForm::UndefinedFunction(_)
    | ExprForm::Boolean(_) => true
    ExprForm::AppliedUndef(_, args) | ExprForm::Applied(_, args) =>
      args.is_empty()
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
    ExprForm::Dummy(name, _) => dummy_display_name(name)
    ExprForm::Wild(name) => wild_display_name(name)
    ExprForm::FunctionHead(name) => name
    ExprForm::UndefinedFunction(name) => name
    ExprForm::Boolean(true) => "True"
    ExprForm::Boolean(false) => "False"
    ExprForm::Add(_) => "Add"
    ExprForm::Mul(_) => "Mul"
    ExprForm::Pow(_, _) => "Pow"
    ExprForm::Mod(_, _) => "Mod"
    ExprForm::Tuple(_) => "Tuple"
    ExprForm::Dict(_) => "Dict"
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
    ExprForm::AppliedUndef(name, _) | ExprForm::Applied(name, _) => name
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
pub fn dict_items(expr : Expr) -> Array[(Expr, Expr)]? {
  match expr_form(expr) {
    ExprForm::Dict(items) => Some(items)
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
pub fn undefined_application_parts(expr : Expr) -> (String, Array[Expr])? {
  match expr {
    Expr::AppliedUndef(name, args) => Some((name, args))
    _ => None
  }
}

///|
pub fn function_head_name(expr : Expr) -> String? {
  match expr_form(expr) {
    ExprForm::FunctionHead(name) => Some(name)
    ExprForm::UndefinedFunction(name) => Some(name)
    _ => None
  }
}

///|
pub fn is_function_head(expr : Expr) -> Bool {
  match function_head_name(expr) {
    Some(_) => true
    None => false
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
    ExprForm::Dict(items) => {
      let args : Array[Expr] = []
      for item in items {
        let (key, value) = item
        args.push(tuple_expr([key, value]))
      }
      Some(("Dict", args))
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
    ExprForm::Mod(lhs, rhs) => Some(("Mod", [lhs, rhs]))
    ExprForm::AppliedUndef(name, args) | ExprForm::Applied(name, args) =>
      Some((name, args))
    _ => None
  }
}

///|
pub fn application_parts(expr : Expr) -> (Expr, Array[Expr])? {
  match expr_form(expr) {
    ExprForm::AppliedUndef(name, args) => Some((undefined_function(name), args))
    ExprForm::Applied(name, args) => Some((function_head(name), args))
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
    | ExprForm::Dummy(_, _)
    | ExprForm::Wild(_)
    | ExprForm::FunctionHead(_)
    | ExprForm::UndefinedFunction(_)
    | ExprForm::Boolean(_) => []
    ExprForm::Add(items)
    | ExprForm::Mul(items)
    | ExprForm::Tuple(items)
    | ExprForm::AppliedUndef(_, items)
    | ExprForm::Applied(_, items) => items.copy()
    ExprForm::Dict(items) => {
      let out : Array[Expr] = []
      for item in items {
        let (key, value) = item
        out.push(tuple_expr([key, value]))
      }
      out
    }
    ExprForm::Pow(base, exp) => [base, exp]
    ExprForm::Mod(lhs, rhs) => [lhs, rhs]
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
    Expr::Dict(items) =>
      for item in items {
        let (key, value) = item
        remove_bound_symbol(out, key)
        remove_bound_symbol(out, value)
      }
    _ =>
      match expr_form(expr) {
        ExprForm::Tuple(items) =>
          for item in items {
            remove_bound_symbol(out, item)
          }
        ExprForm::Dict(items) =>
          for item in items {
            let (key, value) = item
            remove_bound_symbol(out, key)
            remove_bound_symbol(out, value)
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
    Expr::FunctionHead(_) | Expr::UndefinedFunction(_) | Expr::Boolean(_) => return
    _ => ()
  }
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_)
    | ExprForm::Dummy(_, _)
    | ExprForm::Wild(_)
    | ExprForm::FunctionHead(_)
    | ExprForm::UndefinedFunction(_)
    | ExprForm::Boolean(_) => ()
    ExprForm::Symbol(name) => out.set("sym:\{name}", expr)
    ExprForm::Add(items)
    | ExprForm::Mul(items)
    | ExprForm::Tuple(items)
    | ExprForm::AppliedUndef(_, items)
    | ExprForm::Applied(_, items) =>
      for item in items {
        free_symbol_map(item, out)
      }
    ExprForm::Dict(items) =>
      for item in items {
        let (key, value) = item
        free_symbol_map(key, out)
        free_symbol_map(value, out)
      }
    ExprForm::Pow(base, exp) => {
      free_symbol_map(base, out)
      free_symbol_map(exp, out)
    }
    ExprForm::Mod(lhs, rhs) => {
      free_symbol_map(lhs, out)
      free_symbol_map(rhs, out)
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

///|
fn push_unique_sorted(out : Array[Expr], expr : Expr) -> Unit {
  for item in out {
    if compare_expr(item, expr) == 0 {
      return
    }
  }
  out.push(expr)
  out.mut_view().sort_by((a, b) => compare_expr(a, b))
}

///|
fn collect_atoms(expr : Expr, out : Array[Expr]) -> Unit {
  if is_atomic(expr) {
    push_unique_sorted(out, expr)
    return
  }
  for child in args(expr) {
    collect_atoms(child, out)
  }
}

///|
pub fn atoms(expr : Expr) -> Array[Expr] {
  let out : Array[Expr] = []
  collect_atoms(expr, out)
  out
}
