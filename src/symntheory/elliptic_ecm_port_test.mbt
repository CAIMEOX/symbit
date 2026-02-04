///|
fn bi_ec(value : Int) -> BigInt {
  @bigint.BigInt::from_int(value)
}

///|
fn pair_list_to_pylist(values : Array[(BigInt, BigInt)]) -> String {
  let parts : Array[String] = Array::new()
  for item in values {
    let (x, y) = item
    parts.push("(\{x.to_string()}, \{y.to_string()})")
  }
  parts.sort()
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn bigint_list_to_pylist(values : Array[BigInt]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
test "ntheory elliptic curve points parity" {
  let curve = EllipticCurve::new(
    bi_ec(1),
    bi_ec(1),
    a1=bi_ec(1),
    a2=bi_ec(1),
    a3=bi_ec(1),
    modulus=bi_ec(5),
  )
  let pts = try! curve.points()
  assert_eq(
    pair_list_to_pylist(pts),
    try! @sympy_nt.elliptic_curve_points_str(1, 1, a1=1, a2=1, a3=1, modulus=5),
  )
}

///|
test "ntheory ecm parity" {
  let f1 = ecm(bi_ec(91))
  assert_eq(bigint_list_to_pylist(f1), try! @sympy_nt.ecm_factors_str(91))
}
