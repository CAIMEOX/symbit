///|
fn assert_oracle(result : Result[String, Error], expected : String) -> Unit raise {
  match result {
    Ok(value) => assert_eq(value, expected)
    Err(e) => raise e
  }
}

///|
test "tensor basic expression" {
  let l = tensor_index_type("L")
  let i = tensor_index("i", l)
  let j = tensor_index("j", l, is_up=false)
  let a = tensor_head("A", [l, l])
  let expr = a.call([i, j])
  let s = to_string(expr)
  assert_eq(s, "A(i, -j)")
  assert_oracle(try? @sympy_tensor.tensor_str(expr), s)
}

///|
test "tensor contraction indices" {
  let l = tensor_index_type("L")
  let i = tensor_index("i", l)
  let j = tensor_index("j", l)
  let jd = neg_index(j)
  let a = tensor_head("A", [l, l])
  let b = tensor_head("B", [l])
  let expr = mul([a.call([i, j]), b.call([jd])])
  let info = get_indices(expr)
  assert_eq(info.free.length(), 1)
  assert_eq(info.dummy.length(), 1)
}
