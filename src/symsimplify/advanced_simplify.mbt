///|
/// - Does: Decomposes one expression into a symbolic numerator and denominator pair.
/// - Input: Any `Expr`.
/// - Returns: `(Expr, Expr)` where the original expression is represented as `num * den**-1`.
/// - Limits: Keeps symbolic factors unevaluated when no simpler exact split is available.
pub fn fraction(expr : Expr) -> (Expr, Expr) {
  split_fraction_simple(expr)
}

///|
/// - Does: Extracts the symbolic numerator of one expression.
/// - Input: Any `Expr`.
/// - Returns: One `Expr`.
/// - Limits: Uses the same structural split as `fraction`, so unevaluated factors can remain in the result.
pub fn numer(expr : Expr) -> Expr {
  let (n, _) = fraction(expr)
  n
}

///|
/// - Does: Extracts the symbolic denominator of one expression.
/// - Input: Any `Expr`.
/// - Returns: One `Expr`.
/// - Limits: Uses the same structural split as `fraction`, so unevaluated factors can remain in the result.
pub fn denom(expr : Expr) -> Expr {
  let (_, d) = fraction(expr)
  d
}

///|
/// - Does: Groups additive terms by powers of one target symbol.
/// - Input: One expression and one target `Expr`, typically a symbol.
/// - Returns: One rewritten `Expr`.
/// - Limits: Non-symbol targets are left unchanged instead of raising an error.
pub fn collect(expr : Expr, sym : Expr) -> Expr {
  match sym {
    Symbol(_) => collect_one_symbol(expr, sym)
    _ => expr
  }
}

///|
/// - Does: Applies `collect` recursively through the expression tree.
/// - Input: One expression and one target `Expr`, typically a symbol.
/// - Returns: One rewritten `Expr`.
/// - Limits: Uses the same symbol-only front door as `collect`, so unsupported targets are propagated unchanged.
pub fn rcollect(expr : Expr, sym : Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => rcollect(child, sym))
  collect(rewritten, sym)
}

///|
/// - Does: Factors a shared rational constant out of additive terms.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only exact rational additive coefficients are combined; non-additive inputs are returned unchanged.
pub fn collect_const(expr : Expr) -> Expr {
  match expr {
    Add(args) => {
      if args.is_empty() {
        return expr
      }
      let terms : Array[(@symnum.BigRational, Expr)] = Array::new()
      for arg in args {
        terms.push(split_coeff_mul(arg))
      }
      let g = rational_gcd(terms.map(t => t.0))
      if g.is_zero() || g.is_one() {
        return expr
      }
      let scaled : Array[Expr] = Array::new()
      for pair in terms {
        let coeff = pair.0
        let rest = pair.1
        let new_coeff = coeff.div_r(g) catch { _ => return expr }
        let scaled_term = if rest == int(1) {
          @symcore.Expr::Number(new_coeff)
        } else if new_coeff.is_one() {
          rest
        } else {
          @symcore.mul([Number(new_coeff), rest])
        }
        scaled.push(scaled_term)
      }
      @symcore.mul([Number(g), @symcore.add(scaled)])
    }
    _ => expr
  }
}

///|
/// - Does: Collapses nested powers when algebraic exponent rules allow it.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Stops after a bounded number of passes and leaves unsupported power patterns unchanged.
pub fn powdenest(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_powdenest, max_passes~)
}

///|
/// - Does: Switches between exponential and trigonometric forms to shorten an expression.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only built-in rewrite families are tried, so expressions outside that surface are returned as-is.
pub fn exptrigsimp(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_exptrigsimp, max_passes~)
}

///|
/// - Does: Applies Gamma-function simplifications and related exact identities.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only supported Gamma/combinatorial identities are used; unsupported forms are left unchanged.
pub fn gammasimp(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_gammasimp, max_passes~)
}

///|
/// - Does: Combines logarithmic sums and powers into more compact logarithmic forms.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Respects only the implemented algebraic identities and does not infer extra assumptions.
pub fn logcombine(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_logcombine, max_passes~)
}

