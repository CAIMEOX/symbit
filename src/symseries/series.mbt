///|
/// Series expansion entry point (limited to polynomial/rational, x0=0).

///|
fn poly_to_expr(
  poly : Array[@symcore.Expr],
  x : @symcore.Expr,
  n : Int,
) -> @symcore.Expr {
  let terms : Array[@symcore.Expr] = Array::new()
  let limit = if n < poly.length() { n } else { poly.length() }
  for k in 0..<limit {
    let coeff = poly[k]
    if is_zero_expr(coeff) {
      continue
    }
    let term = if k == 0 {
      coeff
    } else {
      expr_mul(coeff, @symcore.pow(x, @symcore.int(k)))
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(terms)
  }
}

///|
fn split_num_den(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr) {
  match expr {
    @symcore.Expr::Mul(args) => {
      let num : Array[@symcore.Expr] = Array::new()
      let den : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Pow(base, exp) =>
            match int_exp(exp) {
              Some(e) if e < 0 => den.push(@symcore.pow(base, @symcore.int(-e)))
              _ => num.push(arg)
            }
          _ => num.push(arg)
        }
      }
      let num_expr = if num.is_empty() {
        @symcore.int(1)
      } else {
        @symcore.mul(num)
      }
      let den_expr = if den.is_empty() {
        @symcore.int(1)
      } else {
        @symcore.mul(den)
      }
      (num_expr, den_expr)
    }
    @symcore.Expr::Pow(base, exp) =>
      match int_exp(exp) {
        Some(e) if e < 0 =>
          (@symcore.int(1), @symcore.pow(base, @symcore.int(-e)))
        _ => (expr, @symcore.int(1))
      }
    _ => (expr, @symcore.int(1))
  }
}

///|
fn series_rational(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  n : Int,
) -> (@symcore.Expr, Bool)? {
  let (num_expr, den_expr) = split_num_den(expr)
  let num_poly = poly_from_expr(num_expr, x)
  let den_poly = poly_from_expr(den_expr, x)
  match (num_poly, den_poly) {
    (Some(num), Some(den)) => {
      if den.is_empty() {
        return None
      }
      if den.length() == 1 {
        let inv = match expr_inv(den[0]) {
          Some(v) => v
          None => return None
        }
        let scaled = poly_scale(num, inv)
        let needs_order = poly_needs_order(scaled, n)
        return Some((poly_to_expr(scaled, x, n), needs_order))
      }
      if is_zero_expr(den[0]) {
        return None
      }
      match poly_series_div(num, den, n) {
        Some(q) => Some((poly_to_expr(q, x, n), true))
        None => None
      }
    }
    _ => None
  }
}

///|
pub fn series(
  expr : @symcore.Expr,
  x? : @symcore.Expr = @symcore.symbol("x"),
  x0? : @symcore.Expr = @symcore.int(0),
  n? : Int = 6,
  dir? : String = "+",
) -> @symcore.Expr raise {
  if n <= 0 {
    fail("series n must be positive")
  }
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("series variable must be a Symbol")
  }
  let t = @symcore.symbol("__series_t")
  let env : Map[String, @symcore.Expr] = {}
  let forward_shift = if dir == "-" {
    @symcore.add([x0, expr_neg(t)])
  } else {
    @symcore.add([x0, t])
  }
  env[var_name] = forward_shift
  let shifted = @symcore.subst(expr, env)
  let expanded = match series_poly(shifted, t, n) {
    Some((poly, needs_order)) => Some((poly_to_expr(poly, t, n), needs_order))
    None => series_rational(shifted, t, n)
  }
  match expanded {
    Some((poly_expr, needs_order)) => {
      // Substitute back t -> (x - x0)
      let back : Map[String, @symcore.Expr] = {}
      let back_shift = if dir == "-" {
        @symcore.add([x0, expr_neg(x)])
      } else {
        @symcore.add([x, expr_neg(x0)])
      }
      back["__series_t"] = back_shift
      let order_shift = @symcore.add([x, expr_neg(x0)])
      if needs_order {
        match x0 {
          @symcore.Expr::Number(n0) if !n0.is_zero() => {
            let poly_sub = @symcore.subst(poly_expr, back)
            let order_term = @symcore.function("O", [
              @symcore.pow(order_shift, @symcore.int(n)),
              @symcore.function("Tuple", [x, x0]),
            ])
            @symcore.add([poly_sub, order_term])
          }
          _ => {
            let with_order = @symcore.add([
              poly_expr,
              big_o(@symcore.pow(t, @symcore.int(n))),
            ])
            @symcore.subst(with_order, back)
          }
        }
      } else {
        @symcore.subst(poly_expr, back)
      }
    }
    None => fail("series-not-implemented")
  }
}

