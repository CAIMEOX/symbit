///|
/// - Does: Rationalizes supported radical denominators inside one expression.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the implemented radical-denominator patterns are handled.
pub fn radsimp(expr : Expr, max_passes? : Int = 6) -> Expr {
  fixpoint_rewrite(expr, rewrite_radsimp, max_passes~)
}

///|
/// - Does: Rewrites additive rational expressions over a common denominator and reduces them.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Uses the local structural fraction splitter rather than a full polynomial-domain algorithm.
pub fn ratsimp(expr : Expr, max_passes? : Int = 6) -> Expr {
  fixpoint_rewrite(expr, rewrite_ratsimp, max_passes~)
}

///|
/// - Does: Exposes the modular rational-simplification front door.
/// - Input: One expression plus optional basis, generators, quick/polynomial flags, and `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: The current implementation ignores the modular arguments and falls back to `ratsimp`.
pub fn ratsimpmodprime(
  expr : Expr,
  basis? : Array[Expr] = [],
  gens? : Array[Expr] = [],
  quick? : Bool = true,
  polynomial? : Bool = false,
  max_passes? : Int = 6,
) -> Expr {
  let _ = basis
  let _ = gens
  let _ = quick
  let _ = polynomial
  ratsimp(expr, max_passes~)
}

///|
/// - Does: Collects additive terms that share square-root factors.
/// - Input: Any `Expr` plus optional `evaluate`.
/// - Returns: One rewritten `Expr`.
/// - Limits: The current front door ignores `evaluate` and uses the implemented structural collection only.
pub fn collect_sqrt(expr : Expr, evaluate? : Bool = true) -> Expr {
  let _ = evaluate
  collect_function_terms(expr, "sqrt")
}

///|
/// - Does: Collects repeated `Abs` factors inside multiplicative terms.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only explicit `Abs` factors are grouped.
pub fn collect_abs(expr : Expr) -> Expr {
  collect_function_terms(expr, "Abs")
}

///|
/// - Does: Rationalizes one symbolic fraction `(num, den)` by removing supported radicals from the denominator.
/// - Input: Two expressions `(num, den)`.
/// - Returns: `(Expr, Expr)`.
/// - Limits: Unsupported denominators are returned unchanged.
pub fn rad_rationalize(num : Expr, den : Expr) -> (Expr, Expr) {
  match rationalized_denominator(den) {
    Some((mul_num, new_den)) => (@symcore.mul([num, mul_num]), new_den)
    None => (num, den)
  }
}

///|
/// - Does: Expands both numerator and denominator parts of a rational expression.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Uses structural numerator/denominator splitting and multiplication expansion only.
pub fn fraction_expand(expr : Expr) -> Expr {
  let (num, den) = split_fraction(expr)
  let n = expand_mul_expr(num)
  let d = expand_mul_expr(den)
  if d == int(1) {
    n
  } else {
    @symcore.mul([n, @symcore.pow(d, int(-1))])
  }
}

///|
/// - Does: Expands only the symbolic numerator of a rational expression.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Denominator structure is preserved exactly as split by the local fraction helper.
pub fn numer_expand(expr : Expr) -> Expr {
  let (num, den) = split_fraction(expr)
  let n = expand_mul_expr(num)
  if den == int(1) {
    n
  } else {
    @symcore.mul([n, @symcore.pow(den, int(-1))])
  }
}

///|
/// - Does: Expands only the symbolic denominator of a rational expression.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Numerator structure is preserved exactly as split by the local fraction helper.
pub fn denom_expand(expr : Expr) -> Expr {
  let (num, den) = split_fraction(expr)
  let d = expand_mul_expr(den)
  if d == int(1) {
    num
  } else {
    @symcore.mul([num, @symcore.pow(d, int(-1))])
  }
}

