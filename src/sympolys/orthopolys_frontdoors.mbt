///|
/// Orthogonal and Appell polynomial front doors.
///
/// Current Limits:
/// - These functions return expression values, matching the default source
///   front-door behavior.
/// - Parameterized families accept expression parameters, but heavy expression
///   simplification is intentionally left to the core/simplify layers.

///|
/// Generate the Jacobi polynomial `P_n^(a,b)(x)`.
///
/// - Does: Evaluates the recurrence used by the source `dup_jacobi` kernel.
/// - Input: Degree `n`, parameters `a`/`b`, and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn jacobi_poly(
  n : Int,
  a : Expr,
  b : Expr,
  gen? : String = "x",
) -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  match (expr_rat_sp(a), expr_rat_sp(b)) {
    (Some(ar), Some(br)) => return jacobi_poly_rational(n, ar, br, gen)
    _ => ()
  }
  let x = Expr::Symbol(gen)
  if n < 1 {
    return int(1)
  }
  let mut m2 = int(1)
  let mut m1 = ((a + b) * sp_rat(1, 2) + int(1)) * x + (a - b) * sp_rat(1, 2)
  for i in 2..<=n {
    let ii = int(i)
    let den = ii * (a + b + ii) * (a + b + int(2 * i - 2))
    let f0 = (a + b + int(2 * i - 1)) *
      (a * a - b * b) *
      ((int(2) * den) ^ int(-1))
    let f1 = (a + b + int(2 * i - 1)) *
      (a + b + int(2 * i - 2)) *
      (a + b + int(2 * i)) *
      ((int(2) * den) ^ int(-1))
    let f2 = (a + int(i - 1)) *
      (b + int(i - 1)) *
      (a + b + int(2 * i)) *
      (den ^ int(-1))
    let next = m1 * f0 + x * m1 * f1 - m2 * f2
    m2 = m1
    m1 = next
  }
  canonical_poly_expr(m1, gen, QQ)
}

///|
fn jacobi_poly_rational(
  n : Int,
  a : @symnum.BigRational,
  b : @symnum.BigRational,
  gen : String,
) -> Expr raise PolyError {
  let x = Expr::Symbol(gen)
  if n < 1 {
    return int(1)
  }
  let mut m2 : Array[Expr] = [int(1)]
  let mut m1 : Array[Expr] = [
    rational_to_expr(
      a.sub_r(b).div_r(rat_int(2)) catch {
        _ => raise DivisionByZero
      },
    ),
    rational_to_expr(
      a.add_r(b).div_r(rat_int(2)) catch {
        _ => raise DivisionByZero
      },
    ) +
    int(1),
  ]
  for i in 2..<=n {
    let i_rat = rat_int(i)
    let den = i_rat
      .mul_r(a.add_r(b).add_r(i_rat))
      .mul_r(a.add_r(b).add_r(rat_int(2 * i - 2)))
    if den.is_zero() {
      raise DivisionByZero
    }
    let common = a.add_r(b).add_r(rat_int(2 * i - 1))
    let f0 = rat_div_sp(
      common.mul_r(a.mul_r(a).sub_r(b.mul_r(b))),
      rat_int(2).mul_r(den),
    )
    let f1 = rat_div_sp(
      common
      .mul_r(a.add_r(b).add_r(rat_int(2 * i - 2)))
      .mul_r(a.add_r(b).add_r(rat_int(2 * i))),
      rat_int(2).mul_r(den),
    )
    let f2 = rat_div_sp(
      a
      .add_r(rat_int(i - 1))
      .mul_r(b.add_r(rat_int(i - 1)))
      .mul_r(a.add_r(b).add_r(rat_int(2 * i))),
      den,
    )
    let next = expr_poly_sub(
      expr_poly_add(
        expr_poly_scale(m1, rational_to_expr(f0)),
        expr_poly_scale(expr_poly_shift(m1), rational_to_expr(f1)),
      ),
      expr_poly_scale(m2, rational_to_expr(f2)),
    )
    m2 = m1
    m1 = next
  }
  canonical_poly_expr(poly_expr_from_coeffs(m1, x), gen, QQ)
}

