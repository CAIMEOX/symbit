///|
/// Simplify Bessel-function expressions.
pub fn besselsimp(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_compat(expr, rewrite_besselsimp, max_passes~)
}

///|
/// Simplify Kronecker-delta expressions.
pub fn kroneckersimp(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_compat(expr, rewrite_kroneckersimp, max_passes~)
}

///|
/// Convert exact numeric expressions to simpler symbolic forms.
pub fn nsimplify(
  expr : Expr,
  constants? : Array[Expr] = [],
  full? : Bool = false,
  rational? : Bool = true,
  max_passes? : Int = 8,
) -> Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let search_passes = if full { passes + 2 } else { passes }

  let mut best = simplify(expr, max_passes=search_passes)
  best = fixpoint_compat(
    best,
    node => rewrite_nsimplify_exact(node, constants, rational),
    max_passes=search_passes,
  )
  best = shorter_expr(best, simplify(best, max_passes=2))
  best = shorter_expr(best, tr4(best))
  best = shorter_expr(best, fu(best, max_passes=1))
  if expr_has_bessel(best) {
    best = shorter_expr(best, besselsimp(best, max_passes=1))
  }
  if expr_has_kronecker_delta(best) {
    best = shorter_expr(best, kroneckersimp(best, max_passes=1))
  }
  if !constants.is_empty() {
    let aliased = compat_rewrite_named_constants(best, constants)
    if aliased != best {
      best = simplify(aliased, max_passes=2)
    }
  }
  best
}

///|
fn fixpoint_compat(
  expr : Expr,
  rule : (Expr) -> Expr,
  max_passes? : Int = 8,
) -> Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = rewrite_bottom_up_compat(cur, rule)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
fn rewrite_bottom_up_compat(expr : Expr, rule : (Expr) -> Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => {
    rewrite_bottom_up_compat(child, rule)
  })
  rule(rewritten)
}

///|
priv struct CompatBesselTermInfo {
  term : Expr
  order : Expr
  arg : Expr
  norm : Expr
  shift : Int
}

///|
priv enum CompatDeltaBind {
  Bound
  Keep
  Conflict
}

///|
fn rewrite_besselsimp(expr : Expr) -> Expr {
  let atom = compat_rewrite_bessel_atom(expr)
  if atom != expr {
    return simplify(atom, max_passes=2)
  }
  let recur_j = compat_rewrite_bessel_recurrence(expr, "besselj")
  if recur_j != expr {
    return recur_j
  }
  compat_rewrite_bessel_recurrence(expr, "bessely")
}

///|
fn compat_rewrite_bessel_atom(expr : Expr) -> Expr {
  match expr {
    Expr::Function(name, [nu, z]) => {
      if compat_is_zero_number(z) && (name == "besselj" || name == "besseli") {
        if !compat_is_nonnegative_integer_expr(nu) {
          return expr
        }
        let n = compat_integer_expr_value(nu)
        return if n == 0 { int(1) } else { int(0) }
      }
      match compat_half_integer_bessel(name, nu, z) {
        Some(out) => out
        None => expr
      }
    }
    _ => expr
  }
}

///|
fn compat_half_integer_bessel(name : String, nu : Expr, z : Expr) -> Expr? {
  let half = compat_half_rational()
  let minus_half = half.neg_r()
  let kernel = match nu {
    Expr::Number(n) if n == half =>
      match name {
        "besselj" => Some(@symcore.function("sin", [z]))
        "bessely" => Some(neg_expr(@symcore.function("cos", [z])))
        "besseli" => Some(@symcore.function("sinh", [z]))
        "besselk" =>
          Some(
            @symcore.mul([
              compat_sqrt_pi(),
              @symcore.function("exp", [neg_expr(z)]),
              @symcore.pow(
                @symcore.mul([compat_sqrt_two(), @symcore.function("sqrt", [z])]),
                int(-1),
              ),
            ]),
          )
        _ => None
      }
    Expr::Number(n) if n == minus_half =>
      match name {
        "besselj" => Some(@symcore.function("cos", [z]))
        "bessely" => Some(@symcore.function("sin", [z]))
        "besseli" => Some(@symcore.function("cosh", [z]))
        _ => None
      }
    _ => None
  }
  match kernel {
    Some(value) if name == "besselk" => Some(value)
    Some(value) =>
      Some(
        @symcore.mul([
          compat_sqrt_two(),
          value,
          @symcore.pow(
            @symcore.mul([compat_sqrt_pi(), @symcore.function("sqrt", [z])]),
            int(-1),
          ),
        ]),
      )
    None => None
  }
}

