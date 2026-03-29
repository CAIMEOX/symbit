///|
pub(all) enum NumberSymbolKind {
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
pub(all) enum RelOp {
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
  IdentityFunction
  FunctionHead(String)
  UndefinedFunction(String)
  Apply(Expr, Array[Expr])
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
pub fn standalone_function_head_display_name(name : String) -> String {
  match name {
    "Eq" => "<class 'sympy.core.relational.Equality'>"
    "Ne" => "<class 'sympy.core.relational.Unequality'>"
    "Lt" => "<class 'sympy.core.relational.StrictLessThan'>"
    "Le" => "<class 'sympy.core.relational.LessThan'>"
    "Gt" => "<class 'sympy.core.relational.StrictGreaterThan'>"
    "Ge" => "<class 'sympy.core.relational.GreaterThan'>"
    "Tuple" => "<class 'sympy.core.containers.Tuple'>"
    "Dict" => "<class 'sympy.core.containers.Dict'>"
    "Derivative" => "<class 'sympy.core.function.Derivative'>"
    "Lambda" => "<class 'sympy.core.function.Lambda'>"
    "IdentityFunction" => "<class 'sympy.functions.elementary.miscellaneous.IdentityFunction'>"
    "Subs" => "<class 'sympy.core.function.Subs'>"
    "Zero" => "<class 'sympy.core.numbers.Zero'>"
    "One" => "<class 'sympy.core.numbers.One'>"
    "NegativeOne" => "<class 'sympy.core.numbers.NegativeOne'>"
    "Half" => "<class 'sympy.core.numbers.Half'>"
    "Integer" => "<class 'sympy.core.numbers.Integer'>"
    "Rational" => "<class 'sympy.core.numbers.Rational'>"
    "Pi" => "<class 'sympy.core.numbers.Pi'>"
    "Exp1" => "<class 'sympy.core.numbers.Exp1'>"
    "ImaginaryUnit" => "<class 'sympy.core.numbers.ImaginaryUnit'>"
    "Infinity" => "<class 'sympy.core.numbers.Infinity'>"
    "NegativeInfinity" => "<class 'sympy.core.numbers.NegativeInfinity'>"
    "ComplexInfinity" => "<class 'sympy.core.numbers.ComplexInfinity'>"
    "NaN" => "<class 'sympy.core.numbers.NaN'>"
    "BooleanTrue" => "<class 'sympy.logic.boolalg.BooleanTrue'>"
    "BooleanFalse" => "<class 'sympy.logic.boolalg.BooleanFalse'>"
    "Symbol" => "<class 'sympy.core.symbol.Symbol'>"
    "Dummy" => "<class 'sympy.core.symbol.Dummy'>"
    "Wild" => "<class 'sympy.core.symbol.Wild'>"
    _ =>
      match builtin_head_display_override(name) {
        Some(display) => display
        None => name
      }
  }
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
    if i + 1 < deriv_args.length() &&
      is_explicit_derivative_order(deriv_args[i + 1]) {
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
fn lambda_signature_items(vars : Expr) -> Array[Expr] {
  match normalize_legacy_expr(vars) {
    Expr::Tuple(items) => items
    other => [other]
  }
}

///|
fn is_lambda_signature_atom(expr : Expr) -> Bool {
  match normalize_legacy_expr(expr) {
    Expr::Symbol(_) | Expr::Dummy(_, _) | Expr::Wild(_) => true
    _ => false
  }
}

///|
fn lambda_identity_expr() -> Expr {
  Expr::IdentityFunction
}

///|
pub fn lambda_arity(vars : Expr) -> Int? {
  let items = lambda_signature_items(vars)
  for item in items {
    match normalize_legacy_expr(item) {
      Expr::Tuple(_) | Expr::Symbol(_) | Expr::Dummy(_, _) | Expr::Wild(_) => ()
      _ => return None
    }
  }
  Some(items.length())
}

///|
pub fn lambda_signature_error(vars : Expr) -> String? {
  let seen : Array[Expr] = []
  letrec check = (expr : Expr) => {
    let normalized = normalize_legacy_expr(expr)
    if is_lambda_signature_atom(normalized) {
      if seen.contains(normalized) {
        return Some("Duplicate symbol " + normalized.to_string())
      }
      seen.push(normalized)
      return None
    }
    match normalized {
      Expr::Tuple(items) => {
        for item in items {
          match check(item) {
            Some(err) => return Some(err)
            None => ()
          }
        }
        None
      }
      _ => Some(
        "Lambda signature should be only tuples and symbols, not " +
        normalized.to_string(),
      )
    }
  }
  let top_level = lambda_signature_items(vars)
  for item in top_level {
    match check(item) {
      Some(err) => return Some(err)
      None => ()
    }
  }
  None
}

///|
pub fn lambda_expr(vars : Expr, body : Expr) -> Expr {
  let vars = normalize_legacy_expr(vars)
  let body = normalize_legacy_expr(body)
  match lambda_signature_error(vars) {
    Some(_) => Expr::Apply(Expr::FunctionHead("Lambda"), [vars, body])
    None => {
      let items = lambda_signature_items(vars)
      if items.length() == 1 && items[0] == body {
        lambda_identity_expr()
      } else {
        Expr::Lambda(vars, body)
      }
    }
  }
}

///|
pub fn expr_display(expr : Expr) -> String {
  expr.to_string()
}

///|
pub fn sorted_dict_entries(items : Array[(Expr, Expr)]) -> Array[(Expr, Expr)] {
  let sorted = items.copy()
  sorted.sort_by((lhs, rhs) => {
    let (lhs_key, lhs_value) = lhs
    let (rhs_key, rhs_value) = rhs
    let key_cmp = if is_number_atom(lhs_key) && !is_number_atom(rhs_key) {
      -1
    } else if !is_number_atom(lhs_key) && is_number_atom(rhs_key) {
      1
    } else {
      compare_expr(lhs_key, rhs_key)
    }
    if key_cmp != 0 {
      key_cmp
    } else {
      compare_expr(lhs_value, rhs_value)
    }
  })
  sorted
}

///|
fn normalize_legacy_function(name : String, args : Array[Expr]) -> Expr {
  function(name, args.map(normalize_legacy_expr))
}

///|
pub fn expr_form(expr : Expr) -> ExprForm {
  match expr {
    Expr::Number(n) => ExprForm::Number(n)
    Expr::Float(f) => ExprForm::Float(f)
    Expr::ComplexFloat(z) => ExprForm::ComplexFloat(z)
    Expr::NumberSymbol(kind) => ExprForm::NumberSymbol(kind)
    Expr::Boolean(value) => ExprForm::Boolean(value)
    Expr::IdentityFunction => ExprForm::IdentityFunction
    Expr::Dummy(name, id) => ExprForm::Dummy(name, id)
    Expr::Wild(name) => ExprForm::Wild(name)
    Expr::FunctionHead(name) => ExprForm::FunctionHead(name)
    Expr::UndefinedFunction(name) => ExprForm::UndefinedFunction(name)
    Expr::Apply(head, args) => ExprForm::Apply(head, args)
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
    Expr::Function(name, args) =>
      expr_form(normalize_legacy_function(name, args))
  }
}

///|
pub fn normalize_legacy_expr(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => Expr::Add(args.map(normalize_legacy_expr))
    Expr::Mul(args) => Expr::Mul(args.map(normalize_legacy_expr))
    Expr::Pow(base, exp) =>
      Expr::Pow(normalize_legacy_expr(base), normalize_legacy_expr(exp))
    Expr::Mod(lhs, rhs) =>
      Expr::Mod(normalize_legacy_expr(lhs), normalize_legacy_expr(rhs))
    Expr::Tuple(args) => Expr::Tuple(args.map(normalize_legacy_expr))
    Expr::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((normalize_legacy_expr(key), normalize_legacy_expr(value)))
      }
      Expr::Dict(out)
    }
    Expr::Relational(op, lhs, rhs) =>
      Expr::Relational(
        op,
        normalize_legacy_expr(lhs),
        normalize_legacy_expr(rhs),
      )
    Expr::Derivative(inner, deriv_args) =>
      Expr::Derivative(
        normalize_legacy_expr(inner),
        deriv_args.map(normalize_legacy_expr),
      )
    Expr::Subs(inner, variable, value) =>
      Expr::Subs(
        normalize_legacy_expr(inner),
        normalize_legacy_expr(variable),
        normalize_legacy_expr(value),
      )
    Expr::Lambda(vars, body) =>
      Expr::Lambda(normalize_legacy_expr(vars), normalize_legacy_expr(body))
    Expr::Apply(head, args) => {
      let head = normalize_legacy_expr(head)
      let args = args.map(normalize_legacy_expr)
      match raw_apply(head, args) {
        Some(applied) => applied
        None => Expr::Apply(head, args)
      }
    }
    Expr::Function(name, args) => normalize_legacy_function(name, args)
    _ => expr
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
    ExprForm::Float(f) =>
      @symnum.mpf_cmp(
        f.to_mpf(),
        Float::from_int(1, prec=f.precision()).to_mpf(),
      ) ==
      0
    ExprForm::ComplexFloat(z) =>
      @symnum.mpf_cmp(
        z.to_mpc().real,
        Float::from_int(1, prec=z.precision()).to_mpf(),
      ) ==
      0 &&
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
    | ExprForm::IdentityFunction
    | ExprForm::FunctionHead(_)
    | ExprForm::UndefinedFunction(_)
    | ExprForm::Boolean(_) => true
    ExprForm::Apply(_, args) => args.is_empty()
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
    ExprForm::IdentityFunction => "IdentityFunction"
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
    ExprForm::Apply(head, _) =>
      match function_head_name(head) {
        Some(name) => name
        None => "Apply"
      }
  }
}

///|
pub fn tuple_items(expr : Expr) -> Array[Expr]? {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Tuple(items) => Some(items)
    _ => None
  }
}