///|
/// Low-level dense Jacobi polynomial coefficients.
///
/// - Does: Evaluates the source recurrence for `P_n^(a,b)` in dense form.
/// - Input: Degree `n`, parameters `a`/`b` as `FieldElem`, and a coefficient
///   domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported coefficient division in the given domain.
pub fn dup_jacobi(
  n : Int,
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let one = fe_from_int(1, domain)
  let two = fe_from_int(2, domain)
  let half = orth_fe_inv(two)
  let a_plus_b = fe_add(a, b)
  let mut m2 = [one]
  let mut m1 = [fe_add(fe_mul(a_plus_b, half), one), fe_mul(fe_sub(a, b), half)]
  for i in 2..<=n {
    let ii = fe_from_int(i, domain)
    let den = fe_mul(
      fe_mul(ii, fe_add(a_plus_b, ii)),
      fe_add(a_plus_b, fe_from_int(2 * i - 2, domain)),
    )
    let f0 = orth_fe_div(
      fe_mul(
        fe_add(a_plus_b, fe_from_int(2 * i - 1, domain)),
        fe_sub(fe_mul(a, a), fe_mul(b, b)),
      ),
      fe_mul(two, den),
    )
    let f1 = orth_fe_div(
      fe_mul(
        fe_mul(
          fe_add(a_plus_b, fe_from_int(2 * i - 1, domain)),
          fe_add(a_plus_b, fe_from_int(2 * i - 2, domain)),
        ),
        fe_add(a_plus_b, fe_from_int(2 * i, domain)),
      ),
      fe_mul(two, den),
    )
    let f2 = orth_fe_div(
      fe_mul(
        fe_mul(
          fe_add(a, fe_from_int(i - 1, domain)),
          fe_add(b, fe_from_int(i - 1, domain)),
        ),
        fe_add(a_plus_b, fe_from_int(2 * i, domain)),
      ),
      den,
    )
    let p0 = dup_mul_ground(m1, f0, domain)
    let p1 = dup_mul_ground(dup_lshift(m1, 1, domain), f1, domain)
    let p2 = dup_mul_ground(m2, f2, domain)
    m2 = m1
    m1 = dup_sub(dup_add(p0, p1, domain), p2, domain)
  }
  m1
}

///|
/// Low-level dense Gegenbauer polynomial coefficients.
///
/// - Does: Evaluates the source three-term recurrence for `C_n^(a)`.
/// - Input: Degree `n`, parameter `a`, and a coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported coefficient division in the given domain.
pub fn dup_gegenbauer(
  n : Int,
  a : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let one = fe_from_int(1, domain)
  let two = fe_from_int(2, domain)
  let mut m2 = [one]
  let mut m1 = [fe_mul(two, a), fe_from_int(0, domain)]
  for i in 2..<=n {
    let factor1 = fe_add(
      orth_fe_div(fe_mul(two, fe_sub(a, one)), fe_from_int(i, domain)),
      two,
    )
    let factor2 = fe_add(
      orth_fe_div(fe_mul(two, fe_sub(a, one)), fe_from_int(i, domain)),
      one,
    )
    let p1 = dup_mul_ground(dup_lshift(m1, 1, domain), factor1, domain)
    let p2 = dup_mul_ground(m2, factor2, domain)
    m2 = m1
    m1 = dup_sub(p1, p2, domain)
  }
  m1
}