///|
fn compat_rewrite_bessel_recurrence(expr : Expr, name : String) -> Expr {
  let infos = compat_collect_bessel_terms(expr, name)
  let mut candidate : CompatBesselTermInfo? = None
  for info in infos {
    if compat_has_bessel_shift(infos, info.norm, info.arg, info.shift + 1) &&
      compat_has_bessel_shift(infos, info.norm, info.arg, info.shift + 2) {
      match candidate {
        Some(prev) =>
          if info.shift < prev.shift ||
            (
              info.shift == prev.shift &&
              @symcore.compare_expr(info.arg, prev.arg) < 0
            ) {
            candidate = Some(info)
          }
        None => candidate = Some(info)
      }
    }
  }
  match candidate {
    Some(info) => {
      let next_order = add_small_int(info.order, 1)
      let next_term = @symcore.function(name, [next_order, info.arg])
      let next_next_term = @symcore.function(name, [
        add_small_int(info.order, 2),
        info.arg,
      ])
      let recurrence = @symcore.add([
        @symcore.mul([
          int(2),
          next_order,
          @symcore.pow(info.arg, int(-1)),
          next_term,
        ]),
        neg_expr(next_next_term),
      ])
      let rewritten = compat_replace_exact(expr, info.term, recurrence)
      simplify(
        factor_terms_simple(ratsimp(rewritten, max_passes=1)),
        max_passes=2,
      )
    }
    None => expr
  }
}

///|
fn compat_collect_bessel_terms(
  expr : Expr,
  name : String,
) -> Array[CompatBesselTermInfo] {
  let out : Array[CompatBesselTermInfo] = Array::new()
  compat_collect_bessel_terms_rec(expr, name, out)
  out
}

///|
fn compat_collect_bessel_terms_rec(
  expr : Expr,
  name : String,
  out : Array[CompatBesselTermInfo],
) -> Unit {
  match expr {
    Expr::Function(fn_name, [order, arg]) if fn_name == name => {
      let (norm, shift) = split_expr_integer_shift(order)
      out.push(CompatBesselTermInfo::{ term: expr, order, arg, norm, shift })
    }
    _ =>
      for child in @symcore.children(expr) {
        compat_collect_bessel_terms_rec(child, name, out)
      }
  }
}

///|
fn compat_has_bessel_shift(
  infos : Array[CompatBesselTermInfo],
  norm : Expr,
  arg : Expr,
  shift : Int,
) -> Bool {
  for info in infos {
    if info.norm == norm && info.arg == arg && info.shift == shift {
      return true
    }
  }
  false
}

///|
fn compat_replace_exact(expr : Expr, target : Expr, replacement : Expr) -> Expr {
  if expr == target {
    return replacement
  }
  @symcore.map_children(expr, child => {
    compat_replace_exact(child, target, replacement)
  })
}

///|
fn rewrite_kroneckersimp(expr : Expr) -> Expr {
  match expr {
    Expr::Function(name, [a, b]) if name == "KroneckerDelta" =>
      compat_simplify_delta(a, b)
    Expr::Mul(args) => compat_simplify_delta_mul(args)
    _ => expr
  }
}

