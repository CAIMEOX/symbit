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
  let s = sparse_matrix(3, 3, entries)
  inspect(s.to_string(), content="Matrix([[0, 2, 0], [0, 0, 0], [5, 0, 0]])")
  inspect(
    s.transpose().to_string(),
    content="Matrix([[0, 0, 5], [2, 0, 0], [0, 0, 0]])",
  )
  inspect(
    s.setitem(0, 1, @symcore.int(0)).to_string(),
    content="Matrix([[0, 0, 0], [0, 0, 0], [5, 0, 0]])",
  )
}

///|
test "matrices dense to sparse roundtrip" {
  let m = matrix([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let s = m.to_sparse()
  inspect(s.to_string(), content="Matrix([[1, 0], [0, 3]])")
}

///|
test "matrices sparse metadata and scaling helpers" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 1)] = @symcore.int(2)
  entries[(1, 0)] = @symcore.int(3)
  let s = sparse_matrix(2, 2, entries)
  assert_eq(s.nnz(), 2)
  assert_eq(s.todok().length(), 2)
  inspect(s.row_list().length(), content="2")
  inspect(s.col_list().length(), content="2")
  inspect(
    s.scalar_multiply(@symcore.int(2)).to_string(),
    content="Matrix([[0, 4], [6, 0]])",
  )
  inspect(
    s.applyfunc(value => value + @symcore.int(1)).to_string(),
    content="Matrix([[0, 3], [4, 0]])",
  )
  let plus_left_entries : Map[(Int, Int), Expr] = {}
  plus_left_entries[(0, 0)] = @symcore.int(1)
  let plus_right_entries : Map[(Int, Int), Expr] = {}
  plus_right_entries[(0, 1)] = @symcore.int(4)
  inspect(
    (sparse_matrix(2, 2, plus_left_entries) +
    sparse_matrix(2, 2, plus_right_entries)).to_string(),
    content="Matrix([[1, 4], [0, 0]])",
  )
}

///|
test "matrices sparse immutable structural and solver helpers" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(1)
  entries[(1, 1)] = @symcore.int(2)
  let s = sparse_matrix(2, 2, entries)
  let copy = s.copy()
  assert_true(copy.equals(s))
  assert_eq(copy.as_immutable().nnz(), 2)
  assert_eq(copy.as_mutable().nnz(), 2)
  inspect(s.reshape(1, 4).to_string(), content="Matrix([[1, 0, 0, 2]])")
  inspect(s.extract([0, 1], [1]).to_string(), content="Matrix([[0], [2]])")
  let join_entries : Map[(Int, Int), Expr] = {}
  join_entries[(0, 0)] = @symcore.int(3)
  let joined = s.row_join(sparse_matrix(2, 1, join_entries))
  inspect(joined.to_string(), content="Matrix([[1, 0, 3], [0, 2, 0]])")
  let inserted = s.col_insert(1, sparse_matrix(2, 1, join_entries))
  inspect(inserted.to_string(), content="Matrix([[1, 3, 0], [0, 0, 2]])")
  inspect(s.row_del(0).to_string(), content="Matrix([[0, 2]])")
  assert_false(joined.is_diagonal())
  let tri_entries : Map[(Int, Int), Expr] = {}
  tri_entries[(0, 0)] = @symcore.int(2)
  tri_entries[(1, 0)] = @symcore.int(1)
  tri_entries[(1, 1)] = @symcore.int(3)
  let lower = sparse_matrix(2, 2, tri_entries)
  let rhs = matrix([[@symcore.int(2)], [@symcore.int(7)]])
  inspect(
    lower.lower_triangular_solve(rhs).to_string(),
    content="Matrix([[1], [2]])",
  )
  let upper_entries : Map[(Int, Int), Expr] = {}
  upper_entries[(0, 0)] = @symcore.int(2)
  upper_entries[(0, 1)] = @symcore.int(1)
  upper_entries[(1, 1)] = @symcore.int(3)
  let upper = sparse_matrix(2, 2, upper_entries)
  inspect(
    upper.upper_triangular_solve(rhs).to_string(),
    content="Matrix([[-1/6], [7/3]])",
  )
}

