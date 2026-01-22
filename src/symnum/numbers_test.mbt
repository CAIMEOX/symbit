///|
test "normalize and sign handling" {
  let half = try! BigRational::new(BigInt::from_int(2), BigInt::from_int(4))
  inspect(half.to_string(), content="1/2")
  let neg = try! BigRational::new(BigInt::from_int(2), BigInt::from_int(-4))
  inspect(neg.to_string(), content="-1/2")
  let both_neg = try! BigRational::new(
    BigInt::from_int(-2),
    BigInt::from_int(-4),
  )
  inspect(both_neg.to_string(), content="1/2")
}

///|
test "zero denominator error" {
  let result : Result[BigRational, RationalError] = try? BigRational::new(
    BigInt::from_int(1),
    BigInt::from_int(0),
  )
  inspect(result, content="Err(ZeroDenominator)")
}

///|
test "arithmetic closure" {
  let a = BigRational::from_int(1)
  let b = BigRational::from_int(2)
  inspect(a.add_r(b).to_string(), content="3")
  inspect(
    a
    .mul_r(try! BigRational::new(BigInt::from_int(3), BigInt::from_int(5)))
    .to_string(),
    content="3/5",
  )
}
