///|
/// Front doors for formal power series objects.
///
/// Current Limits:
/// - The public API is centered on local truncation, coefficient access, and multivariate wrappers.
/// - Unsupported expressions can still fall back to plain expression results.

///|
/// Represent the result of requesting a formal power series.
///
/// - Does: Distinguishes between a successful formal series object and a plain expression fallback.
/// - Input: Either a source `Expr` or a `FormalPowerSeries` value, depending on the variant.
/// - Returns: One `FpsResult` value.
/// - Limits: The `Expr` variant means the requested formal series object was not constructed.
pub enum FpsResult {
  Expr(@symcore.Expr)
  Series(FormalPowerSeries)
}

///|
/// Store one univariate formal power series request.
///
/// - Does: Keeps the source expression, the expansion variable, and the expansion center together.
/// - Input: Raw `Expr` fields for the source expression, variable, and center.
/// - Returns: One `FormalPowerSeries` value.
/// - Limits: The struct stores the request as-is; actual expansion checks happen in the front-door functions.
pub struct FormalPowerSeries {
  expr : @symcore.Expr
  x : @symcore.Expr
  x0 : @symcore.Expr
}

///|
/// Store one multivariate formal power series request.
///
/// - Does: Keeps the source expression together with the variable list and expansion centers.
/// - Input: One source `Expr`, an array of variables, and an equally sized array of centers.
/// - Returns: One `FormalPowerSeriesMulti` value.
/// - Limits: Validation of variables and center rank happens in `fps_multivariate`.
pub struct FormalPowerSeriesMulti {
  expr : @symcore.Expr
  vars : Array[@symcore.Expr]
  x0s : Array[@symcore.Expr]
}

///|
fn fps_depends_on(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(s) => s == name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => fps_depends_on(child, name))
    @symcore.Expr::Pow(base, exp) =>
      fps_depends_on(base, name) || fps_depends_on(exp, name)
    _ =>
      match @symcore.application_args(expr) {
        Some(args) => args.any(child => fps_depends_on(child, name))
        None => false
      }
  }
}

///|
fn series_poly_shift(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
  n : Int,
) -> (Array[@symcore.Expr], Bool)? raise {
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fps variable must be a Symbol")
  }
  let t = @symcore.Expr::Symbol("__fps_t")
  let env : Map[String, @symcore.Expr] = Map([])
  env[var_name] = @symcore.add([x0, t])
  let shifted = @symcore.subst(expr, env)
  series_poly(shifted, t, n)
}

///|
fn poly_expr_with_shift(
  poly : Array[@symcore.Expr],
  x : @symcore.Expr,
  x0 : @symcore.Expr,
  n : Int,
  with_order : Bool,
) -> @symcore.Expr {
  let t = @symcore.Expr::Symbol("__fps_t")
  let poly_expr = poly_to_expr(poly, t, n)
  let back : Map[String, @symcore.Expr] = Map([])
  let shift_expr = @symcore.add([x, expr_neg(x0)])
  back["__fps_t"] = shift_expr
  if with_order {
    match x0 {
      @symcore.Expr::Number(n0) if !n0.is_zero() => {
        let poly_sub = @symcore.subst(poly_expr, back)
        let order_term = @symcore.function("O", [
          @symcore.pow(shift_expr, @symcore.int(n)),
          @symcore.function("Tuple", [x, x0]),
        ])
        @symcore.add([poly_sub, order_term])
      }
      _ => {
        let series_expr = @symcore.add([
          poly_expr,
          big_o(@symcore.pow(t, @symcore.int(n))),
        ])
        @symcore.subst(series_expr, back)
      }
    }
  } else {
    @symcore.subst(poly_expr, back)
  }
}

///|
fn fps_strip_order_expr(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    _ if @symcore.application_has_name(expr, "O") => @symcore.int(0)
    @symcore.Expr::Add(args) => {
      let kept : Array[@symcore.Expr] = Array::new()
      for arg in args {
        if @symcore.application_has_name(arg, "O") {
          ()
        } else {
          kept.push(arg)
        }
      }
      if kept.is_empty() {
        @symcore.int(0)
      } else if kept.length() == 1 {
        kept[0]
      } else {
        @symcore.add(kept)
      }
    }
    _ => expr
  }
}