///|
/// Generate the Gegenbauer polynomial `C_n^(a)(x)`.
///
/// - Does: Applies the source Gegenbauer recurrence and returns an expression.
/// - Input: Degree `n`, parameter `a`, and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn gegenbauer_poly(
  n : Int,
  a : Expr,
  gen? : String = "x",
) -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  match expr_rat_sp(a) {
    Some(ar) => {
      let coeffs = dup_gegenbauer(n, fe_from_rational(ar, QQ), QQ)
      return canonical_poly_expr(dense_coeffs_to_expr(coeffs, x), gen, QQ)
    }
    None => ()
  }
  if n < 1 {
    return int(1)
  }
  let mut m2 : Array[Expr] = [int(1)]
  let mut m1 : Array[Expr] = [int(0), int(2) * a]
  for i in 2..<=n {
    let factor1 = int(2) * (a - int(1)) * sp_rat(1, i) + int(2)
    let factor2 = int(2) * (a - int(1)) * sp_rat(1, i) + int(1)
    let p1 = expr_poly_scale(expr_poly_shift(m1), factor1)
    let p2 = expr_poly_scale(m2, factor2)
    m2 = m1
    m1 = expr_poly_sub(p1, p2)
  }
  canonical_poly_expr(poly_expr_from_coeffs(m1, x), gen, QQ)
}

///|
/// Low-level dense Chebyshev-T polynomial coefficients.
///
/// - Does: Applies `T_0=1`, `T_1=x`, `T_n=2*x*T_(n-1)-T_(n-2)`.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn dup_chebyshevt(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let mut m2 = [fe_from_int(1, domain)]
  let mut m1 = [fe_from_int(1, domain), fe_from_int(0, domain)]
  for _ in 0..<(n - 1) {
    let next = dup_sub(
      dup_mul_ground(dup_lshift(m1, 1, domain), fe_from_int(2, domain), domain),
      m2,
      domain,
    )
    m2 = m1
    m1 = next
  }
  m1
}

///|
/// Low-level dense Chebyshev-U polynomial coefficients.
///
/// - Does: Applies `U_0=1`, `U_1=2*x`, `U_n=2*x*U_(n-1)-U_(n-2)`.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn dup_chebyshevu(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let mut m2 = [fe_from_int(1, domain)]
  let mut m1 = [fe_from_int(2, domain), fe_from_int(0, domain)]
  for _ in 2..<=n {
    let next = dup_sub(
      dup_mul_ground(dup_lshift(m1, 1, domain), fe_from_int(2, domain), domain),
      m2,
      domain,
    )
    m2 = m1
    m1 = next
  }
  m1
}

///|
/// Generate the Chebyshev polynomial of the first kind.
///
/// - Does: Applies `T_0 = 1`, `T_1 = x`, `T_n = 2*x*T_(n-1)-T_(n-2)`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn chebyshevt_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  if n == 0 {
    return int(1)
  }
  if n == 1 {
    return x
  }
  let mut m2 = int(1)
  let mut m1 = x
  for _ in 2..<=n {
    let next = int(2) * x * m1 - m2
    m2 = m1
    m1 = next
  }
  canonical_poly_expr(m1, gen, ZZ)
}

///|
/// Generate the Chebyshev polynomial of the second kind.
///
/// - Does: Applies `U_0 = 1`, `U_1 = 2*x`,
///   `U_n = 2*x*U_(n-1)-U_(n-2)`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn chebyshevu_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  if n == 0 {
    return int(1)
  }
  if n == 1 {
    return int(2) * x
  }
  let mut m2 = int(1)
  let mut m1 = int(2) * x
  for _ in 2..<=n {
    let next = int(2) * x * m1 - m2
    m2 = m1
    m1 = next
  }
  canonical_poly_expr(m1, gen, ZZ)
}

///|
/// Generate the physicists' Hermite polynomial.
///
/// - Does: Applies `H_0 = 1`, `H_1 = 2*x`,
///   `H_n = 2*x*H_(n-1)-2*(n-1)*H_(n-2)`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn hermite_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  if n == 0 {
    return int(1)
  }
  if n == 1 {
    return int(2) * x
  }
  let mut m2 = int(1)
  let mut m1 = int(2) * x
  for i in 2..<=n {
    let next = int(2) * x * m1 - int(2 * (i - 1)) * m2
    m2 = m1
    m1 = next
  }
  canonical_poly_expr(m1, gen, ZZ)
}

