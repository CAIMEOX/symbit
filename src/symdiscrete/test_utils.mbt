///|
pub fn rat(num : Int, den : Int) -> Expr {
  @symcore.number(
    @symnum.BigRational::from_int(num).div_r(@symnum.BigRational::from_int(den)),
  )
}

///|
pub fn sqrt_int(n : Int) -> Expr {
  @symcore.function("sqrt", [@symcore.int(n)])
}

///|
pub fn complex(re : Expr, im : Expr) -> Expr {
  @symcore.add([re, @symcore.mul([im, @symcore.symbol("I")])])
}

///|
pub fn assert_oracle(result : Result[Bool, Error]) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch")
    Err(err) => fail(err.to_string())
  }
}

///|
pub fn assert_oracle_named(
  name : String,
  result : Result[Bool, Error],
) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch: \{name}")
    Err(err) => fail("\{name}: \{err.to_string()}")
  }
}
