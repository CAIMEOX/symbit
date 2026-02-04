///|
/// Formal power series utilities (pure MoonBit).

///|
pub enum FpsResult {
  Expr(@symcore.Expr)
  Series(FormalPowerSeries)
}

///|
pub struct FormalPowerSeries {
  expr : @symcore.Expr
  x : @symcore.Expr
  x0 : @symcore.Expr
}

///|
fn fps_depends_on(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(s) => s == name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => fps_depends_on(child, name))
    @symcore.Expr::Pow(base, exp) =>
      fps_depends_on(base, name) || fps_depends_on(exp, name)
    @symcore.Expr::Function(_, args) =>
      args.any(child => fps_depends_on(child, name))
    _ => false
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
  let t = @symcore.symbol("__fps_t")
  let env : Map[String, @symcore.Expr] = {}
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
  let t = @symcore.symbol("__fps_t")
  let poly_expr = poly_to_expr(poly, t, n)
  let back : Map[String, @symcore.Expr] = {}
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
pub fn FormalPowerSeries::function(self : FormalPowerSeries) -> @symcore.Expr {
  self.expr
}

///|
pub fn FormalPowerSeries::truncate(
  self : FormalPowerSeries,
  n? : Int = 6,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("truncate requires non-negative n")
  }
  match series_poly_shift(self.expr, self.x, self.x0, n) {
    Some((poly, _)) => poly_expr_with_shift(poly, self.x, self.x0, n, true)
    None => fail("fps-truncate-not-implemented")
  }
}

///|
pub fn FormalPowerSeries::polynomial(
  self : FormalPowerSeries,
  n? : Int = 6,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("polynomial requires non-negative n")
  }
  match series_poly_shift(self.expr, self.x, self.x0, n) {
    Some((poly, _)) => poly_expr_with_shift(poly, self.x, self.x0, n, false)
    None => fail("fps-polynomial-not-implemented")
  }
}

///|
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
        let t = @symcore.symbol("__fps_t")
        let term = if n == 0 {
          poly[n]
        } else {
          expr_mul(poly[n], @symcore.pow(t, @symcore.int(n)))
        }
        let back : Map[String, @symcore.Expr] = {}
        back["__fps_t"] = @symcore.add([self.x, expr_neg(self.x0)])
        @symcore.subst(term, back)
      } else {
        zero_expr()
      }
    None => fail("fps-coeff-not-implemented")
  }
}

///|
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
      let t = @symcore.symbol("__fps_t")
      let back : Map[String, @symcore.Expr] = {}
      back["__fps_t"] = @symcore.add([self.x, expr_neg(self.x0)])
      let mut i = start
      while i < stop {
        let coeff = if i < poly.length() { poly[i] } else { zero_expr() }
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
    None => fail("fps-slice-not-implemented")
  }
}

///|
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
          let t = @symcore.symbol("__fps_t")
          let term = if k == 0 {
            poly[k]
          } else {
            expr_mul(poly[k], @symcore.pow(t, @symcore.int(k)))
          }
          let back : Map[String, @symcore.Expr] = {}
          back["__fps_t"] = @symcore.add([self.x, expr_neg(self.x0)])
          return @symcore.subst(term, back)
        }
        k += 1
      }
      zero_expr()
    }
    None => fail("fps-leading-term-not-implemented")
  }
}