///|
fn compat_simplify_delta_mul(args : Array[Expr]) -> Expr {
  let env : Map[String, Expr] = {}
  let others : Array[Expr] = Array::new()
  let pending : Array[(Expr, Expr)] = Array::new()
  for arg in args {
    match arg {
      Expr::Function(name, [a, b]) if name == "KroneckerDelta" =>
        match compat_simplify_delta(a, b) {
          Expr::Number(n) if n.is_zero() => return int(0)
          Expr::Number(n) if n.is_one() => ()
          Expr::Function(_, [lhs, rhs]) => pending.push((lhs, rhs))
          other => others.push(other)
        }
      _ => others.push(arg)
    }
  }

  let mut active = pending
  let mut changed = true
  while changed {
    changed = false
    let next_active : Array[(Expr, Expr)] = Array::new()
    for pair in active {
      let lhs = compat_normalize_with_env(pair.0, env)
      let rhs = compat_normalize_with_env(pair.1, env)
      match compat_simplify_delta(lhs, rhs) {
        Expr::Number(n) if n.is_zero() => return int(0)
        Expr::Number(n) if n.is_one() => changed = true
        Expr::Function(_, [a, b]) =>
          match compat_try_bind_delta(env, a, b) {
            CompatDeltaBind::Conflict => return int(0)
            CompatDeltaBind::Bound => changed = true
            CompatDeltaBind::Keep =>
              next_active.push(compat_canonical_delta_pair(a, b))
          }
        _ => ()
      }
    }
    for i in 0..<next_active.length() {
      for j in (i + 1)..<next_active.length() {
        if compat_delta_pairs_conflict(next_active[i], next_active[j]) {
          return int(0)
        }
      }
    }
    active = compat_unique_delta_pairs(next_active)
  }

  let out : Array[Expr] = Array::new()
  for other in others {
    out.push(compat_normalize_with_env(other, env))
  }
  for pair in active {
    let lhs = compat_normalize_with_env(pair.0, env)
    let rhs = compat_normalize_with_env(pair.1, env)
    match compat_simplify_delta(lhs, rhs) {
      Expr::Number(n) if n.is_zero() => return int(0)
      Expr::Number(n) if n.is_one() => ()
      other => out.push(other)
    }
  }
  simplify(@symcore.mul(out), max_passes=2)
}

///|
fn compat_unique_delta_pairs(
  pairs : Array[(Expr, Expr)],
) -> Array[(Expr, Expr)] {
  let seen : Map[String, Bool] = {}
  let out : Array[(Expr, Expr)] = Array::new()
  for pair in pairs {
    let key = @symprint.debug_repr(pair.0) + "|" + @symprint.debug_repr(pair.1)
    if seen.get(key) is Some(_) {
      continue
    }
    seen[key] = true
    out.push(pair)
  }
  out
}

///|
fn compat_canonical_delta_pair(a : Expr, b : Expr) -> (Expr, Expr) {
  if @symcore.compare_expr(a, b) <= 0 {
    (a, b)
  } else {
    (b, a)
  }
}

///|
fn compat_try_bind_delta(
  env : Map[String, Expr],
  a : Expr,
  b : Expr,
) -> CompatDeltaBind {
  match (a, b) {
    (Expr::Symbol(name_a), Expr::Symbol(name_b)) =>
      if name_a == name_b {
        CompatDeltaBind::Bound
      } else if name_a.compare(name_b) <= 0 {
        compat_bind_symbol(env, name_b, a)
      } else {
        compat_bind_symbol(env, name_a, b)
      }
    (Expr::Symbol(name), value) => compat_bind_symbol(env, name, value)
    (value, Expr::Symbol(name)) => compat_bind_symbol(env, name, value)
    _ => CompatDeltaBind::Keep
  }
}

///|
fn compat_bind_symbol(
  env : Map[String, Expr],
  name : String,
  value : Expr,
) -> CompatDeltaBind {
  let normalized = compat_normalize_with_env(value, env)
  if compat_expr_contains_symbol_name(normalized, name) {
    return CompatDeltaBind::Keep
  }
  match env.get(name) {
    Some(v) =>
      if compat_normalize_with_env(v, env) == normalized {
        CompatDeltaBind::Bound
      } else {
        CompatDeltaBind::Conflict
      }
    None => {
      env[name] = normalized
      CompatDeltaBind::Bound
    }
  }
}

///|
fn compat_delta_pairs_conflict(lhs : (Expr, Expr), rhs : (Expr, Expr)) -> Bool {
  compat_delta_args_cancel(lhs.0, lhs.1, rhs.0, rhs.1)
}

///|
fn compat_delta_args_cancel(a1 : Expr, a2 : Expr, b1 : Expr, b2 : Expr) -> Bool {
  if compat_definitely_equal(a1, b1) && compat_definitely_unequal(a2, b2) {
    return true
  }
  if compat_definitely_equal(a1, b2) && compat_definitely_unequal(a2, b1) {
    return true
  }
  if compat_definitely_equal(a2, b1) && compat_definitely_unequal(a1, b2) {
    return true
  }
  compat_definitely_equal(a2, b2) && compat_definitely_unequal(a1, b1)
}

///|
fn compat_definitely_equal(a : Expr, b : Expr) -> Bool {
  a == b
}

///|
fn compat_definitely_unequal(a : Expr, b : Expr) -> Bool {
  match (a, b) {
    (Expr::Number(x), Expr::Number(y)) => x != y
    _ => false
  }
}

