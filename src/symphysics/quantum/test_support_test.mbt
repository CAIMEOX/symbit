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

fn quantum_sum1(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Sum", [expr, @symcore.function("Tuple", [sym, lower, upper])])
}

fn quantum_sum2(
  expr : @symcore.Expr,
  sym1 : @symcore.Expr,
  lower1 : @symcore.Expr,
  upper1 : @symcore.Expr,
  sym2 : @symcore.Expr,
  lower2 : @symcore.Expr,
  upper2 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function(
    "Sum",
    [
      expr,
      @symcore.function("Tuple", [sym1, lower1, upper1]),
      @symcore.function("Tuple", [sym2, lower2, upper2]),
    ],
  )
}
