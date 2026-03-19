///|\
/// Test helpers for strategies.

///|
fn expr_str(expr : @symcore.Expr) -> String {
  @symprint.to_string(expr)
}

///|
fn assert_str_eq(
  actual : String,
  expected : String,
  label : String,
) -> Unit raise {
  guard actual == expected else {
    println("mismatch [\{label}]: actual=\{actual} expected=\{expected}")
    fail("mismatch")
  }
}

///|
fn assert_expr_str_eq(
  expr : @symcore.Expr,
  expected : String,
  label : String,
) -> Unit raise {
  assert_str_eq(expr_str(expr), expected, label)
}

///|
fn sort_ints(xs : Array[Int]) -> Array[Int] {
  xs.sort_by((a, b) => a.compare(b))
  xs
}

///|
fn sort_strings(xs : Array[String]) -> Array[String] {
  xs.sort_by((a, b) => a.compare(b))
  xs
}

///|
fn assert_set_int_eq(
  actual : Array[Int],
  expected : Array[Int],
  label : String,
) -> Unit raise {
  let a = sort_ints(actual)
  let b = sort_ints(expected)
  guard a == b else {
    println("set mismatch [\{label}]: actual=\{a} expected=\{b}")
    fail("set mismatch")
  }
}

///|
fn assert_set_str_eq(
  actual : Array[String],
  expected : Array[String],
  label : String,
) -> Unit raise {
  let a = sort_strings(actual)
  let b = sort_strings(expected)
  guard a == b else {
    println("set mismatch [\{label}]: actual=\{a} expected=\{b}")
    fail("set mismatch")
  }
}
