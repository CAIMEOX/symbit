///|
fn quantum_test_assert_string_equal(
  lhs : String,
  rhs : String,
  _context : String,
) -> Unit raise {
  assert_eq(lhs, rhs)
}

///|
fn quantum_test_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  assert_true((try! expr_equal(ours, rhs)))
}

///|
fn quantum_test_assert_array_equal(
  lhs : Array[String],
  rhs : Array[String],
  _context : String,
) -> Unit raise {
  assert_eq(lhs, rhs)
}

///|
fn quantum_test_assert_matrix_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  context : String,
) -> Unit raise {
  assert_eq(lhs.height(), rows)
  assert_eq(lhs.width(), cols)
  quantum_test_assert_array_equal(try! matrix_flat_strings(lhs), rhs, context)
}

///|
fn quantum_test_assert_matrix_expr_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  _context : String,
) -> Unit raise {
  assert_eq(lhs.height(), rows)
  assert_eq(lhs.width(), cols)
  let flat = try! matrix_flat_strings(lhs)
  assert_eq(flat.length(), rhs.length())
  for idx in 0..<flat.length() {
    assert_true((try! expr_equal(flat[idx], rhs[idx])))
  }
}

///|
fn quantum_measurements_to_expr_string(
  results : Array[(@symcore.Expr, @symcore.Expr)],
) -> String {
  let items : Array[String] = []
  for item in results {
    items.push(
      "(\{@symprint.to_string(item.0)}, \{@symprint.to_string(item.1)})",
    )
  }
  let joined = items.join(", ")
  "[\{joined}]"
}

///|
fn quantum_test_frac(num : Int, den : Int) -> @symcore.Expr {
  @symcore.number(
    try! @symnum.BigRational::new(
      @bigint.BigInt::from_int(num),
      @bigint.BigInt::from_int(den),
    ),
  )
}

///|
fn quantum_sum1(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Sum", [
    expr,
    @symcore.function("Tuple", [sym, lower, upper]),
  ])
}

///|
fn quantum_sum2(
  expr : @symcore.Expr,
  sym1 : @symcore.Expr,
  lower1 : @symcore.Expr,
  upper1 : @symcore.Expr,
  sym2 : @symcore.Expr,
  lower2 : @symcore.Expr,
  upper2 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Sum", [
    expr,
    @symcore.function("Tuple", [sym1, lower1, upper1]),
    @symcore.function("Tuple", [sym2, lower2, upper2]),
  ])
}
