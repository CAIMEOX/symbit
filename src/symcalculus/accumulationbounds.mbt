///|
/// Accumulation-bounds helpers.
///
/// Current Limits:
/// - Bounds are represented as `AccumBounds(min, max)` function applications.
/// - Arithmetic is exact for simple finite rational endpoints and conservative
///   for symbolic or infinite endpoints.
/// - Advanced interval simplification and assumption-driven ordering are not
///   complete.

///|
/// Expression alias used by the calculus package.
///
/// - Does: Re-exports the expression type used by calculus front doors.
/// - Input: Any `@symcore.Expr` value.
/// - Returns: The same underlying expression type.
/// - Limits: This is an alias only and adds no calculus-specific behavior.
pub type Expr = @symcore.Expr

///|
/// Rational-number alias used by finite-difference and interval helpers.
///
/// - Does: Re-exports the rational type used for exact numeric endpoints.
/// - Input: Any `@symnum.BigRational` value.
/// - Returns: The same underlying rational type.
/// - Limits: This is an alias only and adds no interval-specific behavior.
pub type BigRational = @symnum.BigRational

///|
suberror AccumBoundsError {
  InvalidBounds(String)
} derive(Debug, Eq)

///|
priv enum SimpleEndpoint {
  Finite(BigRational)
  PosInf
  NegInf
  Nan
  Other(Expr)
}

///|
fn expr_finite(n : BigRational) -> Expr {
  @symcore.Expr::Number(n)
}

///|
fn expr_number(expr : Expr) -> BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn simple_endpoint(expr : Expr) -> SimpleEndpoint {
  match expr {
    Expr::Number(n) => SimpleEndpoint::Finite(n)
    Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
    | Expr::Symbol("oo") => SimpleEndpoint::PosInf
    Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN) | Expr::Symbol("nan") =>
      SimpleEndpoint::Nan
    Expr::Mul(args) if args.length() == 2 => {
      let mut saw_neg_one = false
      let mut saw_pos_inf = false
      for arg in args {
        match arg {
          Expr::Number(n) if n.compare(BigRational::from_int(-1)) == 0 =>
            saw_neg_one = true
          Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
          | Expr::Symbol("oo") => saw_pos_inf = true
          _ => return SimpleEndpoint::Other(expr)
        }
      }
      if saw_neg_one && saw_pos_inf {
        SimpleEndpoint::NegInf
      } else {
        SimpleEndpoint::Other(expr)
      }
    }
    _ => SimpleEndpoint::Other(expr)
  }
}

///|
fn simple_to_expr(s : SimpleEndpoint) -> Expr {
  match s {
    SimpleEndpoint::Finite(n) => expr_finite(n)
    SimpleEndpoint::PosInf =>
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
    SimpleEndpoint::NegInf =>
      @symcore.mul([
        @symcore.int(-1),
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
      ])
    SimpleEndpoint::Nan =>
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)
    SimpleEndpoint::Other(e) => e
  }
}

///|
fn rat_zero() -> BigRational {
  BigRational::zero()
}

///|
fn rat_one() -> BigRational {
  BigRational::one()
}

///|
fn rat_add(a : BigRational, b : BigRational) -> BigRational {
  a.add_r(b)
}

///|
fn rat_mul(a : BigRational, b : BigRational) -> BigRational {
  a.mul_r(b)
}

///|
fn rat_div(a : BigRational, b : BigRational) -> BigRational? {
  guard !b.is_zero() else { None }
  (try? a.div_r(b) : Result[BigRational, @symnum.RationalError]).to_option()
}

///|
fn rat_abs(x : BigRational) -> BigRational {
  if x.compare(rat_zero()) < 0 {
    x.neg_r()
  } else {
    x
  }
}

///|
fn rat_min(a : BigRational, b : BigRational) -> BigRational {
  if a.compare(b) <= 0 {
    a
  } else {
    b
  }
}

///|
fn rat_max(a : BigRational, b : BigRational) -> BigRational {
  if a.compare(b) >= 0 {
    a
  } else {
    b
  }
}

