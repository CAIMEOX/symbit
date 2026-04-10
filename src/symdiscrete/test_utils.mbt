///|
/// Build an exact rational expression from two machine integers.
pub fn rat(num : Int, den : Int) -> Expr {
  @symcore.rational_from_ints(num, den) catch {
    _ => @symcore.function("Rational", [@symcore.int(num), @symcore.int(den)])
  }
}

///|
/// Build `sqrt(n)` as a symbolic expression.
pub fn sqrt_int(n : Int) -> Expr {
  @symcore.function("sqrt", [@symcore.int(n)])
}

///|
/// Build the complex expression `re + im*I`.
pub fn complex(re : Expr, im : Expr) -> Expr {
  @symcore.add([
    re,
    @symcore.mul([
      im,
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
    ]),
  ])
}

///|
/// Fail the current test unless the oracle result is `Ok(true)`.
pub fn assert_oracle(result : Result[Bool, Error]) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch")
    Err(err) => fail(err.to_string())
  }
}

///|
/// Named variant of [`assert_oracle`](#assert_oracle) for clearer failures.
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
