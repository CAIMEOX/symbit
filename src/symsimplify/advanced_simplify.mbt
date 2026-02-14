///|
pub fn fraction(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr) {
  split_fraction_simple(expr)
}

///|
pub fn numer(expr : @symcore.Expr) -> @symcore.Expr {
  let (n, _) = fraction(expr)
  n
}

///|
pub fn denom(expr : @symcore.Expr) -> @symcore.Expr {
  let (_, d) = fraction(expr)
  d
}

///|
pub fn collect(expr : @symcore.Expr, sym : @symcore.Expr) -> @symcore.Expr {
  match sym {
    @symcore.Expr::Symbol(_) => collect_one_symbol(expr, sym)
    _ => expr
  }
}

///|
pub fn rcollect(expr : @symcore.Expr, sym : @symcore.Expr) -> @symcore.Expr {
  let rewritten = @symcore.map_children(expr, child => rcollect(child, sym))
  collect(rewritten, sym)
}

///|
pub fn collect_const(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      if args.is_empty() {
        return expr
      }
      let terms : Array[(@symnum.BigRational, @symcore.Expr)] = Array::new()
      for arg in args {
        terms.push(split_coeff_mul(arg))
      }
      let g = rational_gcd(terms.map(t => t.0))
      if g.is_zero() || g.is_one() {
        return expr
      }
      let scaled : Array[@symcore.Expr] = Array::new()
      for pair in terms {
        let coeff = pair.0
        let rest = pair.1
        let new_coeff = try! coeff.div_r(g)
        let scaled_term = if rest == @symcore.int(1) {
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
pub fn powdenest(
  expr : @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  fixpoint_advanced(expr, rewrite_powdenest, max_passes~)
}

///|
pub fn exptrigsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  fixpoint_advanced(expr, rewrite_exptrigsimp, max_passes~)
}

///|
pub fn gammasimp(
  expr : @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  fixpoint_advanced(expr, rewrite_gammasimp, max_passes~)
}

///|
pub fn logcombine(
  expr : @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  fixpoint_advanced(expr, rewrite_logcombine, max_passes~)
}

///|
pub fn separatevars(
  expr : @symcore.Expr,
  force? : Bool = false,
) -> @symcore.Expr {
  rewrite_bottom_up_advanced(expr, child => rewrite_separatevars(child, force~))
}

///|
pub fn posify(
  expr : @symcore.Expr,
) -> (@symcore.Expr, Map[String, @symcore.Expr]) {
  let symbols : Map[String, Bool] = {}
  collect_symbols(expr, symbols)
  let env : Map[String, @symcore.Expr] = {}
  let restore : Map[String, @symcore.Expr] = {}
  for name, _ in symbols {
    let new_name = "_\{name}"
    env[name] = @symcore.symbol(new_name)
    restore[new_name] = @symcore.symbol(name)
  }
  (@symcore.subst(expr, env), restore)
}

///|
pub fn hypersimp(
  f : @symcore.Expr,
  k : @symcore.Expr,
) -> @symcore.Expr {
  match k {
    @symcore.Expr::Symbol(name) => {
      let env : Map[String, @symcore.Expr] = {}
      env[name] = @symcore.add([k, @symcore.int(1)])
      let fk1 = @symcore.subst(f, env)
      combsimp(simplify(@symcore.mul([fk1, @symcore.pow(f, @symcore.int(-1))])))
    }
    _ => @symcore.int(0)
  }
}

///|
pub fn hypersimilar(
  f : @symcore.Expr,
  g : @symcore.Expr,
  k : @symcore.Expr,
) -> Bool {
  match k {
    @symcore.Expr::Symbol(name) => {
      let rf = hypersimp(f, k)
      let rg = hypersimp(g, k)
      let ratio = combsimp(
        simplify(@symcore.mul([rf, @symcore.pow(rg, @symcore.int(-1))])),
      )
      is_rational_form(ratio, name) && !contains_function(ratio)
    }
    _ => false
  }
}

///|
fn split_fraction_simple(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr) {
  match expr {
    @symcore.Expr::Number(n) =>
      if n.is_integral() {
        (expr, @symcore.int(1))
      } else {
        (
          @symcore.number(@symnum.BigRational::from_bigint(n.numerator())),
          @symcore.number(@symnum.BigRational::from_bigint(n.denominator())),
        )
      }
    @symcore.Expr::Pow(base, @symcore.Expr::Number(exp)) => {
      if exp.is_integral() && exp.numerator().to_int() < 0 {
        let p = -exp.numerator().to_int()
        (@symcore.int(1), @symcore.pow(base, @symcore.int(p)))
      } else {
        (expr, @symcore.int(1))
      }
    }
    @symcore.Expr::Mul(args) => {
      let num_factors : Array[@symcore.Expr] = Array::new()
      let den_factors : Array[@symcore.Expr] = Array::new()
      for arg in args {
        let (n, d) = split_fraction_simple(arg)
        if n != @symcore.int(1) {
          num_factors.push(n)
        }
        if d != @symcore.int(1) {
          den_factors.push(d)
        }
      }
      (@symcore.mul(num_factors), @symcore.mul(den_factors))
    }
    _ => (expr, @symcore.int(1))
  }
}

///|
fn collect_one_symbol(expr : @symcore.Expr, sym : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let bins : Map[Int, @symcore.Expr] = {}
      let leftover : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match decompose_sym_power(arg, sym) {
          Some((exp, coeff)) => {
            match bins.get(exp) {
              Some(prev) => bins[exp] = @symcore.add([prev, coeff])
              None => bins[exp] = coeff
            }
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
          @symcore.mul([coeff, @symcore.pow(sym, @symcore.int(exp))])
        }
        leftover.push(term)
      }
      @symcore.add(leftover)
    }
    _ => expr
  }
}