///|
/// Generate the probabilists' Hermite polynomial.
///
/// - Does: Applies `He_0 = 1`, `He_1 = x`,
///   `He_n = x*He_(n-1)-(n-1)*He_(n-2)`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn hermite_prob_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  if n == 0 {
    return int(1)
  }
  if n == 1 {
    return x
  }
  let mut m2 = int(1)
  let mut m1 = x
  for i in 2..<=n {
    let next = x * m1 - int(i - 1) * m2
    m2 = m1
    m1 = next
  }
  canonical_poly_expr(m1, gen, ZZ)
}

///|
/// Low-level dense physicists' Hermite polynomial coefficients.
///
/// - Does: Applies `H_n = 2*x*H_(n-1)-2*(n-1)*H_(n-2)`.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn dup_hermite(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let mut m2 = [fe_from_int(1, domain)]
  let mut m1 = [fe_from_int(2, domain), fe_from_int(0, domain)]
  for i in 2..<=n {
    let a = dup_lshift(m1, 1, domain)
    let b = dup_mul_ground(m2, fe_from_int(i - 1, domain), domain)
    let next = dup_mul_ground(
      dup_sub(a, b, domain),
      fe_from_int(2, domain),
      domain,
    )
    m2 = m1
    m1 = next
  }
  m1
}

///|
/// Low-level dense probabilists' Hermite polynomial coefficients.
///
/// - Does: Applies `He_n = x*He_(n-1)-(n-1)*He_(n-2)`.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn dup_hermite_prob(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let mut m2 = [fe_from_int(1, domain)]
  let mut m1 = [fe_from_int(1, domain), fe_from_int(0, domain)]
  for i in 2..<=n {
    let a = dup_lshift(m1, 1, domain)
    let b = dup_mul_ground(m2, fe_from_int(i - 1, domain), domain)
    let next = dup_sub(a, b, domain)
    m2 = m1
    m1 = next
  }
  m1
}

///|
/// Generate the Legendre polynomial.
///
/// - Does: Applies the standard three-term Legendre recurrence.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn legendre_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  if n == 0 {
    return int(1)
  }
  if n == 1 {
    return x
  }
  let mut m2 = int(1)
  let mut m1 = x
  for i in 2..<=n {
    let next = sp_rat(2 * i - 1, i) * x * m1 - sp_rat(i - 1, i) * m2
    m2 = m1
    m1 = next
  }
  canonical_poly_expr(m1, gen, QQ)
}

///|
/// Low-level dense Legendre polynomial coefficients.
///
/// - Does: Applies the source three-term Legendre recurrence.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn dup_legendre(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let mut m2 = [fe_from_int(1, domain)]
  let mut m1 = [fe_from_int(1, domain), fe_from_int(0, domain)]
  for i in 2..<=n {
    let a = dup_mul_ground(
      dup_lshift(m1, 1, domain),
      orth_fe_rat(2 * i - 1, i, domain),
      domain,
    )
    let b = dup_mul_ground(m2, orth_fe_rat(i - 1, i, domain), domain)
    let next = dup_sub(a, b, domain)
    m2 = m1
    m1 = next
  }
  m1
}

///|
/// Generate the generalized Laguerre polynomial.
///
/// - Does: Applies the recurrence used by the source `dup_laguerre` kernel.
/// - Input: Degree `n`, optional generator name, and optional `alpha`.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn laguerre_poly(
  n : Int,
  gen? : String = "x",
  alpha? : Expr = int(0),
) -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  let mut m2 = int(0)
  let mut m1 = int(1)
  for i in 1..<=n {
    let ii_inv = sp_rat(1, i)
    let a = m1 * (int(-1) * x * ii_inv + (alpha - int(1)) * ii_inv + int(2))
    let b = m2 * ((alpha - int(1)) * ii_inv + int(1))
    m2 = m1
    m1 = a - b
  }
  canonical_poly_expr(m1, gen, QQ)
}

