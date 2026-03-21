///|
/// Return `(num, den)` so `expr = num/den` in symbolic form.
pub fn fraction(expr : Expr) -> (Expr, Expr) {
  split_fraction_simple(expr)
}

///|
/// Return the numerator of `expr`.
pub fn numer(expr : Expr) -> Expr {
  let (n, _) = fraction(expr)
  n
}

///|
/// Return the denominator of `expr`.
pub fn denom(expr : Expr) -> Expr {
  let (_, d) = fraction(expr)
  d
}

///|
/// Collect additive terms by powers of `sym`.
pub fn collect(expr : Expr, sym : Expr) -> Expr {
  match sym {
    Expr::Symbol(_) => collect_one_symbol(expr, sym)
    _ => expr
  }
}

///|
/// Recursively apply `collect` to `expr` and its children.
pub fn rcollect(expr : Expr, sym : Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => rcollect(child, sym))
  collect(rewritten, sym)
}

///|
/// Factor a shared rational constant out of additive terms.
pub fn collect_const(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
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
          @symcore.number(new_coeff)
        } else if new_coeff.is_one() {
          rest
        } else {
          @symcore.mul([@symcore.number(new_coeff), rest])
        }
        scaled.push(scaled_term)
      }
      @symcore.mul([@symcore.number(g), @symcore.add(scaled)])
    }
    _ => expr
  }
}

///|
/// Denest nested powers when exponent rules allow.
pub fn powdenest(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_powdenest, max_passes~)
}

///|
/// Switch between exp/trig forms to simplify expressions.
pub fn exptrigsimp(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_exptrigsimp, max_passes~)
}

///|
/// Simplify Gamma-function identities.
pub fn gammasimp(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_gammasimp, max_passes~)
}

///|
/// Combine additive/multiplicative log terms into compact logarithmic form.
pub fn logcombine(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_advanced(expr, rewrite_logcombine, max_passes~)
}

///|
/// Separate multiplicative factors by symbolic variable sets.
pub fn separatevars(expr : Expr, force? : Bool = false) -> Expr {
  rewrite_bottom_up_advanced(expr, child => rewrite_separatevars(child, force~))
}

///|
/// Replace symbols with positivity-assumed dummies and return a restoration map.
pub fn posify(expr : Expr) -> (Expr, Map[String, Expr]) {
  let symbols : Map[String, Bool] = {}
  collect_symbols(expr, symbols)
  let env : Map[String, Expr] = {}
  let restore : Map[String, Expr] = {}
  for name, _ in symbols {
    let new_name = "_\{name}"
    env[name] = symbol(new_name)
    restore[new_name] = symbol(name)
  }
  (@symcore.subst(expr, env), restore)
}

///|
/// Return the hypergeometric term ratio `f(k+1)/f(k)` when it exists.
pub fn hypersimp(f : Expr, k : Expr) -> Expr {
  match k {
    Expr::Symbol(name) => {
      let env : Map[String, Expr] = {}
      env[name] = @symcore.add([k, int(1)])
      let fk1 = @symcore.subst(f, env)
      combsimp(simplify(@symcore.mul([fk1, @symcore.pow(f, int(-1))])))
    }
    _ => int(0)
  }
}

