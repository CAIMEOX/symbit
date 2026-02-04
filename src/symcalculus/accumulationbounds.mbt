///|
pub type Expr = @symcore.Expr

///|
pub type BigRational = @symnum.BigRational

///|
suberror AccumBoundsError {
  InvalidBounds(String)
} derive(Show, Eq)

///|
priv enum SimpleEndpoint {
  Finite(BigRational)
  PosInf
  NegInf
  Nan
  Other(Expr)
}

///|
fn expr_zero() -> Expr {
  @symcore.int(0)
}

///|
fn expr_one() -> Expr {
  @symcore.int(1)
}

///|
fn expr_neg_one() -> Expr {
  @symcore.int(-1)
}

///|
fn expr_oo() -> Expr {
  @symcore.symbol("oo")
}

///|
fn expr_neg_oo() -> Expr {
  @symcore.mul([expr_neg_one(), expr_oo()])
}

///|
fn expr_nan() -> Expr {
  @symcore.symbol("nan")
}

///|
fn expr_finite(n : BigRational) -> Expr {
  @symcore.number(n)
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
    Expr::Symbol(s) if s == "oo" => SimpleEndpoint::PosInf
    Expr::Symbol(s) if s == "nan" => SimpleEndpoint::Nan
    Expr::Mul(args) if args.length() == 2 =>
      match (args[0], args[1]) {
        (Expr::Number(n), Expr::Symbol(s)) if s == "oo" &&
          n.compare(BigRational::from_int(-1)) == 0 => SimpleEndpoint::NegInf
        _ => SimpleEndpoint::Other(expr)
      }
    _ => SimpleEndpoint::Other(expr)
  }
}

///|
fn simple_to_expr(s : SimpleEndpoint) -> Expr {
  match s {
    SimpleEndpoint::Finite(n) => expr_finite(n)
    SimpleEndpoint::PosInf => expr_oo()
    SimpleEndpoint::NegInf => expr_neg_oo()
    SimpleEndpoint::Nan => expr_nan()
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
  let res : Result[BigRational, Error] = try? a.div_r(b)
  match res {
    Ok(v) => Some(v)
    Err(_) => None
  }
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
  match expr {
    Expr::Function(name, args) if name == "AccumBounds" && args.length() == 2 =>
      Some((args[0], args[1]))
    _ => None
  }
}

///|
pub fn accum_is_bounds(expr : Expr) -> Bool {
  accum_unpack(expr) is Some(_)
}

///|
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
pub fn accum_min(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((min, _)) => Some(min)
    None => None
  }
}

///|
pub fn accum_max(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((_, max)) => Some(max)
    None => None
  }
}

///|
pub fn accum_delta(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((min, max)) =>
      Some(@symcore.add([max, @symcore.mul([expr_neg_one(), min])]))
    None => None
  }
}

///|
pub fn accum_mid(expr : Expr) -> Expr? {
  match accum_unpack(expr) {
    Some((min, max)) => {
      let half = @symcore.number(
        try! BigRational::new(BigInt::from_int(1), BigInt::from_int(2)),
      )
      Some(@symcore.mul([half, @symcore.add([min, max])]))
    }
    None => None
  }
}

///|
pub fn accum_neg(expr : Expr) -> Expr {
  match accum_unpack(expr) {
    Some((min, max)) =>
      try! accum_bounds(
        @symcore.mul([expr_neg_one(), max]),
        @symcore.mul([expr_neg_one(), min]),
      )
    None => @symcore.mul([expr_neg_one(), expr])
  }
}

///|
pub fn accum_add(lhs : Expr, rhs : Expr) -> Expr {
  match (accum_unpack(lhs), accum_unpack(rhs)) {
    (Some((a1, a2)), Some((b1, b2))) => {
      let s1 = simple_add(simple_endpoint(a1), simple_endpoint(b1))
      let s2 = simple_add(simple_endpoint(a2), simple_endpoint(b2))
      if s1 is SimpleEndpoint::Nan || s2 is SimpleEndpoint::Nan {
        return try! accum_bounds(expr_neg_oo(), expr_oo())
      }
      if simple_is_finite(s1) && simple_is_finite(s2) {
        return try! accum_bounds(simple_to_expr(s1), simple_to_expr(s2))
      }
      @symcore.add([lhs, rhs])
    }
    (Some((a1, a2)), None) => {
      let s = simple_endpoint(rhs)
      if simple_is_finite(s) {
        let s1 = simple_add(simple_endpoint(a1), s)
        let s2 = simple_add(simple_endpoint(a2), s)
        if s1 is SimpleEndpoint::Nan || s2 is SimpleEndpoint::Nan {
          return try! accum_bounds(expr_neg_oo(), expr_oo())
        }
        if simple_is_finite(s1) && simple_is_finite(s2) {
          return try! accum_bounds(simple_to_expr(s1), simple_to_expr(s2))
        }
      }
      @symcore.add([lhs, rhs])
    }
    (None, Some(_)) => accum_add(rhs, lhs)
    _ => @symcore.add([lhs, rhs])
  }
}

