///|
/// Exact rational helpers for symbolic stats formulas.

///|
fn stats_exact_rational(num : Int, den : Int) -> @symcore.Expr {
  let exact : Result[@symcore.Expr, @symnum.RationalError] = try?
    @symcore.rational_from_ints(num, den)
  match exact {
    Ok(value) => value
    Err(_) =>
      @symcore.mul([
        @symcore.int(num),
        @symcore.pow(@symcore.int(den), @symcore.int(-1)),
      ])
  }
}

///|
fn stats_exact_big_rational(
  num : Int,
  den : Int,
) -> @symnum.BigRational? {
  let exact : Result[@symnum.BigRational, @symnum.RationalError] = try?
    @symnum.BigRational::new(
      @bigint.BigInt::from_int(num),
      @bigint.BigInt::from_int(den),
    )
  match exact {
    Ok(value) => Some(value)
    Err(_) => None
  }
}