///|
fn poly_truncate(poly : Array[@symcore.Expr], n : Int) -> Array[@symcore.Expr] {
  if poly.length() <= n {
    poly
  } else {
    let out : Array[@symcore.Expr] = Array::new()
    for i in 0..<n {
      out.push(poly[i])
    }
    poly_trim(out)
  }
}

///|
fn poly_mul_trunc(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  n : Int,
) -> Array[@symcore.Expr] {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let out : Array[@symcore.Expr] = Array::new()
  for _ in 0..<n {
    out.push(zero_expr())
  }
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let idx = i + j
      if idx >= n {
        break
      }
      out[idx] = expr_add(out[idx], expr_mul(a[i], b[j]))
    }
  }
  poly_trim(out)
}

///|
fn poly_pow_trunc(
  base : Array[@symcore.Expr],
  exp : Int,
  n : Int,
) -> Array[@symcore.Expr] {
  if exp == 0 {
    return [one_expr()]
  }
  let mut e = exp
  let mut result : Array[@symcore.Expr] = [one_expr()]
  let mut b = base
  while e > 0 {
    if e % 2 == 1 {
      result = poly_mul_trunc(result, b, n)
    }
    e = e / 2
    if e > 0 {
      b = poly_mul_trunc(b, b, n)
    }
  }
  result
}

///|
fn factorial_bigint(n : Int) -> BigInt {
  let mut acc = BigInt::from_int(1)
  let mut i = 2
  while i <= n {
    acc = acc.mul(BigInt::from_int(i))
    i = i + 1
  }
  acc
}

///|
fn safe_rational(num : BigInt, den : BigInt) -> @symnum.BigRational {
  try @symnum.BigRational::new(num, den) catch {
    _ => @symnum.BigRational::zero()
  } noraise {
    v => v
  }
}

///|
fn rational_expr(num : Int, den : Int) -> @symcore.Expr {
  try @symcore.rational_from_ints(num, den) catch {
    _ => @symcore.function("Rational", [@symcore.int(num), @symcore.int(den)])
  } noraise {
    v => v
  }
}

///|
fn const_sin(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(0)
    _ => @symcore.function("sin", [expr])
  }
}

///|
fn const_cos(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(1)
    _ => @symcore.function("cos", [expr])
  }
}

///|
fn const_tan(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(0)
    _ => @symcore.function("tan", [expr])
  }
}

///|
fn const_exp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(1)
    _ => @symcore.function("exp", [expr])
  }
}

///|
fn const_sinh(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(0)
    _ => @symcore.function("sinh", [expr])
  }
}

///|
fn const_cosh(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(1)
    _ => @symcore.function("cosh", [expr])
  }
}

///|
fn const_tanh(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(0)
    _ => @symcore.function("tanh", [expr])
  }
}

///|
fn const_log(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) if n.is_one() => @symcore.int(0)
    _ => @symcore.function("log", [expr])
  }
}

///|
fn series_exp_zero(u : Array[@symcore.Expr], n : Int) -> Array[@symcore.Expr] {
  let mut out : Array[@symcore.Expr] = [one_expr()]
  let mut term : Array[@symcore.Expr] = [one_expr()]
  let mut k = 1
  while k < n {
    term = poly_mul_trunc(term, u, n)
    let denom = factorial_bigint(k)
    let coeff = @symcore.number(safe_rational(BigInt::from_int(1), denom))
    out = poly_add(out, poly_scale(term, coeff))
    k = k + 1
  }
  poly_truncate(out, n)
}

///|
fn series_sin_zero(u : Array[@symcore.Expr], n : Int) -> Array[@symcore.Expr] {
  let u2 = poly_mul_trunc(u, u, n)
  let mut out : Array[@symcore.Expr] = []
  let mut term = u
  let mut k = 0
  let mut sign = 1
  while true {
    let power = 2 * k + 1
    if power >= n {
      break
    }
    let denom = factorial_bigint(power)
    let coeff = @symcore.number(safe_rational(BigInt::from_int(sign), denom))
    out = poly_add(out, poly_scale(term, coeff))
    term = poly_mul_trunc(term, u2, n)
    sign = -sign
    k = k + 1
  }
  poly_truncate(out, n)
}

