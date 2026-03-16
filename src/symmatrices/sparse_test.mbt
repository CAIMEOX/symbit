///|
fn apply_row_swaps(
  m : Matrix,
  swaps : Array[(Int, Int)],
) -> Matrix raise MatrixError {
  let data : Array[Array[Expr]] = []
  for row in m.data {
    let copied : Array[Expr] = []
    for item in row {
      copied.push(item)
    }
    data.push(copied)
  }
  for swap in swaps {
    let tmp = data[swap.0]
    data[swap.0] = data[swap.1]
    data[swap.1] = tmp
  }
  matrix(data)
}

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
  let plus_left_entries : Map[(Int, Int), Expr] = {}
  plus_left_entries[(0, 0)] = @symcore.int(1)
  let plus_right_entries : Map[(Int, Int), Expr] = {}
  plus_right_entries[(0, 1)] = @symcore.int(4)
  inspect(
    ((try! sparse_matrix(2, 2, plus_left_entries)) +
    (try! sparse_matrix(2, 2, plus_right_entries))).to_string(),
    content="Matrix([[1, 4], [0, 0]])",
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
  let inserted = try! s.col_insert(1, try! sparse_matrix(2, 1, join_entries))
  inspect(inserted.to_string(), content="Matrix([[1, 3, 0], [0, 0, 2]])")
  inspect((try! s.row_del(0)).to_string(), content="Matrix([[0, 2]])")
  assert_false(joined.is_diagonal())
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
  let upper_entries : Map[(Int, Int), Expr] = {}
  upper_entries[(0, 0)] = @symcore.int(2)
  upper_entries[(0, 1)] = @symcore.int(1)
  upper_entries[(1, 1)] = @symcore.int(3)
  let upper = try! sparse_matrix(2, 2, upper_entries)
  inspect(
    (try! upper.upper_triangular_solve(rhs)).to_string(),
    content="Matrix([[-1/6], [7/3]])",
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
  assert_true(diagm.is_upper())
  assert_true(diagm.is_lower())
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

///|
test "matrices sparse native multiply and triangular determinant" {
  let lhs_entries : Map[(Int, Int), Expr] = {}
  lhs_entries[(0, 0)] = @symcore.int(1)
  lhs_entries[(0, 2)] = @symcore.int(2)
  lhs_entries[(1, 1)] = @symcore.int(3)
  let rhs_entries : Map[(Int, Int), Expr] = {}
  rhs_entries[(0, 1)] = @symcore.int(4)
  rhs_entries[(2, 0)] = @symcore.int(5)
  rhs_entries[(1, 1)] = @symcore.int(6)
  let lhs = try! sparse_matrix(2, 3, lhs_entries)
  let rhs = try! sparse_matrix(3, 2, rhs_entries)
  inspect((lhs * rhs).to_string(), content="Matrix([[10, 4], [0, 18]])")
  let tri_entries : Map[(Int, Int), Expr] = {}
  tri_entries[(0, 0)] = @symcore.int(2)
  tri_entries[(0, 1)] = @symcore.int(1)
  tri_entries[(1, 1)] = @symcore.int(5)
  let tri = try! sparse_matrix(2, 2, tri_entries)
  inspect(@symprint.to_string(try! tri.det()), content="10")
}

///|
test "matrices sparse native rref echelon and subspace helpers" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(1)
  entries[(0, 2)] = @symcore.int(2)
  entries[(1, 1)] = @symcore.int(1)
  entries[(1, 2)] = @symcore.int(3)
  entries[(2, 0)] = @symcore.int(2)
  entries[(2, 2)] = @symcore.int(4)
  let s = try! sparse_matrix(3, 3, entries)
  inspect(
    (try! s.echelon_form()).to_string(),
    content="Matrix([[1, 0, 2], [0, 1, 3], [0, 0, 0]])",
  )
  inspect(
    (try! s.rref()).0.to_string(),
    content="Matrix([[1, 0, 2], [0, 1, 3], [0, 0, 0]])",
  )
  inspect(try! s.rank(), content="2")
  inspect(vecs_to_string(try! s.rowspace()), content="[[1, 0, 2], [0, 1, 3]]")
  inspect(
    vecs_to_string(try! s.columnspace()),
    content="[[1, 0, 2], [0, 1, 0]]",
  )
  inspect(vecs_to_string(try! s.nullspace()), content="[[-2, -3, 1]]")
}

///|
test "matrices sparse native lu reconstructs row-permuted matrix" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 1)] = @symcore.int(2)
  entries[(0, 2)] = @symcore.int(1)
  entries[(1, 0)] = @symcore.int(4)
  entries[(1, 1)] = @symcore.int(5)
  entries[(2, 2)] = @symcore.int(3)
  let s = try! sparse_matrix(3, 3, entries)
  let (l, u, swaps) = try! s.lu()
  inspect(
    (l * u).to_string(),
    content=(try! apply_row_swaps(try! s.to_dense(), swaps)).to_string(),
  )
}
