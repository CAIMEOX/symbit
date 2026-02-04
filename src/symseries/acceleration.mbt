///|
/// Convergence acceleration (Richardson, Shanks) for basic symbolic sequences.

///|
fn symbol_name(expr : @symcore.Expr) -> String raise {
  match expr {
    @symcore.Expr::Symbol(name) => name
    _ => fail("acceleration variable must be a Symbol")
  }
}

///|
fn pow_int_bigint(base : Int, exp : Int) -> BigInt {
  if exp <= 0 {
    return BigInt::from_int(1)
  }
  let mut result = BigInt::from_int(1)
  let mut b = BigInt::from_int(base)
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result.mul(b)
    }
    e = e / 2
    if e > 0 {
      b = b.mul(b)
    }
  }
  result
}

///|
fn substitute_symbol(
  expr : @symcore.Expr,
  name : String,
  value : Int,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  env[name] = @symcore.int(value)
  @symcore.subst(expr, env)
}

///|
fn rational_coeff(sign : Int, num : BigInt, den : BigInt) -> @symcore.Expr {
  let mut n = num
  if sign < 0 {
    n = n.neg()
  }
  let coeff = safe_rational(n, den)
  @symcore.number(coeff)
}

///|
pub fn richardson(
  expr : @symcore.Expr,
  k : @symcore.Expr,
  n : Int,
  m : Int,
) -> @symcore.Expr raise {
  if n < 0 || m < 0 {
    fail("richardson requires non-negative n and m")
  }
  let name = symbol_name(k)
  let mut acc = zero_expr()
  let mut j = 0
  while j <= m {
    let k_val = n + j
    let a_sub = substitute_symbol(expr, name, k_val)
    let sign = if (j + m) % 2 == 0 { 1 } else { -1 }
    let pow_nj = pow_int_bigint(k_val, m)
    let denom = factorial_bigint(j).mul(factorial_bigint(m - j))
    let coeff = rational_coeff(sign, pow_nj, denom)
    acc = expr_add(acc, expr_mul(a_sub, coeff))
    j += 1
  }
  acc
}

///|
fn copy_expr_array(items : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for item in items {
    out.push(item)
  }
  out
}

///|
pub fn shanks(
  expr : @symcore.Expr,
  k : @symcore.Expr,
  n : Int,
  m? : Int = 1,
) -> @symcore.Expr raise {
  if n < 0 || m < 0 {
    fail("shanks requires non-negative n and m")
  }
  let name = symbol_name(k)
  let size = n + m + 2
  let mut table : Array[@symcore.Expr] = Array::new()
  for j in 0..<size {
    table.push(substitute_symbol(expr, name, j))
  }
  let table2 = copy_expr_array(table)
  let mut i = 1
  while i <= m {
    let mut j = i
    while j <= n + m {
      let x = table[j - 1]
      let y = table[j]
      let z = table[j + 1]
      let numerator = expr_sub(expr_mul(z, x), expr_mul(y, y))
      let denom = expr_add(expr_add(z, x), expr_mul(@symcore.int(-2), y))
      let inv = match expr_inv(denom) {
        Some(v) => v
        None => fail("shanks division by zero")
      }
      table2[j] = expr_mul(numerator, inv)
      j += 1
    }
    table = copy_expr_array(table2)
    i += 1
  }
  table[n]
}
