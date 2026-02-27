///|
/// Fourier series with symbolic coefficient projection for polynomial/trig inputs.

///|
pub enum FourierSeriesResult {
  Expr(@symcore.Expr)
  Series(FourierSeries)
}

///|
pub struct FourierSeries {
  expr : @symcore.Expr
  x : @symcore.Expr
  a : @symcore.Expr
  b : @symcore.Expr
}

///|
priv enum TrigKind {
  Sin
  Cos
}

///|
fn depends_on(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(s) => s == name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => depends_on(child, name))
    @symcore.Expr::Pow(base, exp) =>
      depends_on(base, name) || depends_on(exp, name)
    @symcore.Expr::Function(_, args) =>
      args.any(child => depends_on(child, name))
    _ => false
  }
}

///|
fn expr_div(num : @symcore.Expr, den : @symcore.Expr) -> @symcore.Expr {
  expr_mul(num, @symcore.pow(den, @symcore.int(-1)))
}

///|
fn subst_var(
  expr : @symcore.Expr,
  var_name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = value
  @symcore.subst(expr, env)
}

///|
fn split_linear_coeff(
  arg : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
) -> @symcore.Expr? {
  if arg == x {
    return Some(@symcore.int(1))
  }
  match arg {
    @symcore.Expr::Mul(args) => {
      let mut seen_x = false
      let coeff_args : Array[@symcore.Expr] = Array::new()
      for factor in args {
        if factor == x {
          if seen_x {
            return None
          }
          seen_x = true
        } else if contains_symbol(factor, var_name) {
          return None
        } else {
          coeff_args.push(factor)
        }
      }
      if !seen_x {
        return None
      }
      if coeff_args.is_empty() {
        Some(@symcore.int(1))
      } else {
        Some(@symcore.mul(coeff_args))
      }
    }
    _ => None
  }
}

///|
fn parse_linear_trig(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
) -> (TrigKind, @symcore.Expr)? {
  match expr {
    @symcore.Expr::Function(name, args) if args.length() == 1 => {
      let kind = if name == "sin" {
        Some(TrigKind::Sin)
      } else if name == "cos" {
        Some(TrigKind::Cos)
      } else {
        None
      }
      match kind {
        Some(k) =>
          match split_linear_coeff(args[0], x, var_name) {
            Some(freq) => Some((k, freq))
            None => None
          }
        None => None
      }
    }
    _ => None
  }
}

///|
fn eval_at(
  expr : @symcore.Expr,
  var_name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  subst_var(expr, var_name, value)
}

///|
fn integrate_linear_trig(
  kind : TrigKind,
  freq : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  if is_zero_expr(freq) {
    return match kind {
      TrigKind::Sin => @symcore.int(0)
      TrigKind::Cos => expr_sub(b, a)
    }
  }
  let arg_x = expr_mul(freq, x)
  let anti = match kind {
    TrigKind::Sin => expr_neg(expr_div(@symcore.function("cos", [arg_x]), freq))
    TrigKind::Cos => expr_div(@symcore.function("sin", [arg_x]), freq)
  }
  let at_b = eval_at(anti, var_name, b)
  let at_a = eval_at(anti, var_name, a)
  expr_sub(at_b, at_a)
}

///|
fn integral_poly(
  poly : Array[@symcore.Expr],
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  let mut acc = @symcore.int(0)
  for i in 0..<poly.length() {
    let coeff = poly[i]
    if is_zero_expr(coeff) {
      continue
    }
    let p = i + 1
    let anti_term =
      expr_mul(coeff, expr_div(@symcore.pow(x, @symcore.int(p)), @symcore.int(p)))
    let at_b = eval_at(anti_term, var_name, b)
    let at_a = eval_at(anti_term, var_name, a)
    acc = expr_add(acc, expr_sub(at_b, at_a))
  }
  acc
}