///|
fn fps_factorial_expr(n : Int) -> @symcore.Expr {
  let mut fact = BigInt::from_int(1)
  let mut i = 2
  while i <= n {
    fact = fact.mul(BigInt::from_int(i))
    i = i + 1
  }
  @symcore.Expr::Number(safe_rational(BigInt::from_int(1), fact))
}

///|
fn fps_eval_at(
  expr : @symcore.Expr,
  name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = Map([])
  env[name] = value
  @symcore.subst(expr, env)
}

///|
fn fps_derivative_term(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
  n : Int,
) -> @symcore.Expr {
  let name = match x {
    @symcore.Expr::Symbol(s) => s
    _ => ""
  }
  if name == "" {
    return @symcore.int(0)
  }
  let mut deriv = expr
  let mut i = 0
  while i < n {
    deriv = @symcalculus.diff(deriv, x)
    i += 1
  }
  let value = fps_eval_at(deriv, name, x0)
  let coeff = expr_mul(value, fps_factorial_expr(n))
  if n == 0 {
    coeff
  } else {
    expr_mul(
      coeff,
      @symcore.pow(@symcore.add([x, expr_neg(x0)]), @symcore.int(n)),
    )
  }
}

///|
/// Request a univariate formal power series object.
///
/// - Does: Tries to build a formal power series wrapper for `expr` around `x0`.
/// - Input: `expr` is the source expression, `x` is the expansion Symbol, and the remaining arguments configure the request.
/// - Returns: `FpsResult::Series` on success or `FpsResult::Expr` when the expression is returned unchanged.
/// - Limits: Raises if the variable is missing or not a Symbol; several optional flags are currently accepted for compatibility but not deeply interpreted.
pub fn fps(
  expr : @symcore.Expr,
  x? : @symcore.Expr,
  x0? : @symcore.Expr = @symcore.int(0),
  dir? : Int = 1,
  hyper? : Bool = true,
  order? : Int = 4,
  rational? : Bool = true,
  full? : Bool = false,
) -> FpsResult raise {
  let _ = dir
  let _ = hyper
  let _ = rational
  let _ = full
  let x_expr = match x {
    Some(v) => v
    None => fail("fps requires a variable")
  }
  let var_name = match x_expr {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fps variable must be a Symbol")
  }
  if !fps_depends_on(expr, var_name) {
    return FpsResult::Expr(expr)
  }
  let test_n = if order <= 0 { 1 } else { order }
  match series_poly_shift(expr, x_expr, x0, test_n) {
    Some(_) => FpsResult::Series(FormalPowerSeries::{ expr, x: x_expr, x0 })
    None => FpsResult::Expr(expr)
  }
}

///|
/// Return the original expression stored in a formal series object.
///
/// - Does: Exposes the source expression wrapped by the formal series.
/// - Input: One `FormalPowerSeries` value.
/// - Returns: One `Expr`.
/// - Limits: This accessor does not evaluate or truncate anything.
pub fn FormalPowerSeries::function(self : FormalPowerSeries) -> @symcore.Expr {
  self.expr
}

///|
/// Truncate a formal power series and keep the order marker.
///
/// - Does: Expands the stored series up to order `n` and preserves the trailing order term when available.
/// - Input: One `FormalPowerSeries` value and a non-negative truncation order.
/// - Returns: One truncated series `Expr`.
/// - Limits: Raises if `n` is negative; unsupported inputs fall back to the package-level `series` front door.
pub fn FormalPowerSeries::truncate(
  self : FormalPowerSeries,
  n? : Int = 6,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("truncate requires non-negative n")
  }
  match series_poly_shift(self.expr, self.x, self.x0, n) {
    Some((poly, _)) => poly_expr_with_shift(poly, self.x, self.x0, n, true)
    None => series(self.expr, x=self.x, x0=self.x0, n~)
  }
}

///|
/// Return only the polynomial part of a formal power series.
///
/// - Does: Truncates the stored series up to order `n` and removes any trailing order marker.
/// - Input: One `FormalPowerSeries` value and a non-negative truncation order.
/// - Returns: One polynomial `Expr`.
/// - Limits: Raises if `n` is negative; unsupported inputs fall back to the package-level `series` front door and strip the order term afterward.
pub fn FormalPowerSeries::polynomial(
  self : FormalPowerSeries,
  n? : Int = 6,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("polynomial requires non-negative n")
  }
  match series_poly_shift(self.expr, self.x, self.x0, n) {
    Some((poly, _)) => poly_expr_with_shift(poly, self.x, self.x0, n, false)
    None => fps_strip_order_expr(series(self.expr, x=self.x, x0=self.x0, n~))
  }
}