///|
/// - Does: Splits surd terms into a shared radical factor and two additive partitions.
/// - Input: Any `Expr`, usually an additive radical expression.
/// - Returns: `(Expr, Expr, Expr)`.
/// - Limits: Only the supported square-root integer pattern is recognized.
pub fn split_surds(expr : Expr) -> (Expr, Expr, Expr) {
  let terms = match expr {
    Add(args) => args
    _ => [expr]
  }
  let surds : Array[(Expr, Int)] = Array::new()
  let others : Array[Expr] = Array::new()
  for term in terms {
    match parse_coeff_sqrt_int(term) {
      Some(item) => surds.push(item)
      None => others.push(term)
    }
  }
  if surds.is_empty() {
    return (int(1), int(0), expr)
  }
  let mut g = surds[0].1
  for i in 1..<surds.length() {
    g = int_gcd(g, surds[i].1)
  }
  if g <= 0 {
    g = 1
  }
  let a_terms : Array[Expr] = Array::new()
  let b_terms = others.map(t => t)
  for item in surds {
    let coeff = item.0
    let rad = item.1
    if rad % g == 0 {
      let inner = int(rad / g)
      a_terms.push(@symcore.mul([coeff, @symcore.function("sqrt", [inner])]))
    } else {
      b_terms.push(@symcore.mul([coeff, @symcore.function("sqrt", [int(rad)])]))
    }
  }
  (int(g), @symcore.add(a_terms), @symcore.add(b_terms))
}

///|
/// - Does: Denests supported nested square roots when algebraic identities apply.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the implemented denesting identities are used, so many nested radicals remain unchanged.
pub fn sqrtdenest(expr : Expr, max_passes? : Int = 6) -> Expr {
  fixpoint_rewrite(expr, rewrite_sqrtdenest, max_passes~)
}

///|
fn fixpoint_rewrite(
  expr : Expr,
  rule : (Expr) -> Expr,
  max_passes? : Int = 6,
) -> Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = rewrite_bottom_up_rational(cur, rule)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
fn rewrite_bottom_up_rational(expr : Expr, rule : (Expr) -> Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => {
    rewrite_bottom_up_rational(child, rule)
  })
  rule(rewritten)
}

///|
fn rewrite_radsimp(expr : Expr) -> Expr {
  let (num, den) = split_fraction(expr)
  match den {
    Number(n) if n.is_one() => expr
    _ =>
      match rationalized_denominator(den) {
        Some((mul_num, new_den)) =>
          @symcore.mul([num, mul_num, @symcore.pow(new_den, int(-1))])
        None => expr
      }
  }
}

