///|
/// Exact rational helpers for symbolic stats formulas.

///|
fn stats_exact_rational(num : Int, den : Int) -> @symcore.Expr {
  @symcore.rational_from_ints(num, den) catch {
    _ =>
      @symcore.mul([
        @symcore.int(num),
        @symcore.pow(@symcore.int(den), @symcore.int(-1)),
      ])
  }
}

///|
fn stats_exact_big_rational(num : Int, den : Int) -> @symnum.BigRational? {
  let exact = @symnum.BigRational::new(
    @bigint.BigInt::from_int(num),
    @bigint.BigInt::from_int(den),
  ) catch {
    _ => return None
  }
  Some(exact)
}
