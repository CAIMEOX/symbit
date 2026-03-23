///|
/// Rationalize the denominator by removing square roots.
pub fn radsimp(expr : Expr, max_passes? : Int = 6) -> Expr {
  fixpoint_rewrite(expr, rewrite_radsimp, max_passes~)
}

///|
/// Put an expression over a common denominator, cancel and reduce.
pub fn ratsimp(expr : Expr, max_passes? : Int = 6) -> Expr {
  fixpoint_rewrite(expr, rewrite_ratsimp, max_passes~)
}

///|
/// Simplify a rational expression modulo a prime ideal basis.
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
/// Return `expr` with terms having common square roots collected together.
pub fn collect_sqrt(expr : Expr, evaluate? : Bool = true) -> Expr {
  let _ = evaluate
  collect_function_terms(expr, "sqrt")
}

///|
/// Return `expr` with product arguments of multiple `Abs` factors collected.
pub fn collect_abs(expr : Expr) -> Expr {
  collect_function_terms(expr, "Abs")
}

///|
/// Rationalize `num/den` by removing square roots in the denominator.
pub fn rad_rationalize(num : Expr, den : Expr) -> (Expr, Expr) {
  match rationalized_denominator(den) {
    Some((mul_num, new_den)) => (@symcore.mul([num, mul_num]), new_den)
    None => (num, den)
  }
}

///|
/// Expand numerator and denominator parts of a rational expression.
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
/// Expand only the numerator.
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
/// Expand only the denominator.
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
/// Split surd terms by a shared square-free rational factor for denesting.
pub fn split_surds(expr : Expr) -> (Expr, Expr, Expr) {
  let terms = match expr {
    Expr::Add(args) => args
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
/// Denest nested square roots when algebraic identities permit.
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
    Expr::Number(n) if n.is_one() => expr
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
    Expr::Add([a, b]) =>
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
    Expr::Add(args) => {
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
      cancel_common_factors(
        @symcore.mul([num_sum, @symcore.pow(common_den, int(-1))]),
      )
    }
    _ => cancel_common_factors(expr)
  }
}