///|
fn decompose_sym_power(
  term : @symcore.Expr,
  sym : @symcore.Expr,
) -> (Int, @symcore.Expr)? {
  if term == sym {
    return Some((1, @symcore.int(1)))
  }
  match term {
    @symcore.Expr::Pow(base, @symcore.Expr::Number(e)) if base == sym => {
      if e.is_integral() && e.numerator().to_int() >= 0 {
        Some((e.numerator().to_int(), @symcore.int(1)))
      } else {
        None
      }
    }
    @symcore.Expr::Mul(args) => {
      let mut exp = 0
      let coeff_factors : Array[@symcore.Expr] = Array::new()
      for arg in args {
        if arg == sym {
          exp = exp + 1
          continue
        }
        match arg {
          @symcore.Expr::Pow(base, @symcore.Expr::Number(e)) if base == sym => {
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
fn split_coeff_mul(term : @symcore.Expr) -> (@symnum.BigRational, @symcore.Expr) {
  match term {
    @symcore.Expr::Number(n) => (n, @symcore.int(1))
    @symcore.Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) => coeff = coeff.mul_r(n)
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
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
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
fn rewrite_bottom_up_advanced(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
) -> @symcore.Expr {
  let rewritten = @symcore.map_children(
    expr,
    child => rewrite_bottom_up_advanced(child, rule),
  )
  rule(rewritten)
}

///|
fn rewrite_powdenest(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Pow(@symcore.Expr::Pow(base, a), b) => @symcore.pow(base, @symcore.mul([a, b]))
    @symcore.Expr::Function(name, [@symcore.Expr::Function(inner, [x])]) =>
      if name == "exp" && inner == "log" {
        x
      } else {
        expr
      }
    @symcore.Expr::Function(name, [@symcore.Expr::Mul([a, @symcore.Expr::Function(inner, [x])])]) =>
      if name == "exp" && inner == "log" {
        @symcore.pow(x, a)
      } else {
        expr
      }
    @symcore.Expr::Function(name, [@symcore.Expr::Mul([@symcore.Expr::Function(inner, [x]), a])]) =>
      if name == "exp" && inner == "log" {
        @symcore.pow(x, a)
      } else {
        expr
      }
    _ => expr
  }
}

///|
fn rewrite_exptrigsimp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, [@symcore.Expr::Function(inner, [x])]) => {
      if name == "exp" && inner == "log" {
        x
      } else {
        expr
      }
    }
    @symcore.Expr::Add([a, b]) => {
      match parse_exp_i_pair(a, b) {
        Some((x, sign)) => {
          if sign == 1 {
            @symcore.mul([@symcore.int(2), @symcore.function("cos", [x])])
          } else {
            @symcore.mul([
              @symcore.int(2),
              @symcore.symbol("I"),
              @symcore.function("sin", [x]),
            ])
          }
        }
        None => {
          match parse_cos_i_sin_pair(a, b) {
            Some((x, sign)) => {
              if sign == 1 {
                @symcore.function("exp", [@symcore.mul([@symcore.symbol("I"), x])])
              } else {
                @symcore.function("exp", [
                  @symcore.mul([@symcore.int(-1), @symcore.symbol("I"), x]),
                ])
              }
            }
            None => expr
          }
        }
      }
    }
    _ => expr
  }
}

///|
fn parse_exp_i_pair(
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> (@symcore.Expr, Int)? {
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
fn exp_i_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function(name, [@symcore.Expr::Mul([a, b])]) =>
      if name == "exp" && a == @symcore.symbol("I") {
        Some(b)
      } else if name == "exp" && b == @symcore.symbol("I") {
        Some(a)
      } else {
        None
      }
    _ => None
  }
}

///|
fn exp_minus_i_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function(name, [@symcore.Expr::Mul(args)]) if name == "exp" =>
      if args.length() == 3 &&
        args[0] == @symcore.int(-1) &&
        args[1] == @symcore.symbol("I") {
        Some(args[2])
      } else if args.length() == 3 &&
        args[0] == @symcore.int(-1) &&
        args[2] == @symcore.symbol("I") {
        Some(args[1])
      } else {
        None
      }
    _ => None
  }
}

///|
fn neg_exp_minus_i_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Mul([@symcore.Expr::Number(c), t]) =>
      if c.compare(@symnum.BigRational::from_int(-1)) == 0 {
        exp_minus_i_arg(t)
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_cos_i_sin_pair(
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> (@symcore.Expr, Int)? {
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
fn cos_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function(name, [x]) if name == "cos" => Some(x)
    _ => None
  }
}

///|
fn i_sin_arg(expr : @symcore.Expr) -> (@symcore.Expr, Int)? {
  match expr {
    @symcore.Expr::Mul([i, @symcore.Expr::Function(name, [x])]) =>
      if i == @symcore.symbol("I") && name == "sin" {
        Some((x, 1))
      } else {
        None
      }
    @symcore.Expr::Mul([@symcore.Expr::Function(name, [x]), i]) =>
      if i == @symcore.symbol("I") && name == "sin" {
        Some((x, 1))
      } else {
        None
      }
    @symcore.Expr::Mul([@symcore.Expr::Number(c), i, @symcore.Expr::Function(name, [x])]) =>
      if c.compare(@symnum.BigRational::from_int(-1)) == 0 &&
        i == @symcore.symbol("I") &&
        name == "sin" {
        Some((x, -1))
      } else {
        None
      }
    _ => None
  }
}

///|
fn rewrite_gammasimp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, [@symcore.Expr::Add([x, @symcore.Expr::Number(n)])]) =>
      if name == "gamma" && n.is_one() {
        @symcore.mul([x, @symcore.function("gamma", [x])])
      } else {
        expr
      }
    @symcore.Expr::Function(name, [@symcore.Expr::Number(n)]) if name == "gamma" =>
      if n.is_integral() && n.numerator().to_int() > 0 {
        @symcore.function("factorial", [@symcore.int(n.numerator().to_int() - 1)])
      } else {
        expr
      }
    @symcore.Expr::Mul(args) => combsimp(@symcore.mul(args))
    _ => expr
  }
}