///|
fn int_pow_sin(
  m : Int,
  freq : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  if is_zero_expr(freq) {
    return @symcore.int(0)
  }
  if m == 0 {
    return expr_neg(expr_div(@symcore.function("cos", [expr_mul(freq, x)]), freq))
  }
  let xm = @symcore.pow(x, @symcore.int(m))
  let head = expr_neg(expr_div(expr_mul(xm, @symcore.function("cos", [expr_mul(freq, x)])), freq))
  let tail = expr_mul(
    expr_div(@symcore.int(m), freq),
    int_pow_cos(m - 1, freq, x),
  )
  expr_add(head, tail)
}

///|
fn int_pow_cos(
  m : Int,
  freq : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  if is_zero_expr(freq) {
    let p = m + 1
    return expr_div(@symcore.pow(x, @symcore.int(p)), @symcore.int(p))
  }
  if m == 0 {
    return expr_div(@symcore.function("sin", [expr_mul(freq, x)]), freq)
  }
  let xm = @symcore.pow(x, @symcore.int(m))
  let head = expr_div(expr_mul(xm, @symcore.function("sin", [expr_mul(freq, x)])), freq)
  let tail = expr_mul(
    expr_div(@symcore.int(m), freq),
    int_pow_sin(m - 1, freq, x),
  )
  expr_sub(head, tail)
}

///|
fn integral_poly_trig(
  poly : Array[@symcore.Expr],
  kind : TrigKind,
  freq : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  let mut acc = @symcore.int(0)
  for i in 0..<poly.length() {
    let coeff = poly[i]
    if is_zero_expr(coeff) {
      continue
    }
    let anti = match kind {
      TrigKind::Sin => int_pow_sin(i, freq, x)
      TrigKind::Cos => int_pow_cos(i, freq, x)
    }
    let scaled = expr_mul(coeff, anti)
    let at_b = eval_at(scaled, var_name, b)
    let at_a = eval_at(scaled, var_name, a)
    acc = expr_add(acc, expr_sub(at_b, at_a))
  }
  acc
}

///|
fn integrate_expr(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Add(args) => {
      let mut acc = @symcore.int(0)
      for term in args {
        match integrate_expr(term, x, var_name, a, b) {
          Some(v) => acc = expr_add(acc, v)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let const_factors : Array[@symcore.Expr] = Array::new()
      let dep_factors : Array[@symcore.Expr] = Array::new()
      for factor in args {
        if contains_symbol(factor, var_name) {
          dep_factors.push(factor)
        } else {
          const_factors.push(factor)
        }
      }
      let coeff = if const_factors.is_empty() {
        @symcore.int(1)
      } else {
        @symcore.mul(const_factors)
      }
      if dep_factors.is_empty() {
        return Some(expr_mul(coeff, expr_sub(b, a)))
      }
      if dep_factors.length() == 1 {
        return match integrate_expr(dep_factors[0], x, var_name, a, b) {
          Some(v) => Some(expr_mul(coeff, v))
          None => None
        }
      }
      if dep_factors.length() == 2 {
        let u = dep_factors[0]
        let v = dep_factors[1]
        match (parse_linear_trig(u, x, var_name), parse_linear_trig(v, x, var_name)) {
          (Some((ku, fu)), Some((kv, fv))) => {
            let sum_freq = expr_add(fu, fv)
            let diff_freq = expr_sub(fu, fv)
            let diff_cos =
              if fu == fv {
                @symcore.int(1)
              } else {
                @symcore.function("cos", [expr_mul(diff_freq, x)])
              }
            let diff_sin =
              if fu == fv {
                @symcore.int(0)
              } else {
                @symcore.function("sin", [expr_mul(diff_freq, x)])
              }
            let half = rational_expr(1, 2)
            let projected = match (ku, kv) {
              (TrigKind::Sin, TrigKind::Sin) =>
                expr_mul(
                  half,
                  expr_sub(
                    diff_cos,
                    @symcore.function("cos", [expr_mul(sum_freq, x)]),
                  ),
                )
              (TrigKind::Cos, TrigKind::Cos) =>
                expr_mul(
                  half,
                  expr_add(
                    diff_cos,
                    @symcore.function("cos", [expr_mul(sum_freq, x)]),
                  ),
                )
              (TrigKind::Sin, TrigKind::Cos) =>
                expr_mul(
                  half,
                  expr_add(
                    @symcore.function("sin", [expr_mul(sum_freq, x)]),
                    diff_sin,
                  ),
                )
              (TrigKind::Cos, TrigKind::Sin) =>
                expr_mul(
                  half,
                  expr_sub(
                    @symcore.function("sin", [expr_mul(sum_freq, x)]),
                    diff_sin,
                  ),
                )
            }
            return match integrate_expr(projected, x, var_name, a, b) {
              Some(v0) => Some(expr_mul(coeff, v0))
              None => None
            }
          }
          _ => ()
        }
        match (poly_from_expr(u, x), parse_linear_trig(v, x, var_name)) {
          (Some(poly), Some((kind, freq))) => {
            let projected = integral_poly_trig(poly, kind, freq, x, var_name, a, b)
            return Some(expr_mul(coeff, projected))
          }
          _ => ()
        }
        match (poly_from_expr(v, x), parse_linear_trig(u, x, var_name)) {
          (Some(poly), Some((kind, freq))) => {
            let projected = integral_poly_trig(poly, kind, freq, x, var_name, a, b)
            return Some(expr_mul(coeff, projected))
          }
          _ => ()
        }
      }
      None
    }
    _ =>
      match poly_from_expr(expr, x) {
        Some(poly) => Some(integral_poly(poly, x, var_name, a, b))
        None =>
          match parse_linear_trig(expr, x, var_name) {
            Some((kind, freq)) =>
              Some(integrate_linear_trig(kind, freq, x, var_name, a, b))
            None => None
          }
      }
  }
}

///|
fn symbolic_integral(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Integral", [
    expr,
    @symcore.function("Tuple", [x, a, b]),
  ])
}

