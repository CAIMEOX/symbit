///|
test "array latex renders dense arrays and array expressions" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let dense2 = dense([2, 2], [x, @symcore.int(1), @symcore.int(0), y]) catch {
    _ => fail("dense2")
  }
  inspect(
    dense2.latex(),
    content="\\left[\\begin{matrix}x & 1\\\\0 & y\\end{matrix}\\right]",
  )
  let dense3 = dense([2, 2, 2], [
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
    @symcore.int(5),
    @symcore.int(6),
    @symcore.int(7),
    @symcore.int(8),
  ]) catch {
    _ => fail("dense3")
  }
  inspect(
    dense3.latex(),
    content="\\left[\\begin{matrix}\\left[\\begin{matrix}1 & 2\\\\3 & 4\\end{matrix}\\right] & \\left[\\begin{matrix}5 & 6\\\\7 & 8\\end{matrix}\\right]\\end{matrix}\\right]",
  )

  let n = @symcore.Expr::Symbol("n")
  let a = array_symbol("A", shape=[n, n])
  let b = array_symbol("B")
  inspect(a.latex(), content="A")
  inspect(
    array_element(a, [@symcore.int(1), @symcore.int(2)]).latex(),
    content="{{A}_{1, 2}}",
  )
  let tp = array_tensor_product([a, b])
  inspect(
    tp.latex(),
    content="\\operatorname{ArrayTensorProduct}\\left(A, B\\right)",
  )
  inspect(
    array_contraction(tp, [(0, 1)]).latex(),
    content="\\operatorname{ArrayContraction}\\left(\\operatorname{ArrayTensorProduct}\\left(A, B\\right), \\left( 0, \\  1\\right)\\right)",
  )
}
