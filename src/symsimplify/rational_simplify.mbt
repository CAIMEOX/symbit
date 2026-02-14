///|
pub fn radsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  fixpoint_rewrite(expr, rewrite_radsimp, max_passes~)
}

///|
pub fn ratsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  fixpoint_rewrite(expr, rewrite_ratsimp, max_passes~)
}

///|
pub fn ratsimpmodprime(
  expr : @symcore.Expr,
  basis? : Array[@symcore.Expr] = [],
  gens? : Array[@symcore.Expr] = [],
  quick? : Bool = true,
  polynomial? : Bool = false,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  let _ = basis
  let _ = gens
  let _ = quick
  let _ = polynomial
  ratsimp(expr, max_passes~)
}

///|
pub fn collect_sqrt(
  expr : @symcore.Expr,
  evaluate? : Bool = true,
) -> @symcore.Expr {
  let _ = evaluate
  collect_function_terms(expr, "sqrt")
}

///|
pub fn collect_abs(expr : @symcore.Expr) -> @symcore.Expr {
  collect_function_terms(expr, "Abs")
}

///|
pub fn rad_rationalize(
  num : @symcore.Expr,
  den : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) {
  match rationalized_denominator(den) {
    Some((mul_num, new_den)) => (@symcore.mul([num, mul_num]), new_den)
    None => (num, den)
  }
}

///|
pub fn fraction_expand(expr : @symcore.Expr) -> @symcore.Expr {
  let (num, den) = split_fraction(expr)
  let n = expand_mul_expr(num)
  let d = expand_mul_expr(den)
  if d == @symcore.int(1) {
    n
  } else {
    @symcore.mul([n, @symcore.pow(d, @symcore.int(-1))])
  }
}

///|
pub fn numer_expand(expr : @symcore.Expr) -> @symcore.Expr {
  let (num, den) = split_fraction(expr)
  let n = expand_mul_expr(num)
  if den == @symcore.int(1) {
    n
  } else {
    @symcore.mul([n, @symcore.pow(den, @symcore.int(-1))])
  }
}

///|
pub fn denom_expand(expr : @symcore.Expr) -> @symcore.Expr {
  let (num, den) = split_fraction(expr)
  let d = expand_mul_expr(den)
  if d == @symcore.int(1) {
    num
  } else {
    @symcore.mul([num, @symcore.pow(d, @symcore.int(-1))])
  }
}

///|
pub fn split_surds(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) {
  let terms = match expr {
    @symcore.Expr::Add(args) => args
    _ => [expr]
  }
  let surds : Array[(@symcore.Expr, Int)] = Array::new()
  let others : Array[@symcore.Expr] = Array::new()
  for term in terms {
    match parse_coeff_sqrt_int(term) {
      Some(item) => surds.push(item)
      None => others.push(term)
    }
  }
  if surds.is_empty() {
    return (@symcore.int(1), @symcore.int(0), expr)
  }
  let mut g = surds[0].1
  for i in 1..<surds.length() {
    g = int_gcd(g, surds[i].1)
  }
  if g <= 0 {
    g = 1
  }
  let a_terms : Array[@symcore.Expr] = Array::new()
  let b_terms = others.map(t => t)
  for item in surds {
    let coeff = item.0
    let rad = item.1
    if rad % g == 0 {
      let inner = @symcore.int(rad / g)
      a_terms.push(@symcore.mul([coeff, @symcore.function("sqrt", [inner])]))
    } else {
      b_terms.push(@symcore.mul([coeff, @symcore.function("sqrt", [@symcore.int(rad)])]))
    }
  }
  (@symcore.int(g), @symcore.add(a_terms), @symcore.add(b_terms))
}

///|
pub fn sqrtdenest(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  fixpoint_rewrite(expr, rewrite_sqrtdenest, max_passes~)
}

