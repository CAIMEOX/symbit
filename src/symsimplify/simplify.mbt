///|
/// Simplifies the given expression.
pub fn simplify(
  expr : Expr,
  plan? : SimplifyPlan = SimplifyPlan::Default,
  max_passes? : Int = 8,
) -> Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  simplify_deep(expr, plan, passes)
}

///|
fn simplify_deep(expr : Expr, plan : SimplifyPlan, max_passes : Int) -> Expr {
  if is_atom(expr) {
    return expr
  }
  let with_children = @symcore.map_children(expr, child => {
    simplify_deep(child, plan, max_passes)
  })
  simplify_fixed_point(with_children, plan, max_passes)
}

///|
fn simplify_fixed_point(
  expr : Expr,
  plan : SimplifyPlan,
  max_passes : Int,
) -> Expr {
  let mut cur = expr
  for _ in 0..<max_passes {
    let next = simplify_once(cur, plan)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
fn simplify_once(expr : Expr, plan : SimplifyPlan) -> Expr {
  let patterns = plan_patterns(plan)
  let mut best = expr

  let canonical_signs = collect_abs(signsimp(best, max_passes=1))
  best = shorter_expr(best, canonical_signs)

  let local_patterns = apply_patterns_once(best, patterns)
  best = shorter_expr(best, local_patterns)

  if expr_has_distributable_mul(best) {
    let expanded = expand_mul_expr(best)
    let expanded_local = apply_patterns_once(expanded, patterns)
    best = shorter_expr(best, expanded_local)
    best = shorter_expr(best, simplify_rational_structure(expanded_local))
  }

  let factored = factor_terms_simple(best)
  best = shorter_expr(best, factored)

  let factored_consts = collect_const(factored)
  best = shorter_expr(best, factored_consts)

  let structured_rational = simplify_rational_structure(best)
  best = shorter_expr(best, structured_rational)

  let powers = powsimp(best, max_passes=1)
  best = shorter_expr(best, powers)
  best = shorter_expr(best, powdenest(best, max_passes=1))

  let rational_candidate = ratsimp(best, max_passes=1)
  best = shorter_expr(best, rational_candidate)
  best = shorter_expr(best, simplify_rational_structure(best))

  if expr_has_radicals(best) {
    best = shorter_expr(best, radsimp(best, max_passes=1))
    best = shorter_expr(best, sqrtdenest(best, max_passes=1))
  }

  if expr_has_trig_or_hyper(best) {
    best = shorter_expr(best, trigsimp(best, max_passes=1))
    best = shorter_expr(best, trigsimp(factor_terms_simple(best), max_passes=1))
  }

  if expr_has_exp_trig_or_hyper(best) {
    best = shorter_expr(best, exptrigsimp(best, max_passes=1))
  }

  if expr_has_logs(best) {
    best = shorter_expr(best, logcombine(best, max_passes=1))
  }

  if expr_has_gamma_or_combinatorics(best) {
    best = shorter_expr(best, gammasimp(best, max_passes=1))
    best = shorter_expr(best, combsimp(best, max_passes=1))
  }

  if expr_has_hypergeometric(best) {
    best = shorter_expr(best, hyperexpand(best, max_passes=1))
  }

  if expr_has_kronecker_delta(best) {
    best = shorter_expr(best, kroneckersimp(best, max_passes=1))
  }

  if expr_has_bessel(best) {
    best = shorter_expr(best, besselsimp(best, max_passes=1))
  }

  let finalized = apply_patterns_once(factor_terms_simple(best), patterns)
  shorter_expr(best, collect_abs(signsimp(finalized, max_passes=1)))
}

///|
fn shorter_expr(lhs : Expr, rhs : Expr) -> Expr {
  if expr_complexity(rhs) < expr_complexity(lhs) {
    rhs
  } else {
    lhs
  }
}

///|
fn expr_complexity(expr : Expr) -> Int {
  node_count(expr) * 32 + @symprint.debug_repr(expr).length()
}

///|
fn simplify_rational_structure(expr : Expr) -> Expr {
  let (num, den) = fraction(expr)
  if den == int(1) {
    return expr
  }
  let simp_num = simplify_rational_part(num)
  let simp_den = simplify_rational_part(den)
  let base = cancel_common_factors_simple(simp_num, simp_den)
  let expanded_num = simplify_rational_part(expand_mul_expr(simp_num))
  let expanded_den = simplify_rational_part(expand_mul_expr(simp_den))
  let expanded = cancel_common_factors_simple(expanded_num, expanded_den)
  shorter_expr(base, expanded)
}

///|
fn simplify_rational_part(expr : Expr) -> Expr {
  let mut out = factor_terms_simple(expr)
  if expr_has_distributable_mul(out) {
    out = shorter_expr(out, factor_terms_simple(expand_mul_expr(out)))
  }
  out = shorter_expr(out, collect_const(out))
  if expr_has_trig_or_hyper(out) {
    out = shorter_expr(out, trigsimp(out, max_passes=1))
  }
  if expr_has_logs(out) {
    out = shorter_expr(out, logcombine(out, max_passes=1))
  }
  out
}

///|
fn cancel_common_factors_simple(num : Expr, den : Expr) -> Expr {
  let nfs = flatten_mul_nonunit(num)
  let dfs = flatten_mul_nonunit(den)
  let den_count : Map[String, Int] = {}
  let den_factor : Map[String, Expr] = {}
  for factor in dfs {
    let key = @symprint.debug_repr(factor)
    den_factor[key] = factor
    match den_count.get(key) {
      Some(count) => den_count[key] = count + 1
      None => den_count[key] = 1
    }
  }
  let kept_num : Array[Expr] = Array::new()
  for factor in nfs {
    let key = @symprint.debug_repr(factor)
    match den_count.get(key) {
      Some(count) if count > 0 => den_count[key] = count - 1
      _ => kept_num.push(factor)
    }
  }
  let kept_den : Array[Expr] = Array::new()
  for key, count in den_count {
    for _ in 0..<count {
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
fn factor_terms_simple(expr : Expr) -> Expr {
  match expr {
    Expr::Add(_) => factor_add_terms(expr)
    _ => expr
  }
}

///|
fn factor_add_terms(expr : Expr) -> Expr {
  let canonical = powsimp(expr, max_passes=1)
  match canonical {
    Expr::Add(args) => {
      if args.length() < 2 {
        return canonical
      }

      let sign_factored = factor_negative_add_sign(canonical)
      if sign_factored != canonical {
        return factor_mul_add_factors(sign_factored)
      }

      let const_factored = collect_const(canonical)
      if const_factored != canonical {
        return factor_mul_add_factors(const_factored)
      }

      match factor_special_add(canonical) {
        Some(special) => return special
        None => ()
      }

      let term_factors : Array[Array[Expr]] = Array::new()
      for arg in args {
        term_factors.push(flatten_mul_exact(arg))
      }

      let common_counts : Map[String, Int] = {}
      let common_exprs : Map[String, Expr] = {}
      for factor in term_factors[0] {
        if is_numeric_factor(factor) {
          continue
        }
        let key = @symprint.debug_repr(factor)
        common_exprs[key] = factor
        match common_counts.get(key) {
          Some(count) => common_counts[key] = count + 1
          None => common_counts[key] = 1
        }
      }

      for i in 1..<term_factors.length() {
        let counts : Map[String, Int] = {}
        for factor in term_factors[i] {
          if is_numeric_factor(factor) {
            continue
          }
          let key = @symprint.debug_repr(factor)
          match counts.get(key) {
            Some(count) => counts[key] = count + 1
            None => counts[key] = 1
          }
        }
        let common_keys : Array[String] = Array::new()
        for key, _ in common_counts {
          common_keys.push(key)
        }
        for key in common_keys {
          let count = common_counts[key]
          let next_count = match counts.get(key) {
            Some(other_count) =>
              if other_count < count {
                other_count
              } else {
                count
              }
            None => 0
          }
          common_counts[key] = next_count
        }
      }

      let common_factors : Array[Expr] = Array::new()
      for key, count in common_counts {
        if count <= 0 {
          continue
        }
        for _ in 0..<count {
          common_factors.push(common_exprs[key])
        }
      }
      if common_factors.is_empty() {
        return canonical
      }

      let remainders : Array[Expr] = Array::new()
      for factors in term_factors {
        let needed : Map[String, Int] = {}
        for key, count in common_counts {
          if count > 0 {
            needed[key] = count
          }
        }
        let remaining : Array[Expr] = Array::new()
        for factor in factors {
          if is_numeric_factor(factor) {
            remaining.push(factor)
            continue
          }
          let key = @symprint.debug_repr(factor)
          match needed.get(key) {
            Some(count) if count > 0 => needed[key] = count - 1
            _ => remaining.push(factor)
          }
        }
        remainders.push(
          if remaining.is_empty() {
            int(1)
          } else {
            @symcore.mul(remaining)
          },
        )
      }

      let remainder = factor_add_terms(@symcore.add(remainders))
      @symcore.mul([@symcore.mul(common_factors), remainder])
    }
    _ => canonical
  }
}

///|
fn factor_negative_add_sign(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
      if args.is_empty() {
        return expr
      }
      for arg in args {
        let (coeff, _) = split_add_term(arg)
        if coeff.compare(@symnum.BigRational::zero()) >= 0 {
          return expr
        }
      }
      let flipped = args.map(arg => @symcore.mul([int(-1), arg]))
      @symcore.mul([int(-1), @symcore.add(flipped)])
    }
    _ => expr
  }
}

///|
fn factor_mul_add_factors(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let out : Array[Expr] = Array::new()
      let mut changed = false
      for arg in args {
        match arg {
          Expr::Add(_) => {
            let factored = factor_add_terms(arg)
            out.push(factored)
            changed = changed || factored != arg
          }
          _ => out.push(arg)
        }
      }
      if changed {
        @symcore.mul(out)
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn factor_special_add(expr : Expr) -> Expr? {
  match try_factor_perfect_square(expr) {
    Some(factored) => Some(factored)
    None => try_factor_difference_of_squares(expr)
  }
}

///|
fn try_factor_perfect_square(expr : Expr) -> Expr? {
  let terms = match expr {
    Expr::Add(args) if args.length() == 3 => args
    _ => return None
  }
  for i in 0..<terms.length() {
    for j in 0..<terms.length() {
      if i == j {
        continue
      }
      let k = 3 - i - j
      match exact_square_root(terms[i]) {
        Some(a) =>
          match exact_square_root(terms[j]) {
            Some(b) =>
              match match_perfect_square_cross(terms[k], a, b) {
                Some(sign) => {
                  let binomial = if sign > 0 {
                    @symcore.add([a, b])
                  } else {
                    @symcore.add([a, @symcore.mul([int(-1), b])])
                  }
                  return Some(@symcore.pow(binomial, int(2)))
                }
                None => ()
              }
            None => ()
          }
        None => ()
      }
    }
  }
  None
}

///|
fn try_factor_difference_of_squares(expr : Expr) -> Expr? {
  let terms = match expr {
    Expr::Add(args) if args.length() == 2 => args
    _ => return None
  }
  for i in 0..<terms.length() {
    let j = 1 - i
    match exact_square_root(terms[i]) {
      Some(a) =>
        match exact_negative_square_root(terms[j]) {
          Some(b) =>
            return Some(
              @symcore.mul([
                @symcore.add([a, @symcore.mul([int(-1), b])]),
                @symcore.add([a, b]),
              ]),
            )
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
fn exact_square_root(term : Expr) -> Expr? {
  match term {
    Expr::Pow(base, Expr::Number(exp)) =>
      if exp.compare(@symnum.BigRational::from_int(2)) == 0 {
        Some(base)
      } else {
        None
      }
    Expr::Number(n) =>
      match rational_sqrt(n) {
        Some(root) => Some(@symcore.number(root))
        None => None
      }
    _ => None
  }
}

///|
fn exact_negative_square_root(term : Expr) -> Expr? {
  match term {
    Expr::Mul([Expr::Number(c), square]) =>
      if c.compare(@symnum.BigRational::from_int(-1)) == 0 {
        exact_square_root(square)
      } else {
        None
      }
    Expr::Number(n) =>
      if n.compare(@symnum.BigRational::zero()) < 0 {
        exact_square_root(@symcore.number(n.neg_r()))
      } else {
        None
      }
    _ => None
  }
}

///|
fn match_perfect_square_cross(term : Expr, a : Expr, b : Expr) -> Int? {
  if term == @symcore.mul([int(2), a, b]) {
    return Some(1)
  }
  if term == @symcore.mul([int(-2), a, b]) {
    return Some(-1)
  }
  None
}

///|
fn flatten_mul_exact(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Mul(args) => {
      let out : Array[Expr] = Array::new()
      for arg in args {
        for factor in expand_factorable_term(arg) {
          out.push(factor)
        }
      }
      out
    }
    _ => expand_factorable_term(expr)
  }
}

///|
fn flatten_mul_nonunit(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Mul(args) => {
      let out : Array[Expr] = Array::new()
      for arg in args {
        for factor in expand_factorable_term(arg) {
          if factor != int(1) {
            out.push(factor)
          }
        }
      }
      out
    }
    Expr::Number(n) if n.is_one() => []
    _ => expand_factorable_term(expr)
  }
}

///|
fn expand_factorable_term(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Pow(base, Expr::Number(exp)) if exp.is_integral() => {
      let power = exp.numerator().to_int()
      if power > 1 && power <= 32 {
        let out : Array[Expr] = Array::new()
        for _ in 0..<power {
          out.push(base)
        }
        out
      } else {
        [expr]
      }
    }
    _ => [expr]
  }
}

///|
fn is_numeric_factor(expr : Expr) -> Bool {
  expr is Expr::Number(_)
}

///|
fn expr_has_logs(expr : Expr) -> Bool {
  expr_contains_function(expr, name => name == "log")
}

///|
fn expr_has_trig_or_hyper(expr : Expr) -> Bool {
  expr_contains_function(expr, name => {
    is_trig_name(name) ||
    name == "sinh" ||
    name == "cosh" ||
    name == "tanh" ||
    name == "coth" ||
    name == "sech" ||
    name == "csch"
  })
}

///|
fn expr_has_exp_trig_or_hyper(expr : Expr) -> Bool {
  expr_contains_function(expr, name => {
    name == "exp" ||
    is_trig_name(name) ||
    name == "sinh" ||
    name == "cosh" ||
    name == "tanh" ||
    name == "coth" ||
    name == "sech" ||
    name == "csch"
  })
}

///|
fn expr_has_gamma_or_combinatorics(expr : Expr) -> Bool {
  expr_contains_function(expr, name => {
    name == "gamma" ||
    name == "factorial" ||
    name == "factorial2" ||
    name == "binomial"
  })
}

///|
fn expr_has_hypergeometric(expr : Expr) -> Bool {
  expr_contains_function(expr, name => name == "hyper")
}

///|
fn expr_has_radicals(expr : Expr) -> Bool {
  match expr {
    Expr::Function(name, [_]) if name == "sqrt" => true
    Expr::Pow(_, Expr::Number(exp)) if is_half(exp) => true
    _ => {
      for child in @symcore.children(expr) {
        if expr_has_radicals(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn expr_has_kronecker_delta(expr : Expr) -> Bool {
  expr_contains_function(expr, name => name == "KroneckerDelta")
}

///|
fn expr_has_bessel(expr : Expr) -> Bool {
  expr_contains_function(expr, name => {
    name == "besselj" ||
    name == "bessely" ||
    name == "besseli" ||
    name == "besselk"
  })
}

///|
fn expr_has_distributable_mul(expr : Expr) -> Bool {
  match expr {
    Expr::Mul(args) => {
      for arg in args {
        if arg is Expr::Add(_) {
          return true
        }
      }
      for arg in args {
        if expr_has_distributable_mul(arg) {
          return true
        }
      }
      false
    }
    _ => {
      for child in @symcore.children(expr) {
        if expr_has_distributable_mul(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn expr_contains_function(expr : Expr, predicate : (String) -> Bool) -> Bool {
  match expr {
    Expr::Function(name, _) if predicate(name) => true
    _ => {
      for child in @symcore.children(expr) {
        if expr_contains_function(child, predicate) {
          return true
        }
      }
      false
    }
  }
}

///|
/// Reduce expression by combining powers with similar bases and exponents.
pub fn powsimp(expr : Expr, max_passes? : Int = 6) -> Expr {
  simplify_with_patterns(
    expr,
    [
      SimplifyPattern::FoldConstants,
      SimplifyPattern::PowDenest,
      SimplifyPattern::MulLikeBases,
      SimplifyPattern::FoldConstants,
    ],
    max_passes~,
  )
}

///|
/// Return a reduced expression by using known trig identities.
pub fn trigsimp(expr : Expr, max_passes? : Int = 6) -> Expr {
  simplify_with_patterns(
    expr,
    [
      SimplifyPattern::FoldConstants,
      SimplifyPattern::FunctionIdentities,
      SimplifyPattern::TrigPythagorean,
      SimplifyPattern::FoldConstants,
    ],
    max_passes~,
  )
}

///|
/// Normalize signs in sums/products by pulling minus factors to canonical form.
pub fn signsimp(expr : Expr, max_passes? : Int = 6) -> Expr {
  simplify_with_patterns(
    expr,
    [
      SimplifyPattern::FoldConstants,
      SimplifyPattern::AddLikeTerms,
      SimplifyPattern::FoldConstants,
    ],
    max_passes~,
  )
}

///|
/// Run pattern-driven simplify passes.
pub fn simplify_with_patterns(
  expr : Expr,
  patterns : Array[SimplifyPattern],
  max_passes? : Int = 8,
) -> Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = apply_patterns_once(cur, patterns)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
/// Apply each simplify pattern once over the expression tree.
pub fn apply_patterns_once(
  expr : Expr,
  patterns : Array[SimplifyPattern],
) -> Expr {
  let mut cur = expr
  for pattern in patterns {
    cur = rewrite_bottom_up(cur, pattern)
  }
  cur
}

///|
fn rewrite_bottom_up(expr : Expr, pattern : SimplifyPattern) -> Expr {
  let rewritten = @symcore.map_children(expr, child => {
    rewrite_bottom_up(child, pattern)
  })
  apply_pattern(pattern, rewritten)
}

///|
/// Apply one simplify pattern at the current node.
pub fn apply_pattern(pattern : SimplifyPattern, expr : Expr) -> Expr {
  match pattern {
    SimplifyPattern::FoldConstants => fold_constants(expr)
    SimplifyPattern::AddLikeTerms => add_like_terms(expr)
    SimplifyPattern::MulLikeBases => mul_like_bases(expr)
    SimplifyPattern::PowDenest => pow_denest(expr)
    SimplifyPattern::TrigPythagorean => trig_pythagorean(expr)
    SimplifyPattern::FunctionIdentities => function_identities(expr)
  }
}

///|
fn fold_constants(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => @symcore.add(args)
    Expr::Mul(args) => @symcore.mul(args)
    Expr::Pow(base, exp) => @symcore.pow(base, exp)
    _ => expr
  }
}

///|
priv struct AddTerm {
  base : Expr
  coeff : @symnum.BigRational
}

///|
fn add_like_terms(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
      let minus_one = @symnum.BigRational::from_int(-1)
      let mut const_term = @symnum.BigRational::zero()
      let terms : Map[String, AddTerm] = {}
      for arg in args {
        let (coeff, base_opt) = split_add_term(arg)
        match base_opt {
          None => const_term = const_term.add_r(coeff)
          Some(base_expr) => {
            let key = @symprint.debug_repr(base_expr)
            match terms.get(key) {
              Some(acc) =>
                terms[key] = AddTerm::{
                  base: acc.base,
                  coeff: acc.coeff.add_r(coeff),
                }
              None => terms[key] = AddTerm::{ base: base_expr, coeff }
            }
          }
        }
      }
      let out : Array[Expr] = Array::new()
      for _, acc in terms {
        if acc.coeff.is_zero() {
          continue
        }
        if acc.coeff.is_one() {
          out.push(acc.base)
        } else if acc.coeff.compare(minus_one) == 0 {
          out.push(@symcore.mul([int(-1), acc.base]))
        } else {
          out.push(@symcore.mul([@symcore.number(acc.coeff), acc.base]))
        }
      }
      if !const_term.is_zero() {
        out.push(@symcore.number(const_term))
      }
      @symcore.add(out)
    }
    _ => expr
  }
}

///|
fn split_add_term(term : Expr) -> (@symnum.BigRational, Expr?) {
  match term {
    Expr::Number(n) => (n, None)
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let factors : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Number(n) => coeff = coeff.mul_r(n)
          _ => factors.push(arg)
        }
      }
      if factors.is_empty() {
        (coeff, None)
      } else if factors.length() == 1 {
        (coeff, Some(factors[0]))
      } else {
        (coeff, Some(@symcore.mul(factors)))
      }
    }
    _ => (@symnum.BigRational::one(), Some(term))
  }
}

///|
priv struct BasePow {
  base : Expr
  exp : @symnum.BigRational
}

///|
fn mul_like_bases(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let mut const_factor = @symnum.BigRational::one()
      let powers : Map[String, BasePow] = {}
      for arg in args {
        match arg {
          Expr::Number(n) => const_factor = const_factor.mul_r(n)
          Expr::Pow(base, Expr::Number(exp)) => {
            let key = @symprint.debug_repr(base)
            match powers.get(key) {
              Some(acc) =>
                powers[key] = BasePow::{
                  base: acc.base,
                  exp: acc.exp.add_r(exp),
                }
              None => powers[key] = BasePow::{ base, exp }
            }
          }
          _ => {
            let key = @symprint.debug_repr(arg)
            match powers.get(key) {
              Some(acc) =>
                powers[key] = BasePow::{
                  base: acc.base,
                  exp: acc.exp.add_r(@symnum.BigRational::one()),
                }
              None =>
                powers[key] = BasePow::{
                  base: arg,
                  exp: @symnum.BigRational::one(),
                }
            }
          }
        }
      }
      if const_factor.is_zero() {
        return int(0)
      }
      let factors : Array[Expr] = Array::new()
      for _, acc in powers {
        if acc.exp.is_zero() {
          continue
        }
        if acc.exp.is_one() {
          factors.push(acc.base)
        } else {
          factors.push(@symcore.pow(acc.base, @symcore.number(acc.exp)))
        }
      }
      if factors.is_empty() || !const_factor.is_one() {
        factors.push(@symcore.number(const_factor))
      }
      @symcore.mul(factors)
    }
    _ => expr
  }
}

///|
fn pow_denest(expr : Expr) -> Expr {
  match expr {
    Expr::Pow(Expr::Pow(base, inner_exp), outer_exp) =>
      match (exact_numeric_value(inner_exp), exact_numeric_value(outer_exp)) {
        (Some(a), Some(b)) =>
          @symcore.pow(base, @symcore.number(a.mul_r(b)))
        _ => expr
      }
    Expr::Pow(base, exp) =>
      match (exact_numeric_value(base), exact_numeric_value(exp)) {
        (Some(base_value), Some(exp_value)) =>
          match eval_numeric_pow(base_value, exp_value) {
            Some(v) => numeric_result_like(expr, @symcore.number(v))
            None =>
              match float_source_precision(expr) {
                Some(prec) => {
                  let evaled = @symcore.evalf(expr, prec=prec)
                  if evaled == expr { expr } else { evaled }
                }
                None => expr
              }
          }
        _ => expr
      }
    _ => expr
  }
}

///|
fn eval_numeric_pow(
  base : @symnum.BigRational,
  exp : @symnum.BigRational,
) -> @symnum.BigRational? {
  if !exp.is_integral() {
    return None
  }
  let n = exp.numerator().to_int()
  if n < 0 && base.is_zero() {
    return None
  }
  let abs_n = if n < 0 { -n } else { n }
  let mut out = @symnum.BigRational::one()
  for _ in 0..<abs_n {
    out = out.mul_r(base)
  }
  if n >= 0 {
    Some(out)
  } else {
    match
      (
        try? @symnum.BigRational::one().div_r(out) :
        Result[@symnum.BigRational, @symnum.RationalError]) {
      Ok(value) => Some(value)
      Err(_) => None
    }
  }
}

///|
fn function_identities(expr : Expr) -> Expr {
  match expr {
    Expr::Function(name, [arg]) =>
      match exact_numeric_value(arg) {
        Some(numeric) =>
          match name {
            "sin" | "tan" if numeric.is_zero() =>
              numeric_result_like(arg, int(0))
            "cos" | "exp" if numeric.is_zero() =>
              numeric_result_like(arg, int(1))
            "log" if numeric.is_one() =>
              numeric_result_like(arg, int(0))
            "sqrt" if numeric.is_zero() =>
              numeric_result_like(arg, int(0))
            "sqrt" if numeric.is_one() =>
              numeric_result_like(arg, int(1))
            "Abs" | "abs" =>
              if numeric.compare(@symnum.BigRational::zero()) < 0 {
                numeric_result_like(arg, @symcore.number(numeric.neg_r()))
              } else {
                numeric_result_like(arg, @symcore.number(numeric))
              }
            _ =>
              match (name, arg) {
                ("log", Expr::Symbol(sym_name)) if sym_name == "E" => int(1)
                _ => expr
              }
          }
        None =>
          match (name, arg) {
            ("log", Expr::Symbol(sym_name)) if sym_name == "E" => int(1)
            _ => expr
          }
      }
    _ => expr
  }
}

///|
fn trig_pythagorean(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
      let used : Array[Bool] = Array::make(args.length(), false)
      let out : Array[Expr] = Array::new()
      let mut changed = false
      for i in 0..<args.length() {
        if used[i] {
          continue
        }
        let arg = args[i]
        let sin_inner = trig_square_arg(arg, "sin")
        let cos_inner = trig_square_arg(arg, "cos")
        let mut paired = false
        for j in (i + 1)..<args.length() {
          if used[j] {
            continue
          }
          match (sin_inner, trig_square_arg(args[j], "cos")) {
            (Some(lhs), Some(rhs)) if lhs == rhs => {
              used[i] = true
              used[j] = true
              out.push(int(1))
              changed = true
              paired = true
              break
            }
            _ => ()
          }
          match (cos_inner, trig_square_arg(args[j], "sin")) {
            (Some(lhs), Some(rhs)) if lhs == rhs => {
              used[i] = true
              used[j] = true
              out.push(int(1))
              changed = true
              paired = true
              break
            }
            _ => ()
          }
        }
        if !paired {
          used[i] = true
          out.push(arg)
        }
      }
      if changed {
        @symcore.add(out)
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn trig_square_arg(term : Expr, name : String) -> Expr? {
  match term {
    Expr::Pow(Expr::Function(func, [arg]), Expr::Number(exp)) =>
      if func == name && exp.compare(@symnum.BigRational::from_int(2)) == 0 {
        Some(arg)
      } else {
        None
      }
    _ => None
  }
}