///|
fn rationalized_denominator(den : Expr) -> (Expr, Expr)? {
  match den {
    _ if is_radical(den) =>
      match radical_square(den) {
        Some(square) => Some((den, square))
        None => None
      }
    Add([a, b]) =>
      match (parse_signed_radical(a), parse_signed_radical(b)) {
        (Some((sa, ra)), Some((sb, rb))) => {
          let a_term = if sa > 0 { ra } else { @symcore.mul([int(-1), ra]) }
          let b_term = if sb > 0 { rb } else { @symcore.mul([int(-1), rb]) }
          let conj = @symcore.add([a_term, @symcore.mul([int(-1), b_term])])
          match (radical_square(ra), radical_square(rb)) {
            (Some(a_sq), Some(b_sq)) =>
              Some((conj, @symcore.add([a_sq, @symcore.mul([int(-1), b_sq])])))
            _ => None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn rewrite_ratsimp(expr : Expr) -> Expr {
  match expr {
    Add(args) => {
      if args.is_empty() {
        return expr
      }
      let nums : Array[Expr] = Array::new()
      let dens : Array[Expr] = Array::new()
      for arg in args {
        let (n, d) = split_fraction(arg)
        nums.push(n)
        dens.push(d)
      }
      let common_den = lcm_denominator(dens)
      let num_terms : Array[Expr] = Array::new()
      for i in 0..<nums.length() {
        let quotient = denominator_quotient(common_den, dens[i])
        num_terms.push(@symcore.mul([nums[i], quotient]))
      }
      let num_sum = @symcore.add(num_terms)
      let rebuilt = @symcore.mul([num_sum, @symcore.pow(common_den, int(-1))])
      match poly_cancel_expr(rebuilt) {
        Some(canceled) => canceled
        None => cancel_common_factors(rebuilt)
      }
    }
    _ =>
      match poly_cancel_expr(expr) {
        Some(canceled) => canceled
        None => cancel_common_factors(expr)
      }
  }
}

///|
fn lcm_denominator(dens : Array[Expr]) -> Expr {
  let counts : Map[String, Int] = Map([])
  let factors : Map[String, Expr] = Map([])
  for den in dens {
    let local_counts = factor_count_map(den)
    for key, count in local_counts {
      match counts.get(key) {
        Some(prev) => if count > prev { counts[key] = count }
        None => counts[key] = count
      }
      factors[key] = factor_expr_by_key(den, key)
    }
  }
  factors_from_counts(counts, factors)
}

///|
fn denominator_quotient(common_den : Expr, den : Expr) -> Expr {
  let common_counts = factor_count_map(common_den)
  let common_factors = factor_expr_map(common_den)
  let local_counts = factor_count_map(den)
  let out_counts : Map[String, Int] = Map([])
  for key, total in common_counts {
    let used = match local_counts.get(key) {
      Some(count) => count
      None => 0
    }
    let remain = total - used
    if remain > 0 {
      out_counts[key] = remain
    }
  }
  factors_from_counts(out_counts, common_factors)
}

///|
fn expr_symbol_names_for_poly(expr : Expr) -> Array[String] {
  let names : Array[String] = []
  for sym in @symcore.free_symbols(expr) {
    match sym {
      Symbol(name) => if !names.contains(name) { names.push(name) }
      Dummy(name, _) => if !names.contains(name) { names.push(name) }
      _ => ()
    }
  }
  names.sort()
  names
}

///|
fn poly_cancel_expr(expr : Expr) -> Expr? {
  let (num, den) = split_fraction(expr)
  let gens = expr_symbol_names_for_poly(@symcore.mul([num, den]))
  if gens.is_empty() {
    return None
  }
  let num_poly = @sympolys.Poly::from_expr(num, gens, EX) catch {
    _ => return None
  }
  let den_poly = @sympolys.Poly::from_expr(den, gens, EX) catch {
    _ => return None
  }
  if den_poly.is_zero() {
    return None
  }
  let (num_s, den_s) = @sympolys.cancel(num_poly, den_poly) catch {
    _ => return None
  }
  let num_expr = num_s.to_expr()
  let den_expr = den_s.to_expr()
  Some(
    if den_expr == int(1) {
      num_expr
    } else {
      @symcore.mul([num_expr, @symcore.pow(den_expr, int(-1))])
    },
  )
}

///|
fn factor_integral_number_rational(expr : Expr) -> Array[Expr]? {
  match expr {
    Number(n) if n.is_integral() => {
      let value = n.numerator().to_int()
      if value == 0 {
        return Some([expr])
      }
      let sign = if value < 0 { -1 } else { 1 }
      let mut rest = if value < 0 { -value } else { value }
      if rest <= 1 {
        return Some([expr])
      }
      let out : Array[Expr] = []
      if sign < 0 {
        out.push(int(-1))
      }
      let mut factor = 2
      while factor * factor <= rest {
        while rest % factor == 0 {
          out.push(int(factor))
          rest = rest / factor
        }
        factor += if factor == 2 { 1 } else { 2 }
      }
      if rest > 1 {
        out.push(int(rest))
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn flatten_mul_nonunit_rational(expr : Expr) -> Array[Expr] {
  match expr {
    Mul(args) => {
      let out : Array[Expr] = []
      for arg in args {
        for factor in flatten_mul_nonunit_rational(arg) {
          if factor != int(1) {
            out.push(factor)
          }
        }
      }
      out
    }
    Pow(base, Number(exp)) if exp.is_integral() => {
      let power = exp.numerator().to_int()
      if power > 1 && power <= 32 {
        let base_factors = flatten_mul_nonunit_rational(base)
        let out : Array[Expr] = []
        for _ in 0..<power {
          for factor in base_factors {
            if factor != int(1) {
              out.push(factor)
            }
          }
        }
        out
      } else {
        [expr]
      }
    }
    Number(n) if n.is_one() => []
    _ =>
      match factor_integral_number_rational(expr) {
        Some(factors) => factors.filter(f => f != int(1))
        None => [expr]
      }
  }
}

///|
fn factor_count_map(expr : Expr) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for factor in flatten_mul_nonunit_rational(expr) {
    let key = Repr(factor).to_string()
    match counts.get(key) {
      Some(prev) => counts[key] = prev + 1
      None => counts[key] = 1
    }
  }
  counts
}

///|
fn factor_expr_map(expr : Expr) -> Map[String, Expr] {
  let factors : Map[String, Expr] = Map([])
  for factor in flatten_mul_nonunit_rational(expr) {
    let key = Repr(factor).to_string()
    factors[key] = factor
  }
  factors
}

///|
fn factor_expr_by_key(expr : Expr, key : String) -> Expr {
  for factor in flatten_mul_nonunit_rational(expr) {
    if Repr(factor).to_string() == key {
      return factor
    }
  }
  expr
}

///|
fn factors_from_counts(
  counts : Map[String, Int],
  factors : Map[String, Expr],
) -> Expr {
  let out : Array[Expr] = Array::new()
  for key, count in counts {
    for _ in 0..<count {
      out.push(factors[key])
    }
  }
  @symcore.mul(out)
}

///|
fn rewrite_sqrtdenest(expr : Expr) -> Expr {
  match unary_application_arg(expr, "sqrt") {
    Some(arg) =>
      match try_denest_quadratic_surds(arg) {
        Some(denested) => denested
        None => expr
      }
    None => expr
  }
}

///|
fn try_denest_quadratic_surds(arg : Expr) -> Expr? {
  let (a, b) = match parse_a_plus_two_sqrt_b(arg) {
    Some(pair) => pair
    None => return None
  }
  let four = @symnum.BigRational::from_int(4)
  let disc = a.mul_r(a).add_r(b.mul_r(four).neg_r())
  match rational_sqrt(disc) {
    Some(sdisc) => {
      let half = @symnum.BigRational::from_ints(1, 2) catch { _ => return None }
      let m = a.add_r(sdisc).mul_r(half)
      let n = a.add_r(sdisc.neg_r()).mul_r(half)
      if m.compare(@symnum.BigRational::zero()) < 0 ||
        n.compare(@symnum.BigRational::zero()) < 0 {
        return None
      }
      Some(
        @symcore.add([
          @symcore.function("sqrt", [Number(m)]),
          @symcore.function("sqrt", [Number(n)]),
        ]),
      )
    }
    None => None
  }
}

///|
fn parse_a_plus_two_sqrt_b(
  expr : Expr,
) -> (@symnum.BigRational, @symnum.BigRational)? {
  match expr {
    Add([x, y]) =>
      match (parse_numeric_term(x), parse_two_sqrt_term(y)) {
        (Some(a), Some(b)) => Some((a, b))
        _ =>
          match (parse_numeric_term(y), parse_two_sqrt_term(x)) {
            (Some(a), Some(b)) => Some((a, b))
            _ => None
          }
      }
    _ => None
  }
}

///|
fn parse_numeric_term(term : Expr) -> @symnum.BigRational? {
  exact_numeric_value(term)
}

///|
fn parse_two_sqrt_term(term : Expr) -> @symnum.BigRational? {
  match term {
    Mul(args) if args.length() == 2 => {
      let mut saw_two = false
      let mut radical : Expr? = None
      for arg in args {
        match arg {
          Number(c) if c.compare(@symnum.BigRational::from_int(2)) == 0 =>
            saw_two = true
          _ => if radical is None { radical = Some(arg) } else { return None }
        }
      }
      if saw_two {
        match radical {
          Some(r) => radical_radicand_as_rational(r)
          None => None
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn radical_radicand_as_rational(expr : Expr) -> @symnum.BigRational? {
  match unary_application_arg(expr, "sqrt") {
    Some(arg) => exact_numeric_value(arg)
    None =>
      match expr {
        Pow(base, exp) =>
          match (exact_numeric_value(base), exact_numeric_value(exp)) {
            (Some(b), Some(e)) if is_half(e) => Some(b)
            _ => None
          }
        _ => None
      }
  }
}

///|
fn split_fraction(expr : Expr) -> (Expr, Expr) {
  split_fraction_simple(expr)
}

///|
fn cancel_common_factors(expr : Expr) -> Expr {
  let (num, den) = split_fraction(expr)
  let simp_num = factor_terms_simple(
    signsimp(expand_mul_expr(num), max_passes=2),
  )
  let simp_den = factor_terms_simple(
    signsimp(expand_mul_expr(den), max_passes=2),
  )
  let nfs = flatten_mul_nonunit(simp_num)
  let dfs = flatten_mul_nonunit(simp_den)
  let den_count : Map[String, Int] = Map([])
  let den_factor : Map[String, Expr] = Map([])
  for f in dfs {
    let key = Repr(f).to_string()
    den_factor[key] = f
    match den_count.get(key) {
      Some(c) => den_count[key] = c + 1
      None => den_count[key] = 1
    }
  }
  let kept_num : Array[Expr] = Array::new()
  for f in nfs {
    let key = Repr(f).to_string()
    match den_count.get(key) {
      Some(c) if c > 0 => den_count[key] = c - 1
      _ => kept_num.push(f)
    }
  }
  let kept_den : Array[Expr] = Array::new()
  for key, c in den_count {
    if c <= 0 {
      continue
    }
    for _ in 0..<c {
      kept_den.push(den_factor[key])
    }
  }
  let num_out = @symcore.mul(kept_num)
  let den_out = @symcore.mul(kept_den)
  if den_out == int(1) {
    num_out
  } else {
    @symcore.mul([num_out, @symcore.pow(den_out, int(-1))])
  }
}

///|
fn collect_function_terms(expr : Expr, target_name : String) -> Expr {
  match expr {
    Add(args) => {
      let grouped : Map[String, Array[Expr]] = Map([])
      let grouped_arg : Map[String, Expr] = Map([])
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match parse_coeff_times_named_unary(arg, target_name) {
          Some((coeff, inner)) => {
            let key = Repr(inner).to_string()
            match grouped.get(key) {
              Some(coeffs) => coeffs.push(coeff)
              None => {
                grouped[key] = [coeff]
                grouped_arg[key] = inner
              }
            }
          }
          None => rest.push(arg)
        }
      }
      for key, coeffs in grouped {
        let coeff_sum = @symcore.add(coeffs)
        let inner = grouped_arg[key]
        let name = if target_name == "Abs" { "Abs" } else { target_name }
        rest.push(@symcore.mul([coeff_sum, @symcore.function(name, [inner])]))
      }
      @symcore.add(rest)
    }
    _ => expr
  }
}

///|
fn parse_coeff_times_named_unary(
  expr : Expr,
  target_name : String,
) -> (Expr, Expr)? {
  let matches_target = fn(name : String) -> Bool {
    if target_name == "Abs" {
      name == "Abs" || name == "abs"
    } else {
      name == target_name
    }
  }
  match expr {
    _ =>
      match named_unary_application(expr) {
        Some((name, inner)) if matches_target(name) => Some((int(1), inner))
        _ =>
          match expr {
            Mul(args) => {
              let mut seen = false
              let mut inner_expr = int(0)
              let coeff_factors : Array[Expr] = Array::new()
              for arg in args {
                match arg {
                  _ =>
                    match named_unary_application(arg) {
                      Some((name, inner)) if matches_target(name) && !seen => {
                        seen = true
                        inner_expr = inner
                      }
                      _ => coeff_factors.push(arg)
                    }
                }
              }
              if seen {
                Some((@symcore.mul(coeff_factors), inner_expr))
              } else {
                None
              }
            }
            _ => None
          }
      }
  }
}

///|
fn expand_mul_expr(expr : Expr) -> Expr {
  match expr {
    Add(args) => {
      let expanded : Array[Expr] = Array::new()
      let mut changed = false
      for arg in args {
        let next = expand_mul_expr(arg)
        changed = changed || next != arg
        expanded.push(next)
      }
      if changed {
        @symcore.add(expanded)
      } else {
        expr
      }
    }
    Mul(args) => {
      let expanded : Array[Expr] = Array::new()
      let mut changed = false
      let mut has_sum = false
      for arg in args {
        let next = expand_mul_expr(arg)
        changed = changed || next != arg
        match next {
          Add(_) => has_sum = true
          _ => ()
        }
        expanded.push(next)
      }
      if has_sum {
        expand_mul_sequence(expanded)
      } else if changed {
        @symcore.mul(expanded)
      } else {
        expr
      }
    }
    Pow(base, exp) => {
      let base_expanded = expand_mul_expr(base)
      let exp_expanded = expand_mul_expr(exp)
      if base_expanded == base && exp_expanded == exp {
        expr
      } else {
        @symcore.pow(base_expanded, exp_expanded)
      }
    }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) => {
          let expanded : Array[Expr] = Array::new()
          let mut changed = false
          for arg in args {
            let next = expand_mul_expr(arg)
            changed = changed || next != arg
            expanded.push(next)
          }
          if changed {
            @symcore.raw_apply(head, expanded).unwrap_or(expr)
          } else {
            expr
          }
        }
        None => expr
      }
  }
}

///|
fn additive_terms(expr : Expr) -> Array[Expr] {
  match expr {
    Add(args) => args
    _ => [expr]
  }
}

///|
fn expand_mul_sums_range(
  sums : Array[Expr],
  start : Int,
  end_ : Int,
) -> Array[Expr] {
  let len = end_ - start
  if len <= 0 {
    return [int(1)]
  }
  if len == 1 {
    return additive_terms(sums[start])
  }
  let mid = start + len / 2
  let left = expand_mul_sums_range(sums, start, mid)
  let right = expand_mul_sums_range(sums, mid, end_)
  let products : Array[Expr] = Array::new()
  for a in left {
    for b in right {
      products.push(@symcore.mul([a, b]))
    }
  }
  additive_terms(@symcore.add(products))
}

///|
fn expand_mul_sequence(factors : Array[Expr]) -> Expr {
  let plain : Array[Expr] = Array::new()
  let sums : Array[Expr] = Array::new()
  for factor in factors {
    match factor {
      Add(_) => sums.push(factor)
      _ => plain.push(factor)
    }
  }
  if sums.is_empty() {
    return @symcore.mul(factors)
  }
  let plain_term = if plain.is_empty() { int(1) } else { @symcore.mul(plain) }
  let terms = expand_mul_sums_range(sums, 0, sums.length())
  let scaled : Array[Expr] = Array::new()
  for term in terms {
    if plain.is_empty() {
      scaled.push(term)
    } else {
      scaled.push(@symcore.mul([plain_term, term]))
    }
  }
  if scaled.length() == 1 {
    scaled[0]
  } else {
    @symcore.add(scaled)
  }
}

///|
fn parse_coeff_sqrt_int(expr : Expr) -> (Expr, Int)? {
  match unary_application_arg(expr, "sqrt") {
    Some(Number(n)) =>
      if n.is_integral() && n.numerator().to_int() > 0 {
        Some((int(1), n.numerator().to_int()))
      } else {
        None
      }
    Some(_) => None
    None =>
      match expr {
        Mul(args) => {
          let mut found = false
          let mut rad = 0
          let coeff_factors : Array[Expr] = Array::new()
          for arg in args {
            match unary_application_arg(arg, "sqrt") {
              Some(Number(n)) if !found =>
                if n.is_integral() && n.numerator().to_int() > 0 {
                  found = true
                  rad = n.numerator().to_int()
                } else {
                  return None
                }
              Some(_) if !found => return None
              _ => coeff_factors.push(arg)
            }
          }
          if found {
            Some((@symcore.mul(coeff_factors), rad))
          } else {
            None
          }
        }
        _ => None
      }
  }
}

///|
fn int_gcd(a : Int, b : Int) -> Int {
  let mut x = if a < 0 { -a } else { a }
  let mut y = if b < 0 { -b } else { b }
  if x == 0 {
    return if y == 0 { 1 } else { y }
  }
  while y != 0 {
    let r = x % y
    x = y
    y = r
  }
  if x == 0 {
    1
  } else {
    x
  }
}

///|
fn parse_signed_radical(expr : Expr) -> (Int, Expr)? {
  if is_radical(expr) {
    return Some((1, expr))
  }
  match expr {
    Mul(args) if args.length() == 2 => {
      let mut coeff : @symnum.BigRational? = None
      let mut radical : Expr? = None
      for arg in args {
        match arg {
          Number(c) => coeff = Some(c)
          _ => if radical is None { radical = Some(arg) } else { return None }
        }
      }
      match (coeff, radical) {
        (Some(c), Some(r)) if is_radical(r) &&
          c.compare(@symnum.BigRational::from_int(-1)) == 0 => Some((-1, r))
        (Some(c), Some(r)) if is_radical(r) && c.is_one() => Some((1, r))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn is_radical(expr : Expr) -> Bool {
  match expr {
    _ if @symcore.application_has_name(expr, "sqrt", arity=1) => true
    Pow(_, Number(exp)) => is_half(exp)
    _ => false
  }
}

///|
fn radical_square(expr : Expr) -> Expr? {
  match expr {
    _ =>
      match unary_application_arg(expr, "sqrt") {
        Some(arg) => Some(arg)
        None =>
          match expr {
            Pow(base, Number(exp)) =>
              if is_half(exp) {
                Some(base)
              } else {
                None
              }
            _ => None
          }
      }
  }
}

///|
fn is_half(value : @symnum.BigRational) -> Bool {
  value.numerator().equal_int(1) && value.denominator().equal_int(2)
}

///|
fn int_sqrt_if_square(n : Int) -> Int? {
  if n < 0 {
    return None
  }
  let mut i = 0
  while i * i < n {
    i = i + 1
  }
  if i * i == n {
    Some(i)
  } else {
    None
  }
}

///|
fn rational_sqrt(v : @symnum.BigRational) -> @symnum.BigRational? {
  if !v.is_integral() {
    let num = v.numerator().to_int()
    let den = v.denominator().to_int()
    match (int_sqrt_if_square(num), int_sqrt_if_square(den)) {
      (Some(sn), Some(sd)) =>
        Some(
          @symnum.BigRational::new(BigInt::from_int(sn), BigInt::from_int(sd)) catch {
            _ => return None
          },
        )
      _ => None
    }
  } else {
    let n = v.numerator().to_int()
    match int_sqrt_if_square(n) {
      Some(s) => Some(@symnum.BigRational::from_int(s))
      None => None
    }
  }
}