///|
/// - Does: Separates multiplicative factors by symbolic variable sets when possible.
/// - Input: Any `Expr` plus optional `force`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Unsupported couplings remain unevaluated; `force` only widens rewrite attempts and does not guarantee separation.
pub fn separatevars(expr : Expr, force? : Bool = false) -> Expr {
  rewrite_bottom_up_advanced(expr, child => rewrite_separatevars(child, force~))
}

///|
/// - Does: Replaces symbols with positivity-assumed stand-ins and records how to restore the originals.
/// - Input: Any `Expr`.
/// - Returns: `(Expr, Map[String, Expr])` where the map restores the temporary symbols.
/// - Limits: Uses simple name-based stand-ins and does not preserve richer assumption metadata.
pub fn posify(expr : Expr) -> (Expr, Map[String, Expr]) {
  let symbols : Map[String, Bool] = Map([])
  collect_symbols(expr, symbols)
  let env : Map[String, Expr] = Map([])
  let restore : Map[String, Expr] = Map([])
  for name, _ in symbols {
    let new_name = "_\{name}"
    env[name] = Symbol(new_name)
    restore[new_name] = Symbol(name)
  }
  (@symcore.subst(expr, env), restore)
}

///|
/// - Does: Computes the hypergeometric term ratio `f(k + 1) / f(k)` when the index shift is supported.
/// - Input: One expression `f` and one index expression `k`.
/// - Returns: One `Expr`.
/// - Limits: Non-symbol indices return `0` instead of raising, and unsupported terms can stay unsimplified.
pub fn hypersimp(f : Expr, k : Expr) -> Expr {
  match k {
    Symbol(name) => {
      let env : Map[String, Expr] = Map([])
      env[name] = @symcore.add([k, int(1)])
      let fk1 = @symcore.subst(f, env)
      combsimp(simplify(@symcore.mul([fk1, @symcore.pow(f, int(-1))])))
    }
    _ => int(0)
  }
}

///|
/// - Does: Checks whether two sequences are hyper-similar in one index.
/// - Input: Two expressions plus one index expression `k`.
/// - Returns: `Bool`.
/// - Limits: Non-symbol indices return `false`, and the decision is limited to the implemented rational-form check.
pub fn hypersimilar(f : Expr, g : Expr, k : Expr) -> Bool {
  match k {
    Symbol(name) => {
      let rf = hypersimp(f, k)
      let rg = hypersimp(g, k)
      let ratio = combsimp(
        simplify(@symcore.mul([rf, @symcore.pow(rg, int(-1))])),
      )
      is_rational_form(ratio, name) && !contains_function(ratio)
    }
    _ => false
  }
}