///|
/// Return one coefficient term from a formal power series.
///
/// - Does: Extracts the `n`-th coefficient term of the stored series.
/// - Input: One `FormalPowerSeries` value and a non-negative coefficient index.
/// - Returns: One `Expr` for the requested term.
/// - Limits: Raises if `n` is negative; unsupported inputs fall back to repeated differentiation.
pub fn FormalPowerSeries::coeff(
  self : FormalPowerSeries,
  n : Int,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("coeff requires non-negative n")
  }
  let need = n + 1
  match series_poly_shift(self.expr, self.x, self.x0, need) {
    Some((poly, _)) =>
      if n < poly.length() {
        let t = @symcore.Expr::Symbol("__fps_t")
        let term = if n == 0 {
          poly[n]
        } else {
          expr_mul(poly[n], @symcore.pow(t, @symcore.int(n)))
        }
        let back : Map[String, @symcore.Expr] = Map([])
        back["__fps_t"] = @symcore.add([self.x, expr_neg(self.x0)])
        @symcore.subst(term, back)
      } else {
        @symcore.int(0)
      }
    None => fps_derivative_term(self.expr, self.x, self.x0, n)
  }
}

///|
/// Return a slice of coefficient terms from a formal power series.
///
/// - Does: Collects the terms with indices in `[start, stop)` using the given positive step.
/// - Input: One `FormalPowerSeries` value, non-negative bounds, and a positive step.
/// - Returns: An `Array[Expr]` containing the requested terms.
/// - Limits: Raises if the bounds are negative or the step is not positive.
pub fn FormalPowerSeries::slice(
  self : FormalPowerSeries,
  start : Int,
  stop : Int,
  step? : Int = 1,
) -> Array[@symcore.Expr] raise {
  if start < 0 || stop < 0 || step <= 0 {
    fail("slice requires non-negative bounds and positive step")
  }
  if stop <= start {
    return []
  }
  match series_poly_shift(self.expr, self.x, self.x0, stop) {
    Some((poly, _)) => {
      let out : Array[@symcore.Expr] = Array::new()
      let t = @symcore.Expr::Symbol("__fps_t")
      let back : Map[String, @symcore.Expr] = Map([])
      back["__fps_t"] = @symcore.add([self.x, expr_neg(self.x0)])
      let mut i = start
      while i < stop {
        let coeff = if i < poly.length() { poly[i] } else { @symcore.int(0) }
        let term = if i == 0 {
          coeff
        } else {
          expr_mul(coeff, @symcore.pow(t, @symcore.int(i)))
        }
        out.push(@symcore.subst(term, back))
        i += step
      }
      out
    }
    None => {
      let out : Array[@symcore.Expr] = Array::new()
      let mut i = start
      while i < stop {
        out.push(self.coeff(i))
        i += step
      }
      out
    }
  }
}

///|
/// Build a multivariate formal power series wrapper.
///
/// - Does: Stores a multivariate expansion request with one center for each variable.
/// - Input: `expr` is the source expression, `vars` is a non-empty array of Symbols, and `x0s` is either empty or matched in length.
/// - Returns: One `FormalPowerSeriesMulti` value.
/// - Limits: Raises if the variable list is empty, if a variable is not a Symbol, or if the center list length does not match.
pub fn fps_multivariate(
  expr : @symcore.Expr,
  vars : Array[@symcore.Expr],
  x0s? : Array[@symcore.Expr] = [],
) -> FormalPowerSeriesMulti raise {
  guard !vars.is_empty() else { fail("fps_multivariate requires variables") }
  let centers : Array[@symcore.Expr] = Array::new()
  if x0s.is_empty() {
    for _ in vars {
      centers.push(@symcore.int(0))
    }
  } else {
    guard x0s.length() == vars.length() else {
      fail("fps_multivariate centers length mismatch")
    }
    for c in x0s {
      centers.push(c)
    }
  }
  for v in vars {
    match v {
      @symcore.Expr::Symbol(_) => ()
      _ => fail("fps_multivariate variable must be a Symbol")
    }
  }
  FormalPowerSeriesMulti::{ expr, vars, x0s: centers }
}

