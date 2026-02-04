///|
/// Fourier series (minimal finite support for basic trig cases).

///|
pub enum FourierSeriesResult {
  Expr(@symcore.Expr)
  Series(FourierSeries)
}

///|
enum FourierKind {
  Sin
  Cos
  Generic
}

///|
pub struct FourierSeries {
  expr : @symcore.Expr
  x : @symcore.Expr
  a : @symcore.Expr
  b : @symcore.Expr
  kind : FourierKind
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
fn detect_kind(expr : @symcore.Expr, x : @symcore.Expr) -> FourierKind {
  match expr {
    @symcore.Expr::Function(name, args) =>
      if args.length() == 1 && args[0] == x {
        if name == "sin" {
          FourierKind::Sin
        } else if name == "cos" {
          FourierKind::Cos
        } else {
          FourierKind::Generic
        }
      } else {
        FourierKind::Generic
      }
    _ => FourierKind::Generic
  }
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
  let kind = detect_kind(expr, x)
  match kind {
    FourierKind::Generic => FourierSeriesResult::Expr(expr)
    _ => FourierSeriesResult::Series(FourierSeries::{ expr, x, a, b, kind })
  }
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
pub fn FourierSeries::term(
  self : FourierSeries,
  n : Int,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("fourier term requires non-negative index")
  }
  match self.kind {
    FourierKind::Sin => if n == 1 { self.expr } else { zero_expr() }
    FourierKind::Cos => if n == 1 { self.expr } else { zero_expr() }
    FourierKind::Generic => fail("fourier term not implemented")
  }
}

///|
pub fn FourierSeries::as_leading_term(
  self : FourierSeries,
  x : @symcore.Expr,
) -> @symcore.Expr raise {
  if x != self.x {
    fail("fourier leading term variable mismatch")
  }
  match self.kind {
    FourierKind::Sin | FourierKind::Cos => self.expr
    FourierKind::Generic => fail("fourier leading term not implemented")
  }
}

///|
pub fn FourierSeries::truncate(
  self : FourierSeries,
  n? : Int = 6,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("fourier truncate requires non-negative n")
  }
  let mut acc = zero_expr()
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
    return zero_expr()
  }
  let mut acc = zero_expr()
  let pi = @symcore.symbol("pi")
  let mut i = 0
  while i < n {
    let term = self.term(i)
    if !is_zero_expr(term) {
      let frac = if i == 0 { @symcore.int(0) } else { rational_expr(i, n) }
      let arg = expr_mul(pi, frac)
      let factor = @symcore.function("sinc", [arg])
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
  FourierSeries::{
    expr: new_expr,
    x: self.x,
    a: self.a,
    b: self.b,
    kind: FourierKind::Generic,
  }
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
  FourierSeries::{
    expr: new_expr,
    x: self.x,
    a: self.a,
    b: self.b,
    kind: FourierKind::Generic,
  }
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
  FourierSeries::{
    expr: new_expr,
    x: self.x,
    a: self.a,
    b: self.b,
    kind: FourierKind::Generic,
  }
}