///|
fn simple_add(a : SimpleEndpoint, b : SimpleEndpoint) -> SimpleEndpoint {
  match (a, b) {
    (SimpleEndpoint::Finite(x), SimpleEndpoint::Finite(y)) =>
      SimpleEndpoint::Finite(rat_add(x, y))
    (SimpleEndpoint::PosInf, SimpleEndpoint::NegInf) => SimpleEndpoint::Nan
    (SimpleEndpoint::NegInf, SimpleEndpoint::PosInf) => SimpleEndpoint::Nan
    (SimpleEndpoint::PosInf, _) => SimpleEndpoint::PosInf
    (_, SimpleEndpoint::PosInf) => SimpleEndpoint::PosInf
    (SimpleEndpoint::NegInf, _) => SimpleEndpoint::NegInf
    (_, SimpleEndpoint::NegInf) => SimpleEndpoint::NegInf
    (SimpleEndpoint::Nan, _) => SimpleEndpoint::Nan
    (_, SimpleEndpoint::Nan) => SimpleEndpoint::Nan
    (SimpleEndpoint::Other(e), _) => SimpleEndpoint::Other(e)
    (_, SimpleEndpoint::Other(e)) => SimpleEndpoint::Other(e)
  }
}

///|
fn simple_is_finite(a : SimpleEndpoint) -> Bool {
  match a {
    SimpleEndpoint::Finite(_) => true
    _ => false
  }
}

///|
fn finite_value(a : SimpleEndpoint) -> BigRational {
  match a {
    SimpleEndpoint::Finite(x) => x
    _ => rat_zero()
  }
}

///|
fn accum_unpack(expr : Expr) -> (Expr, Expr)? {
  match @symcore.application_args(expr) {
    Some(args) if @symcore.application_has_name(expr, "AccumBounds", arity=2) =>
      Some((args[0], args[1]))
    _ => None
  }
}

///|
/// Test whether an expression is an `AccumBounds(min, max)` wrapper.
///
/// - Does: Checks the symbolic head and arity of an accumulation-bounds object.
/// - Input: One expression.
/// - Returns: `true` when the expression is `AccumBounds(min, max)`.
/// - Limits: Does not validate endpoint ordering or endpoint types.
pub fn accum_is_bounds(expr : Expr) -> Bool {
  accum_unpack(expr) is Some(_)
}

///|
/// Build an accumulation-bounds object from lower and upper expressions.
///
/// When both endpoints are numeric, the constructor rejects reversed bounds and
/// collapses equal endpoints to the endpoint expression itself.
///
/// - Does: Builds an accumulation-bounds object from lower and upper endpoints.
/// - Input: Two endpoint expressions.
/// - Returns: `AccumBounds(min, max)`, a collapsed endpoint, or raises
///   `AccumBoundsError` for reversed numeric endpoints.
/// - Limits: Symbolic endpoint ordering is not proved.
pub fn accum_bounds(min : Expr, max : Expr) -> Expr raise AccumBoundsError {
  if @symcore.compare_expr(min, max) == 0 {
    return min
  }
  match (expr_number(min), expr_number(max)) {
    (Some(a), Some(b)) =>
      if a.compare(b) > 0 {
        raise AccumBoundsError::InvalidBounds(
          "Lower limit should be smaller than upper limit",
        )
      } else {
        @symcore.function("AccumBounds", [min, max])
      }
    _ => @symcore.function("AccumBounds", [min, max])
  }
}

///|
fn accum_bounds_ordered(min : Expr, max : Expr) -> Expr {
  if @symcore.compare_expr(min, max) == 0 {
    min
  } else {
    @symcore.function("AccumBounds", [min, max])
  }
}

///|
/// Return the lower endpoint of an accumulation-bounds object.
///
/// Returns `None` when `expr` is not an accumulation-bounds wrapper.
///
/// - Does: Extracts the lower endpoint from an accumulation-bounds object.
/// - Input: One expression.
/// - Returns: `Some(min)` for bounds input, otherwise `None`.
/// - Limits: Does not simplify or validate the endpoint.
pub fn accum_min(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((min, _)) => Some(min)
    None => None
  }
}