///|
/// Low-level dense generalized Laguerre polynomial coefficients.
///
/// - Does: Applies the source recurrence for `L_n^(alpha)`.
/// - Input: Degree `n`, parameter `alpha`, and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported coefficient division in the given domain.
pub fn dup_laguerre(
  n : Int,
  alpha : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  let mut m2 = [fe_from_int(0, domain)]
  let mut m1 = [fe_from_int(1, domain)]
  for i in 1..<=n {
    let inv_i = orth_fe_inv(fe_from_int(i, domain))
    let linear = [
      fe_neg(inv_i),
      fe_add(
        fe_mul(fe_sub(alpha, fe_from_int(1, domain)), inv_i),
        fe_from_int(2, domain),
      ),
    ]
    let a = dup_mul(m1, linear, domain)
    let b = dup_mul_ground(
      m2,
      fe_add(
        fe_mul(fe_sub(alpha, fe_from_int(1, domain)), inv_i),
        fe_from_int(1, domain),
      ),
      domain,
    )
    let next = dup_sub(a, b, domain)
    m2 = m1
    m1 = next
  }
  m1
}

///|
/// Low-level dense spherical Bessel auxiliary coefficients.
///
/// - Does: Computes the source `fn(n, x)` coefficient polynomial.
/// - Input: Degree marker `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn dup_spherical_bessel_fn(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  if n < 1 {
    return [fe_from_int(1, domain), fe_from_int(0, domain)]
  }
  let mut m2 = [fe_from_int(1, domain)]
  let mut m1 = [fe_from_int(1, domain), fe_from_int(0, domain)]
  for i in 2..<=n {
    let next = dup_sub(
      dup_mul_ground(
        dup_lshift(m1, 1, domain),
        fe_from_int(2 * i - 1, domain),
        domain,
      ),
      m2,
      domain,
    )
    m2 = m1
    m1 = next
  }
  dup_lshift(m1, 1, domain)
}

///|
/// Low-level dense negative-index spherical Bessel auxiliary coefficients.
///
/// - Does: Computes the source `fn(-n, x)` coefficient polynomial.
/// - Input: Positive index marker `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn dup_spherical_bessel_fn_minus(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  let mut m2 = [fe_from_int(1, domain), fe_from_int(0, domain)]
  let mut m1 = [fe_from_int(0, domain)]
  for i in 2..<=n {
    let next = dup_sub(
      dup_mul_ground(
        dup_lshift(m1, 1, domain),
        fe_from_int(3 - 2 * i, domain),
        domain,
      ),
      m2,
      domain,
    )
    m2 = m1
    m1 = next
  }
  m1
}

///|
/// Generate the spherical Bessel auxiliary polynomial.
///
/// - Does: Builds the expression returned by SymPy's `spherical_bessel_fn`.
/// - Input: Integer index `n` and optional generator name.
/// - Returns: An exact expression in powers of `1/x`.
/// - Limits: This is the coefficient helper used by spherical Bessel
///   functions, not numeric Bessel evaluation.
pub fn spherical_bessel_fn(
  n : Int,
  gen? : String = "x",
) -> Expr raise PolyError {
  let x_inv = Expr::Symbol(gen) ^ int(-1)
  let coeffs = if n < 0 {
    dup_spherical_bessel_fn_minus(-n, ZZ)
  } else {
    dup_spherical_bessel_fn(n, ZZ)
  }
  dense_coeffs_to_expr(coeffs, x_inv)
}

///|
/// Generate the Bernoulli polynomial.
///
/// - Does: Builds `sum(binomial(n,k)*B_k*x^(n-k))` using exact Bernoulli
///   numbers with `B_1 = -1/2`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn bernoulli_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  let terms : Array[Expr] = []
  for k in 0..<=n {
    terms.push(
      int_binomial_expr(n, k) *
      rational_to_expr(bernoulli_number_sp(k)) *
      expr_pow_int(x, n - k),
    )
  }
  canonical_poly_expr(expr_add_all(terms), gen, QQ)
}