///|
pub fn accum_sub(lhs : Expr, rhs : Expr) -> Expr {
  accum_add(lhs, accum_neg(rhs))
}

///|
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
        return try! accum_bounds(expr_finite(lo), expr_finite(hi))
      }
      @symcore.mul([lhs, rhs])
    }
    (Some((a1, a2)), None) => {
      let s = simple_endpoint(rhs)
      if simple_is_finite(s) {
        let k = finite_value(s)
        if k.is_zero() {
          return expr_zero()
        }
        let lo = @symcore.mul([expr_finite(k), a1])
        let hi = @symcore.mul([expr_finite(k), a2])
        let ksign = k.compare(rat_zero())
        if ksign >= 0 {
          return try! accum_bounds(lo, hi)
        } else {
          return try! accum_bounds(hi, lo)
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
          return try! accum_bounds(expr_neg_oo(), expr_oo())
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
        return try! accum_bounds(expr_finite(lo), expr_finite(hi))
      }
      @symcore.mul([lhs, @symcore.pow(rhs, expr_neg_one())])
    }
    (Some((_a1, _a2)), None) => {
      let s = simple_endpoint(rhs)
      if simple_is_finite(s) {
        let k = finite_value(s)
        if k.is_zero() {
          return @symcore.mul([lhs, expr_oo()])
        }
        let inv = match rat_div(rat_one(), k) {
          Some(v) => v
          None => rat_zero()
        }
        let scaled = accum_mul(lhs, expr_finite(inv))
        return scaled
      }
      @symcore.mul([lhs, @symcore.pow(rhs, expr_neg_one())])
    }
    (None, Some(_)) => @symcore.mul([lhs, @symcore.pow(rhs, expr_neg_one())])
    _ => @symcore.mul([lhs, @symcore.pow(rhs, expr_neg_one())])
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
          return expr_one()
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
              return try! accum_bounds(
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
            return try! accum_bounds(expr_finite(min_pow), expr_finite(max_pow))
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
            return try! accum_bounds(expr_finite(min_pow), expr_finite(max_pow))
          }
        } else {
          if interval_contains_zero(lo, hi) {
            return try! accum_bounds(expr_neg_oo(), expr_oo())
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
          return try! accum_bounds(expr_finite(min_pow), expr_finite(max_pow))
        }
      }
      @symcore.pow(base, exp)
    }
    _ => @symcore.pow(base, exp)
  }
}

///|
pub fn accum_abs(expr : Expr) -> Expr {
  match accum_unpack(expr) {
    Some((min, max)) => {
      let smin = simple_endpoint(min)
      let smax = simple_endpoint(max)
      if simple_is_finite(smin) && simple_is_finite(smax) {
        let lo = finite_value(smin)
        let hi = finite_value(smax)
        if hi.compare(rat_zero()) <= 0 {
          return try! accum_bounds(
            expr_finite(rat_abs(hi)),
            expr_finite(rat_abs(lo)),
          )
        }
        if lo.compare(rat_zero()) >= 0 {
          return expr
        }
        let max_abs = rat_max(rat_abs(lo), rat_abs(hi))
        return try! accum_bounds(expr_finite(rat_zero()), expr_finite(max_abs))
      }
      @symcore.function("Abs", [expr])
    }
    None => @symcore.function("Abs", [expr])
  }
}

///|
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
        return try! accum_bounds(expr_finite(lo), expr_finite(hi))
      }
      @symcore.function("Union", [lhs, rhs])
    }
    _ => @symcore.function("Union", [lhs, rhs])
  }
}