///|
/// Return the upper endpoint of an accumulation-bounds object.
///
/// - Does: Extracts the upper endpoint from an accumulation-bounds object.
/// - Input: One expression.
/// - Returns: `Some(max)` for bounds input, otherwise `None`.
/// - Limits: Does not simplify or validate the endpoint.
pub fn accum_max(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((_, max)) => Some(max)
    None => None
  }
}

///|
/// Return the width `max - min` of an accumulation-bounds object.
///
/// - Does: Computes the symbolic endpoint difference.
/// - Input: One expression.
/// - Returns: `Some(max - min)` for bounds input, otherwise `None`.
/// - Limits: Does not simplify sign or non-negativity of the result.
pub fn accum_delta(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((min, max)) =>
      Some(@symcore.add([max, @symcore.mul([@symcore.int(-1), min])]))
    None => None
  }
}

///|
/// Return the midpoint `(min + max) / 2` of an accumulation-bounds object.
///
/// - Does: Computes the symbolic midpoint of the bounds endpoints.
/// - Input: One expression.
/// - Returns: `Some((min + max) / 2)` for bounds input, otherwise `None`.
/// - Limits: Does not simplify infinities or symbolic midpoint forms.
pub fn accum_mid(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((min, max)) => {
      let half = @symcore.rational_from_ints(1, 2) catch {
        _ =>
          @symcore.mul([
            @symcore.int(1),
            @symcore.pow(@symcore.int(2), @symcore.int(-1)),
          ])
      }
      Some(@symcore.mul([half, @symcore.add([min, max])]))
    }
    None => None
  }
}

///|
/// Negate an accumulation-bounds object or plain expression.
///
/// Bounds are flipped and re-ordered so the lower endpoint stays on the left.
///
/// - Does: Negates a bounds object endpoint-wise or negates a plain expression.
/// - Input: One expression.
/// - Returns: A bounds expression for bounds input, otherwise `-expr`.
/// - Limits: Symbolic endpoint re-ordering is structural and conservative.
pub fn accum_neg(expr : Expr) -> Expr {
  match accum_unpack(expr) {
    Some((min, max)) =>
      accum_bounds_ordered(
        @symcore.mul([@symcore.int(-1), max]),
        @symcore.mul([@symcore.int(-1), min]),
      )
    None => @symcore.mul([@symcore.int(-1), expr])
  }
}

///|
/// Add two accumulation-bounds expressions or plain expressions.
///
/// When both operands have finite numeric endpoints, the result is another
/// accumulation-bounds object with combined endpoints.
///
/// - Does: Adds accumulation-bounds objects and finite scalar shifts when
///   possible.
/// - Input: Two expressions.
/// - Returns: A bounds expression or symbolic `lhs + rhs`.
/// - Limits: Symbolic and mixed infinite cases may fall back to plain symbolic
///   addition.
pub fn accum_add(lhs : Expr, rhs : Expr) -> Expr {
  match (accum_unpack(lhs), accum_unpack(rhs)) {
    (Some((a1, a2)), Some((b1, b2))) => {
      let s1 = simple_add(simple_endpoint(a1), simple_endpoint(b1))
      let s2 = simple_add(simple_endpoint(a2), simple_endpoint(b2))
      if s1 is SimpleEndpoint::Nan || s2 is SimpleEndpoint::Nan {
        return accum_bounds_ordered(
          @symcore.mul([
            @symcore.int(-1),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          ]),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        )
      }
      if simple_is_finite(s1) && simple_is_finite(s2) {
        return accum_bounds_ordered(simple_to_expr(s1), simple_to_expr(s2))
      }
      @symcore.add([lhs, rhs])
    }
    (Some((a1, a2)), None) => {
      let s = simple_endpoint(rhs)
      if simple_is_finite(s) {
        let s1 = simple_add(simple_endpoint(a1), s)
        let s2 = simple_add(simple_endpoint(a2), s)
        if s1 is SimpleEndpoint::Nan || s2 is SimpleEndpoint::Nan {
          return accum_bounds_ordered(
            @symcore.mul([
              @symcore.int(-1),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            ]),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          )
        }
        if simple_is_finite(s1) && simple_is_finite(s2) {
          return accum_bounds_ordered(simple_to_expr(s1), simple_to_expr(s2))
        }
      }
      @symcore.add([lhs, rhs])
    }
    (None, Some(_)) => accum_add(rhs, lhs)
    _ => @symcore.add([lhs, rhs])
  }
}