///|
/// Low-level dense Bernoulli polynomial coefficients.
///
/// - Does: Evaluates the source Appell recurrence for `B_n(x)`.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported rational coefficients in the domain.
pub fn dup_bernoulli(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if n < 1 {
    return [fe_from_int(1, domain)]
  }
  let mut p = [fe_from_int(1, domain), orth_fe_rat(-1, 2, domain)]
  for i in 2..<=n {
    p = dup_integrate(
      dup_mul_ground(p, fe_from_int(i, domain), domain),
      1,
      domain,
    )
    if i % 2 == 0 {
      let scale = orth_fe_rat(
        orth_int_pow(2, i - 1),
        orth_int_pow(2, i) - 1,
        domain,
      )
      let value = fe_mul(dup_eval(p, orth_fe_rat(1, 2, domain), domain), scale)
      p = dup_sub_ground(p, value, domain)
    }
  }
  p
}

///|
/// Generate the central Bernoulli polynomial.
///
/// - Does: Builds `2^n * B_n((x + 1)/2)`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn bernoulli_c_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  let shifted = (x + int(1)) * sp_rat(1, 2)
  let terms : Array[Expr] = []
  for k in 0..<=n {
    terms.push(
      int_binomial_expr(n, k) *
      rational_to_expr(bernoulli_number_sp(k)) *
      expr_pow_int(shifted, n - k),
    )
  }
  let expr = int_pow_expr(2, n) * expr_add_all(terms)
  canonical_poly_expr(expr, gen, QQ)
}

///|
/// Low-level dense central Bernoulli polynomial coefficients.
///
/// - Does: Evaluates the source Appell recurrence for `B_n^c(x)`.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported rational coefficients in the domain.
pub fn dup_bernoulli_c(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let mut p = [fe_from_int(1, domain)]
  for i in 1..<=n {
    p = dup_integrate(
      dup_mul_ground(p, fe_from_int(i, domain), domain),
      1,
      domain,
    )
    if i % 2 == 0 {
      let scale = orth_fe_rat(
        orth_int_pow(2, i - 1) - 1,
        orth_int_pow(2, i) - 1,
        domain,
      )
      let value = fe_mul(dup_eval(p, fe_from_int(1, domain), domain), scale)
      p = dup_sub_ground(p, value, domain)
    }
  }
  p
}

///|
/// Generate the Genocchi polynomial.
///
/// - Does: Builds `2*(B_n(x)-B_n^c(x))`.
/// - Input: Degree marker `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn genocchi_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let expr = int(2) * (bernoulli_poly(n, gen~) - bernoulli_c_poly(n, gen~))
  canonical_poly_expr(expr, gen, QQ)
}

///|
/// Low-level dense Genocchi polynomial coefficients.
///
/// - Does: Evaluates the source Appell recurrence for `G_n(x)`.
/// - Input: Degree marker `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported exact division in the domain.
pub fn dup_genocchi(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if n < 1 {
    return [fe_from_int(0, domain)]
  }
  let mut p = [fe_from_int(-1, domain)]
  for i in 2..<=n {
    p = dup_integrate(
      dup_mul_ground(p, fe_from_int(i, domain), domain),
      1,
      domain,
    )
    if i % 2 == 0 {
      let value = orth_fe_div(
        dup_eval(p, fe_from_int(1, domain), domain),
        fe_from_int(2, domain),
      )
      p = dup_sub_ground(p, value, domain)
    }
  }
  p
}

///|
/// Generate the Euler polynomial.
///
/// - Does: Builds `-G_(n+1)(x)/(n+1)`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn euler_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let expr = int(-1) * genocchi_poly(n + 1, gen~) * sp_rat(1, n + 1)
  canonical_poly_expr(expr, gen, QQ)
}

