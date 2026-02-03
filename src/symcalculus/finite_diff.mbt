///|
fn fd_rat_zero() -> BigRational {
  BigRational::zero()
}

///|
fn fd_rat_one() -> BigRational {
  BigRational::one()
}

///|
fn fd_rat_from_int(n : Int) -> BigRational {
  BigRational::from_int(n)
}

///|
fn fd_rat_sub(a : BigRational, b : BigRational) -> BigRational {
  a.add_r(b.neg_r())
}

///|
fn fd_rat_mul(a : BigRational, b : BigRational) -> BigRational {
  a.mul_r(b)
}

///|
fn fd_rat_div(a : BigRational, b : BigRational) -> BigRational {
  try! a.div_r(b)
}

///|
pub fn finite_diff_weights(
  order : Int,
  x_list : Array[BigRational],
  x0? : BigRational = BigRational::zero(),
) -> Array[Array[Array[BigRational]]] raise {
  let n_max = x_list.length() - 1
  let delta : Array[Array[Array[BigRational]]] = Array::makei(
    order + 1,
    _ => Array::makei(n_max + 1, _ => Array::makei(n_max + 1, _ => fd_rat_zero())),
  )
  delta[0][0].set(0, fd_rat_one())
  let mut c1 = fd_rat_one()
  for n in 1..=n_max {
    let mut c2 = fd_rat_one()
    for nu in 0..<n {
      let c3 = fd_rat_sub(x_list[n], x_list[nu])
      c2 = fd_rat_mul(c2, c3)
      if n <= order {
        delta[n][n - 1].set(nu, fd_rat_zero())
      }
      let m_limit = if n < order { n } else { order }
      for m in 0..=m_limit {
        let t1 = fd_rat_sub(x_list[n], x0)
        let a = fd_rat_mul(t1, delta[m][n - 1][nu])
        let b = if m == 0 {
          fd_rat_zero()
        } else {
          fd_rat_mul(fd_rat_from_int(m), delta[m - 1][n - 1][nu])
        }
        let num = fd_rat_sub(a, b)
        let val = fd_rat_div(num, c3)
        delta[m][n].set(nu, val)
      }
    }
    let m_limit = if n < order { n } else { order }
    for m in 0..=m_limit {
      let t1 = fd_rat_sub(x_list[n - 1], x0)
      let a = if m == 0 {
        fd_rat_zero()
      } else {
        fd_rat_mul(fd_rat_from_int(m), delta[m - 1][n - 1][n - 1])
      }
      let b = fd_rat_mul(t1, delta[m][n - 1][n - 1])
      let num = fd_rat_sub(a, b)
      let val = fd_rat_div(fd_rat_mul(c1, num), c2)
      delta[m][n].set(n, val)
    }
    c1 = c2
  }
  delta
}

///|
pub fn apply_finite_diff(
  order : Int,
  x_list : Array[BigRational],
  y_list : Array[Expr],
  x0? : BigRational = BigRational::zero(),
) -> Expr raise {
  guard x_list.length() == y_list.length() else {
    fail("x_list and y_list length mismatch")
  }
  let delta = finite_diff_weights(order, x_list, x0=x0)
  let n_max = x_list.length() - 1
  let mut out = @symcore.int(0)
  for nu in 0..<x_list.length() {
    let w = delta[order][n_max][nu]
    let term = @symcore.mul([@symcore.number(w), y_list[nu]])
    out = @symcore.add([out, term])
  }
  out
}
