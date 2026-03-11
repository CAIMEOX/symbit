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

fn quantum_test_assert_array_equal(
  lhs : Array[String],
  rhs : Array[String],
  context : String,
) -> Unit raise {
  guard lhs == rhs else {
    fail("\{context}: ours=\{lhs}; oracle=\{rhs}")
  }
}

fn quantum_test_assert_matrix_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  context : String,
) -> Unit raise {
  guard lhs.height() == rows else {
    fail("\{context}: row mismatch ours=\{lhs.height()} oracle=\{rows}")
  }
  guard lhs.width() == cols else {
    fail("\{context}: col mismatch ours=\{lhs.width()} oracle=\{cols}")
  }
  quantum_test_assert_array_equal(try! matrix_flat_strings(lhs), rhs, context)
}

fn quantum_test_assert_matrix_expr_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  context : String,
) -> Unit raise {
  guard lhs.height() == rows else {
    fail("\{context}: row mismatch ours=\{lhs.height()} oracle=\{rows}")
  }
  guard lhs.width() == cols else {
    fail("\{context}: col mismatch ours=\{lhs.width()} oracle=\{cols}")
  }
  let flat = try! matrix_flat_strings(lhs)
  guard flat.length() == rhs.length() else {
    fail("\{context}: size mismatch ours=\{flat.length()} oracle=\{rhs.length()}")
  }
  for idx in 0..<flat.length() {
    guard (try! @sympy_physics.expr_equal(flat[idx], rhs[idx])) else {
      fail("\{context}[\{idx}]: ours=\{flat[idx]}; oracle=\{rhs[idx]}")
    }
  }
}

fn quantum_measurements_to_expr_string(
  results : Array[(@symcore.Expr, @symcore.Expr)],
) -> String {
  let items : Array[String] = []
  for item in results {
    items.push("(\{@symprint.to_string(item.0)}, \{@symprint.to_string(item.1)})")
  }
  let joined = items.join(", ")
  "[\{joined}]"
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
