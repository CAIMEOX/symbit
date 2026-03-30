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
fn match_count_ops(expr : Expr) -> Int {
  match normalize_legacy_expr(expr) {
    Expr::Add(items) => {
      let mut count = if items.is_empty() { 0 } else { items.length() - 1 }
      for item in items {
        count += match_count_ops(item)
      }
      count
    }
    Expr::Mul(items) =>
      match split_fraction_for_match(Expr::Mul(items)) {
        Some((numerator, denominator)) => {
          let numerator_is_exact_integer = match numerator {
            Expr::Number(value) => value.is_integral()
            _ => false
          }
          if is_one(denominator) {
            let mut count = if items.is_empty() { 0 } else { items.length() - 1 }
            for item in items {
              count += match_count_ops(item)
            }
            count
          } else if numerator_is_exact_integer {
            1 + match_count_ops(denominator)
          } else {
            1 + match_count_ops(numerator) + match_count_ops(denominator)
          }
        }
        None => {
          let mut count = if items.is_empty() { 0 } else { items.length() - 1 }
          for item in items {
            count += match_count_ops(item)
          }
          count
        }
      }
    Expr::Pow(base, exp) =>
      match exact_integer_value(exp) {
        Some(value) if value.compare(-1N) == 0 => 1 + match_count_ops(base)
        _ => 1 + match_count_ops(base) + match_count_ops(exp)
      }
    Expr::Mod(lhs, rhs) =>
      1 + match_count_ops(lhs) + match_count_ops(rhs)
    Expr::Apply(head, args) => {
      let mut count = 1 + match_count_ops(head)
      for arg in args {
        count += match_count_ops(arg)
      }
      count
    }
    Expr::Tuple(items) => {
      let mut count = 0
      for item in items {
        count += match_count_ops(item)
      }
      count
    }
    Expr::Dict(items) => {
      let mut count = 0
      for item in items {
        let (key, value) = item
        count += match_count_ops(key) + match_count_ops(value)
      }
      count
    }
    Expr::Relational(_, lhs, rhs) =>
      1 + match_count_ops(lhs) + match_count_ops(rhs)
    Expr::Derivative(inner, deriv_args) => {
      let mut count = 1 + match_count_ops(inner)
      for arg in deriv_args {
        count += match_count_ops(arg)
      }
      count
    }
    Expr::Subs(inner, variable, value) =>
      1 + match_count_ops(inner) + match_count_ops(variable) +
      match_count_ops(value)
    Expr::Lambda(vars, body) =>
      1 + match_count_ops(vars) + match_count_ops(body)
    _ => 0
  }
}

