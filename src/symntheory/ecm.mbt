///|
/// Elliptic curve method factoring (naive wrapper).

///|
/// Public API `ecm`.
///
/// - Does: Attempts to find a non-trivial factor using the elliptic-curve factorization front door.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
pub fn ecm(
  n0 : BigInt,
  b1? : Int = 10000,
  b2? : Int = 100000,
  max_curve? : Int = 200,
  seed? : Int = 0,
) -> Array[BigInt] {
  let _ = b1
  let _ = b2
  let _ = max_curve
  let _ = seed
  let n = abs_bigint(n0)
  let f = factorint(n)
  let out : Array[BigInt] = Array::new()
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    out.push(p)
  }
  if out.is_empty() {
    out.push(n)
  }
  out.sort()
  out
}
