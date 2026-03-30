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
    Expr::Wild(_, _, _) | Expr::WildFunction(_, _) => true
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
fn common_add_wild_factor(items : Array[Expr]) -> (Expr, Array[Expr])? {
  let mut common : Expr? = None
  let remainders : Array[Expr] = []
  for item in items {
    match item {
      Expr::Mul(factors) => {
        let wild_factors : Array[Expr] = []
        let plain_factors : Array[Expr] = []
        for factor in factors {
          if expr_contains_wild(factor) {
            wild_factors.push(factor)
          } else {
            plain_factors.push(factor)
          }
        }
        guard wild_factors.length() == 1 else { return None }
        let factor = wild_factors[0]
        match common {
          Some(existing) if compare_expr(existing, factor) != 0 => return None
          Some(_) => ()
          None => common = Some(factor)
        }
        remainders.push(combine_commutative_items(plain_factors, false))
      }
      _ if expr_contains_wild(item) => {
        match common {
          Some(existing) if compare_expr(existing, item) != 0 => return None
          Some(_) => ()
          None => common = Some(item)
        }
        remainders.push(int(1))
      }
      _ => return None
    }
  }
  common.map(factor => (factor, remainders))
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
  let wild_priority = fn(expr : Expr) -> Int {
    match normalize_legacy_expr(expr) {
      Expr::Apply(Expr::WildFunction(_, _), _) => 0
      Expr::WildFunction(_, _) => 1
      Expr::Wild(_, _, _) => 3
      _ => 2
    }
  }
  for item in pattern_items {
    if expr_contains_wild(item) {
      wild_items.push(item)
    } else {
      exact_items.push(item)
    }
  }
  wild_items.sort_by((lhs, rhs) => {
    cmp_int(wild_priority(lhs), wild_priority(rhs))
  })
  if is_add && wild_items.length() == 1 {
    let remainder = match
      remove_exact_commutative_items(exact_items, expr_items) {
      Some(items) => combine_commutative_items(items, true)
      None =>
        match exact_items.length() {
          0 => combine_commutative_items(expr_items, true)
          _ =>
            add([
              combine_commutative_items(expr_items, true),
              mul([int(-1), combine_commutative_items(exact_items, true)]),
            ])
        }
    }
    return expr_match(wild_items[0], remainder, repl_dict~)
  }
  let remaining_expr = match
    remove_exact_commutative_items(exact_items, expr_items) {
    Some(items) => items
    None => return None
  }
  if wild_items.is_empty() {
    return if remaining_expr.is_empty() {
      Some(clone_match_env(repl_dict))
    } else {
      None
    }
  }
  letrec go = (
    remaining_patterns : Array[Expr],
    remaining_items : Array[Expr],
    env : MatchEnv,
  ) => {
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
            let (selected, leftover) = split_items_by_mask(
              remaining_items, mask,
            )
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
fn insert_monomial_exponent(
  parts : Array[(Expr, BigInt)],
  base : Expr,
  exponent : BigInt,
) -> Unit {
  if exponent.compare(0N) == 0 {
    return
  }
  for i in 0..<parts.length() {
    let (existing_base, existing_exp) = parts[i]
    if compare_expr(existing_base, base) == 0 {
      let updated = existing_exp + exponent
      if updated.compare(0N) == 0 {
        ignore(parts.remove(i))
      } else {
        parts[i] = (existing_base, updated)
      }
      return
    }
  }
  parts.push((base, exponent))
}

///|
fn exact_rational_pow(
  base : @symnum.BigRational,
  exponent : BigInt,
) -> @symnum.BigRational? {
  if exponent.compare(0N) == 0 {
    return Some(@symnum.BigRational::one())
  }
  let mut power = exponent
  let mut base_value = base
  if power.compare(0N) < 0 {
    power = power.neg()
    base_value = base.reciprocal() catch { _ => return None }
  }
  let mut acc = @symnum.BigRational::one()
  while power.compare(0N) > 0 {
    if power.mod(2N).compare(0N) != 0 {
      acc = acc.mul_r(base_value)
    }
    power = power.div(2N)
    if power.compare(0N) > 0 {
      base_value = base_value.mul_r(base_value)
    }
  }
  Some(acc)
}

///|
fn monomial_parts(expr : Expr) -> (@symnum.BigRational, Array[(Expr, BigInt)])? {
  let mut coeff = @symnum.BigRational::one()
  let factors : Array[(Expr, BigInt)] = []
  let merge = fn(term : Expr, exponent : BigInt) -> Bool {
    match exact_numeric_expr_to_rational(term) {
      Some(value) =>
        match exact_rational_pow(value, exponent) {
          Some(powered) => {
            coeff = coeff.mul_r(powered)
            true
          }
          None => false
        }
      None => {
        insert_monomial_exponent(factors, term, exponent)
        true
      }
    }
  }
  letrec go = (term : Expr) => {
    match normalize_legacy_expr(term) {
      Expr::Mul(items) => {
        for item in items {
          if !go(item) {
            return false
          }
        }
        true
      }
      Expr::Pow(base, exp) =>
        match exact_numeric_expr_to_rational(exp) {
          Some(value) if value.is_integral() => merge(base, value.numerator())
          _ => false
        }
      other => merge(other, 1N)
    }
  }
  if !go(normalize_legacy_expr(expr)) {
    return None
  }
  Some((coeff, factors))
}

///|
fn monomial_expr(
  coeff : @symnum.BigRational,
  factors : Array[(Expr, BigInt)],
) -> Expr {
  let items : Array[Expr] = []
  if coeff.compare(@symnum.BigRational::one()) != 0 || factors.is_empty() {
    items.push(Expr::Number(coeff))
  }
  let ordered = factors.copy()
  ordered.sort_by((lhs, rhs) => compare_expr(lhs.0, rhs.0))
  for factor in ordered {
    let (base, exponent) = factor
    if exponent.compare(1N) == 0 {
      items.push(base)
    } else {
      items.push(
        pow(base, Expr::Number(@symnum.BigRational::from_bigint(exponent))),
      )
    }
  }
  combine_commutative_items(items, false)
}

///|
fn divide_monomial_expr(expr : Expr, factor : Expr) -> Expr? {
  match (monomial_parts(expr), monomial_parts(factor)) {
    (Some((expr_coeff, expr_factors)), Some((factor_coeff, factor_factors))) =>
      if factor_coeff.is_zero() {
        None
      } else {
        let quotient_coeff = expr_coeff.div_r(factor_coeff) catch {
          _ => return None
        }
        let quotient_factors = expr_factors.copy()
        for factor_item in factor_factors {
          let (base, exponent) = factor_item
          insert_monomial_exponent(quotient_factors, base, exponent.neg())
        }
        Some(monomial_expr(quotient_coeff, quotient_factors))
      }
    _ => None
  }
}

///|
fn divide_add_by_exact_template(
  expr_items : Array[Expr],
  factor_items : Array[Expr],
) -> Expr? {
  if expr_items.length() != factor_items.length() {
    return None
  }
  letrec go = (
    remaining_expr : Array[Expr],
    remaining_factor : Array[Expr],
    quotient : Expr?,
  ) => {
    if remaining_factor.is_empty() {
      return quotient
    }
    let factor_term = remaining_factor[0]
    let rest_factor = remaining_factor[1:].to_array()
    for i in 0..<remaining_expr.length() {
      let expr_term = remaining_expr[i]
      match divide_monomial_expr(expr_term, factor_term) {
        Some(candidate) => {
          if quotient is Some(existing) &&
            compare_expr(existing, candidate) != 0 {
            continue
          }
          let leftover = remaining_expr.copy()
          ignore(leftover.remove(i))
          match go(leftover, rest_factor, Some(candidate)) {
            Some(done) => return Some(done)
            None => ()
          }
        }
        None => ()
      }
    }
    None
  }
  go(expr_items, factor_items, None)
}

///|
fn divide_expr_by_exact_factor(expr : Expr, factor : Expr) -> Expr? {
  let expr = normalize_legacy_expr(expr)
  let factor = normalize_legacy_expr(factor)
  if is_one(factor) {
    return Some(expr)
  }
  if compare_expr(expr, factor) == 0 {
    return Some(int(1))
  }
  match (expr, factor) {
    (Expr::Add(expr_items), Expr::Add(factor_items)) =>
      divide_add_by_exact_template(expr_items, factor_items)
    _ => divide_monomial_expr(expr, factor)
  }
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
    WildProperty::Symbol =>
      match expr_form(expr) {
        ExprForm::Symbol(_) | ExprForm::Dummy(_, _) | ExprForm::Wild(_, _, _) =>
          true
        _ => false
      }
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
fn wild_function_matches_arity(nargs : Array[Int], arity : Int) -> Bool {
  nargs.is_empty() || nargs.contains(arity)
}

///|
pub fn wild_function_matches(
  pattern : Expr,
  expr : Expr,
  repl_dict? : MatchEnv = {},
) -> MatchEnv? {
  let pattern = normalize_legacy_expr(pattern)
  let expr = normalize_legacy_expr(expr)
  match pattern {
    Expr::WildFunction(_, nargs) =>
      match expr {
        Expr::WildFunction(_, _) => {
          let out = clone_match_env(repl_dict)
          out.set(pattern, expr)
          Some(out)
        }
        Expr::Apply(_, args) if wild_function_matches_arity(
            nargs,
            args.length(),
          ) => {
          let out = clone_match_env(repl_dict)
          out.set(pattern, expr)
          Some(out)
        }
        _ => None
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
  match wild_matches(pattern, expr, repl_dict~) {
    Some(result) => return Some(result)
    None => ()
  }
  match wild_function_matches(pattern, expr, repl_dict~) {
    Some(result) => return Some(result)
    None => ()
  }
  if pattern == expr {
    return Some(clone_match_env(repl_dict))
  }
  match pattern {
    Expr::Apply(Expr::WildFunction(name, nargs), pattern_args) =>
      match expr {
        Expr::Apply(expr_head, expr_args) =>
          if wild_function_matches_arity(nargs, expr_args.length()) &&
            pattern_args.length() == expr_args.length() {
            let wild_fn = Expr::WildFunction(name, nargs)
            let mut current = clone_match_env(repl_dict)
            match current.get(wild_fn) {
              Some(existing) =>
                if compare_expr(existing, expr_head) != 0 {
                  return None
                }
              None => current.set(wild_fn, expr_head)
            }
            for i in 0..<pattern_args.length() {
              let substituted_pattern = xreplace(
                pattern_args[i],
                match_env_rules(current),
              )
              match
                expr_match(substituted_pattern, expr_args[i], repl_dict=current) {
                Some(value) => current = value
                None => return None
              }
            }
            return Some(current)
          }
        _ => ()
      }
    _ => ()
  }
  match pattern {
    Expr::Add(pattern_items) => {
      match common_add_wild_factor(pattern_items) {
        Some((factor, remainders)) =>
          match
            expr_match(
              mul([factor, combine_commutative_items(remainders, true)]),
              expr,
              repl_dict~,
            ) {
            Some(result) => return Some(result)
            None => ()
          }
        None => ()
      }
      match expr {
        Expr::Add(_) => ()
        _ => return expr_match(pattern, Expr::Add([expr]), repl_dict~)
      }
    }
    Expr::Mul(pattern_items) if is_zero(expr) => {
      let wild_items : Array[Expr] = []
      for item in pattern_items {
        if expr_contains_wild(item) {
          wild_items.push(item)
        }
      }
      if !wild_items.is_empty() {
        return expr_match(
          combine_commutative_items(wild_items, false),
          int(0),
          repl_dict~,
        )
      }
    }
    Expr::Mul(pattern_items) => {
      let exact_items : Array[Expr] = []
      let wild_items : Array[Expr] = []
      for item in pattern_items {
        if expr_contains_wild(item) {
          wild_items.push(item)
        } else {
          exact_items.push(item)
        }
      }
      if wild_items.length() == 1 && !exact_items.is_empty() {
        match
          divide_expr_by_exact_factor(
            expr,
            combine_commutative_items(exact_items, false),
          ) {
          Some(quotient) =>
            match expr_match(wild_items[0], quotient, repl_dict~) {
              Some(result) => return Some(result)
              None => ()
            }
          None => ()
        }
      }
    }
    Expr::Pow(base, exp) if is_one(expr) && !expr_contains_wild(base) =>
      return expr_match(exp, int(0), repl_dict~)
    _ => ()
  }
  match pattern {
    Expr::Mul(_) =>
      match expr {
        Expr::Mul(_) => ()
        _ => return expr_match(pattern, Expr::Mul([int(1), expr]), repl_dict~)
      }
    _ => ()
  }
  match (pattern, expr) {
    (Expr::Add(pattern_items), Expr::Add(expr_items)) =>
      return match_commutative_items(pattern_items, expr_items, true, repl_dict)
    (Expr::Mul(pattern_items), Expr::Mul(expr_items)) =>
      return match_commutative_items(
        pattern_items, expr_items, false, repl_dict,
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
  let mut current = match expr_match(pattern_func, expr_func, repl_dict~) {
    Some(value) => value
    None => return None
  }
  for i in 0..<pattern_args.length() {
    let substituted_pattern = xreplace(
      pattern_args[i],
      match_env_rules(current),
    )
    match expr_match(substituted_pattern, expr_args[i], repl_dict=current) {
      Some(value) => current = value
      None => return None
    }
  }
  Some(current)
}
