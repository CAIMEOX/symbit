///|
test "assumptions worker preserves symbol facts and dynamic attributes" {
  let x = @symcore.Expr::Symbol("x")
  let env = @symassume.assume_env([
    ("x", @symassume.symbol_facts(is_positive=True)),
  ])
  assert_eq(expr_attr(x, "is_positive", env~), "True")
  assert_eq(expr_attr(x, "is_zero", env~), "False")
}

///|
test "assumptions worker contains errors and recovers" {
  let rejected = try {
    expr_attr(@symcore.int(1), "__symbit_missing_attribute__") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(ask_query_str("(").has_prefix("OracleError:"))
  assert_true(ask_query_str("Q.integer(sqrt(4))").has_prefix("OracleError:"))
  assert_eq(ask_query_str("Q.integer(2)"), "True")
  assert_eq(ask_query_str("Q.infinite(oo)"), "True")
  assert_eq(ask_query_str("Q.imaginary(I)"), "True")
  assert_eq(is_integer(@symcore.int(2)), "True")
}