///|
fn series_cos_zero(u : Array[@symcore.Expr], n : Int) -> Array[@symcore.Expr] {
  let u2 = poly_mul_trunc(u, u, n)
  let mut out : Array[@symcore.Expr] = []
  let mut term : Array[@symcore.Expr] = [one_expr()]
  let mut k = 0
  let mut sign = 1
  while true {
    let power = 2 * k
    if power >= n {
      break
    }
    let denom = factorial_bigint(power)
    let coeff = @symcore.number(safe_rational(BigInt::from_int(sign), denom))
    out = poly_add(out, poly_scale(term, coeff))
    term = poly_mul_trunc(term, u2, n)
    sign = -sign
    k = k + 1
  }
  poly_truncate(out, n)
}

///|
fn series_sinh_zero(u : Array[@symcore.Expr], n : Int) -> Array[@symcore.Expr] {
  let u2 = poly_mul_trunc(u, u, n)
  let mut out : Array[@symcore.Expr] = []
  let mut term = u
  let mut k = 0
  while true {
    let power = 2 * k + 1
    if power >= n {
      break
    }
    let denom = factorial_bigint(power)
    let coeff = @symcore.number(safe_rational(BigInt::from_int(1), denom))
    out = poly_add(out, poly_scale(term, coeff))
    term = poly_mul_trunc(term, u2, n)
    k = k + 1
  }
  poly_truncate(out, n)
}

///|
fn series_cosh_zero(u : Array[@symcore.Expr], n : Int) -> Array[@symcore.Expr] {
  let u2 = poly_mul_trunc(u, u, n)
  let mut out : Array[@symcore.Expr] = []
  let mut term : Array[@symcore.Expr] = [one_expr()]
  let mut k = 0
  while true {
    let power = 2 * k
    if power >= n {
      break
    }
    let denom = factorial_bigint(power)
    let coeff = @symcore.number(safe_rational(BigInt::from_int(1), denom))
    out = poly_add(out, poly_scale(term, coeff))
    term = poly_mul_trunc(term, u2, n)
    k = k + 1
  }
  poly_truncate(out, n)
}

///|
fn binomial_coeff(alpha : @symnum.BigRational, k : Int) -> @symnum.BigRational {
  if k == 0 {
    return @symnum.BigRational::one()
  }
  let mut coeff = @symnum.BigRational::one()
  let mut i = 0
  while i < k {
    let shift = alpha.add_r(@symnum.BigRational::from_int(-i))
    coeff = coeff.mul_r(shift)
    coeff = try coeff.div_r(@symnum.BigRational::from_int(i + 1)) catch {
      _ => @symnum.BigRational::zero()
    } noraise {
      v => v
    }
    i = i + 1
  }
  coeff
}

///|
fn series_pow_general(
  poly : Array[@symcore.Expr],
  alpha : @symnum.BigRational,
  alpha_expr : @symcore.Expr,
  n : Int,
) -> (Array[@symcore.Expr], Bool)? {
  let (c0, rest) = split_const(poly)
  let c0_inv = match expr_inv(c0) {
    Some(v) => v
    None => return None
  }
  let scaled = poly_scale(rest, c0_inv)
  let mut out : Array[@symcore.Expr] = [one_expr()]
  let mut term : Array[@symcore.Expr] = [one_expr()]
  let mut k = 1
  while k < n {
    term = poly_mul_trunc(term, scaled, n)
    let coeff = @symcore.number(binomial_coeff(alpha, k))
    out = poly_add(out, poly_scale(term, coeff))
    k = k + 1
  }
  Some((poly_scale(out, @symcore.pow(c0, alpha_expr)), true))
}

///|
fn series_atan_zero(u : Array[@symcore.Expr], n : Int) -> Array[@symcore.Expr] {
  let u2 = poly_mul_trunc(u, u, n)
  let mut out : Array[@symcore.Expr] = []
  let mut term = u
  let mut k = 0
  let mut sign = 1
  while true {
    let power = 2 * k + 1
    if power >= n {
      break
    }
    let coeff = rational_expr(sign, power)
    out = poly_add(out, poly_scale(term, coeff))
    term = poly_mul_trunc(term, u2, n)
    sign = -sign
    k = k + 1
  }
  poly_truncate(out, n)
}

///|
fn split_const(
  poly : Array[@symcore.Expr],
) -> (@symcore.Expr, Array[@symcore.Expr]) {
  if poly.is_empty() {
    return (zero_expr(), [])
  }
  let c0 = poly[0]
  let rest = poly.copy()
  rest[0] = zero_expr()
  (c0, rest)
}