///|
/// Truncate a multivariate formal power series.
///
/// - Does: Applies repeated one-variable truncation across the stored variables.
/// - Input: One `FormalPowerSeriesMulti` value and a non-negative truncation order.
/// - Returns: One truncated multivariate `Expr`.
/// - Limits: Raises if `order` is negative; truncation is performed variable by variable.
pub fn FormalPowerSeriesMulti::truncate(
  self : FormalPowerSeriesMulti,
  order? : Int = 4,
) -> @symcore.Expr raise {
  if order < 0 {
    fail("fps_multivariate truncate requires non-negative order")
  }
  let mut out = self.expr
  for i in 0..<self.vars.length() {
    out = series(out, x=self.vars[i], x0=self.x0s[i], n=order)
    out = fps_strip_order_expr(out)
  }
  out
}

///|
/// Return one multivariate coefficient term.
///
/// - Does: Differentiates by the requested orders, evaluates at the stored centers, and rebuilds the corresponding monomial term.
/// - Input: One `FormalPowerSeriesMulti` value and an integer order for each variable.
/// - Returns: One `Expr` for the requested multivariate term.
/// - Limits: Raises if the order rank does not match the variable count or if any order is negative.
pub fn FormalPowerSeriesMulti::coeff(
  self : FormalPowerSeriesMulti,
  orders : Array[Int],
) -> @symcore.Expr raise {
  guard orders.length() == self.vars.length() else {
    fail("fps_multivariate coeff rank mismatch")
  }
  let mut deriv = self.expr
  let mut scale = @symcore.int(1)
  for i in 0..<orders.length() {
    let k = orders[i]
    if k < 0 {
      fail("fps_multivariate coeff requires non-negative orders")
    }
    let mut j = 0
    while j < k {
      deriv = @symcalculus.diff(deriv, self.vars[i])
      j += 1
    }
    scale = expr_mul(scale, fps_factorial_expr(k))
  }
  for i in 0..<self.vars.length() {
    let name = match self.vars[i] {
      @symcore.Expr::Symbol(s) => s
      _ => ""
    }
    deriv = fps_eval_at(deriv, name, self.x0s[i])
  }
  let coeff = expr_mul(deriv, scale)
  let terms : Array[@symcore.Expr] = [coeff]
  for i in 0..<orders.length() {
    let k = orders[i]
    if k == 0 {
      continue
    }
    let shift = @symcore.add([self.vars[i], expr_neg(self.x0s[i])])
    terms.push(@symcore.pow(shift, @symcore.int(k)))
  }
  if terms.length() == 1 {
    terms[0]
  } else {
    @symcore.mul(terms)
  }
}

///|
/// Return the leading term of a formal power series.
///
/// - Does: Extracts the first non-zero term of the stored series with respect to `x`.
/// - Input: One `FormalPowerSeries` value and the variable to compare against.
/// - Returns: One `Expr` for the leading term.
/// - Limits: Raises if the requested variable does not match the stored one.
pub fn FormalPowerSeries::as_leading_term(
  self : FormalPowerSeries,
  x : @symcore.Expr,
) -> @symcore.Expr raise {
  if x != self.x {
    fail("fps-as-leading-term variable mismatch")
  }
  let n = 6
  match series_poly_shift(self.expr, self.x, self.x0, n) {
    Some((poly, _)) => {
      let mut k = 0
      while k < poly.length() {
        if !is_zero_expr(poly[k]) {
          let t = @symcore.Expr::Symbol("__fps_t")
          let term = if k == 0 {
            poly[k]
          } else {
            expr_mul(poly[k], @symcore.pow(t, @symcore.int(k)))
          }
          let back : Map[String, @symcore.Expr] = Map([])
          back["__fps_t"] = @symcore.add([self.x, expr_neg(self.x0)])
          return @symcore.subst(term, back)
        }
        k += 1
      }
      @symcore.int(0)
    }
    None => {
      let poly = fps_strip_order_expr(self.polynomial(n~))
      if poly == @symcore.int(0) {
        @symcore.int(0)
      } else {
        poly
      }
    }
  }
}