///|
fn rewrite_logcombine(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let log_pows : Array[@symcore.Expr] = Array::new()
      let others : Array[@symcore.Expr] = Array::new()
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
        let merged : Array[@symcore.Expr] = [combined]
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
fn parse_coeff_log(term : @symcore.Expr) -> (@symnum.BigRational, @symcore.Expr)? {
  match term {
    @symcore.Expr::Function(name, [arg]) if name == "log" =>
      Some((@symnum.BigRational::one(), arg))
    @symcore.Expr::Mul([@symcore.Expr::Number(c), @symcore.Expr::Function(name, [arg])]) =>
      if name == "log" {
        Some((c, arg))
      } else {
        None
      }
    @symcore.Expr::Mul([@symcore.Expr::Function(name, [arg]), @symcore.Expr::Number(c)]) =>
      if name == "log" {
        Some((c, arg))
      } else {
        None
      }
    _ => None
  }
}

///|
fn rewrite_separatevars(expr : @symcore.Expr, force? : Bool = false) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Pow(@symcore.Expr::Mul(factors), exp) =>
      match exp {
        @symcore.Expr::Number(n) =>
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
fn collect_symbols(expr : @symcore.Expr, out : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => out[name] = true
    _ =>
      for child in @symcore.children(expr) {
        collect_symbols(child, out)
      }
  }
}

///|
fn is_rational_form(expr : @symcore.Expr, k_name : String) -> Bool {
  ignore(k_name)
  match expr {
    @symcore.Expr::Number(_) => true
    @symcore.Expr::Symbol(_) => true
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) => {
      for arg in args {
        if !is_rational_form(arg, k_name) {
          return false
        }
      }
      true
    }
    @symcore.Expr::Pow(base, @symcore.Expr::Number(e)) =>
      e.is_integral() && is_rational_form(base, k_name)
    @symcore.Expr::Pow(_, _) => false
    @symcore.Expr::Function(_, _) => false
  }
}

///|
fn contains_function(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Function(_, _) => true
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