///|
pub fn dict_items(expr : Expr) -> Array[(Expr, Expr)]? {
  let expr = normalize_legacy_expr(expr)
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
  match application_parts(expr) {
    Some((Expr::UndefinedFunction(name), args)) => Some((name, args))
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
fn exact_number_func_name(value : @symnum.BigRational) -> String {
  let half = @symnum.BigRational::from_ints(1, 2) catch {
    _ => abort("invalid half rational")
  }
  if value.is_zero() {
    "Zero"
  } else if value.is_one() {
    "One"
  } else if value.compare(@symnum.BigRational::from_int(-1)) == 0 {
    "NegativeOne"
  } else if value.compare(half) == 0 {
    "Half"
  } else if value.is_integral() {
    "Integer"
  } else {
    "Rational"
  }
}

///|
fn number_symbol_func_name(kind : NumberSymbolKind) -> String {
  match kind {
    NumberSymbolKind::ImaginaryUnit => "ImaginaryUnit"
    NumberSymbolKind::Pi => "Pi"
    NumberSymbolKind::Exp1 => "Exp1"
    NumberSymbolKind::EulerGamma => "EulerGamma"
    NumberSymbolKind::GoldenRatio => "GoldenRatio"
    NumberSymbolKind::Catalan => "Catalan"
    NumberSymbolKind::Infinity => "Infinity"
    NumberSymbolKind::NegativeInfinity => "NegativeInfinity"
    NumberSymbolKind::ComplexInfinity => "ComplexInfinity"
    NumberSymbolKind::NaN => "NaN"
  }
}

///|
fn relational_func_name(op : RelOp) -> String {
  match op {
    RelOp::Eq => "Equality"
    RelOp::Ne => "Unequality"
    RelOp::Lt => "StrictLessThan"
    RelOp::Le => "LessThan"
    RelOp::Gt => "StrictGreaterThan"
    RelOp::Ge => "GreaterThan"
  }
}

///|
fn boolean_func_name(value : Bool) -> String {
  if value {
    "BooleanTrue"
  } else {
    "BooleanFalse"
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
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Relational(op, lhs, rhs) => Some((op, lhs, rhs))
    _ => None
  }
}

///|
pub fn derivative_parts(expr : Expr) -> (Expr, Array[Expr])? {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Derivative(inner, deriv_args) => Some((inner, deriv_args))
    _ => None
  }
}

///|
pub fn subs_parts(expr : Expr) -> (Expr, Expr, Expr)? {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Subs(inner, variable, value) => Some((inner, variable, value))
    _ => None
  }
}

