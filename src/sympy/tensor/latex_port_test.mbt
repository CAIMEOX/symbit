///|
test "tensor latex parity indexed arrays and tensor operators" {
  let n = @symcore.Expr::Symbol("n")
  let i = idx("i")
  let ranged = idx("j", upper=n)
  assert_eq(i.latex(), idx_latex(i))
  assert_eq(ranged.latex(), idx_latex(ranged))

  let base = indexed_base("A", shape=[n, @symcore.int(3)])
  assert_eq(base.latex(), indexed_base_latex(base))
  let item = base.at([
    index_idx(i),
    @symtensor_indexed.index_expr(@symcore.Expr::Symbol("k")),
  ]) catch {
    _ => fail("indexed")
  }
  assert_eq(item.latex(), indexed_latex(item))

  let dense2 = dense([2, 2], [
    @symcore.Expr::Symbol("x"),
    @symcore.int(1),
    @symcore.int(0),
    @symcore.Expr::Symbol("y"),
  ]) catch {
    _ => fail("dense2")
  }
  assert_eq(dense2.latex(), array_latex(dense2))

  let arr_sym = array_symbol("T", shape=[@symcore.int(2), @symcore.int(3)])
  assert_eq(arr_sym.latex(), array_expr_latex(arr_sym))
  let arr_elem = array_element(arr_sym, [
    @symcore.Expr::Symbol("i"),
    @symcore.Expr::Symbol("j"),
  ])
  assert_eq(arr_elem.latex(), array_expr_latex(arr_elem))
  let arr_tp = array_tensor_product([
    array_symbol("T", shape=[@symcore.int(2), @symcore.int(3)]),
    array_symbol("S", shape=[@symcore.int(3), @symcore.int(2)]),
  ])
  assert_eq(arr_tp.latex(), array_expr_latex(arr_tp))
  let arr_ctr = array_contraction(arr_tp, [(1, 2)])
  assert_eq(arr_ctr.latex(), array_expr_latex(arr_ctr))

  let l = tensor_index_type("L")
  let up = tensor_index("i", l)
  let down = tensor_index("j", l, is_up=false)
  let head = tensor_head("A", [l, l])
  let tensor = head.call([up, down]) catch { _ => fail("tensor") }
  assert_eq(tensor.latex(), tensor_latex(tensor))
  let pd = partial_derivative(tensor, [
    @symtensor_tensor.scalar_expr(@symcore.Expr::Symbol("x")),
  ])
  assert_eq(pd.latex(), partial_derivative_latex(pd))
}