///|
fn compat_normalize_with_env(expr : Expr, env : Map[String, Expr]) -> Expr {
  compat_normalize_with_env_rec(expr, env, 0)
}

///|
fn compat_normalize_with_env_rec(
  expr : Expr,
  env : Map[String, Expr],
  depth : Int,
) -> Expr {
  if depth > 24 {
    return expr
  }
  match expr {
    Expr::Symbol(name) =>
      match env.get(name) {
        Some(value) if value != expr =>
          compat_normalize_with_env_rec(value, env, depth + 1)
        _ => expr
      }
    _ =>
      @symcore.map_children(expr, child => {
        compat_normalize_with_env_rec(child, env, depth + 1)
      })
  }
}

///|
fn compat_expr_contains_symbol_name(expr : Expr, name : String) -> Bool {
  match expr {
    Expr::Symbol(sym_name) => sym_name == name
    _ => {
      for child in @symcore.children(expr) {
        if compat_expr_contains_symbol_name(child, name) {
          return true
        }
      }
      false
    }
  }
}

///|
fn compat_simplify_delta(a : Expr, b : Expr) -> Expr {
  if a == b {
    return int(1)
  }
  match (a, b) {
    (Expr::Number(x), Expr::Number(y)) => if x == y { int(1) } else { int(0) }
    _ => {
      let pair = compat_canonical_delta_pair(a, b)
      @symcore.function("KroneckerDelta", [pair.0, pair.1])
    }
  }
}

///|
fn rewrite_nsimplify_exact(
  expr : Expr,
  constants : Array[Expr],
  rational : Bool,
) -> Expr {
  let _ = rational
  let basic = match expr {
    Expr::Function(name, [Expr::Number(n)]) if name == "sqrt" =>
      match compat_exact_rational_nth_root(n, 2) {
        Some(root) => @symcore.Expr::Number(root)
        None => expr
      }
    Expr::Pow(Expr::Number(base), Expr::Number(exp)) =>
      match compat_exact_numeric_pow(base, exp) {
        Some(value) => @symcore.Expr::Number(value)
        None => expr
      }
    Expr::Function(name, [_]) if compat_is_special_trig_name(name) => tr4(expr)
    _ => expr
  }
  if constants.is_empty() {
    basic
  } else {
    compat_rewrite_named_constants(basic, constants)
  }
}

///|
fn compat_exact_numeric_pow(
  base : @symnum.BigRational,
  exp : @symnum.BigRational,
) -> @symnum.BigRational? {
  if exp.is_integral() {
    return eval_numeric_pow(base, exp)
  }
  let den = exp.denominator().to_int()
  if den <= 1 {
    return None
  }
  match compat_exact_rational_nth_root(base, den) {
    Some(root) =>
      eval_numeric_pow(
        root,
        @symnum.BigRational::from_int(exp.numerator().to_int()),
      )
    None => None
  }
}

///|
fn compat_exact_rational_nth_root(
  value : @symnum.BigRational,
  n : Int,
) -> @symnum.BigRational? {
  if n <= 0 {
    return None
  }
  if value.is_zero() {
    return Some(@symnum.BigRational::zero())
  }
  let sign = value.compare(@symnum.BigRational::zero())
  if sign < 0 && n % 2 == 0 {
    return None
  }
  let abs_value = if sign < 0 { value.neg_r() } else { value }
  match
    (
      compat_int_nth_root_if_exact(abs_value.numerator().to_int(), n),
      compat_int_nth_root_if_exact(abs_value.denominator().to_int(), n),
    ) {
    (Some(num), Some(den)) => {
      let signed_num = if sign < 0 { -num } else { num }
      match
        (
          try? @symnum.BigRational::from_ints(signed_num, den) :
          Result[@symnum.BigRational, @symnum.RationalError]) {
        Ok(v) => Some(v)
        Err(_) => None
      }
    }
    _ => None
  }
}

///|
fn compat_int_nth_root_if_exact(value : Int, n : Int) -> Int? {
  if n <= 0 || value < 0 {
    return None
  }
  if value == 0 || value == 1 {
    return Some(value)
  }
  let mut lo = 1
  let mut hi = value
  while lo <= hi {
    let mid = lo + (hi - lo) / 2
    let pow_cmp = compat_compare_pow_to_limit(mid, n, value)
    if pow_cmp == 0 {
      return Some(mid)
    }
    if pow_cmp < 0 {
      lo = mid + 1
    } else {
      hi = mid - 1
    }
  }
  None
}