///|
/// Subtract `rhs` from `lhs` in accumulation-bounds form.
///
/// - Does: Computes subtraction as `lhs + (-rhs)`.
/// - Input: Two expressions.
/// - Returns: A bounds expression or symbolic subtraction form.
/// - Limits: Inherits the simplification limits of `accum_add` and `accum_neg`.
pub fn accum_sub(lhs : Expr, rhs : Expr) -> Expr {
  accum_add(lhs, accum_neg(rhs))
}

///|
/// Multiply two accumulation-bounds expressions or a bounds object by a scalar.
///
/// - Does: Multiplies finite rational bounds endpoint-wise when possible.
/// - Input: Two expressions.
/// - Returns: A bounds expression or symbolic product.
/// - Limits: Symbolic endpoint multiplication and many infinite cases remain
///   conservative.
pub fn accum_mul(lhs : Expr, rhs : Expr) -> Expr {
  match (accum_unpack(lhs), accum_unpack(rhs)) {
    (Some((a1, a2)), Some((b1, b2))) => {
      let sa1 = simple_endpoint(a1)
      let sa2 = simple_endpoint(a2)
      let sb1 = simple_endpoint(b1)
      let sb2 = simple_endpoint(b2)
      if simple_is_finite(sa1) &&
        simple_is_finite(sa2) &&
        simple_is_finite(sb1) &&
        simple_is_finite(sb2) {
        let a1v = finite_value(sa1)
        let a2v = finite_value(sa2)
        let b1v = finite_value(sb1)
        let b2v = finite_value(sb2)
        let p1 = rat_mul(a1v, b1v)
        let p2 = rat_mul(a1v, b2v)
        let p3 = rat_mul(a2v, b1v)
        let p4 = rat_mul(a2v, b2v)
        let min1 = rat_min(p1, p2)
        let min2 = rat_min(p3, p4)
        let max1 = rat_max(p1, p2)
        let max2 = rat_max(p3, p4)
        let lo = rat_min(min1, min2)
        let hi = rat_max(max1, max2)
        return accum_bounds_ordered(expr_finite(lo), expr_finite(hi))
      }
      @symcore.mul([lhs, rhs])
    }
    (Some((a1, a2)), None) => {
      let s = simple_endpoint(rhs)
      if simple_is_finite(s) {
        let k = finite_value(s)
        if k.is_zero() {
          return @symcore.int(0)
        }
        let lo = @symcore.mul([expr_finite(k), a1])
        let hi = @symcore.mul([expr_finite(k), a2])
        let ksign = k.compare(rat_zero())
        if ksign >= 0 {
          return accum_bounds_ordered(lo, hi)
        } else {
          return accum_bounds_ordered(hi, lo)
        }
      }
      @symcore.mul([lhs, rhs])
    }
    (None, Some(_)) => accum_mul(rhs, lhs)
    _ => @symcore.mul([lhs, rhs])
  }
}

///|
fn interval_contains_zero(min : BigRational, max : BigRational) -> Bool {
  min.compare(rat_zero()) <= 0 && max.compare(rat_zero()) >= 0
}

