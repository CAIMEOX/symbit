///|
test "array expression strings" {
  let n = @symcore.Expr::Symbol("n")
  let a = array_symbol("A", shape=[n, n])
  let b = array_symbol("B")
  let elem = array_element(a, [@symcore.int(1), @symcore.int(2)])
  assert_eq(Show::to_string(a), "A(n, n)")
  assert_eq(Show::to_string(b), "B")
  assert_eq(Show::to_string(elem), "A(n, n)[1, 2]")
  let tp = array_tensor_product([a, b])
  assert_eq(Show::to_string(tp), "ArrayTensorProduct(A(n, n), B)")
  let cn = array_contraction(tp, [(0, 1)])
  assert_eq(
    Show::to_string(cn),
    "ArrayContraction(ArrayTensorProduct(A(n, n), B), [(0, 1)])",
  )
}
