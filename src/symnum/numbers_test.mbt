///|
test "normalize and sign handling" {
  let half = BigRational::new(BigInt::from_int(2), BigInt::from_int(4))
  inspect(half.to_string(), content="1/2")
  let neg = BigRational::new(BigInt::from_int(2), BigInt::from_int(-4))
  inspect(neg.to_string(), content="-1/2")
  let both_neg = BigRational::new(BigInt::from_int(-2), BigInt::from_int(-4))
  inspect(both_neg.to_string(), content="1/2")
}

///|
test "zero denominator error" {
  try BigRational::new(BigInt::from_int(1), BigInt::from_int(0)) catch {
    RationalError::ZeroDenominator => ()
  } noraise {
    _ => fail("expected zero denominator error")
  }
}

///|
test "arithmetic closure" {
  let a = BigRational::from_int(1)
  let b = BigRational::from_int(2)
  inspect(a.add_r(b).to_string(), content="3")
  inspect(
    a
    .mul_r(BigRational::new(BigInt::from_int(3), BigInt::from_int(5)))
    .to_string(),
    content="3/5",
  )
}

///|
test "division by zero raises rational error" {
  let a = BigRational::from_int(1)
  try a.div_r(BigRational::zero()) catch {
    RationalError::ZeroDenominator => ()
  } noraise {
    _ => fail("expected division by zero error")
  }
}
