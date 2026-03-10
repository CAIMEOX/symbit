fn quantum_test_assert_string_equal(
  lhs : String,
  rhs : String,
  context : String,
) -> Unit raise {
  guard lhs == rhs else {
    fail("\{context}: ours=\{lhs}; oracle=\{rhs}")
  }
}

fn quantum_test_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  guard (try! @sympy_physics.expr_equal(ours, rhs)) else {
    fail("\{context}: ours=\{ours}; oracle=\{rhs}")
  }
}

fn quantum_test_frac(num : Int, den : Int) -> @symcore.Expr {
  @symcore.number(
    try! @symnum.BigRational::new(
      @bigint.BigInt::from_int(num),
      @bigint.BigInt::from_int(den),
    ),
  )
}