///|
pub fn lambda_parts(expr : Expr) -> (Expr, Expr)? {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Lambda(vars, body) => Some((vars, body))
    _ => None
  }
}

///|
pub fn applied_parts(expr : Expr) -> (String, Array[Expr])? {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Tuple(items) => Some(("Tuple", items))
    ExprForm::Dict(items) => {
      let args : Array[Expr] = []
      for item in items {
        let (key, value) = item
        args.push(Expr::Tuple([key, value]))
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
    ExprForm::Apply(head, args) =>
      match function_head_name(head) {
        Some(name) => Some((name, args))
        None => None
      }
    _ => None
  }
}

///|
pub fn application_parts(expr : Expr) -> (Expr, Array[Expr])? {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Expr::Apply(head, args) => return Some((head, args.map(child => child)))
    _ => ()
  }
  None
}

///|
pub fn is_application(expr : Expr) -> Bool {
  application_parts(expr) is Some(_)
}

///|
pub fn func(expr : Expr) -> Expr? {
  let expr = normalize_legacy_expr(expr)
  match application_parts(expr) {
    Some((head, _)) => Some(head)
    None =>
      match expr_form(expr) {
        ExprForm::Number(value) =>
          Some(Expr::FunctionHead(exact_number_func_name(value)))
        ExprForm::Float(_) => Some(Expr::FunctionHead("Float"))
        ExprForm::ComplexFloat(_) => Some(Expr::FunctionHead("ComplexFloat"))
        ExprForm::NumberSymbol(kind) =>
          Some(Expr::FunctionHead(number_symbol_func_name(kind)))
        ExprForm::Symbol(_) => Some(Expr::FunctionHead("Symbol"))
        ExprForm::Dummy(_, _) => Some(Expr::FunctionHead("Dummy"))
        ExprForm::Wild(_) => Some(Expr::FunctionHead("Wild"))
        ExprForm::IdentityFunction => Some(Expr::FunctionHead("IdentityFunction"))
        ExprForm::Boolean(value) =>
          Some(Expr::FunctionHead(boolean_func_name(value)))
        ExprForm::FunctionHead(_) | ExprForm::UndefinedFunction(_) => None
        ExprForm::Add(_) => Some(Expr::FunctionHead("Add"))
        ExprForm::Mul(_) => Some(Expr::FunctionHead("Mul"))
        ExprForm::Pow(_, _) => Some(Expr::FunctionHead("Pow"))
        ExprForm::Mod(_, _) => Some(Expr::FunctionHead("Mod"))
        ExprForm::Tuple(_) => Some(Expr::FunctionHead("Tuple"))
        ExprForm::Dict(_) => Some(Expr::FunctionHead("Dict"))
        ExprForm::Relational(op, _, _) =>
          Some(Expr::FunctionHead(relational_func_name(op)))
        ExprForm::Derivative(_, _) => Some(Expr::FunctionHead("Derivative"))
        ExprForm::Subs(_, _, _) => Some(Expr::FunctionHead("Subs"))
        ExprForm::Lambda(_, _) => Some(Expr::FunctionHead("Lambda"))
        ExprForm::Apply(_, _) => None
      }
  }
}