///|
/// Low-level dense Euler polynomial coefficients.
///
/// - Does: Computes `-G_(n+1)(x)/(n+1)` using the Genocchi kernel.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported exact division in the domain.
pub fn dup_euler(n : Int, domain : Domain) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  dup_exquo_ground(dup_genocchi(n + 1, ZZ), fe_from_int(-n - 1, domain), domain)
}

///|
/// Generate the Andre polynomial.
///
/// - Does: Evaluates the Appell recurrence from `dup_andre`.
/// - Input: Degree `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for negative `n`.
pub fn andre_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  guard_nonnegative_degree(n)
  let x = Expr::Symbol(gen)
  let mut coeffs : Array[Expr] = [int(1)]
  for i in 1..<=n {
    coeffs = poly_coeffs_integrate_scaled(coeffs, i)
    if i % 2 == 0 {
      let value_at_one = poly_coeffs_eval(coeffs, int(1))
      coeffs[0] = coeffs[0] - value_at_one
    }
  }
  canonical_poly_expr(poly_expr_from_coeffs(coeffs, x), gen, QQ)
}

///|
/// Low-level dense Andre polynomial coefficients.
///
/// - Does: Evaluates the source Appell recurrence for Andre polynomials.
/// - Input: Degree `n` and coefficient domain.
/// - Returns: Dense coefficients in descending degree order.
/// - Limits: Raises for unsupported exact division in the domain.
pub fn dup_andre(n : Int, domain : Domain) -> Array[FieldElem] raise PolyError {
  guard_nonnegative_degree(n)
  let mut p = [fe_from_int(1, domain)]
  for i in 1..<=n {
    p = dup_integrate(
      dup_mul_ground(p, fe_from_int(i, domain), domain),
      1,
      domain,
    )
    if i % 2 == 0 {
      p = dup_sub_ground(p, dup_eval(p, fe_from_int(1, domain), domain), domain)
    }
  }
  p
}

///|
fn guard_nonnegative_degree(n : Int) -> Unit raise PolyError {
  if n < 0 {
    raise BadExponent
  }
}

///|
fn orth_fe_rat(
  num : Int,
  den : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  let rat = @symnum.BigRational::from_ints(num, den) catch {
    _ => raise DivisionByZero
  }
  fe_from_rational(rat, domain)
}

///|
fn orth_fe_inv(value : FieldElem) -> FieldElem raise PolyError {
  fe_inv(value)
}

///|
fn orth_fe_div(lhs : FieldElem, rhs : FieldElem) -> FieldElem raise PolyError {
  fe_mul(lhs, orth_fe_inv(rhs))
}

///|
fn orth_int_pow(base : Int, exp : Int) -> Int {
  let mut result = 1
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result * b
    }
    e = e / 2
    if e > 0 {
      b = b * b
    }
  }
  result
}

///|
fn dense_coeffs_to_expr(coeffs : Array[FieldElem], x : Expr) -> Expr {
  let terms : Array[Expr] = []
  let degree = coeffs.length() - 1
  for i in 0..<coeffs.length() {
    terms.push(fe_to_expr_const(coeffs[i]) * expr_pow_int(x, degree - i))
  }
  expr_add_all(terms)
}

///|
fn sp_rat(num : Int, den : Int) -> Expr {
  rational_to_expr(
    @symnum.BigRational::from_ints(num, den) catch {
      _ => abort("sp_rat expects nonzero denominator")
    },
  )
}

///|
fn rational_to_expr(value : @symnum.BigRational) -> Expr {
  Number(value)
}

///|
fn rat_int(n : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_int(n)
}

///|
fn rat_div_sp(
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
) -> @symnum.BigRational raise PolyError {
  lhs.div_r(rhs) catch {
    _ => raise DivisionByZero
  }
}

///|
fn expr_rat_sp(expr : Expr) -> @symnum.BigRational? {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) =>
      try @symnum.BigRational::new(num, den) catch {
        _ => None
      } noraise {
        value => Some(value)
      }
    None => None
  }
}