///|
fn fixpoint_rewrite(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
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
fn rewrite_bottom_up_rational(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
) -> @symcore.Expr {
  let rewritten = @symcore.map_children(
    expr,
    child => rewrite_bottom_up_rational(child, rule),
  )
  rule(rewritten)
}

///|
fn rewrite_radsimp(expr : @symcore.Expr) -> @symcore.Expr {
  let (num, den) = split_fraction(expr)
  match den {
    @symcore.Expr::Number(n) if n.is_one() => expr
    _ =>
      match rationalized_denominator(den) {
        Some((mul_num, new_den)) =>
          @symcore.mul([
            num,
            mul_num,
            @symcore.pow(new_den, @symcore.int(-1)),
          ])
        None => expr
      }
  }
}

///|
fn rationalized_denominator(
  den : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr)? {
  match den {
    _ if is_radical(den) =>
      match radical_square(den) {
        Some(square) => Some((den, square))
        None => None
      }
    @symcore.Expr::Add([a, b]) =>
      match (parse_signed_radical(a), parse_signed_radical(b)) {
        (Some((sa, ra)), Some((sb, rb))) => {
          let a_term = if sa > 0 { ra } else { @symcore.mul([@symcore.int(-1), ra]) }
          let b_term = if sb > 0 { rb } else { @symcore.mul([@symcore.int(-1), rb]) }
          let conj = @symcore.add([
            a_term,
            @symcore.mul([@symcore.int(-1), b_term]),
          ])
          match (radical_square(ra), radical_square(rb)) {
            (Some(a_sq), Some(b_sq)) =>
              Some((
                conj,
                @symcore.add([a_sq, @symcore.mul([@symcore.int(-1), b_sq])]),
              ))
            _ => None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn rewrite_ratsimp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      if args.is_empty() {
        return expr
      }
      let nums : Array[@symcore.Expr] = Array::new()
      let dens : Array[@symcore.Expr] = Array::new()
      for arg in args {
        let (n, d) = split_fraction(arg)
        nums.push(n)
        dens.push(d)
      }
      let common_den = @symcore.mul(dens)
      let num_terms : Array[@symcore.Expr] = Array::new()
      for i in 0..<nums.length() {
        let rest_dens : Array[@symcore.Expr] = Array::new()
        for j in 0..<dens.length() {
          if i != j {
            rest_dens.push(dens[j])
          }
        }
        num_terms.push(@symcore.mul([nums[i], @symcore.mul(rest_dens)]))
      }
      let num_sum = @symcore.add(num_terms)
      cancel_common_factors(
        @symcore.mul([num_sum, @symcore.pow(common_den, @symcore.int(-1))]),
      )
    }
    _ => cancel_common_factors(expr)
  }
}

///|
fn rewrite_sqrtdenest(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, [arg]) if name == "sqrt" =>
      match try_denest_quadratic_surds(arg) {
        Some(denested) => denested
        None => expr
      }
    _ => expr
  }
}

///|
fn try_denest_quadratic_surds(arg : @symcore.Expr) -> @symcore.Expr? {
  let (a, b) = match parse_a_plus_two_sqrt_b(arg) {
    Some(pair) => pair
    None => return None
  }
  let four = @symnum.BigRational::from_int(4)
  let two = @symnum.BigRational::from_int(2)
  let disc = a.mul_r(a).add_r(b.mul_r(four).neg_r())
  match rational_sqrt(disc) {
    Some(sdisc) => {
      let m = try! a.add_r(sdisc).div_r(two)
      let n = try! a.add_r(sdisc.neg_r()).div_r(two)
      if m.compare(@symnum.BigRational::zero()) < 0 ||
        n.compare(@symnum.BigRational::zero()) < 0 {
        return None
      }
      Some(@symcore.add([
        @symcore.function("sqrt", [@symcore.number(m)]),
        @symcore.function("sqrt", [@symcore.number(n)]),
      ]))
    }
    None => None
  }
}

///|
fn parse_a_plus_two_sqrt_b(
  expr : @symcore.Expr,
) -> (@symnum.BigRational, @symnum.BigRational)? {
  match expr {
    @symcore.Expr::Add([x, y]) =>
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
fn parse_numeric_term(term : @symcore.Expr) -> @symnum.BigRational? {
  match term {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn parse_two_sqrt_term(term : @symcore.Expr) -> @symnum.BigRational? {
  match term {
    @symcore.Expr::Mul([@symcore.Expr::Number(c), r]) =>
      if c.compare(@symnum.BigRational::from_int(2)) == 0 {
        radical_radicand_as_rational(r)
      } else {
        None
      }
    _ => None
  }
}

///|
fn radical_radicand_as_rational(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Function(name, [@symcore.Expr::Number(b)]) if name == "sqrt" => Some(b)
    @symcore.Expr::Pow(@symcore.Expr::Number(b), @symcore.Expr::Number(e)) =>
      if is_half(e) {
        Some(b)
      } else {
        None
      }
    _ => None
  }
}

///|
fn split_fraction(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr) {
  match expr {
    @symcore.Expr::Pow(base, @symcore.Expr::Number(exp)) => {
      if exp.is_integral() && exp.numerator().to_int() < 0 {
        let den_exp = @symcore.int(-exp.numerator().to_int())
        (@symcore.int(1), @symcore.pow(base, den_exp))
      } else {
        (expr, @symcore.int(1))
      }
    }
    @symcore.Expr::Mul(args) => {
      let num_factors : Array[@symcore.Expr] = Array::new()
      let den_factors : Array[@symcore.Expr] = Array::new()
      for factor in args {
        match factor {
          @symcore.Expr::Pow(base, @symcore.Expr::Number(exp)) =>
            if exp.is_integral() && exp.numerator().to_int() < 0 {
              den_factors.push(
                @symcore.pow(base, @symcore.int(-exp.numerator().to_int())),
              )
            } else {
              num_factors.push(factor)
            }
          _ => num_factors.push(factor)
        }
      }
      (@symcore.mul(num_factors), @symcore.mul(den_factors))
    }
    _ => (expr, @symcore.int(1))
  }
}

///|
fn cancel_common_factors(expr : @symcore.Expr) -> @symcore.Expr {
  let (num, den) = split_fraction(expr)
  let nfs = flatten_mul_factors(num)
  let dfs = flatten_mul_factors(den)
  let den_count : Map[String, Int] = {}
  for f in dfs {
    let key = @symprint.debug_repr(f)
    match den_count.get(key) {
      Some(c) => den_count[key] = c + 1
      None => den_count[key] = 1
    }
  }
  let kept_num : Array[@symcore.Expr] = Array::new()
  for f in nfs {
    let key = @symprint.debug_repr(f)
    match den_count.get(key) {
      Some(c) if c > 0 => den_count[key] = c - 1
      _ => kept_num.push(f)
    }
  }
  let kept_den : Array[@symcore.Expr] = Array::new()
  for key, c in den_count {
    if c <= 0 {
      continue
    }
    // Rebuild factors from key by preserving original exact nodes from den list.
    let mut left = c
    for f in dfs {
      if @symprint.debug_repr(f) == key && left > 0 {
        kept_den.push(f)
        left = left - 1
      }
    }
  }
  let num_out = @symcore.mul(kept_num)
  let den_out = @symcore.mul(kept_den)
  if den_out == @symcore.int(1) {
    num_out
  } else {
    @symcore.mul([num_out, @symcore.pow(den_out, @symcore.int(-1))])
  }
}

///|
fn flatten_mul_factors(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    @symcore.Expr::Mul(args) => args.map(x => x)
    @symcore.Expr::Number(n) if n.is_one() => []
    _ => [expr]
  }
}

///|
fn collect_function_terms(
  expr : @symcore.Expr,
  target_name : String,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let grouped : Map[String, Array[@symcore.Expr]] = {}
      let grouped_arg : Map[String, @symcore.Expr] = {}
      let rest : Array[@symcore.Expr] = Array::new()
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
        let name =
          if target_name == "Abs" {
            "Abs"
          } else {
            target_name
          }
        rest.push(@symcore.mul([coeff_sum, @symcore.function(name, [inner])]))
      }
      @symcore.add(rest)
    }
    _ => expr
  }
}