///|
fn split_fraction_for_match(expr : Expr) -> (Expr, Expr)? {
  let expr = normalize_legacy_expr(expr)
  let numer_items : Array[Expr] = []
  let denom_items : Array[Expr] = []
  let mut coeff = @symnum.BigRational::one()
  let push_power = fn(items : Array[Expr], base : Expr, exponent : BigInt) {
    if exponent.compare(1N) == 0 {
      items.push(base)
    } else {
      items.push(pow(base, Expr::Number(@symnum.BigRational::from_bigint(exponent))))
    }
  }
  let push_term = fn(term : Expr, sign : Int) -> Bool {
    match normalize_legacy_expr(term) {
      Expr::Number(value) => {
        coeff =
          if sign >= 0 {
            coeff.mul_r(value)
          } else {
            coeff.div_r(value) catch { _ => return false }
          }
        true
      }
      Expr::Pow(base, exp) =>
        match exact_integer_value(exp) {
          Some(value) if value.compare(0N) < 0 =>
            {
              if sign >= 0 {
                push_power(denom_items, base, value.neg())
              } else {
                push_power(numer_items, base, value.neg())
              }
              true
            }
          Some(value) =>
            {
              if sign >= 0 {
                push_power(numer_items, base, value)
              } else {
                push_power(denom_items, base, value)
              }
              true
            }
          None => {
            if sign >= 0 {
              numer_items.push(term)
            } else {
              denom_items.push(term)
            }
            true
          }
        }
      other => {
        if sign >= 0 {
          numer_items.push(other)
        } else {
          denom_items.push(other)
        }
        true
      }
    }
  }
  match expr {
    Expr::Mul(items) => {
      for item in items {
        if !push_term(item, 1) {
          return None
        }
      }
    }
    Expr::Pow(_, _) | Expr::Number(_) => {
      if !push_term(expr, 1) {
        return None
      }
    }
    _ => return None
  }
  if coeff.denominator().compare(1N) != 0 {
    denom_items.push(Expr::Number(@symnum.BigRational::from_bigint(coeff.denominator())))
  }
  if coeff.numerator().compare(1N) != 0 || numer_items.is_empty() {
    numer_items.insert(0, Expr::Number(@symnum.BigRational::from_bigint(coeff.numerator())))
  }
  Some((
    combine_commutative_items(numer_items, false),
    combine_commutative_items(denom_items, false),
  ))
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
fn is_plain_pattern_wild(expr : Expr) -> Bool {
  match normalize_legacy_expr(expr) {
    Expr::Wild(_, _, _) | Expr::WildFunction(_, _) => true
    _ => false
  }
}

///|
fn expr_shape_rank(expr : Expr) -> Int {
  match normalize_legacy_expr(expr) {
    Expr::Add(_) => 0
    Expr::Mul(_) => 1
    Expr::Pow(_, _) => 2
    Expr::Mod(_, _) => 3
    Expr::Apply(_, _) => 4
    Expr::Tuple(_) => 5
    Expr::Dict(_) => 6
    Expr::Relational(_, _, _) => 7
    Expr::Derivative(_, _) => 8
    Expr::Subs(_, _, _) => 9
    Expr::Lambda(_, _) => 10
    Expr::Number(_) | Expr::Float(_) | Expr::ComplexFloat(_) => 11
    Expr::NumberSymbol(_) => 12
    Expr::Symbol(_) | Expr::Dummy(_, _) => 13
    Expr::Wild(_, _, _) | Expr::WildFunction(_, _) => 14
    Expr::Boolean(_) => 15
    Expr::FunctionHead(_)
    | Expr::UndefinedFunction(_)
    | Expr::IdentityFunction => 16
    Expr::Function(_, _) => 17
  }
}

///|
fn mask_selected_count(mask : Int, length : Int) -> Int {
  let mut out = 0
  for i in 0..<length {
    if mask.land(1 << i) != 0 {
      out += 1
    }
  }
  out
}

///|
fn commutative_mask_score(
  pattern : Expr,
  remaining_patterns_len : Int,
  remaining_items : Array[Expr],
  is_add : Bool,
  mask : Int,
) -> Int {
  let selected_count = mask_selected_count(mask, remaining_items.length())
  if !is_add &&
    is_plain_pattern_wild(pattern) &&
    remaining_items.length() < remaining_patterns_len {
    return if selected_count == 0 { 0 } else { 1000 + selected_count }
  }
  let (selected, _) = split_items_by_mask(remaining_items, mask)
  let candidate = combine_commutative_items(selected, is_add)
  let pattern_rank = expr_shape_rank(pattern)
  let candidate_rank = expr_shape_rank(candidate)
  let shape_penalty = if pattern_rank == candidate_rank { 0 } else { 100 }
  let empty_penalty = if selected_count == 0 { 10000 } else { 0 }
  shape_penalty + empty_penalty + selected_count
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
    let expr_sum = combine_commutative_items(expr_items, true)
    let remainder = match
      remove_exact_commutative_items(exact_items, expr_items) {
      Some(items) => combine_commutative_items(items, true)
      None =>
        match exact_items.length() {
          0 => expr_sum
          _ =>
            add([
              expr_sum,
              mul([int(-1), combine_commutative_items(exact_items, true)]),
            ])
        }
    }
    if exact_items.length() > 0 && match_count_ops(remainder) > match_count_ops(expr_sum) {
      return None
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
        let masks : Array[Int] = []
        let max_mask = 1 << remaining_items.length()
        for mask in 0..<max_mask {
          masks.push(mask)
        }
        masks.sort_by((lhs, rhs) => {
          let lhs_score = commutative_mask_score(
            current,
            remaining_patterns.length(),
            remaining_items,
            is_add,
            lhs,
          )
          let rhs_score = commutative_mask_score(
            current,
            remaining_patterns.length(),
            remaining_items,
            is_add,
            rhs,
          )
          cmp_int(lhs_score, rhs_score)
        })
        for mask in masks {
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
fn is_exact_negative_one(expr : Expr) -> Bool {
  match expr_form(expr) {
    ExprForm::Number(value) =>
      value.compare(@symnum.BigRational::from_int(-1)) == 0
    _ => false
  }
}

///|
fn exact_integer_value(expr : Expr) -> BigInt? {
  match expr_form(expr) {
    ExprForm::Number(value) if value.is_integral() => Some(value.numerator())
    _ => None
  }
}

///|
fn reciprocal_for_match(expr : Expr) -> Expr {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Expr::Pow(base, exp) if is_exact_negative_one(exp) => base
    Expr::Number(value) =>
      if value.is_zero() {
        pow(expr, int(-1))
      } else {
        Expr::Number(
          @symnum.BigRational::new(value.denominator(), value.numerator()) catch {
            _ => return pow(expr, int(-1))
          },
        )
      }
    Expr::NumberSymbol(NumberSymbolKind::Infinity)
    | Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)
    | Expr::NumberSymbol(NumberSymbolKind::ComplexInfinity) => int(0)
    Expr::NumberSymbol(NumberSymbolKind::NaN) => expr
    _ => pow(expr, int(-1))
  }
}

///|
fn reciprocal_root_for_match(expr : Expr, degree : BigInt) -> Expr {
  if degree.compare(1N) == 0 {
    reciprocal_for_match(expr)
  } else {
    let exponent = Expr::Number(
      @symnum.BigRational::new(-1N, degree) catch {
        _ => return reciprocal_for_match(expr)
      },
    )
    pow(normalize_legacy_expr(expr), exponent)
  }
}

///|
fn base_exp_for_match(expr : Expr) -> (Expr, Expr) {
  match normalize_legacy_expr(expr) {
    Expr::Pow(base, exp) => (base, exp)
    other => (other, int(1))
  }
}

///|
fn positive_root_for_match(expr : Expr, degree : BigInt) -> Expr {
  let expr = normalize_legacy_expr(expr)
  if degree.compare(1N) == 0 {
    return expr
  }
  let one_over_degree_result : Result[
    @symnum.BigRational,
    @symnum.RationalError,
  ] = try? @symnum.BigRational::new(1N, degree)
  let one_over_degree = match one_over_degree_result {
    Ok(value) => Expr::Number(value)
    Err(_) => return pow(expr, int(1))
  }
  match expr {
    Expr::Number(value) =>
      if exact_number_sign(value) < 0 && degree.mod(2N).compare(0N) == 0 {
        let magnitude_result : Result[
          @symnum.BigRational,
          @symnum.RationalError,
        ] = try? @symnum.BigRational::new(
          value.numerator().neg(),
          value.denominator(),
        )
        let magnitude = match magnitude_result {
          Ok(ratio) => Expr::Number(ratio)
          Err(_) => return pow(expr, one_over_degree)
        }
        mul([
          Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit),
          pow(magnitude, one_over_degree),
        ])
      } else {
        pow(expr, one_over_degree)
      }
    Expr::Mul(items) =>
      if degree.mod(2N).compare(0N) == 0 && !items.is_empty() {
        let mut minus_idx = -1
        for i in 0..<items.length() {
          if is_exact_negative_one(items[i]) {
            minus_idx = i
            break
          }
        }
        if minus_idx >= 0 {
          let remainder : Array[Expr] = []
          for i in 0..<items.length() {
            if i != minus_idx {
              remainder.push(items[i])
            }
          }
          let magnitude = combine_commutative_items(remainder, false)
          return mul([
            Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit),
            positive_root_for_match(magnitude, degree),
          ])
        }
        pow(expr, one_over_degree)
      } else {
        pow(expr, one_over_degree)
      }
    Expr::Pow(base, exp) => pow(base, mul([exp, one_over_degree]))
    _ => pow(expr, one_over_degree)
  }
}