///|
fn compat_compare_pow_to_limit(base : Int, exp : Int, limit : Int) -> Int {
  let mut out = 1
  for _ in 0..<exp {
    if base != 0 && out > limit / base {
      return 1
    }
    out = out * base
  }
  if out < limit {
    -1
  } else if out > limit {
    1
  } else {
    0
  }
}

///|
fn compat_rewrite_named_constants(expr : Expr, constants : Array[Expr]) -> Expr {
  if !compat_has_named_constant(constants, "GoldenRatio") {
    return expr
  }
  match compat_match_linear_sqrt5(expr) {
    Some((a, b)) if !b.is_zero() => {
      let golden = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::GoldenRatio)
      let constant_part = a.add_r(b.neg_r())
      let golden_part = b.mul_r(@symnum.BigRational::from_int(2))
      compat_make_linear_expr(constant_part, golden_part, golden)
    }
    _ => expr
  }
}

///|
fn compat_has_named_constant(constants : Array[Expr], name : String) -> Bool {
  for constant in constants {
    match constant {
      Expr::Symbol(const_name) if const_name == name => return true
      _ => ()
    }
  }
  false
}

///|
fn compat_match_linear_sqrt5(
  expr : Expr,
) -> (@symnum.BigRational, @symnum.BigRational)? {
  match expr {
    Expr::Add(args) => {
      let mut constant = @symnum.BigRational::zero()
      let mut sqrt_coeff = @symnum.BigRational::zero()
      for arg in args {
        match compat_linear_sqrt5_term(arg) {
          Some((c, s)) => {
            constant = constant.add_r(c)
            sqrt_coeff = sqrt_coeff.add_r(s)
          }
          None => return None
        }
      }
      Some((constant, sqrt_coeff))
    }
    _ => compat_linear_sqrt5_term(expr)
  }
}

///|
fn compat_linear_sqrt5_term(
  expr : Expr,
) -> (@symnum.BigRational, @symnum.BigRational)? {
  match expr {
    Expr::Number(n) => Some((n, @symnum.BigRational::zero()))
    Expr::Function(name, [Expr::Number(n)]) if name == "sqrt" &&
      n == @symnum.BigRational::from_int(5) =>
      Some((@symnum.BigRational::zero(), @symnum.BigRational::one()))
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let mut has_sqrt5 = false
      for arg in args {
        match arg {
          Expr::Number(n) => coeff = coeff.mul_r(n)
          Expr::Function(name, [Expr::Number(n)]) if name == "sqrt" &&
            n == @symnum.BigRational::from_int(5) => has_sqrt5 = true
          _ => return None
        }
      }
      if has_sqrt5 {
        Some((@symnum.BigRational::zero(), coeff))
      } else {
        Some((coeff, @symnum.BigRational::zero()))
      }
    }
    _ => None
  }
}

///|
fn compat_make_linear_expr(
  constant : @symnum.BigRational,
  coeff : @symnum.BigRational,
  base : Expr,
) -> Expr {
  let out : Array[Expr] = Array::new()
  if !coeff.is_zero() {
    if coeff.is_one() {
      out.push(base)
    } else {
      out.push(@symcore.mul([@symcore.Expr::Number(coeff), base]))
    }
  }
  if !constant.is_zero() {
    out.push(@symcore.Expr::Number(constant))
  }
  @symcore.add(out)
}

///|
fn compat_is_special_trig_name(name : String) -> Bool {
  name == "sin" ||
  name == "cos" ||
  name == "tan" ||
  name == "cot" ||
  name == "sec" ||
  name == "csc"
}

///|
fn compat_sqrt_two() -> Expr {
  @symcore.function("sqrt", [int(2)])
}

///|
fn compat_sqrt_pi() -> Expr {
  @symcore.function("sqrt", [@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)])
}

///|
fn compat_half_rational() -> @symnum.BigRational {
  @symnum.BigRational::from_ints(1, 2) catch {
    _ => @symnum.BigRational::zero()
  }
}

///|
fn compat_is_zero_number(expr : Expr) -> Bool {
  numeric_zero_pred(expr)
}

///|
fn compat_is_nonnegative_integer_expr(expr : Expr) -> Bool {
  match exact_integer_value(expr) {
    Some(value) => value >= 0
    None => false
  }
}

///|
fn compat_integer_expr_value(expr : Expr) -> Int {
  exact_integer_value(expr).unwrap_or(0)
}
