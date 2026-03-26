///|
test "array expression strings" {
  let n = @symcore.Expr::Symbol("n")
  let a = array_symbol("A", shape=[n, n])
  let b = array_symbol("B")
  let elem = array_element(a, [@symcore.int(1), @symcore.int(2)])
  assert_eq(a.to_string(), "A(n, n)")
  assert_eq(b.to_string(), "B")
  assert_eq(elem.to_string(), "A(n, n)[1, 2]")
  let tp = array_tensor_product([a, b])
  assert_eq(tp.to_string(), "ArrayTensorProduct(A(n, n), B)")
  let cn = array_contraction(tp, [(0, 1)])
  assert_eq(
    cn.to_string(),
    "ArrayContraction(ArrayTensorProduct(A(n, n), B), [(0, 1)])",
  )
}
