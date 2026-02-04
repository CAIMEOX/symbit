///|
/// Quadratic sieve factoring (naive wrapper).

///|
pub fn qs_factor(
  n0 : BigInt,
  prime_bound? : Int = 2000,
  m? : Int = 10000,
  error_term? : Int = 25,
  seed? : Int = 1234,
) -> Map[BigInt, Int] raise {
  let _ = prime_bound
  let _ = m
  let _ = error_term
  let _ = seed
  if n0 < bi(2) {
    fail("n should be greater than 1")
  }
  factorint(n0)
}

///|
pub fn qs(
  n0 : BigInt,
  prime_bound? : Int = 2000,
  m? : Int = 10000,
  error_term? : Int = 25,
  seed? : Int = 1234,
) -> Array[BigInt] raise {
  let _ = prime_bound
  let _ = m
  let _ = error_term
  let _ = seed
  let f = qs_factor(n0)
  let out : Array[BigInt] = Array::new()
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    out.push(p)
  }
  if out.is_empty() {
    out.push(abs_bigint(n0))
  }
  out.sort()
  out
}