///|
fn split_fraction_simple(expr : Expr) -> (Expr, Expr) {
  match @symcore.normalize_legacy_expr(expr) {
    Number(n) =>
      if n.is_integral() {
        (Number(n), int(1))
      } else {
        (
          Number(@symnum.BigRational::from_bigint(n.numerator())),
          Number(@symnum.BigRational::from_bigint(n.denominator())),
        )
      }
    Add(args) => {
      if args.is_empty() {
        return (int(0), int(1))
      }
      let numerators : Array[Expr] = []
      let denominators : Array[Expr] = []
      for arg in args {
        let (num, den) = split_fraction_simple(arg)
        numerators.push(num)
        denominators.push(den)
      }
      let same_denom = {
        let first = denominators[0]
        let mut all_same = true
        for i in 1..<denominators.length() {
          if @symcore.compare_expr(first, denominators[i]) != 0 {
            all_same = false
            break
          }
        }
        all_same
      }
      if same_denom {
        return (
          @symcore.normalize_legacy_expr(@symcore.add(numerators)),
          denominators[0],
        )
      }
      let summed : Array[Expr] = []
      for i in 0..<numerators.length() {
        let factors : Array[Expr] = [numerators[i]]
        for j in 0..<denominators.length() {
          if i != j {
            factors.push(denominators[j])
          }
        }
        summed.push(@symcore.normalize_legacy_expr(@symcore.mul(factors)))
      }
      (
        @symcore.normalize_legacy_expr(@symcore.add(summed)),
        @symcore.normalize_legacy_expr(@symcore.mul(denominators)),
      )
    }
    Pow(base, Number(exp)) =>
      if exp.is_integral() {
        let (num0, den0) = split_fraction_simple(base)
        let power = exp.numerator().to_int()
        if power == 0 {
          return (int(1), int(1))
        }
        let (num, den, abs_power) = if power < 0 {
          (den0, num0, -power)
        } else {
          (num0, den0, power)
        }
        let out_num = if @symcore.compare_expr(num, int(1)) == 0 {
          int(1)
        } else {
          @symcore.normalize_legacy_expr(@symcore.pow(num, int(abs_power)))
        }
        let out_den = if @symcore.compare_expr(den, int(1)) == 0 {
          int(1)
        } else {
          @symcore.normalize_legacy_expr(@symcore.pow(den, int(abs_power)))
        }
        (out_num, out_den)
      } else {
        (Pow(base, Number(exp)), int(1))
      }
    Mul(args) => {
      let num_factors : Array[Expr] = Array::new()
      let den_factors : Array[Expr] = Array::new()
      for arg in args {
        let (n, d) = split_fraction_simple(arg)
        if n != int(1) {
          num_factors.push(n)
        }
        if d != int(1) {
          den_factors.push(d)
        }
      }
      (@symcore.mul(num_factors), @symcore.mul(den_factors))
    }
    other => (other, int(1))
  }
}

///|
fn collect_one_symbol(expr : Expr, sym : Expr) -> Expr {
  match expr {
    Add(args) => {
      let bins : Map[Int, Expr] = Map([])
      let leftover : Array[Expr] = Array::new()
      for arg in args {
        match decompose_sym_power(arg, sym) {
          Some((exp, coeff)) =>
            match bins.get(exp) {
              Some(prev) => bins[exp] = @symcore.add([prev, coeff])
              None => bins[exp] = coeff
            }
          None => leftover.push(arg)
        }
      }
      let exps : Array[Int] = Array::new()
      for exp, _ in bins {
        exps.push(exp)
      }
      exps.sort()
      for i in 0..<exps.length() {
        let idx = exps.length() - 1 - i
        let exp = exps[idx]
        let coeff = bins[exp]
        let term = if exp == 0 {
          coeff
        } else if exp == 1 {
          @symcore.mul([coeff, sym])
        } else {
          @symcore.mul([coeff, @symcore.pow(sym, int(exp))])
        }
        leftover.push(term)
      }
      @symcore.add(leftover)
    }
    _ => expr
  }
}

///|
fn decompose_sym_power(term : Expr, sym : Expr) -> (Int, Expr)? {
  if term == sym {
    return Some((1, int(1)))
  }
  match term {
    Pow(base, Number(e)) if base == sym =>
      if e.is_integral() && e.numerator().to_int() >= 0 {
        Some((e.numerator().to_int(), int(1)))
      } else {
        None
      }
    Mul(args) => {
      let mut exp = 0
      let coeff_factors : Array[Expr] = Array::new()
      for arg in args {
        if arg == sym {
          exp = exp + 1
          continue
        }
        match arg {
          Pow(base, Number(e)) if base == sym => {
            if !e.is_integral() || e.numerator().to_int() < 0 {
              return None
            }
            exp = exp + e.numerator().to_int()
          }
          _ => coeff_factors.push(arg)
        }
      }
      Some((exp, @symcore.mul(coeff_factors)))
    }
    _ => Some((0, term))
  }
}

///|
fn split_coeff_mul(term : Expr) -> (@symnum.BigRational, Expr) {
  match term {
    Number(n) => (n, int(1))
    Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Number(n) => coeff = coeff.mul_r(n)
          _ => rest.push(arg)
        }
      }
      (coeff, @symcore.mul(rest))
    }
    _ => (@symnum.BigRational::one(), term)
  }
}

