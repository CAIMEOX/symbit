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

///|
test "matrices sparse immutable structural and solver helpers" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(1)
  entries[(1, 1)] = @symcore.int(2)
  let s = try! sparse_matrix(2, 2, entries)
  let copy = s.copy()
  assert_true(try! copy.equals(s))
  assert_true(copy.as_immutable().nnz() == 2)
  assert_true(copy.as_mutable().nnz() == 2)
  inspect((try! s.reshape(1, 4)).to_string(), content="Matrix([[1, 0, 0, 2]])")
  inspect(
    (try! s.extract([0, 1], [1])).to_string(),
    content="Matrix([[0], [2]])",
  )
  let join_entries : Map[(Int, Int), Expr] = {}
  join_entries[(0, 0)] = @symcore.int(3)
  let joined = try! s.row_join(try! sparse_matrix(2, 1, join_entries))
  inspect(joined.to_string(), content="Matrix([[1, 0, 3], [0, 2, 0]])")
  inspect((try! s.row_del(0)).to_string(), content="Matrix([[0, 2]])")
  assert_false(try! joined.is_diagonal())
  let tri_entries : Map[(Int, Int), Expr] = {}
  tri_entries[(0, 0)] = @symcore.int(2)
  tri_entries[(1, 0)] = @symcore.int(1)
  tri_entries[(1, 1)] = @symcore.int(3)
  let lower = try! sparse_matrix(2, 2, tri_entries)
  let rhs = try! matrix([[@symcore.int(2)], [@symcore.int(7)]])
  inspect(
    (try! lower.lower_triangular_solve(rhs)).to_string(),
    content="Matrix([[1], [2]])",
  )
}

///|
test "matrices sparse decomposition and eigen helpers" {
  let diag_entries : Map[(Int, Int), Expr] = {}
  diag_entries[(0, 0)] = @symcore.int(2)
  diag_entries[(1, 1)] = @symcore.int(3)
  let diagm = try! sparse_matrix(2, 2, diag_entries)
  inspect(@symprint.to_string(try! diagm.trace()), content="5")
  inspect(@symprint.to_string(try! diagm.det()), content="6")
  inspect(
    (try! diagm.inv()).to_string(),
    content="Matrix([[1/2, 0], [0, 1/3]])",
  )
  inspect(try! diagm.rank(), content="2")
  inspect((try! diagm.rref()).0.to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(vecs_to_string(try! diagm.rowspace()), content="[[1, 0], [0, 1]]")
  inspect(eigenvals_text(try! diagm.eigenvals()), content="[(2, 1), (3, 1)]")
  let (_, j) = try! diagm.jordan_form(calc_transform=false)
  inspect(j.to_string(), content="Matrix([[2, 0], [0, 3]])")
}
