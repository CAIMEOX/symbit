///|
fn assert_oracle_pd(result : Result[String, Error], expected : String) -> Unit raise {
  match result {
    Ok(value) => assert_eq(value, expected)
    Err(e) => raise e
  }
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
  let s = partial_to_string(pd)
  assert_eq(s, "PartialDerivative(A(i), B(-j))")
  assert_oracle_pd(try? @sympy_tensor.partial_derivative_str(pd), s)
}