///|
/// Divide one accumulation-bounds expression by another expression.
///
/// Finite numeric denominator intervals that cross zero widen to an unbounded
/// result.
///
/// - Does: Divides bounds expressions by finite rational intervals or scalars
///   when possible.
/// - Input: Numerator expression and denominator expression.
/// - Returns: A bounds expression or symbolic quotient form.
/// - Limits: Denominator intervals crossing zero widen conservatively to an
///   unbounded interval.
pub fn accum_div(lhs : Expr, rhs : Expr) -> Expr {
  match (accum_unpack(lhs), accum_unpack(rhs)) {
    (Some((a1, a2)), Some((b1, b2))) => {
      let sa1 = simple_endpoint(a1)
      let sa2 = simple_endpoint(a2)
      let sb1 = simple_endpoint(b1)
      let sb2 = simple_endpoint(b2)
      if simple_is_finite(sa1) &&
        simple_is_finite(sa2) &&
        simple_is_finite(sb1) &&
        simple_is_finite(sb2) {
        let a1v = finite_value(sa1)
        let a2v = finite_value(sa2)
        let b1v = finite_value(sb1)
        let b2v = finite_value(sb2)
        if interval_contains_zero(b1v, b2v) {
          return accum_bounds_ordered(
            @symcore.mul([
              @symcore.int(-1),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            ]),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          )
        }
        let q1 = match rat_div(a1v, b1v) {
          Some(v) => v
          None => rat_zero()
        }
        let q2 = match rat_div(a1v, b2v) {
          Some(v) => v
          None => rat_zero()
        }
        let q3 = match rat_div(a2v, b1v) {
          Some(v) => v
          None => rat_zero()
        }
        let q4 = match rat_div(a2v, b2v) {
          Some(v) => v
          None => rat_zero()
        }
        let min1 = rat_min(q1, q2)
        let min2 = rat_min(q3, q4)
        let max1 = rat_max(q1, q2)
        let max2 = rat_max(q3, q4)
        let lo = rat_min(min1, min2)
        let hi = rat_max(max1, max2)
        return accum_bounds_ordered(expr_finite(lo), expr_finite(hi))
      }
      @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))])
    }
    (Some((_a1, _a2)), None) => {
      let s = simple_endpoint(rhs)
      if simple_is_finite(s) {
        let k = finite_value(s)
        if k.is_zero() {
          return @symcore.mul([
            lhs,
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          ])
        }
        let inv = match rat_div(rat_one(), k) {
          Some(v) => v
          None => rat_zero()
        }
        let scaled = accum_mul(lhs, expr_finite(inv))
        return scaled
      }
      @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))])
    }
    (None, Some(_)) => @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))])
    _ => @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))])
  }
}

///|
fn pow_rational(base : BigRational, exp : Int) -> BigRational? {
  if exp == 0 {
    return Some(rat_one())
  }
  if exp < 0 {
    let pos = pow_rational(base, -exp)
    match pos {
      Some(p) => rat_div(rat_one(), p)
      None => None
    }
  } else {
    let mut out = rat_one()
    for _ in 0..<exp {
      out = rat_mul(out, base)
    }
    Some(out)
  }
}

///|
/// Raise an accumulation-bounds expression to an integer power.
///
/// Non-integer exponents fall back to a symbolic power expression.
///
/// - Does: Raises finite rational bounds to exact integer powers when possible.
/// - Input: A base expression and exponent expression.
/// - Returns: A bounds expression, scalar expression, or symbolic power.
/// - Limits: Non-integer exponents and symbolic endpoint powers are not
///   interval-evaluated.
pub fn accum_pow(base : Expr, exp : Expr) -> Expr {
  match (accum_unpack(base), exp) {
    (Some((a1, a2)), Expr::Number(n)) => {
      if !n.is_integral() {
        return @symcore.pow(base, exp)
      }
      let n_int = n.numerator().to_int()
      let sa1 = simple_endpoint(a1)
      let sa2 = simple_endpoint(a2)
      if simple_is_finite(sa1) && simple_is_finite(sa2) {
        let lo = finite_value(sa1)
        let hi = finite_value(sa2)
        if n_int == 0 {
          return @symcore.int(1)
        }
        if n_int > 0 {
          if n_int % 2 == 0 {
            let lo_abs = rat_abs(lo)
            let hi_abs = rat_abs(hi)
            let max_abs = rat_max(lo_abs, hi_abs)
            let hi_pow = match pow_rational(max_abs, n_int) {
              Some(v) => v
              None => rat_zero()
            }
            if lo.compare(rat_zero()) <= 0 && hi.compare(rat_zero()) >= 0 {
              return accum_bounds_ordered(
                expr_finite(rat_zero()),
                expr_finite(hi_pow),
              )
            }
            let lo_pow = match pow_rational(lo_abs, n_int) {
              Some(v) => v
              None => rat_zero()
            }
            let min_pow = rat_min(lo_pow, hi_pow)
            let max_pow = rat_max(lo_pow, hi_pow)
            return accum_bounds_ordered(
              expr_finite(min_pow),
              expr_finite(max_pow),
            )
          } else {
            let lo_pow = match pow_rational(lo, n_int) {
              Some(v) => v
              None => rat_zero()
            }
            let hi_pow = match pow_rational(hi, n_int) {
              Some(v) => v
              None => rat_zero()
            }
            let min_pow = rat_min(lo_pow, hi_pow)
            let max_pow = rat_max(lo_pow, hi_pow)
            return accum_bounds_ordered(
              expr_finite(min_pow),
              expr_finite(max_pow),
            )
          }
        } else {
          if interval_contains_zero(lo, hi) {
            return accum_bounds_ordered(
              @symcore.mul([
                @symcore.int(-1),
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
              ]),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            )
          }
          let lo_pow = match pow_rational(lo, n_int) {
            Some(v) => v
            None => rat_zero()
          }
          let hi_pow = match pow_rational(hi, n_int) {
            Some(v) => v
            None => rat_zero()
          }
          let min_pow = rat_min(lo_pow, hi_pow)
          let max_pow = rat_max(lo_pow, hi_pow)
          return accum_bounds_ordered(
            expr_finite(min_pow),
            expr_finite(max_pow),
          )
        }
      }
      @symcore.pow(base, exp)
    }
    _ => @symcore.pow(base, exp)
  }
}