///|
test "matrices sparse decomposition and eigen helpers" {
  let diag_entries : Map[(Int, Int), Expr] = {}
  diag_entries[(0, 0)] = @symcore.int(2)
  diag_entries[(1, 1)] = @symcore.int(3)
  let diagm = sparse_matrix(2, 2, diag_entries)
  inspect(@symprint.to_string(diagm.trace()), content="5")
  inspect(@symprint.to_string(diagm.det()), content="6")
  assert_true(diagm.is_upper())
  assert_true(diagm.is_lower())
  inspect(diagm.inv().to_string(), content="Matrix([[1/2, 0], [0, 1/3]])")
  inspect(diagm.rank(), content="2")
  inspect(diagm.rref().0.to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(vecs_to_string(diagm.rowspace()), content="[[1, 0], [0, 1]]")
  inspect(eigenvals_text(diagm.eigenvals()), content="[(2, 1), (3, 1)]")
  let (_, j) = diagm.jordan_form(calc_transform=false)
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
  let lhs = sparse_matrix(2, 3, lhs_entries)
  let rhs = sparse_matrix(3, 2, rhs_entries)
  inspect((lhs * rhs).to_string(), content="Matrix([[10, 4], [0, 18]])")
  let tri_entries : Map[(Int, Int), Expr] = {}
  tri_entries[(0, 0)] = @symcore.int(2)
  tri_entries[(0, 1)] = @symcore.int(1)
  tri_entries[(1, 1)] = @symcore.int(5)
  let tri = sparse_matrix(2, 2, tri_entries)
  inspect(@symprint.to_string(tri.det()), content="10")
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
  let s = sparse_matrix(3, 3, entries)
  inspect(
    s.echelon_form().to_string(),
    content="Matrix([[1, 0, 2], [0, 1, 3], [0, 0, 0]])",
  )
  inspect(
    s.rref().0.to_string(),
    content="Matrix([[1, 0, 2], [0, 1, 3], [0, 0, 0]])",
  )
  inspect(s.rank(), content="2")
  inspect(vecs_to_string(s.rowspace()), content="[[1, 0, 2], [0, 1, 3]]")
  inspect(vecs_to_string(s.columnspace()), content="[[1, 0, 2], [0, 1, 0]]")
  inspect(vecs_to_string(s.nullspace()), content="[[-2, -3, 1]]")
}

///|
test "matrices sparse native lu reconstructs row-permuted matrix" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 1)] = @symcore.int(2)
  entries[(0, 2)] = @symcore.int(1)
  entries[(1, 0)] = @symcore.int(4)
  entries[(1, 1)] = @symcore.int(5)
  entries[(2, 2)] = @symcore.int(3)
  let s = sparse_matrix(3, 3, entries)
  let (l, u, swaps) = s.lu()
  inspect(
    (l * u).to_string(),
    content=apply_row_swaps(s.to_dense(), swaps).to_string(),
  )
}

///|
test "matrices sparse native solve and inverse avoid dense fallback" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(4)
  entries[(0, 1)] = @symcore.int(1)
  entries[(1, 0)] = @symcore.int(2)
  entries[(1, 1)] = @symcore.int(3)
  let s = sparse_matrix(2, 2, entries)
  let rhs = matrix([[@symcore.int(1)], [@symcore.int(0)]])
  inspect(s.solve(rhs).to_string(), content="Matrix([[3/10], [-1/5]])")
  inspect(s.inv().to_string(), content="Matrix([[3/10, -1/10], [-1/5, 2/5]])")
}

///|
test "matrices sparse native cholesky and ldl match reconstruction" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(4)
  entries[(0, 1)] = @symcore.int(2)
  entries[(1, 0)] = @symcore.int(2)
  entries[(1, 1)] = @symcore.int(5)
  let s = sparse_matrix(2, 2, entries)
  let chol = s.cholesky()
  inspect(
    chol.to_string(),
    content="Matrix([[sqrt(4), 0], [2*sqrt(4)**-1, sqrt((-4*sqrt(4)**-2 + 5))]])",
  )
  let (l, d) = s.ldl()
  inspect(l.to_string(), content="Matrix([[1, 0], [1/2, 1]])")
  inspect(d.to_string(), content="Matrix([[4, 0], [0, 4]])")
}

///|
test "matrices sparse native qr reconstructs the source matrix" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(1)
  entries[(1, 0)] = @symcore.int(1)
  entries[(1, 1)] = @symcore.int(1)
  let s = sparse_matrix(2, 2, entries)
  let (q, r) = s.qr()
  inspect(
    q.to_string(),
    content="Matrix([[sqrt(2)**-1, -1*sqrt((sqrt(2)**-4 + (-1*sqrt(2)**-2 + 1)**2))**-1*sqrt(2)**-2], [sqrt(2)**-1, sqrt((sqrt(2)**-4 + (-1*sqrt(2)**-2 + 1)**2))**-1*(-1*sqrt(2)**-2 + 1)]])",
  )
  inspect(
    r.to_string(),
    content="Matrix([[sqrt(2), sqrt((sqrt(2)**-4 + (-1*sqrt(2)**-2 + 1)**2))], [sqrt(2), sqrt((sqrt(2)**-4 + (-1*sqrt(2)**-2 + 1)**2))]])",
  )
}
