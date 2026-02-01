///|
/// Simple LLL lattice reduction over BigInt with default delta=3/4.
pub type Matrix = Array[Array[BigInt]]

///|
pub fn lll_reduce(
  basis : Matrix,
  delta? : @symnum.BigRational,
) -> (Matrix, Matrix) raise PolyError {
  if basis.is_empty() {
    return (basis, identity(0))
  }
  let cols = basis[0].length()
  for row in basis {
    if row.length() != cols {
      raise PolyError::DomainMismatch
    }
  }
  let basis_work = basis.copy()
  let transform = identity(basis_work.length())
  let d = match delta {
    Some(v) => v
    None =>
      @symnum.BigRational::from_int(3).div_r(@symnum.BigRational::from_int(4)) catch {
        _ => raise PolyError::DivisionByZero
      }
  }
  let mut k = 1
  while k < basis_work.length() {
    let (mu, bnorm) = gram_schmidt(basis_work)
    size_reduce(basis_work, transform, mu, k)
    if lovasz_ok(mu, bnorm, d, k) {
      k = k + 1
    } else {
      swap_rows(basis_work, k, k - 1)
      swap_rows(transform, k, k - 1)
      if k > 1 {
        k = k - 1
      }
    }
  }
  (basis_work, transform)
}

///|
fn identity(n : Int) -> Matrix {
  let res : Matrix = Array::new()
  for i in 0..<n {
    let row : Array[BigInt] = Array::make(n, BigInt::from_int(0))
    row.set(i, BigInt::from_int(1))
    res.push(row)
  }
  res
}

///|
fn swap_rows(mat : Matrix, i : Int, j : Int) -> Unit {
  let tmp = mat[i]
  mat.set(i, mat[j])
  mat.set(j, tmp)
}

///|
fn gram_schmidt(
  basis : Matrix,
) -> (Array[Array[@symnum.BigRational]], Array[@symnum.BigRational]) {
  let n = basis.length()
  let m = basis[0].length()
  let bstar : Array[Array[@symnum.BigRational]] = Array::make(
    n,
    Array::make(m, @symnum.BigRational::zero()),
  )
  let mu : Array[Array[@symnum.BigRational]] = Array::make(
    n,
    Array::make(n, @symnum.BigRational::zero()),
  )
  let bnorm : Array[@symnum.BigRational] = Array::make(
    n,
    @symnum.BigRational::zero(),
  )
  for i in 0..<n {
    bstar.set(i, basis[i].map(v => @symnum.BigRational::from_bigint(v)))
    for j in 0..<i {
      let dot_ib = dot_bigrational(basis[i], bstar[j])
      let dot_bb = dot_bigrational_rational(bstar[j], bstar[j])
      let coeff = dot_ib.div_r(dot_bb) catch {
        _ => @symnum.BigRational::zero()
      }
      mu[i].set(j, coeff)
      let proj = bstar[j].map(x => x.mul_r(coeff))
      for k in 0..<m {
        bstar[i].set(k, bstar[i][k].add_r(proj[k].neg_r()))
      }
    }
    bnorm.set(i, dot_bigrational_rational(bstar[i], bstar[i]))
  }
  (mu, bnorm)
}

///|
fn size_reduce(
  basis : Matrix,
  transform : Matrix,
  mu : Array[Array[@symnum.BigRational]],
  k : Int,
) -> Unit {
  if k == 0 {
    return
  }
  let mut j = k - 1
  while true {
    let r = round_bigrational(mu[k][j])
    if !r.is_zero() {
      for idx in 0..<basis[k].length() {
        let updated = basis[k][idx].sub(r.mul(basis[j][idx]))
        basis[k].set(idx, updated)
      }
      for idx in 0..<transform[k].length() {
        let updated = transform[k][idx].sub(r.mul(transform[j][idx]))
        transform[k].set(idx, updated)
      }
    }
    if j == 0 {
      break
    }
    j = j - 1
  }
}

///|
fn lovasz_ok(
  mu : Array[Array[@symnum.BigRational]],
  bnorm : Array[@symnum.BigRational],
  delta : @symnum.BigRational,
  k : Int,
) -> Bool {
  let lhs = delta.mul_r(bnorm[k - 1])
  let mu_sq = mu[k][k - 1].mul_r(mu[k][k - 1])
  let rhs = mu_sq.mul_r(bnorm[k - 1]).add_r(bnorm[k])
  lhs.compare(rhs) <= 0
}

///|
fn dot_bigrational(
  vec : Array[BigInt],
  vec_r : Array[@symnum.BigRational],
) -> @symnum.BigRational {
  let mut acc = @symnum.BigRational::zero()
  for i in 0..<vec.length() {
    let term = vec_r[i].mul_r(@symnum.BigRational::from_bigint(vec[i]))
    acc = acc.add_r(term)
  }
  acc
}

///|
fn dot_bigrational_rational(
  a : Array[@symnum.BigRational],
  b : Array[@symnum.BigRational],
) -> @symnum.BigRational {
  let mut acc = @symnum.BigRational::zero()
  for i in 0..<a.length() {
    acc = acc.add_r(a[i].mul_r(b[i]))
  }
  acc
}

///|
fn round_bigrational(x : @symnum.BigRational) -> BigInt {
  let num = x.numerator()
  let den = x.denominator()
  let half = den.div(BigInt::from_int(2))
  let mut n = num
  let neg = n.op_lt(BigInt::from_int(0))
  if neg {
    n = n.neg()
  }
  let quotient = n.div(den)
  let rem = n.mod(den)
  let mut rounded = quotient
  if rem.op_gt(half) || rem.equal(half) {
    rounded = rounded.add(BigInt::from_int(1))
  }
  if neg {
    rounded = rounded.neg()
  }
  rounded
}