///|
fn parse_coeff_times_named_unary(
  expr : @symcore.Expr,
  target_name : String,
) -> (@symcore.Expr, @symcore.Expr)? {
  let matches_target = fn (name : String) -> Bool {
    if target_name == "Abs" {
      name == "Abs" || name == "abs"
    } else {
      name == target_name
    }
  }
  match expr {
    @symcore.Expr::Function(name, [inner]) if matches_target(name) =>
      Some((@symcore.int(1), inner))
    @symcore.Expr::Mul(args) => {
      let mut seen = false
      let mut inner_expr = @symcore.int(0)
      let coeff_factors : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Function(name, [inner]) if matches_target(name) && !seen => {
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
fn expand_mul_expr(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => @symcore.add(args.map(term => expand_mul_expr(term)))
    @symcore.Expr::Mul(args) => expand_mul_sequence(args.map(f => expand_mul_expr(f)))
    @symcore.Expr::Pow(base, exp) => @symcore.pow(expand_mul_expr(base), expand_mul_expr(exp))
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(a => expand_mul_expr(a)))
    _ => expr
  }
}

///|
fn expand_mul_sequence(factors : Array[@symcore.Expr]) -> @symcore.Expr {
  let mut terms : Array[@symcore.Expr] = [@symcore.int(1)]
  for factor in factors {
    match factor {
      @symcore.Expr::Add(args) => {
        let next_terms : Array[@symcore.Expr] = Array::new()
        for t in terms {
          for arg in args {
            next_terms.push(@symcore.mul([t, arg]))
          }
        }
        terms = next_terms
      }
      _ => {
        for i in 0..<terms.length() {
          terms[i] = @symcore.mul([terms[i], factor])
        }
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
fn parse_coeff_sqrt_int(expr : @symcore.Expr) -> (@symcore.Expr, Int)? {
  match expr {
    @symcore.Expr::Function(name, [@symcore.Expr::Number(n)]) if name == "sqrt" => {
      if n.is_integral() && n.numerator().to_int() > 0 {
        Some((@symcore.int(1), n.numerator().to_int()))
      } else {
        None
      }
    }
    @symcore.Expr::Mul(args) => {
      let mut found = false
      let mut rad = 0
      let coeff_factors : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Function(name, [@symcore.Expr::Number(n)]) if name == "sqrt" && !found => {
            if n.is_integral() && n.numerator().to_int() > 0 {
              found = true
              rad = n.numerator().to_int()
            } else {
              return None
            }
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
  if x == 0 { 1 } else { x }
}

///|
fn parse_signed_radical(expr : @symcore.Expr) -> (Int, @symcore.Expr)? {
  if is_radical(expr) {
    return Some((1, expr))
  }
  match expr {
    @symcore.Expr::Mul([@symcore.Expr::Number(c), r]) =>
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
fn is_radical(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Function(name, [_]) => name == "sqrt"
    @symcore.Expr::Pow(_, @symcore.Expr::Number(exp)) => is_half(exp)
    _ => false
  }
}

///|
fn radical_square(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function(name, [arg]) if name == "sqrt" => Some(arg)
    @symcore.Expr::Pow(base, @symcore.Expr::Number(exp)) =>
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
        Some(try! @symnum.BigRational::new(BigInt::from_int(sn), BigInt::from_int(sd)))
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