///|
fn series_log_one_plus(
  v : Array[@symcore.Expr],
  n : Int,
) -> Array[@symcore.Expr] {
  let mut out : Array[@symcore.Expr] = []
  let mut term = v
  let mut k = 1
  while k < n {
    let sign = if k % 2 == 1 { 1 } else { -1 }
    let coeff = rational_expr(sign, k)
    out = poly_add(out, poly_scale(term, coeff))
    term = poly_mul_trunc(term, v, n)
    k = k + 1
  }
  poly_truncate(out, n)
}

///|
fn replace_expr(
  expr : @symcore.Expr,
  target : @symcore.Expr,
  replacement : @symcore.Expr,
) -> @symcore.Expr {
  if expr == target {
    return replacement
  }
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(child => replace_expr(child, target, replacement)))
    @symcore.Expr::Mul(args) =>
      @symcore.mul(args.map(child => replace_expr(child, target, replacement)))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(
        replace_expr(base, target, replacement),
        replace_expr(exp, target, replacement),
      )
    @symcore.Expr::Function(name, args) =>
      @symcore.function(
        name,
        args.map(child => replace_expr(child, target, replacement)),
      )
    _ => expr
  }
}

///|
fn simplify_tan_coeff(
  expr : @symcore.Expr,
  tan_c0 : @symcore.Expr,
) -> @symcore.Expr {
  let sym = @symcore.symbol("__tan_c0")
  let replaced = replace_expr(expr, tan_c0, sym)
  match poly_from_expr(replaced, sym) {
    Some(poly) => {
      let expanded = poly_to_expr(poly, sym, poly.length())
      replace_expr(expanded, sym, tan_c0)
    }
    None => expr
  }
}

