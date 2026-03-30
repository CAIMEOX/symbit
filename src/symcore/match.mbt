///|
pub type MatchEnv = Map[Expr, Expr]

///|
fn clone_match_env(env : MatchEnv) -> MatchEnv {
  let out : MatchEnv = {}
  for key, value in env {
    out.set(key, value)
  }
  out
}

///|
fn exact_number_sign(value : @symnum.BigRational) -> Int {
  value.numerator().compare(0N)
}

///|
fn wild_property_matches(property : WildProperty, expr : Expr) -> Bool {
  let expr = normalize_legacy_expr(expr)
  match property {
    WildProperty::Integer =>
      match expr_form(expr) {
        ExprForm::Number(value) => value.is_integral()
        _ => false
      }
    WildProperty::Rational =>
      match expr_form(expr) {
        ExprForm::Number(_) => true
        _ => false
      }
    WildProperty::Real => is_real_number_atom(expr)
    WildProperty::Positive =>
      match expr_form(expr) {
        ExprForm::Number(value) => exact_number_sign(value) > 0
        ExprForm::NumberSymbol(kind) =>
          match kind {
            NumberSymbolKind::Pi
            | NumberSymbolKind::Exp1
            | NumberSymbolKind::EulerGamma
            | NumberSymbolKind::GoldenRatio
            | NumberSymbolKind::Catalan
            | NumberSymbolKind::Infinity => true
            _ => false
          }
        _ => false
      }
    WildProperty::Negative =>
      match expr_form(expr) {
        ExprForm::Number(value) => exact_number_sign(value) < 0
        ExprForm::NumberSymbol(NumberSymbolKind::NegativeInfinity) => true
        _ => false
      }
    WildProperty::Finite => is_finite_number_atom(expr)
    WildProperty::Nonzero =>
      match expr_form(expr) {
        ExprForm::Number(value) => !value.is_zero()
        ExprForm::NumberSymbol(kind) =>
          match kind {
            NumberSymbolKind::Pi
            | NumberSymbolKind::Exp1
            | NumberSymbolKind::EulerGamma
            | NumberSymbolKind::GoldenRatio
            | NumberSymbolKind::Catalan
            | NumberSymbolKind::Infinity
            | NumberSymbolKind::NegativeInfinity
            | NumberSymbolKind::ComplexInfinity => true
            _ => false
          }
        _ => false
      }
  }
}

///|
pub fn wild_matches(
  pattern : Expr,
  expr : Expr,
  repl_dict? : MatchEnv = {},
) -> MatchEnv? {
  let pattern = normalize_legacy_expr(pattern)
  let expr = normalize_legacy_expr(expr)
  match pattern {
    Expr::Wild(_, exclude, properties) => {
      for item in exclude {
        if has(expr, item) {
          return None
        }
      }
      for property in properties {
        if !wild_property_matches(property, expr) {
          return None
        }
      }
      match repl_dict.get(pattern) {
        Some(existing) =>
          if existing == expr {
            Some(clone_match_env(repl_dict))
          } else {
            None
          }
        None => {
          let out = clone_match_env(repl_dict)
          out.set(pattern, expr)
          Some(out)
        }
      }
    }
    _ => None
  }
}

///|
pub fn expr_match(
  pattern : Expr,
  expr : Expr,
  repl_dict? : MatchEnv = {},
) -> MatchEnv? {
  let pattern = normalize_legacy_expr(pattern)
  let expr = normalize_legacy_expr(expr)
  match wild_matches(pattern, expr, repl_dict=repl_dict) {
    Some(result) => return Some(result)
    None => ()
  }
  if pattern == expr {
    return Some(clone_match_env(repl_dict))
  }
  if is_atomic(pattern) || is_atomic(expr) {
    return None
  }
  let pattern_args = args(pattern)
  let expr_args = args(expr)
  if pattern_args.length() != expr_args.length() {
    return None
  }
  let pattern_func = match func(pattern) {
    Some(value) => value
    None => return None
  }
  let expr_func = match func(expr) {
    Some(value) => value
    None => return None
  }
  let mut current = match expr_match(
    pattern_func,
    expr_func,
    repl_dict=repl_dict,
  ) {
    Some(value) => value
    None => return None
  }
  for i in 0..<pattern_args.length() {
    match expr_match(pattern_args[i], expr_args[i], repl_dict=current) {
      Some(value) => current = value
      None => return None
    }
  }
  Some(current)
}