///|
/// Check whether two sequences are hyper-similar in index `k`.
pub fn hypersimilar(f : Expr, g : Expr, k : Expr) -> Bool {
  match k {
    Expr::Symbol(name) => {
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
  match expr {
    Expr::Number(n) =>
      if n.is_integral() {
        (expr, int(1))
      } else {
        (
          @symcore.number(@symnum.BigRational::from_bigint(n.numerator())),
          @symcore.number(@symnum.BigRational::from_bigint(n.denominator())),
        )
      }
    Expr::Pow(base, Expr::Number(exp)) =>
      if exp.is_integral() && exp.numerator().to_int() < 0 {
        let p = -exp.numerator().to_int()
        (int(1), @symcore.pow(base, int(p)))
      } else {
        (expr, int(1))
      }
    Expr::Mul(args) => {
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
    _ => (expr, int(1))
  }
}

///|
fn collect_one_symbol(expr : Expr, sym : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
      let bins : Map[Int, Expr] = {}
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
    Expr::Pow(base, Expr::Number(e)) if base == sym =>
      if e.is_integral() && e.numerator().to_int() >= 0 {
        Some((e.numerator().to_int(), int(1)))
      } else {
        None
      }
    Expr::Mul(args) => {
      let mut exp = 0
      let coeff_factors : Array[Expr] = Array::new()
      for arg in args {
        if arg == sym {
          exp = exp + 1
          continue
        }
        match arg {
          Expr::Pow(base, Expr::Number(e)) if base == sym => {
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
    Expr::Number(n) => (n, int(1))
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Number(n) => coeff = coeff.mul_r(n)
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
  if x.op_lt(BigInt::from_int(0)) {
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
    Expr::Pow(Expr::Pow(base, a), b) => @symcore.pow(base, @symcore.mul([a, b]))
    Expr::Function(name, [Expr::Function(inner, [x])]) =>
      if name == "exp" && inner == "log" {
        x
      } else {
        expr
      }
    Expr::Function(name, [Expr::Mul([a, Expr::Function(inner, [x])])]) =>
      if name == "exp" && inner == "log" {
        @symcore.pow(x, a)
      } else {
        expr
      }
    Expr::Function(name, [Expr::Mul([Expr::Function(inner, [x]), a])]) =>
      if name == "exp" && inner == "log" {
        @symcore.pow(x, a)
      } else {
        expr
      }
    _ => expr
  }
}

///|
fn rewrite_exptrigsimp(expr : Expr) -> Expr {
  match expr {
    Expr::Function(name, [Expr::Function(inner, [x])]) =>
      if name == "exp" && inner == "log" {
        x
      } else {
        expr
      }
    Expr::Add([a, b]) =>
      match parse_exp_i_pair(a, b) {
        Some((x, sign)) =>
          if sign == 1 {
            @symcore.mul([int(2), @symcore.function("cos", [x])])
          } else {
            @symcore.mul([int(2), symbol("I"), @symcore.function("sin", [x])])
          }
        None =>
          match parse_cos_i_sin_pair(a, b) {
            Some((x, sign)) =>
              if sign == 1 {
                @symcore.function("exp", [@symcore.mul([symbol("I"), x])])
              } else {
                @symcore.function("exp", [
                  @symcore.mul([int(-1), symbol("I"), x]),
                ])
              }
            None => expr
          }
      }
    _ => expr
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
  match expr {
    Expr::Function(name, [Expr::Mul([a, b])]) =>
      if name == "exp" && a == symbol("I") {
        Some(b)
      } else if name == "exp" && b == symbol("I") {
        Some(a)
      } else {
        None
      }
    _ => None
  }
}

///|
fn exp_minus_i_arg(expr : Expr) -> Expr? {
  match expr {
    Expr::Function(name, [Expr::Mul(args)]) if name == "exp" =>
      if args.length() == 3 && args[0] == int(-1) && args[1] == symbol("I") {
        Some(args[2])
      } else if args.length() == 3 &&
        args[0] == int(-1) &&
        args[2] == symbol("I") {
        Some(args[1])
      } else {
        None
      }
    _ => None
  }
}

///|
fn neg_exp_minus_i_arg(expr : Expr) -> Expr? {
  match expr {
    Expr::Mul([Expr::Number(c), t]) =>
      if c.compare(@symnum.BigRational::from_int(-1)) == 0 {
        exp_minus_i_arg(t)
      } else {
        None
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
  match expr {
    Expr::Function(name, [x]) if name == "cos" => Some(x)
    _ => None
  }
}

///|
fn i_sin_arg(expr : Expr) -> (Expr, Int)? {
  match expr {
    Expr::Mul([i, Expr::Function(name, [x])]) =>
      if i == symbol("I") && name == "sin" {
        Some((x, 1))
      } else {
        None
      }
    Expr::Mul([Expr::Function(name, [x]), i]) =>
      if i == symbol("I") && name == "sin" {
        Some((x, 1))
      } else {
        None
      }
    Expr::Mul([Expr::Number(c), i, Expr::Function(name, [x])]) =>
      if c.compare(@symnum.BigRational::from_int(-1)) == 0 &&
        i == symbol("I") &&
        name == "sin" {
        Some((x, -1))
      } else {
        None
      }
    _ => None
  }
}

///|
fn rewrite_gammasimp(expr : Expr) -> Expr {
  match expr {
    Expr::Function(name, [Expr::Add([x, Expr::Number(n)])]) =>
      if name == "gamma" && n.is_one() {
        @symcore.mul([x, @symcore.function("gamma", [x])])
      } else {
        expr
      }
    Expr::Function(name, [Expr::Number(n)]) if name == "gamma" =>
      if n.is_integral() && n.numerator().to_int() > 0 {
        @symcore.function("factorial", [int(n.numerator().to_int() - 1)])
      } else {
        expr
      }
    Expr::Mul(args) => combsimp(@symcore.mul(args))
    _ => expr
  }
}

///|
fn rewrite_logcombine(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
      let log_pows : Array[Expr] = Array::new()
      let others : Array[Expr] = Array::new()
      for arg in args {
        match parse_coeff_log(arg) {
          Some((coeff, base)) =>
            log_pows.push(@symcore.pow(base, @symcore.number(coeff)))
          None => others.push(arg)
        }
      }
      if log_pows.is_empty() {
        expr
      } else {
        let combined = @symcore.function("log", [@symcore.mul(log_pows)])
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
    Expr::Function(name, [arg]) if name == "log" =>
      Some((@symnum.BigRational::one(), arg))
    Expr::Mul([Expr::Number(c), Expr::Function(name, [arg])]) =>
      if name == "log" {
        Some((c, arg))
      } else {
        None
      }
    Expr::Mul([Expr::Function(name, [arg]), Expr::Number(c)]) =>
      if name == "log" {
        Some((c, arg))
      } else {
        None
      }
    _ => None
  }
}

///|
fn rewrite_separatevars(expr : Expr, force? : Bool = false) -> Expr {
  match expr {
    Expr::Pow(Expr::Mul(factors), exp) =>
      match exp {
        Expr::Number(n) =>
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
    Expr::Symbol(name) => out[name] = true
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
    Expr::Number(_) => true
    Expr::Symbol(_) => true
    Expr::Add(args) | Expr::Mul(args) => {
      for arg in args {
        if !is_rational_form(arg, k_name) {
          return false
        }
      }
      true
    }
    Expr::Pow(base, Expr::Number(e)) =>
      e.is_integral() && is_rational_form(base, k_name)
    Expr::Pow(_, _) => false
    Expr::Function(_, _) => false
  }
}

///|
fn contains_function(expr : Expr) -> Bool {
  match expr {
    Expr::Function(_, _) => true
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