///|
fn series_poly(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  n : Int,
) -> (Array[@symcore.Expr], Bool)? {
  match expr {
    @symcore.Expr::Number(_) => Some(([expr], false))
    @symcore.Expr::Symbol(_) =>
      if expr == x {
        Some(([zero_expr(), one_expr()], false))
      } else {
        Some(([expr], false))
      }
    @symcore.Expr::Add(args) => {
      let mut acc : Array[@symcore.Expr] = [zero_expr()]
      let mut inf = false
      for arg in args {
        match series_poly(arg, x, n) {
          Some((poly, infinite)) => {
            acc = poly_add(acc, poly)
            inf = inf || infinite
          }
          None => return None
        }
      }
      Some((poly_truncate(acc, n), inf))
    }
    @symcore.Expr::Mul(args) => {
      let mut acc : Array[@symcore.Expr] = [one_expr()]
      let mut inf = false
      for arg in args {
        match series_poly(arg, x, n) {
          Some((poly, infinite)) => {
            acc = poly_mul_trunc(acc, poly, n)
            inf = inf || infinite
          }
          None => return None
        }
      }
      Some((poly_truncate(acc, n), inf))
    }
    @symcore.Expr::Pow(base, exp) =>
      match int_exp(exp) {
        Some(e) if e >= 0 =>
          match series_poly(base, x, n) {
            Some((poly, infinite)) => {
              let out = poly_pow_trunc(poly, e, n)
              Some((out, infinite))
            }
            None => None
          }
        Some(e) if e < 0 =>
          match series_poly(base, x, n) {
            Some((poly, _)) => {
              let pow_poly = poly_pow_trunc(poly, -e, n)
              match poly_series_div([one_expr()], pow_poly, n) {
                Some(div) => Some((div, true))
                None => None
              }
            }
            None => None
          }
        _ =>
          match exp {
            @symcore.Expr::Number(alpha) =>
              match series_poly(base, x, n) {
                Some((poly, _)) => series_pow_general(poly, alpha, exp, n)
                None => None
              }
            _ => None
          }
      }
    @symcore.Expr::Function(name, args) => {
      if args.length() != 1 {
        return None
      }
      let arg = args[0]
      match name {
        "exp" =>
          match series_poly(arg, x, n) {
            Some((poly, _)) => {
              let (c0, rest) = split_const(poly)
              let exp_rest = series_exp_zero(rest, n)
              let scaled = poly_scale(exp_rest, const_exp(c0))
              Some((scaled, true))
            }
            None => None
          }
        "sin" | "cos" =>
          match series_poly(arg, x, n) {
            Some((poly, _)) => {
              let (c0, rest) = split_const(poly)
              let sin_rest = series_sin_zero(rest, n)
              let cos_rest = series_cos_zero(rest, n)
              let sin_c0 = const_sin(c0)
              let cos_c0 = const_cos(c0)
              let sin_poly = poly_add(
                poly_scale(cos_rest, sin_c0),
                poly_scale(sin_rest, cos_c0),
              )
              let cos_poly = poly_add(
                poly_scale(cos_rest, cos_c0),
                poly_scale(sin_rest, expr_neg(sin_c0)),
              )
              if name == "sin" {
                Some((poly_truncate(sin_poly, n), true))
              } else {
                Some((poly_truncate(cos_poly, n), true))
              }
            }
            None => None
          }
        "sinh" | "cosh" =>
          match series_poly(arg, x, n) {
            Some((poly, _)) => {
              let (c0, rest) = split_const(poly)
              let sinh_rest = series_sinh_zero(rest, n)
              let cosh_rest = series_cosh_zero(rest, n)
              let sinh_c0 = const_sinh(c0)
              let cosh_c0 = const_cosh(c0)
              let sinh_poly = poly_add(
                poly_scale(cosh_rest, sinh_c0),
                poly_scale(sinh_rest, cosh_c0),
              )
              let cosh_poly = poly_add(
                poly_scale(cosh_rest, cosh_c0),
                poly_scale(sinh_rest, sinh_c0),
              )
              if name == "sinh" {
                Some((poly_truncate(sinh_poly, n), true))
              } else {
                Some((poly_truncate(cosh_poly, n), true))
              }
            }
            None => None
          }
        "tan" =>
          match series_poly(arg, x, n) {
            Some((poly, _)) => {
              let (c0, rest) = split_const(poly)
              let sin_rest = series_sin_zero(rest, n)
              let cos_rest = series_cos_zero(rest, n)
              let tan_c0 = const_tan(c0)
              let num_poly = poly_add(poly_scale(cos_rest, tan_c0), sin_rest)
              let den_poly = poly_add(
                cos_rest,
                poly_scale(sin_rest, expr_neg(tan_c0)),
              )
              match poly_series_div(num_poly, den_poly, n) {
                Some(div) => {
                  let simplified = div.map(coeff => {
                    simplify_tan_coeff(coeff, tan_c0)
                  })
                  Some((simplified, true))
                }
                None => None
              }
            }
            None => None
          }
        "tanh" =>
          match series_poly(arg, x, n) {
            Some((poly, _)) => {
              let (c0, rest) = split_const(poly)
              let sinh_rest = series_sinh_zero(rest, n)
              let cosh_rest = series_cosh_zero(rest, n)
              match poly_series_div(sinh_rest, cosh_rest, n) {
                Some(tanh_rest) => {
                  let tanh_c0 = const_tanh(c0)
                  let num_poly = poly_add([tanh_c0], tanh_rest)
                  let den_poly = poly_add(
                    [one_expr()],
                    poly_scale(tanh_rest, tanh_c0),
                  )
                  match poly_series_div(num_poly, den_poly, n) {
                    Some(div) => {
                      let simplified = div.map(coeff => {
                        simplify_tan_coeff(coeff, tanh_c0)
                      })
                      Some((poly_truncate(simplified, n), true))
                    }
                    None => None
                  }
                }
                None => None
              }
            }
            None => None
          }
        "log" =>
          match series_poly(arg, x, n) {
            Some((poly, _)) => {
              let (c0, rest) = split_const(poly)
              match expr_inv(c0) {
                Some(inv) => {
                  let v = poly_scale(rest, inv)
                  let log1p = series_log_one_plus(v, n)
                  let out = poly_add([const_log(c0)], log1p)
                  Some((poly_truncate(out, n), true))
                }
                None => None
              }
            }
            None => None
          }
        "atan" =>
          match series_poly(arg, x, n) {
            Some((poly, _)) => {
              let (c0, rest) = split_const(poly)
              if is_zero_expr(c0) {
                Some((series_atan_zero(rest, n), true))
              } else {
                None
              }
            }
            None => None
          }
        "sqrt" => {
          let half = @symcore.number(
            try @symnum.BigRational::new(
              BigInt::from_int(1),
              BigInt::from_int(2),
            ) catch {
              _ => @symnum.BigRational::zero()
            } noraise {
              v => v
            },
          )
          series_poly(@symcore.pow(arg, half), x, n)
        }
        _ => None
      }
    }
  }
}
