///|
fn expr_is_zero(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn expr_is_one(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.is_one()
    _ => false
  }
}

///|
fn expr_add(a : Expr, b : Expr) -> Expr {
  if expr_is_zero(a) {
    b
  } else if expr_is_zero(b) {
    a
  } else {
    @symcore.add([a, b])
  }
}

///|
fn expr_mul(a : Expr, b : Expr) -> Expr {
  if expr_is_zero(a) || expr_is_zero(b) {
    int(0)
  } else if expr_is_one(a) {
    b
  } else if expr_is_one(b) {
    a
  } else {
    @symcore.mul([a, b])
  }
}

///|
fn expr_neg(a : Expr) -> Expr {
  expr_mul(int(-1), a)
}

///|
fn expr_pow_int(base : Expr, exp : Int) -> Expr {
  @symcore.pow(base, int(exp))
}

///|
fn expr_int(expr : Expr) -> Int? {
  match expr {
    Number(n) if n.is_integral() => {
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
fn require_symbol_name(expr : Expr) -> String {
  match expr {
    Symbol(name) => name
    _ => "__invalid_symbol__"
  }
}

///|
fn trim_coeffs(coeffs : Array[Expr]) -> Array[Expr] {
  let mut end = coeffs.length()
  while end > 0 && expr_is_zero(coeffs[end - 1]) {
    end -= 1
  }
  if end == 0 {
    return [int(0)]
  }
  let out : Array[Expr] = Array::new()
  for i in 0..<end {
    out.push(coeffs[i])
  }
  out
}

///|
fn coeff_at(coeffs : Array[Expr], idx : Int) -> Expr {
  if idx < coeffs.length() {
    coeffs[idx]
  } else {
    int(0)
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
fn diff_n(expr : Expr, sym : Expr, n : Int) -> Expr {
  let mut out = expr
  for _ in 0..<n {
    out = @symcalculus.diff(out, sym)
  }
  out
}

///|
fn shift_symbol(expr : Expr, sym : Expr, by : Int) -> Expr {
  let name = require_symbol_name(sym)
  let env : Map[String, Expr] = Map([])
  env[name] = @symcore.add([sym, int(by)])
  @symcore.subst(expr, env)
}

///|
fn expr_to_sympy_string(expr : Expr) -> String {
  @symprint.pretty_string(expr)
}
