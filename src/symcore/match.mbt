///|
pub type MatchEnv = Map[Expr, Expr]

///|
pub type WildPropertyResolver = (WildProperty, Expr) -> Bool?

///|
let wild_property_resolver_ref : Ref[WildPropertyResolver?] = { val: None }

///|
pub fn set_wild_property_resolver(resolver : WildPropertyResolver) -> Unit {
  wild_property_resolver_ref.val = Some(resolver)
}

///|
pub fn clear_wild_property_resolver() -> Unit {
  wild_property_resolver_ref.val = None
}

///|
fn clone_match_env(env : MatchEnv) -> MatchEnv {
  let out : MatchEnv = {}
  for key, value in env {
    out.set(key, value)
  }
  out
}

///|
fn match_env_rules(env : MatchEnv) -> Array[(Expr, Expr)] {
  let out : Array[(Expr, Expr)] = []
  for key, value in env {
    out.push((key, value))
  }
  out
}

///|
fn expr_contains_wild(expr : Expr) -> Bool {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Expr::Wild(_, _, _) => true
    _ => {
      for child in args(expr) {
        if expr_contains_wild(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn combine_commutative_items(items : Array[Expr], is_add : Bool) -> Expr {
  match items.length() {
    0 => if is_add { int(0) } else { int(1) }
    1 => items[0]
    _ => if is_add { add(items) } else { mul(items) }
  }
}

///|
fn remove_exact_commutative_items(
  exact_items : Array[Expr],
  expr_items : Array[Expr],
) -> Array[Expr]? {
  let remaining = expr_items.copy()
  for exact in exact_items {
    let mut found = false
    for i in 0..<remaining.length() {
      if remaining[i] == exact {
        ignore(remaining.remove(i))
        found = true
        break
      }
    }
    if !found {
      return None
    }
  }
  Some(remaining)
}

///|
fn split_items_by_mask(
  items : Array[Expr],
  mask : Int,
) -> (Array[Expr], Array[Expr]) {
  let selected : Array[Expr] = []
  let remaining : Array[Expr] = []
  for i in 0..<items.length() {
    if mask.land(1 << i) != 0 {
      selected.push(items[i])
    } else {
      remaining.push(items[i])
    }
  }
  (selected, remaining)
}

///|
fn match_commutative_items(
  pattern_items : Array[Expr],
  expr_items : Array[Expr],
  is_add : Bool,
  repl_dict : MatchEnv,
) -> MatchEnv? {
  let exact_items : Array[Expr] = []
  let wild_items : Array[Expr] = []
  for item in pattern_items {
    if expr_contains_wild(item) {
      wild_items.push(item)
    } else {
      exact_items.push(item)
    }
  }
  let remaining_expr = match remove_exact_commutative_items(exact_items, expr_items) {
    Some(items) => items
    None => return None
  }
  if wild_items.is_empty() {
    return if remaining_expr.is_empty() { Some(clone_match_env(repl_dict)) } else { None }
  }
  letrec go = (remaining_patterns : Array[Expr], remaining_items : Array[Expr], env : MatchEnv) => {
    match remaining_patterns.length() {
      0 => if remaining_items.is_empty() { Some(env) } else { None }
      1 =>
        expr_match(
          remaining_patterns[0],
          combine_commutative_items(remaining_items, is_add),
          repl_dict=env,
        )
      _ => {
        let current = remaining_patterns[0]
        let rest = remaining_patterns[1:].to_array()
        let max_mask = 1 << remaining_items.length()
        for empty_last in [false, true] {
          for mask in 0..<max_mask {
            if (mask == 0) != empty_last {
              continue
            }
            let (selected, leftover) = split_items_by_mask(remaining_items, mask)
            let candidate = combine_commutative_items(selected, is_add)
            match expr_match(current, candidate, repl_dict=env) {
              Some(next_env) =>
                match go(rest, leftover, next_env) {
                  Some(done) => return Some(done)
                  None => ()
                }
              None => ()
            }
          }
        }
        None
      }
    }
  }
  go(wild_items, remaining_expr, clone_match_env(repl_dict))
}

///|
fn exact_number_sign(value : @symnum.BigRational) -> Int {
  value.numerator().compare(0N)
}

///|
fn resolve_wild_property(property : WildProperty, expr : Expr) -> Bool? {
  match wild_property_resolver_ref.val {
    Some(resolver) => resolver(property, expr)
    None => None
  }
}

///|
fn wild_property_matches(property : WildProperty, expr : Expr) -> Bool {
  let expr = normalize_legacy_expr(expr)
  match resolve_wild_property(property, expr) {
    Some(value) => return value
    None => ()
  }
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
      let out = clone_match_env(repl_dict)
      out.set(pattern, expr)
      Some(out)
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
  match pattern {
    Expr::Pow(base, exp) if is_one(expr) && !expr_contains_wild(base) =>
      return expr_match(exp, int(0), repl_dict=repl_dict)
    _ => ()
  }
  match pattern {
    Expr::Mul(_) =>
      match expr {
        Expr::Mul(_) => ()
        _ => return expr_match(pattern, Expr::Mul([int(1), expr]), repl_dict=repl_dict)
      }
    _ => ()
  }
  match (pattern, expr) {
    (Expr::Add(pattern_items), Expr::Add(expr_items)) =>
      return match_commutative_items(
        pattern_items,
        expr_items,
        true,
        repl_dict,
      )
    (Expr::Mul(pattern_items), Expr::Mul(expr_items)) =>
      return match_commutative_items(
        pattern_items,
        expr_items,
        false,
        repl_dict,
      )
    _ => ()
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
    let substituted_pattern = xreplace(pattern_args[i], match_env_rules(current))
    match expr_match(substituted_pattern, expr_args[i], repl_dict=current) {
      Some(value) => current = value
      None => return None
    }
  }
  Some(current)
}