///|
fn int_binomial_expr(n : Int, k : Int) -> Expr {
  int(int_binomial(n, k))
}

///|
fn int_binomial(n : Int, k0 : Int) -> Int {
  if k0 < 0 || k0 > n {
    return 0
  }
  let k = if k0 > n - k0 { n - k0 } else { k0 }
  let mut acc = 1
  for i in 1..<=k {
    acc = acc * (n - k + i) / i
  }
  acc
}

///|
fn int_pow_expr(base : Int, exp : Int) -> Expr {
  if exp == 0 {
    int(1)
  } else {
    int(base) ^ int(exp)
  }
}

///|
fn expr_pow_int(base : Expr, exp : Int) -> Expr {
  if exp == 0 {
    int(1)
  } else if exp == 1 {
    base
  } else {
    base ^ int(exp)
  }
}

///|
fn bernoulli_number_sp(n : Int) -> @symnum.BigRational {
  if n == 1 {
    return @symnum.BigRational::from_ints(-1, 2) catch {
      _ => abort("valid Bernoulli denominator")
    }
  }
  if n > 1 && n % 2 == 1 {
    return @symnum.BigRational::zero()
  }
  let values = Array::make(n + 1, @symnum.BigRational::zero())
  for m in 0..<=n {
    values[m] = @symnum.BigRational::from_ints(1, m + 1) catch {
      _ => abort("valid Bernoulli denominator")
    }
    let mut j = m
    while j >= 1 {
      values[j - 1] = values[j - 1]
        .sub_r(values[j])
        .mul_r(@symnum.BigRational::from_int(j))
      j -= 1
    }
  }
  values[0]
}

///|
fn poly_coeffs_integrate_scaled(
  coeffs : Array[Expr],
  scale : Int,
) -> Array[Expr] {
  let out = Array::make(coeffs.length() + 1, int(0))
  for i in 0..<coeffs.length() {
    out[i + 1] = coeffs[i] * sp_rat(scale, i + 1)
  }
  out
}

///|
fn poly_coeffs_eval(coeffs : Array[Expr], x : Expr) -> Expr {
  let terms : Array[Expr] = []
  for i in 0..<coeffs.length() {
    terms.push(coeffs[i] * expr_pow_int(x, i))
  }
  expr_add_all(terms)
}

///|
fn poly_expr_from_coeffs(coeffs : Array[Expr], x : Expr) -> Expr {
  let terms : Array[Expr] = []
  for i in 0..<coeffs.length() {
    terms.push(coeffs[i] * expr_pow_int(x, i))
  }
  expr_add_all(terms)
}

///|
fn expr_poly_scale(coeffs : Array[Expr], scalar : Expr) -> Array[Expr] {
  coeffs.map(coeff => coeff * scalar)
}

///|
fn expr_poly_shift(coeffs : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = [int(0)]
  for coeff in coeffs {
    out.push(coeff)
  }
  out
}

///|
fn expr_poly_add(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  let len = if lhs.length() > rhs.length() {
    lhs.length()
  } else {
    rhs.length()
  }
  let out = Array::make(len, int(0))
  for i in 0..<len {
    let a = if i < lhs.length() { lhs[i] } else { int(0) }
    let b = if i < rhs.length() { rhs[i] } else { int(0) }
    out[i] = a + b
  }
  out
}

///|
fn expr_poly_sub(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  let len = if lhs.length() > rhs.length() {
    lhs.length()
  } else {
    rhs.length()
  }
  let out = Array::make(len, int(0))
  for i in 0..<len {
    let a = if i < lhs.length() { lhs[i] } else { int(0) }
    let b = if i < rhs.length() { rhs[i] } else { int(0) }
    out[i] = a - b
  }
  out
}

///|
fn canonical_poly_expr(expr : Expr, gen : String, domain : Domain) -> Expr {
  Poly::from_expr(expr, [gen], domain).to_expr() catch {
    _ => expr
  }
}