///|
pub fn fourier_series(
  expr : @symcore.Expr,
  limits? : Array[@symcore.Expr] = [],
  finite? : Bool = true,
) -> FourierSeriesResult raise {
  let _ = finite
  if limits.is_empty() {
    return FourierSeriesResult::Expr(expr)
  }
  if limits.length() != 3 {
    fail("fourier_series requires limits (x, a, b)")
  }
  let x = limits[0]
  let a = limits[1]
  let b = limits[2]
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  if !depends_on(expr, var_name) {
    return FourierSeriesResult::Expr(expr)
  }
  FourierSeriesResult::Series(FourierSeries::{ expr, x, a, b })
}

///|
pub fn FourierSeries::function(self : FourierSeries) -> @symcore.Expr {
  self.expr
}

///|
pub fn FourierSeries::x(self : FourierSeries) -> @symcore.Expr {
  self.x
}

///|
pub fn FourierSeries::period(self : FourierSeries) -> @symcore.Expr {
  expr_sub(self.b, self.a)
}

///|
fn FourierSeries::norm_factor(self : FourierSeries) -> @symcore.Expr {
  expr_div(@symcore.int(2), self.period())
}

///|
fn FourierSeries::omega(self : FourierSeries, n : Int) -> @symcore.Expr {
  let pi = @symcore.symbol("pi")
  let minus_pi = @symcore.mul([@symcore.int(-1), pi])
  let two_pi = @symcore.mul([@symcore.int(2), pi])
  if (self.a == minus_pi && self.b == pi) ||
    (self.a == @symcore.int(0) && self.b == two_pi) {
    return @symcore.int(n)
  }
  let two_n_pi = @symcore.mul([
    @symcore.int(2 * n),
    pi,
  ])
  expr_div(two_n_pi, self.period())
}

///|
pub fn FourierSeries::a0(self : FourierSeries) -> @symcore.Expr raise {
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  match integrate_expr(self.expr, self.x, var_name, self.a, self.b) {
    Some(v) => expr_mul(self.norm_factor(), v)
    None =>
      expr_mul(
        self.norm_factor(),
        symbolic_integral(self.expr, self.x, self.a, self.b),
      )
  }
}

