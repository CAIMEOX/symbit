///|
fn assert_oracle_pd(result : String, expected : String) -> Unit raise {
  assert_eq(result, expected)
}

///|
test "partial derivative string" {
  let l = tensor_index_type("L")
  let i = tensor_index("i", l)
  let j = tensor_index("j", l, is_up=false)
  let a = tensor_head("A", [l])
  let b = tensor_head("B", [l])
  let expr = a.call([i])
  let pd = partial_derivative(expr, [b.call([j])])
  let s = Show::to_string(pd)
  assert_eq(s, "PartialDerivative(A(i), B(-j))")
  assert_oracle_pd(partial_derivative_str(pd), s)
}
