///|
/// Numerical Gaussian quadrature families aligned with `sympy.integrals.quadrature`.

///|
fn quad_rational_to_double(value : @symnum.BigRational) -> Double {
  value.numerator().to_int().to_double() /
  value.denominator().to_int().to_double()
}

///|
fn quad_expr_real_double(expr : Expr) -> Double? {
  match expr_simplify(expr) {
    @symcore.Expr::Number(value) => Some(quad_rational_to_double(value))
    @symcore.Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        match quad_expr_real_double(arg) {
          Some(value) => acc += value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        match quad_expr_real_double(arg) {
          Some(value) => acc *= value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match (quad_expr_real_double(base), quad_expr_real_double(exp)) {
        (Some(lhs), Some(rhs)) => Some(@math.pow(lhs, rhs))
        _ => None
      }
    @symcore.Expr::Function("sqrt", [arg]) =>
      match quad_expr_real_double(arg) {
        Some(value) if value >= 0.0 => Some(value.sqrt())
        _ => None
      }
    _ => None
  }
}

///|
fn quad_require_real_double(
  expr : Expr,
  label : String,
) -> Double raise IntegralError {
  match quad_expr_real_double(expr) {
    Some(value) => value
    None =>
      raise IntegralError::ValueError(
        label + " must be a real numeric expression",
      )
  }
}

///|
fn quad_validate_n(n : Int) -> Unit raise IntegralError {
  if n <= 0 {
    raise IntegralError::ValueError("quadrature order must be positive")
  }
}

///|
fn quad_clamp_digits(n_digits : Int) -> Int {
  if n_digits < 1 {
    1
  } else if n_digits > 15 {
    15
  } else {
    n_digits
  }
}

///|
fn quad_round_sig(value : Double, n_digits : Int) -> Double {
  if value == 0.0 {
    return 0.0
  }
  let digits = quad_clamp_digits(n_digits)
  let scale_exp = digits.to_double() -
    1.0 -
    @math.floor(@math.log10(value.abs()))
  let scale = @math.pow(10.0, scale_exp)
  @math.floor(value * scale + 0.5) / scale
}

///|
fn quad_gamma_lanczos(z : Double) -> Double {
  let coeffs = [
    676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059,
    12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7,
  ]
  if z < 0.5 {
    return @math.PI / (@math.sin(@math.PI * z) * quad_gamma_lanczos(1.0 - z))
  }
  let g = 7.0
  let mut acc = 0.99999999999980993
  let z0 = z - 1.0
  for i in 0..<coeffs.length() {
    acc += coeffs[i] / (z0 + i.to_double() + 1.0)
  }
  let t = z0 + g + 0.5
  (2.0 * @math.PI).sqrt() * @math.pow(t, z0 + 0.5) * @math.exp(-t) * acc
}

///|
fn quad_identity(n : Int) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for i in 0..<n {
    let row : Array[Double] = []
    for j in 0..<n {
      row.push(if i == j { 1.0 } else { 0.0 })
    }
    out.push(row)
  }
  out
}

///|
fn quad_symmetric_eigen(
  diag : Array[Double],
  offdiag : Array[Double],
) -> (Array[Double], Array[Array[Double]]) {
  let n = diag.length()
  let a : Array[Array[Double]] = []
  for _ in 0..<n {
    let row : Array[Double] = []
    for _ in 0..<n {
      row.push(0.0)
    }
    a.push(row)
  }
  for i in 0..<n {
    a[i][i] = diag[i]
    if i + 1 < n {
      a[i][i + 1] = offdiag[i]
      a[i + 1][i] = offdiag[i]
    }
  }
  let vecs = quad_identity(n)
  let max_iter = 80 * n * n + 1
  let tol = 1.0e-14
  for _ in 0..<max_iter {
    let mut p = 0
    let mut q = 0
    let mut best = 0.0
    for i in 0..<n {
      for j in (i + 1)..<n {
        let v = a[i][j].abs()
        if v > best {
          best = v
          p = i
          q = j
        }
      }
    }
    if best < tol {
      break
    }
    let app = a[p][p]
    let aqq = a[q][q]
    let apq = a[p][q]
    let tau = (aqq - app) / (2.0 * apq)
    let t = if tau >= 0.0 {
      1.0 / (tau + (1.0 + tau * tau).sqrt())
    } else {
      -1.0 / (-tau + (1.0 + tau * tau).sqrt())
    }
    let c = 1.0 / (1.0 + t * t).sqrt()
    let s = t * c
    for r in 0..<n {
      if r != p && r != q {
        let arp = a[r][p]
        let arq = a[r][q]
        a[r][p] = c * arp - s * arq
        a[p][r] = a[r][p]
        a[r][q] = s * arp + c * arq
        a[q][r] = a[r][q]
      }
    }
    a[p][p] = c * c * app - 2.0 * s * c * apq + s * s * aqq
    a[q][q] = s * s * app + 2.0 * s * c * apq + c * c * aqq
    a[p][q] = 0.0
    a[q][p] = 0.0
    for r in 0..<n {
      let vrp = vecs[r][p]
      let vrq = vecs[r][q]
      vecs[r][p] = c * vrp - s * vrq
      vecs[r][q] = s * vrp + c * vrq
    }
  }
  let evals : Array[Double] = []
  for i in 0..<n {
    evals.push(a[i][i])
  }
  for i in 0..<n {
    let mut best = i
    for j in (i + 1)..<n {
      if evals[j] < evals[best] {
        best = j
      }
    }
    if best != i {
      let tmp = evals[i]
      evals[i] = evals[best]
      evals[best] = tmp
      for r in 0..<n {
        let vv = vecs[r][i]
        vecs[r][i] = vecs[r][best]
        vecs[r][best] = vv
      }
    }
  }
  (evals, vecs)
}

///|
fn quad_from_jacobi(
  diag : Array[Double],
  offdiag : Array[Double],
  mu0 : Double,
  n_digits : Int,
) -> (Array[Double], Array[Double]) {
  let (nodes0, vecs) = quad_symmetric_eigen(diag, offdiag)
  let nodes : Array[Double] = []
  let weights : Array[Double] = []
  for i in 0..<nodes0.length() {
    nodes.push(quad_round_sig(nodes0[i], n_digits))
    weights.push(quad_round_sig(mu0 * vecs[0][i] * vecs[0][i], n_digits))
  }
  (nodes, weights)
}

///|
fn quad_jacobi_coeffs(
  n : Int,
  alpha : Double,
  beta : Double,
) -> (Array[Double], Array[Double], Double) {
  let diag : Array[Double] = []
  let offdiag : Array[Double] = []
  for i in 0..<n {
    let ni = i.to_double()
    let ai = if i == 0 {
      let denom = alpha + beta + 2.0
      if denom.abs() < 1.0e-14 {
        0.0
      } else {
        (beta - alpha) / denom
      }
    } else {
      let den = (2.0 * ni + alpha + beta) * (2.0 * ni + alpha + beta + 2.0)
      (beta * beta - alpha * alpha) / den
    }
    diag.push(ai)
  }
  for i in 1..<n {
    let ni = i.to_double()
    let num = 4.0 * ni * (ni + alpha) * (ni + beta) * (ni + alpha + beta)
    let den = @math.pow(2.0 * ni + alpha + beta, 2.0) *
      (2.0 * ni + alpha + beta + 1.0) *
      (2.0 * ni + alpha + beta - 1.0)
    offdiag.push((num / den).sqrt())
  }
  let mu0 = @math.pow(2.0, alpha + beta + 1.0) *
    quad_gamma_lanczos(alpha + 1.0) *
    quad_gamma_lanczos(beta + 1.0) /
    quad_gamma_lanczos(alpha + beta + 2.0)
  (diag, offdiag, mu0)
}

///|
fn quad_laguerre_coeffs(
  n : Int,
  alpha : Double,
) -> (Array[Double], Array[Double], Double) {
  let diag : Array[Double] = []
  let offdiag : Array[Double] = []
  for i in 0..<n {
    let ni = i.to_double()
    diag.push(2.0 * ni + alpha + 1.0)
  }
  for i in 1..<n {
    let ni = i.to_double()
    offdiag.push((ni * (ni + alpha)).sqrt())
  }
  (diag, offdiag, quad_gamma_lanczos(alpha + 1.0))
}

///|
fn quad_hermite_coeffs(n : Int) -> (Array[Double], Array[Double], Double) {
  let diag : Array[Double] = []
  let offdiag : Array[Double] = []
  for _ in 0..<n {
    diag.push(0.0)
  }
  for i in 1..<n {
    offdiag.push((i.to_double() / 2.0).sqrt())
  }
  (diag, offdiag, @math.PI.sqrt())
}

///|
fn quad_legendre_eval(n : Int, x : Double) -> Double {
  if n == 0 {
    return 1.0
  }
  if n == 1 {
    return x
  }
  let mut p0 = 1.0
  let mut p1 = x
  for k in 1..<n {
    let kd = k.to_double()
    let p2 = ((2.0 * kd + 1.0) * x * p1 - kd * p0) / (kd + 1.0)
    p0 = p1
    p1 = p2
  }
  p1
}

///|
pub fn gauss_legendre(
  n : Int,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  quad_validate_n(n)
  let (diag, offdiag, mu0) = quad_jacobi_coeffs(n, 0.0, 0.0)
  quad_from_jacobi(diag, offdiag, mu0, n_digits)
}

///|
pub fn gauss_jacobi(
  n : Int,
  alpha : Expr,
  beta : Expr,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  quad_validate_n(n)
  let a = quad_require_real_double(alpha, "alpha")
  let b = quad_require_real_double(beta, "beta")
  if a <= -1.0 || b <= -1.0 {
    raise IntegralError::ValueError("alpha and beta must be greater than -1")
  }
  let (diag, offdiag, mu0) = quad_jacobi_coeffs(n, a, b)
  quad_from_jacobi(diag, offdiag, mu0, n_digits)
}

///|
pub fn gauss_chebyshev_t(
  n : Int,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  quad_validate_n(n)
  gauss_jacobi(n, expr_rat(-1, 2), expr_rat(-1, 2), n_digits~)
}

///|
pub fn gauss_chebyshev_u(
  n : Int,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  quad_validate_n(n)
  gauss_jacobi(n, expr_rat(1, 2), expr_rat(1, 2), n_digits~)
}

///|
pub fn gauss_laguerre(
  n : Int,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  quad_validate_n(n)
  let (diag, offdiag, mu0) = quad_laguerre_coeffs(n, 0.0)
  quad_from_jacobi(diag, offdiag, mu0, n_digits)
}

///|
pub fn gauss_gen_laguerre(
  n : Int,
  alpha : Expr,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  quad_validate_n(n)
  let a = quad_require_real_double(alpha, "alpha")
  if a <= -1.0 {
    raise IntegralError::ValueError("alpha must be greater than -1")
  }
  let (diag, offdiag, mu0) = quad_laguerre_coeffs(n, a)
  quad_from_jacobi(diag, offdiag, mu0, n_digits)
}

///|
pub fn gauss_hermite(
  n : Int,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  quad_validate_n(n)
  let (diag, offdiag, mu0) = quad_hermite_coeffs(n)
  quad_from_jacobi(diag, offdiag, mu0, n_digits)
}

///|
pub fn gauss_lobatto(
  n : Int,
  n_digits? : Int = 15,
) -> (Array[Double], Array[Double]) raise IntegralError {
  if n < 2 {
    raise IntegralError::ValueError("Gauss-Lobatto requires order at least 2")
  }
  if n == 2 {
    return (
      [quad_round_sig(-1.0, n_digits), quad_round_sig(1.0, n_digits)],
      [quad_round_sig(1.0, n_digits), quad_round_sig(1.0, n_digits)],
    )
  }
  let (inner_nodes, _) = gauss_jacobi(
    n - 2,
    expr_one(),
    expr_one(),
    n_digits=15,
  )
  let nodes : Array[Double] = [quad_round_sig(-1.0, n_digits)]
  let weights : Array[Double] = []
  let edge = 2.0 / (n.to_double() * (n - 1).to_double())
  weights.push(quad_round_sig(edge, n_digits))
  for node in inner_nodes {
    nodes.push(quad_round_sig(node, n_digits))
    let pn = quad_legendre_eval(n - 1, node)
    let weight = 2.0 / (n.to_double() * (n - 1).to_double() * pn * pn)
    weights.push(quad_round_sig(weight, n_digits))
  }
  nodes.push(quad_round_sig(1.0, n_digits))
  weights.push(quad_round_sig(edge, n_digits))
  (nodes, weights)
}