///|
fn rational_gcd(values : Array[@symnum.BigRational]) -> @symnum.BigRational {
  if values.is_empty() {
    return @symnum.BigRational::one()
  }
  let mut ng = abs_big(values[0].numerator())
  let mut dl = values[0].denominator()
  for i in 1..<values.length() {
    let v = values[i]
    ng = @symnum.gcd_bigint(ng, abs_big(v.numerator()))
    let g = @symnum.gcd_bigint(dl, v.denominator())
    dl = dl.div(g).mul(v.denominator())
  }
  @symnum.BigRational::new(ng, dl) catch {
    _ => @symnum.BigRational::one()
  }
}

///|
fn abs_big(x : BigInt) -> BigInt {
  if x < BigInt::from_int(0) {
    x.neg()
  } else {
    x
  }
}

///|
fn fixpoint_advanced(
  expr : Expr,
  rule : (Expr) -> Expr,
  max_passes? : Int = 8,
) -> Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = rewrite_bottom_up_advanced(cur, rule)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
fn rewrite_bottom_up_advanced(expr : Expr, rule : (Expr) -> Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => {
    rewrite_bottom_up_advanced(child, rule)
  })
  rule(rewritten)
}

///|
fn rewrite_powdenest(expr : Expr) -> Expr {
  match expr {
    Pow(Pow(base, a), b) => @symcore.pow(base, @symcore.mul([a, b]))
    _ =>
      match named_unary_application(expr) {
        Some((name, inner_expr)) =>
          match named_unary_application(inner_expr) {
            Some((inner, x)) if name == "exp" && inner == "log" => x
            _ =>
              match inner_expr {
                Mul(args) if args.length() == 2 => {
                  let mut log_arg : Expr? = None
                  let mut other : Expr? = None
                  for arg in args {
                    match named_unary_application(arg) {
                      Some((inner, x)) if name == "exp" && inner == "log" =>
                        if log_arg is None {
                          log_arg = Some(x)
                        } else {
                          return expr
                        }
                      _ =>
                        if other is None {
                          other = Some(arg)
                        } else {
                          return expr
                        }
                    }
                  }
                  match (log_arg, other) {
                    (Some(x), Some(a)) => @symcore.pow(x, a)
                    _ => expr
                  }
                }
                _ => expr
              }
          }
        None => expr
      }
  }
}

///|
fn rewrite_exptrigsimp(expr : Expr) -> Expr {
  match expr {
    _ =>
      match named_unary_application(expr) {
        Some((name, inner_expr)) =>
          match named_unary_application(inner_expr) {
            Some((inner, x)) if name == "exp" && inner == "log" => x
            _ => expr
          }
        None =>
          match expr {
            Add([a, b]) =>
              match parse_exp_i_pair(a, b) {
                Some((x, sign)) =>
                  if sign == 1 {
                    @symcore.mul([int(2), @symcore.function("cos", [x])])
                  } else {
                    @symcore.mul([
                      int(2),
                      NumberSymbol(ImaginaryUnit),
                      @symcore.function("sin", [x]),
                    ])
                  }
                None =>
                  match parse_cos_i_sin_pair(a, b) {
                    Some((x, sign)) =>
                      if sign == 1 {
                        @symcore.function("exp", [
                          @symcore.mul([NumberSymbol(ImaginaryUnit), x]),
                        ])
                      } else {
                        @symcore.function("exp", [
                          @symcore.mul([int(-1), NumberSymbol(ImaginaryUnit), x]),
                        ])
                      }
                    None => expr
                  }
              }
            _ => expr
          }
      }
  }
}

///|
fn parse_exp_i_pair(a : Expr, b : Expr) -> (Expr, Int)? {
  match (exp_i_arg(a), exp_minus_i_arg(b)) {
    (Some(x), Some(y)) if x == y => Some((x, 1))
    _ =>
      match (exp_i_arg(a), neg_exp_minus_i_arg(b)) {
        (Some(x), Some(y)) if x == y => Some((x, -1))
        _ =>
          match (exp_i_arg(b), exp_minus_i_arg(a)) {
            (Some(x), Some(y)) if x == y => Some((x, 1))
            _ =>
              match (exp_i_arg(b), neg_exp_minus_i_arg(a)) {
                (Some(x), Some(y)) if x == y => Some((x, -1))
                _ => None
              }
          }
      }
  }
}

