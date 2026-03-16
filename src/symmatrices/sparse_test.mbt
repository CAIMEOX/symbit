///|
test "matrices sparse construction and conversion" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 1)] = @symcore.int(2)
  entries[(2, 0)] = @symcore.int(5)
  let s = try! sparse_matrix(3, 3, entries)
  inspect(
    try! s.to_string(),
    content="Matrix([[0, 2, 0], [0, 0, 0], [5, 0, 0]])",
  )
  inspect(
    try! s.transpose().to_string(),
    content="Matrix([[0, 0, 5], [2, 0, 0], [0, 0, 0]])",
  )
  inspect(
    try! (try! s.setitem(0, 1, @symcore.int(0))).to_string(),
    content="Matrix([[0, 0, 0], [0, 0, 0], [5, 0, 0]])",
  )
}

///|
test "matrices dense to sparse roundtrip" {
  let m = try! matrix([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let s = m.to_sparse()
  inspect(try! s.to_string(), content="Matrix([[1, 0], [0, 3]])")
}

///|
test "matrices sparse metadata and scaling helpers" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 1)] = @symcore.int(2)
  entries[(1, 0)] = @symcore.int(3)
  let s = try! sparse_matrix(2, 2, entries)
  assert_eq(s.nnz(), 2)
  assert_eq(s.todok().length(), 2)
  inspect(s.row_list().length(), content="2")
  inspect(s.col_list().length(), content="2")
  inspect(
    (try! s.scalar_multiply(@symcore.int(2))).to_string(),
    content="Matrix([[0, 4], [6, 0]])",
  )
  inspect(
    (try! s.applyfunc(value => value + @symcore.int(1))).to_string(),
    content="Matrix([[0, 3], [4, 0]])",
  )
}
