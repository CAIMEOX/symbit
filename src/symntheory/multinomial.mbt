///|
/// Binomial and multinomial coefficients.

///|
fn factorial(n : Int) -> BigInt {
  let mut acc = bi(1)
  for i in 2..<=n {
    acc = acc * bi(i)
  }
  acc
}

///|
pub fn binomial_coefficients_list(n : Int) -> Array[BigInt] raise {
  if n < 0 {
    fail("n must be non-negative")
  }
  let out : Array[BigInt] = Array::new()
  let mut c = bi(1)
  out.push(c)
  for k in 1..<=n {
    let num = bi(n - k + 1)
    let den = bi(k)
    c = c * num / den
    out.push(c)
  }
  out
}

///|
pub fn binomial_coefficients(n : Int) -> Array[(Array[Int], BigInt)] raise {
  let coeffs = binomial_coefficients_list(n)
  let out : Array[(Array[Int], BigInt)] = Array::new()
  for k in 0..<=n {
    let exp : Array[Int] = [k, n - k]
    out.push((exp, coeffs[k]))
  }
  out
}

///|
fn multinomial_rec(
  remaining : Int,
  slots : Int,
  prefix : Array[Int],
  fact : Array[BigInt],
  total : Int,
  out : Array[(Array[Int], BigInt)],
) -> Unit {
  if slots == 1 {
    let tuple = prefix.copy()
    tuple.push(remaining)
    let mut denom = bi(1)
    for v in tuple {
      denom = denom * fact[v]
    }
    let coeff = fact[total] / denom
    out.push((tuple, coeff))
    return
  }
  for v in 0..<=remaining {
    let next = prefix.copy()
    next.push(v)
    multinomial_rec(remaining - v, slots - 1, next, fact, total, out)
  }
}

///|
pub fn multinomial_coefficients(
  m : Int,
  n : Int,
) -> Array[(Array[Int], BigInt)] raise {
  if n < 0 || m < 1 {
    fail("invalid parameters")
  }
  let fact : Array[BigInt] = Array::new()
  for i in 0..<=n {
    fact.push(factorial(i))
  }
  let out : Array[(Array[Int], BigInt)] = Array::new()
  multinomial_rec(n, m, Array::new(), fact, n, out)
  out
}
