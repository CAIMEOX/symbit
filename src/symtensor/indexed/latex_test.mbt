///|
test "indexed latex renders base indices and composite expressions" {
  let n = @symcore.Expr::Symbol("n")
  let x = @symcore.Expr::Symbol("x")
  let i = idx("i")
  let ranged = idx("j", upper=n)
  inspect(i.latex(), content="i")
  inspect(
    ranged.latex(),
    content="{j}_{0\\mathrel{..}\\nobreak n - 1}",
  )
  let base = indexed_base("A")
  inspect(base.latex(), content="A")
  let item = base.at([index_idx(i), index_expr(@symcore.Expr::Symbol("k"))]) catch {
    _ => fail("indexed")
  }
  inspect(item.latex(), content="{A}_{i,k}")
  inspect(
    mul([scalar_expr(x), indexed_expr(item)]).latex(),
    content="x {A}_{i,k}",
  )
}
