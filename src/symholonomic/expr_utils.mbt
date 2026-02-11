///|
fn holo_zero() -> @symcore.Expr {
  @symcore.int(0)
}

///|
fn holo_one() -> @symcore.Expr {
  @symcore.int(1)
}

///|
fn holo_neg_one() -> @symcore.Expr {
  @symcore.int(-1)
}

///|
fn expr_is_zero(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn expr_is_one(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_one()
    _ => false
  }
}

///|
fn expr_add(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if expr_is_zero(a) {
    b
  } else if expr_is_zero(b) {
    a
  } else {
    @symcore.add([a, b])
  }
}

///|
fn expr_mul(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if expr_is_zero(a) || expr_is_zero(b) {
    holo_zero()
  } else if expr_is_one(a) {
    b
  } else if expr_is_one(b) {
    a
  } else {
    @symcore.mul([a, b])
  }
}

///|
fn expr_neg(a : @symcore.Expr) -> @symcore.Expr {
  expr_mul(holo_neg_one(), a)
}

///|
fn expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  expr_add(a, expr_neg(b))
}

///|
fn expr_pow_int(base : @symcore.Expr, exp : Int) -> @symcore.Expr {
  @symcore.pow(base, @symcore.int(exp))
}

///|
fn expr_int(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => {
      let num = n.numerator()
      if num.bit_length() > 30 {
        None
      } else {
        Some(num.to_int())
      }
    }
    _ => None
  }
}

///|
fn require_symbol_name(expr : @symcore.Expr) -> String {
  match expr {
    @symcore.Expr::Symbol(name) => name
    _ => "__invalid_symbol__"
  }
}

///|
fn trim_coeffs(coeffs : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let mut end = coeffs.length()
  while end > 0 && expr_is_zero(coeffs[end - 1]) {
    end -= 1
  }
  if end == 0 {
    return [holo_zero()]
  }
  let out : Array[@symcore.Expr] = Array::new()
  for i in 0..<end {
    out.push(coeffs[i])
  }
  out
}

///|
fn coeff_at(coeffs : Array[@symcore.Expr], idx : Int) -> @symcore.Expr {
  if idx < coeffs.length() {
    coeffs[idx]
  } else {
    holo_zero()
  }
}

///|
fn binom_int(n : Int, k : Int) -> @symnum.BigRational {
  if k < 0 || k > n {
    return @symnum.BigRational::zero()
  }
  if k == 0 || k == n {
    return @symnum.BigRational::one()
  }
  let kk = if k > n - k { n - k } else { k }
  let mut num = BigInt::from_int(1)
  let mut den = BigInt::from_int(1)
  for i in 1..<=kk {
    num = num.mul(BigInt::from_int(n - kk + i))
    den = den.mul(BigInt::from_int(i))
  }
  @symnum.BigRational::new(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
}

///|
fn diff_n(expr : @symcore.Expr, sym : @symcore.Expr, n : Int) -> @symcore.Expr {
  let mut out = expr
  for _ in 0..<n {
    out = @symcalculus.diff(out, sym)
  }
  out
}

///|
fn shift_symbol(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  by : Int,
) -> @symcore.Expr {
  let name = require_symbol_name(sym)
  let env : Map[String, @symcore.Expr] = {}
  env[name] = @symcore.add([sym, @symcore.int(by)])
  @symcore.subst(expr, env)
}

///|
fn expr_to_sympy_string(expr : @symcore.Expr) -> String {
  @symprint.to_string(expr)
}

///|
fn expr_array_to_sympy_strings(exprs : Array[@symcore.Expr]) -> Array[String] {
  let out : Array[String] = Array::new()
  for expr in exprs {
    out.push(expr_to_sympy_string(expr))
  }
  out
}