///|
/// Apply absolute value to an accumulation-bounds expression.
///
/// - Does: Computes absolute-value bounds for finite rational endpoints.
/// - Input: One expression.
/// - Returns: A bounds expression, original non-negative bounds, or symbolic
///   `Abs(expr)`.
/// - Limits: Symbolic endpoints fall back to a symbolic absolute value.
pub fn accum_abs(expr : Expr) -> Expr {
  match accum_unpack(expr) {
    Some((min, max)) => {
      let smin = simple_endpoint(min)
      let smax = simple_endpoint(max)
      if simple_is_finite(smin) && simple_is_finite(smax) {
        let lo = finite_value(smin)
        let hi = finite_value(smax)
        if hi.compare(rat_zero()) <= 0 {
          return accum_bounds_ordered(
            expr_finite(rat_abs(hi)),
            expr_finite(rat_abs(lo)),
          )
        }
        if lo.compare(rat_zero()) >= 0 {
          return expr
        }
        let max_abs = rat_max(rat_abs(lo), rat_abs(hi))
        return accum_bounds_ordered(
          expr_finite(rat_zero()),
          expr_finite(max_abs),
        )
      }
      @symcore.function("Abs", [expr])
    }
    None => @symcore.function("Abs", [expr])
  }
}

///|
/// Build the smallest interval covering both accumulation-bounds operands.
///
/// - Does: Unions two finite rational accumulation-bounds objects.
/// - Input: Two expressions.
/// - Returns: A covering bounds expression or symbolic `Union(lhs, rhs)`.
/// - Limits: Symbolic and infinite endpoint unions are not fully simplified.
pub fn accum_union(lhs : Expr, rhs : Expr) -> Expr {
  match (accum_unpack(lhs), accum_unpack(rhs)) {
    (Some((a1, a2)), Some((b1, b2))) => {
      let sa1 = simple_endpoint(a1)
      let sa2 = simple_endpoint(a2)
      let sb1 = simple_endpoint(b1)
      let sb2 = simple_endpoint(b2)
      if simple_is_finite(sa1) &&
        simple_is_finite(sa2) &&
        simple_is_finite(sb1) &&
        simple_is_finite(sb2) {
        let lo = rat_min(finite_value(sa1), finite_value(sb1))
        let hi = rat_max(finite_value(sa2), finite_value(sb2))
        return accum_bounds_ordered(expr_finite(lo), expr_finite(hi))
      }
      @symcore.function("Union", [lhs, rhs])
    }
    _ => @symcore.function("Union", [lhs, rhs])
  }
}