///|
fn lcm_denominator(dens : Array[Expr]) -> Expr {
  let counts : Map[String, Int] = {}
  let factors : Map[String, Expr] = {}
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
  let out_counts : Map[String, Int] = {}
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
fn factor_count_map(expr : Expr) -> Map[String, Int] {
  let counts : Map[String, Int] = {}
  for factor in flatten_mul_nonunit(expr) {
    let key = @symprint.debug_repr(factor)
    match counts.get(key) {
      Some(prev) => counts[key] = prev + 1
      None => counts[key] = 1
    }
  }
  counts
}

///|
fn factor_expr_map(expr : Expr) -> Map[String, Expr] {
  let factors : Map[String, Expr] = {}
  for factor in flatten_mul_nonunit(expr) {
    let key = @symprint.debug_repr(factor)
    factors[key] = factor
  }
  factors
}

///|
fn factor_expr_by_key(expr : Expr, key : String) -> Expr {
  for factor in flatten_mul_nonunit(expr) {
    if @symprint.debug_repr(factor) == key {
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
  match expr {
    Expr::Function(name, [arg]) if name == "sqrt" =>
      match try_denest_quadratic_surds(arg) {
        Some(denested) => denested
        None => expr
      }
    _ => expr
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
          @symcore.function("sqrt", [@symcore.number(m)]),
          @symcore.function("sqrt", [@symcore.number(n)]),
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
    Expr::Add([x, y]) =>
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
    Expr::Mul([Expr::Number(c), r]) =>
      if c.compare(@symnum.BigRational::from_int(2)) == 0 {
        radical_radicand_as_rational(r)
      } else {
        None
      }
    _ => None
  }
}

///|
fn radical_radicand_as_rational(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Function(name, [arg]) if name == "sqrt" =>
      match exact_numeric_value(arg) {
        Some(value) => Some(value)
        None => None
      }
    Expr::Pow(base, exp) =>
      match (exact_numeric_value(base), exact_numeric_value(exp)) {
        (Some(b), Some(e)) if is_half(e) => Some(b)
        _ => None
      }
    _ => None
  }
}

///|
fn split_fraction(expr : Expr) -> (Expr, Expr) {
  match expr {
    Expr::Pow(base, Expr::Number(exp)) =>
      if exp.is_integral() && exp.numerator().to_int() < 0 {
        let den_exp = int(-exp.numerator().to_int())
        (int(1), @symcore.pow(base, den_exp))
      } else {
        (expr, int(1))
      }
    Expr::Mul(args) => {
      let num_factors : Array[Expr] = Array::new()
      let den_factors : Array[Expr] = Array::new()
      for factor in args {
        match factor {
          Expr::Pow(base, Expr::Number(exp)) =>
            if exp.is_integral() && exp.numerator().to_int() < 0 {
              den_factors.push(
                @symcore.pow(base, int(-exp.numerator().to_int())),
              )
            } else {
              num_factors.push(factor)
            }
          _ => num_factors.push(factor)
        }
      }
      (@symcore.mul(num_factors), @symcore.mul(den_factors))
    }
    _ => (expr, int(1))
  }
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
  let den_count : Map[String, Int] = {}
  let den_factor : Map[String, Expr] = {}
  for f in dfs {
    let key = @symprint.debug_repr(f)
    den_factor[key] = f
    match den_count.get(key) {
      Some(c) => den_count[key] = c + 1
      None => den_count[key] = 1
    }
  }
  let kept_num : Array[Expr] = Array::new()
  for f in nfs {
    let key = @symprint.debug_repr(f)
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
    Expr::Add(args) => {
      let grouped : Map[String, Array[Expr]] = {}
      let grouped_arg : Map[String, Expr] = {}
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match parse_coeff_times_named_unary(arg, target_name) {
          Some((coeff, inner)) => {
            let key = @symprint.debug_repr(inner)
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
    Expr::Function(name, [inner]) if matches_target(name) =>
      Some((int(1), inner))
    Expr::Mul(args) => {
      let mut seen = false
      let mut inner_expr = int(0)
      let coeff_factors : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Function(name, [inner]) if matches_target(name) && !seen => {
            seen = true
            inner_expr = inner
          }
          _ => coeff_factors.push(arg)
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

///|
fn expand_mul_expr(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => @symcore.add(args.map(term => expand_mul_expr(term)))
    Expr::Mul(args) => expand_mul_sequence(args.map(f => expand_mul_expr(f)))
    Expr::Pow(base, exp) =>
      @symcore.pow(expand_mul_expr(base), expand_mul_expr(exp))
    Expr::Function(name, args) =>
      @symcore.function(name, args.map(a => expand_mul_expr(a)))
    _ => expr
  }
}

///|
fn expand_mul_sequence(factors : Array[Expr]) -> Expr {
  let mut terms : Array[Expr] = [int(1)]
  for factor in factors {
    match factor {
      Expr::Add(args) => {
        let next_terms : Array[Expr] = Array::new()
        for t in terms {
          for arg in args {
            next_terms.push(@symcore.mul([t, arg]))
          }
        }
        terms = next_terms
      }
      _ =>
        for i in 0..<terms.length() {
          terms[i] = @symcore.mul([terms[i], factor])
        }
    }
  }
  if terms.length() == 1 {
    terms[0]
  } else {
    @symcore.add(terms)
  }
}

///|
fn parse_coeff_sqrt_int(expr : Expr) -> (Expr, Int)? {
  match expr {
    Expr::Function(name, [Expr::Number(n)]) if name == "sqrt" =>
      if n.is_integral() && n.numerator().to_int() > 0 {
        Some((int(1), n.numerator().to_int()))
      } else {
        None
      }
    Expr::Mul(args) => {
      let mut found = false
      let mut rad = 0
      let coeff_factors : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Function(name, [Expr::Number(n)]) if name == "sqrt" && !found =>
            if n.is_integral() && n.numerator().to_int() > 0 {
              found = true
              rad = n.numerator().to_int()
            } else {
              return None
            }
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
    Expr::Mul([Expr::Number(c), r]) =>
      if c.compare(@symnum.BigRational::from_int(-1)) == 0 && is_radical(r) {
        Some((-1, r))
      } else if c.is_one() && is_radical(r) {
        Some((1, r))
      } else {
        None
      }
    _ => None
  }
}

///|
fn is_radical(expr : Expr) -> Bool {
  match expr {
    Expr::Function(name, [_]) => name == "sqrt"
    Expr::Pow(_, Expr::Number(exp)) => is_half(exp)
    _ => false
  }
}

///|
fn radical_square(expr : Expr) -> Expr? {
  match expr {
    Expr::Function(name, [arg]) if name == "sqrt" => Some(arg)
    Expr::Pow(base, Expr::Number(exp)) =>
      if is_half(exp) {
        Some(base)
      } else {
        None
      }
    _ => None
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