///|
fn exp_i_arg(expr : Expr) -> Expr? {
  match named_unary_application(expr) {
    Some((name, Mul(args))) if name == "exp" && args.length() == 2 => {
      let mut saw_i = false
      let mut other : Expr? = None
      for arg in args {
        if arg == NumberSymbol(ImaginaryUnit) {
          saw_i = true
        } else if other is None {
          other = Some(arg)
        } else {
          return None
        }
      }
      if saw_i {
        other
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn exp_minus_i_arg(expr : Expr) -> Expr? {
  match named_unary_application(expr) {
    Some((name, Mul(args))) if name == "exp" =>
      if args.length() == 3 {
        let mut saw_neg_one = false
        let mut saw_i = false
        let mut other : Expr? = None
        for arg in args {
          match arg {
            Number(c) if c.compare(@symnum.BigRational::from_int(-1)) == 0 =>
              saw_neg_one = true
            _ if arg == NumberSymbol(ImaginaryUnit) => saw_i = true
            _ => if other is None { other = Some(arg) } else { return None }
          }
        }
        if saw_neg_one && saw_i {
          other
        } else {
          None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn neg_exp_minus_i_arg(expr : Expr) -> Expr? {
  match expr {
    Mul(args) if args.length() == 2 => {
      let mut saw_neg_one = false
      let mut other : Expr? = None
      for arg in args {
        match arg {
          Number(c) if c.compare(@symnum.BigRational::from_int(-1)) == 0 =>
            saw_neg_one = true
          _ => if other is None { other = Some(arg) } else { return None }
        }
      }
      if saw_neg_one {
        match other {
          Some(t) => exp_minus_i_arg(t)
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
fn parse_cos_i_sin_pair(a : Expr, b : Expr) -> (Expr, Int)? {
  match (cos_arg(a), i_sin_arg(b)) {
    (Some(x), Some((y, sign))) if x == y => Some((x, sign))
    _ =>
      match (cos_arg(b), i_sin_arg(a)) {
        (Some(x), Some((y, sign))) if x == y => Some((x, sign))
        _ => None
      }
  }
}

///|
fn cos_arg(expr : Expr) -> Expr? {
  unary_application_arg(expr, "cos")
}

///|
fn i_sin_arg(expr : Expr) -> (Expr, Int)? {
  match expr {
    Mul(args) if args.length() == 2 => {
      let mut saw_i = false
      let mut sin_arg : Expr? = None
      for arg in args {
        if arg == NumberSymbol(ImaginaryUnit) {
          saw_i = true
        } else {
          match unary_application_arg(arg, "sin") {
            Some(x) => sin_arg = Some(x)
            None => return None
          }
        }
      }
      if saw_i {
        match sin_arg {
          Some(x) => Some((x, 1))
          None => None
        }
      } else {
        None
      }
    }
    Mul(args) if args.length() == 3 => {
      let mut sign = 1
      let mut saw_i = false
      let mut sin_arg : Expr? = None
      for arg in args {
        match arg {
          Number(c) =>
            if c.compare(@symnum.BigRational::from_int(-1)) == 0 {
              sign = -1
            } else {
              return None
            }
          _ if arg == NumberSymbol(ImaginaryUnit) => saw_i = true
          _ =>
            match unary_application_arg(arg, "sin") {
              Some(x) => sin_arg = Some(x)
              None => return None
            }
        }
      }
      if saw_i {
        match sin_arg {
          Some(x) => Some((x, sign))
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
fn rewrite_gammasimp(expr : Expr) -> Expr {
  match expr {
    _ =>
      match named_unary_application(expr) {
        Some((name, Add(args))) if name == "gamma" && args.length() == 2 => {
          let mut shifted : Expr? = None
          let mut offset_one = false
          for arg in args {
            match arg {
              Number(n) if n.is_one() => offset_one = true
              _ =>
                if shifted is None {
                  shifted = Some(arg)
                } else {
                  return expr
                }
            }
          }
          if offset_one {
            match shifted {
              Some(x) => @symcore.mul([x, @symcore.function("gamma", [x])])
              None => expr
            }
          } else {
            expr
          }
        }
        Some((name, Number(n))) if name == "gamma" =>
          if n.is_integral() && n.numerator().to_int() > 0 {
            @symcore.function("factorial", [int(n.numerator().to_int() - 1)])
          } else {
            expr
          }
        _ =>
          match expr {
            Mul(args) => simplify_gamma_ratio_mul(args)
            _ => expr
          }
      }
  }
}

///|
fn simplify_gamma_ratio_mul(args : Array[Expr]) -> Expr {
  let numer_gamma : Array[Expr] = Array::new()
  let denom_gamma : Array[Expr] = Array::new()
  let others : Array[Expr] = Array::new()
  for arg in args {
    match gamma_numerator_arg(arg) {
      Some(value) => numer_gamma.push(value)
      None =>
        match gamma_denominator_arg(arg) {
          Some(value) => denom_gamma.push(value)
          None => others.push(arg)
        }
    }
  }
  if numer_gamma.is_empty() || denom_gamma.is_empty() {
    return combsimp(@symcore.mul(args))
  }

  let used_den : Array[Bool] = Array::make(denom_gamma.length(), false)
  let out = others.map(x => x)
  for num_arg in numer_gamma {
    let mut matched = false
    for j in 0..<denom_gamma.length() {
      if used_den[j] {
        continue
      }
      let den_arg = denom_gamma[j]
      match gamma_integer_shift(num_arg, den_arg) {
        Some(steps) => {
          out.push(rising_product_from(den_arg, steps))
          used_den[j] = true
          matched = true
          break
        }
        None =>
          match gamma_integer_shift(den_arg, num_arg) {
            Some(steps) => {
              out.push(
                @symcore.pow(rising_product_from(num_arg, steps), int(-1)),
              )
              used_den[j] = true
              matched = true
              break
            }
            None => ()
          }
      }
    }
    if !matched {
      out.push(@symcore.function("gamma", [num_arg]))
    }
  }

  for j in 0..<denom_gamma.length() {
    if !used_den[j] {
      out.push(
        @symcore.pow(@symcore.function("gamma", [denom_gamma[j]]), int(-1)),
      )
    }
  }
  combsimp(@symcore.mul(out))
}

///|
fn gamma_numerator_arg(expr : Expr) -> Expr? {
  unary_application_arg(expr, "gamma")
}

///|
fn gamma_denominator_arg(expr : Expr) -> Expr? {
  match pow_named_unary_application(expr) {
    Some((name, arg, Number(exp))) =>
      if name == "gamma" && exp.is_integral() && exp.numerator().to_int() == -1 {
        Some(arg)
      } else {
        None
      }
    _ => None
  }
}

///|
fn gamma_integer_shift(target : Expr, base : Expr) -> Int? {
  let (target_norm, target_shift) = split_expr_integer_shift(target)
  let (base_norm, base_shift) = split_expr_integer_shift(base)
  if target_norm != base_norm {
    return None
  }
  let diff = target_shift - base_shift
  if diff > 0 {
    Some(diff)
  } else {
    None
  }
}

///|
fn split_expr_integer_shift(expr : Expr) -> (Expr, Int) {
  match expr {
    Add(args) => {
      let mut shift = 0
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Number(n) if n.is_integral() => shift += n.numerator().to_int()
          _ => rest.push(arg)
        }
      }
      (if rest.is_empty() { int(0) } else { @symcore.add(rest) }, shift)
    }
    Number(n) if n.is_integral() => (int(0), n.numerator().to_int())
    _ => (expr, 0)
  }
}

///|
fn rising_product_from(start : Expr, steps : Int) -> Expr {
  if steps <= 0 {
    return int(1)
  }
  let factors : Array[Expr] = Array::new()
  for i in 0..<steps {
    factors.push(add_small_int(start, i))
  }
  @symcore.mul(factors)
}

///|
fn add_small_int(expr : Expr, offset : Int) -> Expr {
  if offset == 0 {
    expr
  } else {
    @symcore.add([expr, int(offset)])
  }
}

///|
fn rewrite_logcombine(expr : Expr) -> Expr {
  match expr {
    Add(args) => {
      let log_pows : Array[Expr] = Array::new()
      let others : Array[Expr] = Array::new()
      for arg in args {
        match parse_coeff_log(arg) {
          Some((coeff, base)) =>
            log_pows.push(@symcore.pow(base, Number(coeff)))
          None => others.push(arg)
        }
      }
      if log_pows.is_empty() {
        expr
      } else {
        let combined_arg = simplify_rational_structure(@symcore.mul(log_pows))
        let combined = @symcore.function("log", [combined_arg])
        let merged : Array[Expr] = [combined]
        for item in others {
          merged.push(item)
        }
        @symcore.add(merged)
      }
    }
    _ => expr
  }
}

///|
fn parse_coeff_log(term : Expr) -> (@symnum.BigRational, Expr)? {
  match term {
    _ if unary_application_arg(term, "log") is Some(arg) =>
      Some((@symnum.BigRational::one(), arg))
    Mul(args) if args.length() == 2 => {
      let mut coeff : @symnum.BigRational? = None
      let mut log_arg : Expr? = None
      for arg in args {
        match arg {
          Number(c) => coeff = Some(c)
          _ =>
            match unary_application_arg(arg, "log") {
              Some(inner) => log_arg = Some(inner)
              None => return None
            }
        }
      }
      match (coeff, log_arg) {
        (Some(c), Some(arg)) => Some((c, arg))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn rewrite_separatevars(expr : Expr, force? : Bool = false) -> Expr {
  match expr {
    Pow(Mul(factors), exp) =>
      match exp {
        Number(n) =>
          if force || n.is_integral() {
            @symcore.mul(factors.map(f => @symcore.pow(f, exp)))
          } else {
            expr
          }
        _ => expr
      }
    _ => expr
  }
}

///|
fn collect_symbols(expr : Expr, out : Map[String, Bool]) -> Unit {
  match expr {
    Symbol(name) => out[name] = true
    NumberSymbol(_) => ()
    _ =>
      for child in @symcore.children(expr) {
        collect_symbols(child, out)
      }
  }
}

///|
fn is_rational_form(expr : Expr, k_name : String) -> Bool {
  ignore(k_name)
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | NumberSymbol(_) | Boolean(_) =>
      true
    Symbol(_) | Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => true
    UndefinedFunction(_) => false
    Apply(_, args) => {
      for arg in args {
        if !is_rational_form(arg, k_name) {
          return false
        }
      }
      false
    }
    Add(args) | Mul(args) => {
      for arg in args {
        if !is_rational_form(arg, k_name) {
          return false
        }
      }
      true
    }
    Pow(base, Number(e)) => e.is_integral() && is_rational_form(base, k_name)
    Mod(lhs, rhs) =>
      is_rational_form(lhs, k_name) && is_rational_form(rhs, k_name)
    Pow(_, _) => false
    Tuple(_)
    | Dict(_)
    | Relational(_, _, _)
    | Derivative(_, _)
    | Subs(_, _, _)
    | Lambda(_, _) => false
    _ if @symcore.application_parts(expr) is Some(_) => false
    _ => false
  }
}

///|
fn contains_function(expr : Expr) -> Bool {
  match expr {
    _ if @symcore.application_parts(expr) is Some(_) => true
    Derivative(_, _) | Subs(_, _, _) | Lambda(_, _) => true
    _ => {
      for child in @symcore.children(expr) {
        if contains_function(child) {
          return true
        }
      }
      false
    }
  }
}