///|
fn expand_multiplicative_coeff_for_add_match(expr : Expr) -> Expr? {
  match monomial_parts(expr) {
    Some((coeff, factors)) => {
      let one = @symnum.BigRational::one()
      let neg_one = @symnum.BigRational::from_int(-1)
      if coeff.compare(one) > 0 {
        Some(
          raw_add([
            monomial_expr(one, factors),
            monomial_expr(coeff.add_r(neg_one), factors),
          ]),
        )
      } else if coeff.compare(neg_one) < 0 {
        Some(
          raw_add([
            monomial_expr(neg_one, factors),
            monomial_expr(coeff.add_r(one), factors),
          ]),
        )
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn expand_positive_power_for_mul_match(expr : Expr) -> Expr? {
  match normalize_legacy_expr(expr) {
    Expr::Pow(base, exp) =>
      match exact_integer_value(exp) {
        Some(n) if n.compare(1N) > 0 && n.compare(32N) <= 0 => {
          let count = n.to_int()
          let factors : Array[Expr] = []
          for _ in 0..<count {
            factors.push(base)
          }
          Some(raw_mul(factors))
        }
        _ => None
      }
    _ => None
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
        _ =>
          match expand_multiplicative_coeff_for_add_match(expr) {
            Some(expanded) => return expr_match(pattern, expanded, repl_dict~)
            None => return expr_match(pattern, Expr::Add([expr]), repl_dict~)
          }
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
            if match_count_ops(quotient) > match_count_ops(expr) {
              ()
            } else {
              match expr_match(wild_items[0], quotient, repl_dict~) {
                Some(result) => return Some(result)
                None => ()
              }
            }
          None => ()
        }
      }
      match expand_positive_power_for_mul_match(expr) {
        Some(expanded) => return expr_match(pattern, expanded, repl_dict~)
        None => ()
      }
    }
    Expr::Pow(base, exp) if is_one(expr) && !expr_contains_wild(base) =>
      return expr_match(exp, int(0), repl_dict~)
    Expr::Pow(base, exp) => {
      match exact_integer_value(exp) {
        Some(n) if n.compare(0N) > 0 =>
          match expr_match(base, positive_root_for_match(expr, n), repl_dict~) {
            Some(result) => return Some(result)
            None => ()
          }
        Some(n) if n.compare(0N) < 0 =>
          if is_zero(expr) {
            return None
          } else {
            match
              expr_match(base, reciprocal_root_for_match(expr, -n), repl_dict~) {
              Some(result) => return Some(result)
              None => ()
            }
          }
        _ => ()
      }
      let (expr_base, expr_exp) = base_exp_for_match(expr)
      match expr_match(base, expr_base, repl_dict~) {
        Some(next_env) =>
          match
            expr_match(
              xreplace(exp, match_env_rules(next_env)),
              expr_exp,
              repl_dict=next_env,
            ) {
            Some(result) => return Some(result)
            None => ()
          }
        None => ()
      }
    }
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