///|
pub fn rebuild_application(expr : Expr, args : Array[Expr]) -> Expr? {
  match application_parts(expr) {
    Some((head, _)) => raw_apply(head, args)
    None => None
  }
}

///|
pub fn application_name(expr : Expr) -> String? {
  match application_parts(expr) {
    Some((head, _)) => function_head_name(head)
    None => None
  }
}

///|
pub fn application_args(expr : Expr) -> Array[Expr]? {
  match application_parts(expr) {
    Some((_, args)) => Some(args)
    None => None
  }
}

///|
pub fn application_has_name(
  expr : Expr,
  name : String,
  arity? : Int = -1,
) -> Bool {
  match application_parts(expr) {
    Some((head, args)) =>
      match function_head_name(head) {
        Some(head_name) =>
          head_name == name && (arity < 0 || args.length() == arity)
        None => false
      }
    None => false
  }
}

///|
pub fn args(expr : Expr) -> Array[Expr] {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_)
    | ExprForm::Symbol(_)
    | ExprForm::Dummy(_, _)
    | ExprForm::Wild(_)
    | ExprForm::IdentityFunction
    | ExprForm::FunctionHead(_)
    | ExprForm::UndefinedFunction(_)
    | ExprForm::Boolean(_) => []
    ExprForm::Add(items)
    | ExprForm::Mul(items)
    | ExprForm::Tuple(items)
    | ExprForm::Apply(_, items) => items.copy()
    ExprForm::Dict(items) => {
      let sorted = sorted_dict_entries(items)
      let out : Array[Expr] = []
      for item in sorted {
        let (key, value) = item
        out.push(Expr::Tuple([key, value]))
      }
      out
    }
    ExprForm::Pow(base, exp) => [base, exp]
    ExprForm::Mod(lhs, rhs) => [lhs, rhs]
    ExprForm::Relational(_, lhs, rhs) => [lhs, rhs]
    ExprForm::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = [inner]
      let mut i = 0
      while i + 1 < deriv_args.length() {
        out.push(Expr::Tuple([deriv_args[i], deriv_args[i + 1]]))
        i += 2
      }
      out
    }
    ExprForm::Subs(inner, variable, value) =>
      [
        inner,
        match variable {
          Expr::Tuple(_) => variable
          _ => Expr::Tuple([variable])
        },
        match value {
          Expr::Tuple(_) => value
          _ => Expr::Tuple([value])
        },
      ]
    ExprForm::Lambda(vars, body) =>
      [
        match vars {
          Expr::Tuple(_) => vars
          _ => Expr::Tuple([vars])
        },
        body,
      ]
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
    Expr::FunctionHead(_) | Expr::UndefinedFunction(_) | Expr::Boolean(_) =>
      return
    _ => ()
  }
  match expr_form(expr) {
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_)
    | ExprForm::Dummy(_, _)
    | ExprForm::Wild(_)
    | ExprForm::IdentityFunction
    | ExprForm::FunctionHead(_)
    | ExprForm::UndefinedFunction(_)
    | ExprForm::Boolean(_) => ()
    ExprForm::Symbol(name) => out.set("sym:\{name}", expr)
    ExprForm::Add(items) | ExprForm::Mul(items) | ExprForm::Tuple(items) =>
      for item in items {
        free_symbol_map(item, out)
      }
    ExprForm::Apply(head, items) => {
      free_symbol_map(head, out)
      for item in items {
        free_symbol_map(item, out)
      }
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
        free_symbol_map(wrt, out)
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
  match application_parts(expr) {
    Some((head, app_args)) => {
      if has(head, needle) {
        return true
      }
      for child in app_args {
        if has(child, needle) {
          return true
        }
      }
      return false
    }
    None => ()
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