///|
pub fn FourierSeries::an(self : FourierSeries, n : Int) -> @symcore.Expr raise {
  if n <= 0 {
    return @symcore.int(0)
  }
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  let basis = @symcore.function("cos", [expr_mul(self.omega(n), self.x)])
  let integrand = expr_mul(self.expr, basis)
  match integrate_expr(integrand, self.x, var_name, self.a, self.b) {
    Some(v) => expr_mul(self.norm_factor(), v)
    None =>
      expr_mul(
        self.norm_factor(),
        symbolic_integral(integrand, self.x, self.a, self.b),
      )
  }
}

///|
pub fn FourierSeries::bn(self : FourierSeries, n : Int) -> @symcore.Expr raise {
  if n <= 0 {
    return @symcore.int(0)
  }
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  let basis = @symcore.function("sin", [expr_mul(self.omega(n), self.x)])
  let integrand = expr_mul(self.expr, basis)
  match integrate_expr(integrand, self.x, var_name, self.a, self.b) {
    Some(v) => expr_mul(self.norm_factor(), v)
    None =>
      expr_mul(
        self.norm_factor(),
        symbolic_integral(integrand, self.x, self.a, self.b),
      )
  }
}

///|
pub fn FourierSeries::term(
  self : FourierSeries,
  n : Int,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("fourier term requires non-negative index")
  }
  if n == 0 {
    return expr_mul(rational_expr(1, 2), self.a0())
  }
  let wnx = expr_mul(self.omega(n), self.x)
  let cos_part = expr_mul(self.an(n), @symcore.function("cos", [wnx]))
  let sin_part = expr_mul(self.bn(n), @symcore.function("sin", [wnx]))
  expr_add(cos_part, sin_part)
}

///|
pub fn FourierSeries::as_leading_term(
  self : FourierSeries,
  x : @symcore.Expr,
) -> @symcore.Expr raise {
  if x != self.x {
    fail("fourier leading term variable mismatch")
  }
  self.term(1)
}

///|
pub fn FourierSeries::truncate(
  self : FourierSeries,
  n? : Int = 6,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("fourier truncate requires non-negative n")
  }
  let mut acc = @symcore.int(0)
  let mut i = 0
  while i < n {
    acc = expr_add(acc, self.term(i))
    i += 1
  }
  acc
}

///|
pub fn FourierSeries::sigma_approximation(
  self : FourierSeries,
  n : Int,
) -> @symcore.Expr raise {
  if n <= 0 {
    return @symcore.int(0)
  }
  let mut acc = @symcore.int(0)
  let pi = @symcore.symbol("pi")
  let mut i = 0
  while i < n {
    let term = self.term(i)
    if !is_zero_expr(term) {
      let factor = if i == 0 {
        @symcore.int(1)
      } else {
        @symcore.function("sinc", [expr_mul(pi, rational_expr(i, n))])
      }
      acc = expr_add(acc, expr_mul(factor, term))
    }
    i += 1
  }
  acc
}

///|
pub fn FourierSeries::shift(
  self : FourierSeries,
  amount : @symcore.Expr,
) -> FourierSeries {
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => ""
  }
  if var_name == "" {
    return self
  }
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = @symcore.add([self.x, amount])
  let new_expr = @symcore.subst(self.expr, env)
  FourierSeries::{ expr: new_expr, x: self.x, a: self.a, b: self.b }
}

///|
pub fn FourierSeries::shiftx(
  self : FourierSeries,
  amount : @symcore.Expr,
) -> FourierSeries {
  self.shift(amount)
}

///|
pub fn FourierSeries::scale(
  self : FourierSeries,
  factor : @symcore.Expr,
) -> FourierSeries {
  let new_expr = expr_mul(factor, self.expr)
  FourierSeries::{ expr: new_expr, x: self.x, a: self.a, b: self.b }
}

///|
pub fn FourierSeries::scalex(
  self : FourierSeries,
  factor : @symcore.Expr,
) -> FourierSeries {
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => ""
  }
  if var_name == "" {
    return self
  }
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = expr_mul(factor, self.x)
  let new_expr = @symcore.subst(self.expr, env)
  FourierSeries::{ expr: new_expr, x: self.x, a: self.a, b: self.b }
}
