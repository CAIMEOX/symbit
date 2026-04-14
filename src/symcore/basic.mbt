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
pub(all) enum WildProperty {
  Symbol
  Integer
  Rational
  Real
  Positive
  Negative
  Finite
  Nonzero
}

///|
pub(all) enum ExactNumberKind {
  Zero
  One
  NegativeOne
  Half
  Integer
  Rational
}

///|
pub(all) enum Kind {
  NumberKind
  BooleanKind
  TupleKind(Array[Kind])
  UndefinedKind
}

///|
pub enum ExprForm {
  Number(@symnum.BigRational)
  Float(Float)
  ComplexFloat(ComplexFloat)
  NumberSymbol(NumberSymbolKind)
  Symbol(String)
  Dummy(String, Int)
  Wild(String, Array[Expr], Array[WildProperty])
  WildFunction(String, Array[Int])
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
pub fn wild_property_name(property : WildProperty) -> String {
  match property {
    WildProperty::Symbol => "symbol"
    WildProperty::Integer => "integer"
    WildProperty::Rational => "rational"
    WildProperty::Real => "real"
    WildProperty::Positive => "positive"
    WildProperty::Negative => "negative"
    WildProperty::Finite => "finite"
    WildProperty::Nonzero => "nonzero"
  }
}

///|
pub fn kind_name(kind : Kind) -> String {
  match kind {
    Kind::NumberKind => "NumberKind"
    Kind::BooleanKind => "BooleanKind"
    Kind::TupleKind(items) =>
      "TupleKind(" + items.map(kind_name).join(", ") + ")"
    Kind::UndefinedKind => "UndefinedKind"
  }
}

///|
fn kind_is_undefined(kind : Kind) -> Bool {
  match kind {
    Kind::UndefinedKind => true
    _ => false
  }
}

///|
fn combine_kinds(lhs : Kind, rhs : Kind) -> Kind {
  match (lhs, rhs) {
    (Kind::UndefinedKind, _) | (_, Kind::UndefinedKind) => Kind::UndefinedKind
    (Kind::NumberKind, Kind::NumberKind) => Kind::NumberKind
    (Kind::BooleanKind, Kind::BooleanKind) => Kind::BooleanKind
    (Kind::TupleKind(items_lhs), Kind::TupleKind(items_rhs)) =>
      if items_lhs.length() != items_rhs.length() {
        Kind::UndefinedKind
      } else {
        let out : Array[Kind] = []
        for i in 0..<items_lhs.length() {
          out.push(combine_kinds(items_lhs[i], items_rhs[i]))
        }
        if out.any(kind_is_undefined) {
          Kind::UndefinedKind
        } else {
          Kind::TupleKind(out)
        }
      }
    _ => Kind::UndefinedKind
  }
}

///|
pub fn common_kind(kinds : Array[Kind]) -> Kind {
  if kinds.is_empty() {
    return Kind::UndefinedKind
  }
  let mut current = kinds[0]
  for i in 1..<kinds.length() {
    current = combine_kinds(current, kinds[i])
    if kind_is_undefined(current) {
      return current
    }
  }
  current
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
    "IdentityFunction" =>
      "<class 'sympy.functions.elementary.miscellaneous.IdentityFunction'>"
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
/// Build a derivative expression over a variable and optional order.
///
/// - Does: Constructs a core derivative node.
/// - Input: An expression, a differentiation variable, and an optional order.
/// - Returns: `Expr::Derivative`.
/// - Limits: This front door builds the expression object only; analytical
///   calculus routines live in higher-level packages.
pub fn derivative(expr : Expr, wrt : Expr, order? : Expr = int(1)) -> Expr {
  Expr::Derivative(expr, [wrt, order])
}

///|
fn expr_can_diff_wrt(expr : Expr) -> Bool {
  match normalize_legacy_expr(expr) {
    Expr::Symbol(_) | Expr::Dummy(_, _) => true
    Expr::Apply(Expr::UndefinedFunction(_), _) => true
    Expr::Derivative(inner, deriv_args) =>
      match normalize_legacy_expr(inner) {
        Expr::Apply(Expr::UndefinedFunction(_), inner_args) => {
          let mut all_symbol_args = true
          for arg in inner_args {
            match normalize_legacy_expr(arg) {
              Expr::Symbol(_) | Expr::Dummy(_, _) => ()
              _ => {
                all_symbol_args = false
                break
              }
            }
          }
          if !all_symbol_args {
            return false
          }
          for pair in derivative_constructor_pairs(deriv_args[:]) {
            let (wrt, order) = pair
            if !expr_can_diff_wrt(wrt) ||
              !derivative_order_is_positive_integer(order) {
              return false
            }
          }
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
fn derivative_order_is_zero(expr : Expr) -> Bool {
  match normalize_legacy_expr(expr) {
    Expr::Number(n) => n.is_integral() && n.is_zero()
    _ => false
  }
}

///|
fn derivative_order_is_positive_integer(expr : Expr) -> Bool {
  match normalize_legacy_expr(expr) {
    Expr::Number(n) => n.is_integral() && n.numerator().compare(0N) > 0
    _ => false
  }
}

///|
fn derivative_order_is_negative_integer(expr : Expr) -> Bool {
  match normalize_legacy_expr(expr) {
    Expr::Number(n) => n.is_integral() && n.numerator().compare(0N) < 0
    _ => false
  }
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
fn derivative_constructor_pairs(
  deriv_args : ArrayView[Expr],
) -> Array[(Expr, Expr)] {
  let out : Array[(Expr, Expr)] = []
  let mut i = 0
  while i < deriv_args.length() {
    let current = normalize_legacy_expr(deriv_args[i])
    match current {
      Expr::Tuple([wrt, order]) => {
        out.push((wrt, order))
        i += 1
      }
      _ =>
        if i + 1 < deriv_args.length() &&
          is_explicit_derivative_order(normalize_legacy_expr(deriv_args[i + 1])) {
          out.push((current, normalize_legacy_expr(deriv_args[i + 1])))
          i += 2
        } else {
          out.push((current, int(1)))
          i += 1
        }
    }
  }
  out
}

///|
pub fn derivative_signature_error(deriv_args : ArrayView[Expr]) -> String? {
  for pair in derivative_constructor_pairs(deriv_args) {
    let (wrt, order) = pair
    if !expr_can_diff_wrt(wrt) {
      return Some("Can't calculate derivative wrt " + expr_display(wrt) + ".")
    }
    if derivative_order_is_negative_integer(order) {
      return Some("order of differentiation must be nonnegative")
    }
  }
  None
}

///|
pub fn derivative_constructor_expr(
  expr : Expr,
  deriv_args : ArrayView[Expr],
) -> Expr {
  let expr = normalize_legacy_expr(expr)
  match derivative_signature_error(deriv_args) {
    Some(_) => {
      let legacy_args : Array[Expr] = [expr]
      for arg in deriv_args {
        legacy_args.push(normalize_legacy_expr(arg))
      }
      Expr::Apply(Expr::FunctionHead("Derivative"), legacy_args)
    }
    None => {
      let out : Array[Expr] = []
      for pair in derivative_constructor_pairs(deriv_args) {
        let (wrt, order) = pair
        if derivative_order_is_zero(order) {
          ()
        } else {
          out.push(wrt)
          out.push(order)
        }
      }
      if out.is_empty() {
        expr
      } else {
        Expr::Derivative(expr, out)
      }
    }
  }
}

///|
fn subs_items(expr : Expr) -> Array[Expr] {
  match normalize_legacy_expr(expr) {
    Expr::Tuple(items) => items
    other => [other]
  }
}

///|
fn subs_items_expr(items : Array[Expr]) -> Expr {
  match items {
    [] => Expr::Tuple([])
    [item] => item
    _ => Expr::Tuple(items)
  }
}

///|
pub fn subs_signature_error(variable : Expr, value : Expr) -> String? {
  let variables = subs_items(variable)
  let values = subs_items(value)
  let repeated : Array[String] = []
  for variable in variables {
    let count = variables.filter(current => current == variable).length()
    if count > 1 {
      let name = variable.to_string()
      if !repeated.contains(name) {
        repeated.push(name)
      }
    }
  }
  if !repeated.is_empty() {
    Some(
      "The following expressions appear more than once: " + repeated.join(", "),
    )
  } else if variables.length() != values.length() {
    Some("Number of point values must be the same as the number of variables.")
  } else {
    None
  }
}

///|
/// Build or extend a structural substitution expression.
///
/// - Does: Replaces one exact subexpression with another exact subexpression.
/// - Input: The target expression, the variable expression, and the replacement
///   expression.
/// - Returns: A rewritten `Expr`, often a `Subs` node.
/// - Limits: Matching is structural; it does not perform algebraic equivalence
///   matching.
///
/// ```mbt check
/// test "symcore subs_expr performs structural replacement" {
///   let x = Expr::Symbol("x")
///   let expr = add([x, int(1)])
///   inspect(
///     @symprint.to_string(subs_expr(expr, x, int(3))),
///     content="Subs(x + 1, x, 3)",
///   )
/// }
/// ```
pub fn subs_expr(expr : Expr, variable : Expr, value : Expr) -> Expr {
  let expr = normalize_legacy_expr(expr)
  let variable = normalize_legacy_expr(variable)
  let value = normalize_legacy_expr(value)
  match subs_signature_error(variable, value) {
    Some(_) => Expr::Apply(Expr::FunctionHead("Subs"), [expr, variable, value])
    None => {
      let variables = subs_items(variable)
      let values = subs_items(value)
      if values.is_empty() {
        expr
      } else {
        match expr {
          Expr::Subs(inner, inner_variable, inner_value) =>
            Expr::Subs(
              inner,
              subs_items_expr(subs_items(inner_variable) + variables),
              subs_items_expr(subs_items(inner_value) + values),
            )
          _ => Expr::Subs(expr, variable, value)
        }
      }
    }
  }
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
    Expr::Symbol(_) | Expr::Dummy(_, _) | Expr::Wild(_, _, _) => true
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
      Expr::Tuple(_)
      | Expr::Symbol(_)
      | Expr::Dummy(_, _)
      | Expr::Wild(_, _, _) => ()
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
      _ =>
        Some(
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
  let normalized_args = args.map(normalize_legacy_expr)
  match name {
    "True"
    | "False"
    | "Tuple"
    | "S"
    | "Integer"
    | "Rational"
    | "Float"
    | "Eq"
    | "Ne"
    | "Lt"
    | "Le"
    | "Gt"
    | "Ge"
    | "Mod"
    | "Derivative"
    | "Subs"
    | "Lambda"
    | "Dict" =>
      with_evaluate(true, fn() {
        with_distribute(true, fn() {
          with_exp_is_pow(false, fn() { function(name, normalized_args) })
        })
      })
    _ => Expr::Apply(Expr::FunctionHead(name), normalized_args)
  }
}

///|
/// Expose the structural view of an expression.
///
/// - Does: Converts `Expr` into its public structural discriminator.
/// - Input: Any `Expr`.
/// - Returns: An `ExprForm`.
/// - Limits: This is for branching and inspection, not a stable serialization
///   format.
pub fn expr_form(expr : Expr) -> ExprForm {
  match expr {
    Expr::Number(n) => ExprForm::Number(n)
    Expr::Float(f) => ExprForm::Float(f)
    Expr::ComplexFloat(z) => ExprForm::ComplexFloat(z)
    Expr::NumberSymbol(kind) => ExprForm::NumberSymbol(kind)
    Expr::Boolean(value) => ExprForm::Boolean(value)
    Expr::IdentityFunction => ExprForm::IdentityFunction
    Expr::Dummy(name, id) => ExprForm::Dummy(name, id)
    Expr::Wild(name, exclude, properties) =>
      ExprForm::Wild(name, exclude, properties)
    Expr::WildFunction(name, nargs) => ExprForm::WildFunction(name, nargs)
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
      raw_derivative(
        normalize_legacy_expr(inner),
        deriv_args.map(normalize_legacy_expr)[:],
      )
    Expr::Subs(inner, variable, value) =>
      subs_expr(
        normalize_legacy_expr(inner),
        normalize_legacy_expr(variable),
        normalize_legacy_expr(value),
      )
    Expr::Lambda(vars, body) =>
      lambda_expr(normalize_legacy_expr(vars), normalize_legacy_expr(body))
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
    | ExprForm::Wild(_, _, _)
    | ExprForm::WildFunction(_, _)
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
    ExprForm::Wild(name, _, _) => wild_display_name(name)
    ExprForm::WildFunction(name, _) => wild_display_name(name)
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
    Expr::Wild(name, _, _) | Expr::WildFunction(name, _) => Some(name)
    _ => None
  }
}

///|
pub fn wild_parts(expr : Expr) -> (String, Array[Expr], Array[WildProperty])? {
  match expr {
    Expr::Wild(name, exclude, properties) =>
      Some((name, exclude.copy(), properties.copy()))
    _ => None
  }
}

///|
pub fn wild_function_parts(expr : Expr) -> (String, Array[Int])? {
  match expr {
    Expr::WildFunction(name, nargs) => Some((name, nargs.copy()))
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
    ExprForm::WildFunction(name, _) => Some(name)
    _ => None
  }
}

///|
pub fn exact_number_kind(expr : Expr) -> ExactNumberKind? {
  match expr_form(expr) {
    ExprForm::Number(value) => Some(exact_number_kind_from_rational(value))
    _ => None
  }
}

///|
fn exact_number_kind_from_rational(
  value : @symnum.BigRational,
) -> ExactNumberKind {
  let half = @symnum.BigRational::from_ints(1, 2) catch {
    _ => abort("invalid half rational")
  }
  if value.is_zero() {
    ExactNumberKind::Zero
  } else if value.is_one() {
    ExactNumberKind::One
  } else if value.compare(@symnum.BigRational::from_int(-1)) == 0 {
    ExactNumberKind::NegativeOne
  } else if value.compare(half) == 0 {
    ExactNumberKind::Half
  } else if value.is_integral() {
    ExactNumberKind::Integer
  } else {
    ExactNumberKind::Rational
  }
}

///|
pub fn exact_number_head_name(kind : ExactNumberKind) -> String {
  match kind {
    ExactNumberKind::Zero => "Zero"
    ExactNumberKind::One => "One"
    ExactNumberKind::NegativeOne => "NegativeOne"
    ExactNumberKind::Half => "Half"
    ExactNumberKind::Integer => "Integer"
    ExactNumberKind::Rational => "Rational"
  }
}

///|
pub fn singleton_head(expr : Expr) -> Expr? {
  match expr_form(expr) {
    ExprForm::Number(value) =>
      Some(
        Expr::FunctionHead(
          exact_number_head_name(exact_number_kind_from_rational(value)),
        ),
      )
    ExprForm::NumberSymbol(kind) =>
      Some(Expr::FunctionHead(number_symbol_func_name(kind)))
    ExprForm::Boolean(value) =>
      Some(Expr::FunctionHead(boolean_func_name(value)))
    _ => None
  }
}

///|
pub fn exact_number_num_den(expr : Expr) -> (BigInt, BigInt)? {
  match expr_form(expr) {
    ExprForm::Number(value) => Some((value.numerator(), value.denominator()))
    _ => None
  }
}

///|
fn is_boolean_application_head(name : String) -> Bool {
  match name {
    "And"
    | "Or"
    | "Not"
    | "Xor"
    | "Nand"
    | "Nor"
    | "Implies"
    | "Equivalent"
    | "ITE" => true
    _ => false
  }
}

///|
fn application_kind(head : Expr, args : Array[Expr]) -> Kind {
  match function_head_name(head) {
    Some(name) =>
      if is_boolean_application_head(name) {
        Kind::BooleanKind
      } else {
        match name {
          "Tuple" => Kind::TupleKind(args.map(expr_kind))
          "Dict" | "Lambda" => Kind::UndefinedKind
          "Subs" | "Derivative" =>
            if args.is_empty() {
              Kind::UndefinedKind
            } else {
              expr_kind(args[0])
            }
          _ => Kind::NumberKind
        }
      }
    None => Kind::UndefinedKind
  }
}

///|
pub fn expr_kind(expr : Expr) -> Kind {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Boolean(_) | ExprForm::Relational(_, _, _) => Kind::BooleanKind
    ExprForm::Tuple(items) => Kind::TupleKind(items.map(expr_kind))
    ExprForm::Dict(_) => Kind::UndefinedKind
    ExprForm::FunctionHead(_)
    | ExprForm::UndefinedFunction(_)
    | ExprForm::IdentityFunction
    | ExprForm::Lambda(_, _) => Kind::UndefinedKind
    ExprForm::Number(_)
    | ExprForm::Float(_)
    | ExprForm::ComplexFloat(_)
    | ExprForm::NumberSymbol(_)
    | ExprForm::Symbol(_)
    | ExprForm::Dummy(_, _)
    | ExprForm::Wild(_, _, _) => Kind::NumberKind
    ExprForm::WildFunction(_, _) => Kind::UndefinedKind
    ExprForm::Apply(head, args) => application_kind(head, args)
    ExprForm::Add(items) | ExprForm::Mul(items) =>
      common_kind(items.map(expr_kind))
    ExprForm::Pow(base, exp) =>
      match expr_kind(exp) {
        Kind::NumberKind => expr_kind(base)
        _ => Kind::UndefinedKind
      }
    ExprForm::Mod(lhs, rhs) => common_kind([expr_kind(lhs), expr_kind(rhs)])
    ExprForm::Derivative(inner, _) | ExprForm::Subs(inner, _, _) =>
      expr_kind(inner)
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
          Some(
            Expr::FunctionHead(
              exact_number_head_name(exact_number_kind_from_rational(value)),
            ),
          )
        ExprForm::Float(_) => Some(Expr::FunctionHead("Float"))
        ExprForm::ComplexFloat(_) => Some(Expr::FunctionHead("ComplexFloat"))
        ExprForm::NumberSymbol(kind) =>
          Some(Expr::FunctionHead(number_symbol_func_name(kind)))
        ExprForm::Symbol(_) => Some(Expr::FunctionHead("Symbol"))
        ExprForm::Dummy(_, _) => Some(Expr::FunctionHead("Dummy"))
        ExprForm::Wild(_, _, _) => Some(Expr::FunctionHead("Wild"))
        ExprForm::WildFunction(_, _) => Some(Expr::FunctionHead("WildFunction"))
        ExprForm::IdentityFunction =>
          Some(Expr::FunctionHead("IdentityFunction"))
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
    | ExprForm::Wild(_, _, _)
    | ExprForm::WildFunction(_, _)
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
    Expr::Wild(name, _, _) => ignore(out.remove("wild:\{name}"))
    Expr::WildFunction(name, _) => ignore(out.remove("wildf:\{name}"))
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
    Expr::Wild(name, _, _) => {
      out.set("wild:\{name}", expr)
      return
    }
    Expr::WildFunction(name, _) => {
      out.set("wildf:\{name}", expr)
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
    | ExprForm::Wild(_, _, _)
    | ExprForm::WildFunction(_, _)
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
      let inner_symbols : Map[String, Expr] = {}
      free_symbol_map(inner, inner_symbols)
      remove_bound_symbol(inner_symbols, variable)
      for key, value0 in inner_symbols {
        out.set(key, value0)
      }
      free_symbol_map(value, out)
    }
    ExprForm::Lambda(vars, body) => {
      free_symbol_map(body, out)
      remove_bound_symbol(out, vars)
    }
  }
}

///|
fn exact_number_matches_head(
  kind : ExactNumberKind,
  needle_name : String,
) -> Bool {
  match kind {
    ExactNumberKind::Zero =>
      match needle_name {
        "Zero"
        | "Integer"
        | "Rational"
        | "Number"
        | "AtomicExpr"
        | "Atom"
        | "Expr"
        | "Basic" => true
        _ => false
      }
    ExactNumberKind::One =>
      match needle_name {
        "One"
        | "Integer"
        | "Rational"
        | "Number"
        | "AtomicExpr"
        | "Atom"
        | "Expr"
        | "Basic" => true
        _ => false
      }
    ExactNumberKind::NegativeOne =>
      match needle_name {
        "NegativeOne"
        | "Integer"
        | "Rational"
        | "Number"
        | "AtomicExpr"
        | "Atom"
        | "Expr"
        | "Basic" => true
        _ => false
      }
    ExactNumberKind::Half =>
      match needle_name {
        "Half"
        | "Rational"
        | "Number"
        | "AtomicExpr"
        | "Atom"
        | "Expr"
        | "Basic" => true
        _ => false
      }
    ExactNumberKind::Integer =>
      match needle_name {
        "Integer"
        | "Rational"
        | "Number"
        | "AtomicExpr"
        | "Atom"
        | "Expr"
        | "Basic" => true
        _ => false
      }
    ExactNumberKind::Rational =>
      match needle_name {
        "Rational" | "Number" | "AtomicExpr" | "Atom" | "Expr" | "Basic" => true
        _ => false
      }
  }
}

///|
fn expr_matches_class_head(expr : Expr, needle_name : String) -> Bool {
  let expr = normalize_legacy_expr(expr)
  match expr_form(expr) {
    ExprForm::Number(value) =>
      exact_number_matches_head(
        exact_number_kind_from_rational(value),
        needle_name,
      )
    ExprForm::Float(_) =>
      match needle_name {
        "Float" | "Number" | "AtomicExpr" | "Atom" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::ComplexFloat(_) =>
      match needle_name {
        "ComplexFloat" | "Number" | "AtomicExpr" | "Atom" | "Expr" | "Basic" =>
          true
        _ => false
      }
    ExprForm::NumberSymbol(_) =>
      match needle_name {
        "NumberSymbol" | "Number" | "AtomicExpr" | "Atom" | "Expr" | "Basic" =>
          true
        _ => false
      }
    ExprForm::Symbol(_) =>
      match needle_name {
        "Symbol" | "AtomicExpr" | "Atom" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Dummy(_, _) =>
      match needle_name {
        "Dummy" | "Symbol" | "AtomicExpr" | "Atom" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Wild(_, _, _) =>
      match needle_name {
        "Wild" | "Symbol" | "AtomicExpr" | "Atom" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::WildFunction(_, _) =>
      match needle_name {
        "WildFunction" | "Basic" => true
        _ => false
      }
    ExprForm::FunctionHead(_) =>
      match needle_name {
        "FunctionClass" | "Basic" => true
        _ => false
      }
    ExprForm::UndefinedFunction(_) =>
      match needle_name {
        "UndefinedFunction" | "FunctionClass" | "Basic" => true
        _ => false
      }
    ExprForm::IdentityFunction =>
      match needle_name {
        "IdentityFunction" | "FunctionClass" | "Basic" => true
        _ => false
      }
    ExprForm::Boolean(_) =>
      match needle_name {
        "Boolean" | "Basic" => true
        _ => false
      }
    ExprForm::Add(_) =>
      match needle_name {
        "Add" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Mul(_) =>
      match needle_name {
        "Mul" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Pow(_, _) =>
      match needle_name {
        "Pow" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Mod(_, _) =>
      match needle_name {
        "Mod" | "Function" | "Application" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Tuple(_) =>
      match needle_name {
        "Tuple" | "Basic" => true
        _ => false
      }
    ExprForm::Dict(_) =>
      match needle_name {
        "Dict" | "Basic" => true
        _ => false
      }
    ExprForm::Relational(_, _, _) =>
      match needle_name {
        "Relational" | "Boolean" | "Basic" => true
        _ => false
      }
    ExprForm::Derivative(_, _) =>
      match needle_name {
        "Derivative" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Subs(_, _, _) =>
      match needle_name {
        "Subs" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Lambda(_, _) =>
      match needle_name {
        "Lambda" | "Expr" | "Basic" => true
        _ => false
      }
    ExprForm::Apply(_, _) =>
      match needle_name {
        "Function" | "Application" | "Expr" | "Basic" => true
        _ => false
      }
  }
}

///|
fn contains_commutative_subexpr(
  expr_items : Array[Expr],
  needle_items : Array[Expr],
) -> Bool {
  let remaining = expr_items.copy()
  for needle_item in needle_items {
    let mut found = false
    for i in 0..<remaining.length() {
      if remaining[i] == needle_item {
        ignore(remaining.remove(i))
        found = true
        break
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
fn has_matcher(expr : Expr, needle : Expr) -> Bool {
  let expr = normalize_legacy_expr(expr)
  let needle = normalize_legacy_expr(needle)
  match (expr_form(expr), expr_form(needle)) {
    (ExprForm::Add(expr_items), ExprForm::Add(needle_items)) =>
      contains_commutative_subexpr(expr_items, needle_items)
    (ExprForm::Mul(expr_items), ExprForm::Mul(needle_items)) =>
      contains_commutative_subexpr(expr_items, needle_items)
    _ => false
  }
}

///|
/// Collect the free symbolic variables occurring in an expression.
///
/// - Does: Walks an expression and extracts its free symbols.
/// - Input: Any `Expr`.
/// - Returns: `Array[Expr]`, typically containing `Expr::Symbol` items.
/// - Limits: The order is canonicalized rather than source-order oriented.
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
  let expr = normalize_legacy_expr(expr)
  let needle = normalize_legacy_expr(needle)
  if expr == needle {
    return true
  }
  match needle {
    Expr::FunctionHead(name) if expr_matches_class_head(expr, name) =>
      return true
    _ => ()
  }
  match func(expr) {
    Some(head) if head == needle => return true
    _ => ()
  }
  if has_matcher(expr, needle) {
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
