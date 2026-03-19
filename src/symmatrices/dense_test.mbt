///|
fn mtxt(m : Matrix) -> String {
  m.to_string()
}

///|
test "matrices dense constructors and indexing" {
  let x = @symcore.symbol("x")
  let m = matrix([[x, @symcore.int(2)], [@symcore.int(3), @symcore.int(4)]])
  assert_eq(m.shape(), (2, 2))
  inspect(@symprint.to_string(m.getitem(0, 0)), content="x")
  inspect(
    mtxt(m.setitem(0, 1, @symcore.int(9))),
    content="Matrix([[x, 9], [3, 4]])",
  )
}

///|
test "matrices dense arithmetic and structural operations" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let b = matrix([
    [@symcore.int(5), @symcore.int(6)],
    [@symcore.int(7), @symcore.int(8)],
  ])
  inspect(mtxt(a + b), content="Matrix([[6, 8], [10, 12]])")
  inspect(mtxt(a * b), content="Matrix([[19, 22], [43, 50]])")
  inspect(
    mtxt(matrix_multiply_elementwise(a, b)),
    content="Matrix([[5, 12], [21, 32]])",
  )
  inspect(mtxt(a.transpose()), content="Matrix([[1, 3], [2, 4]])")
  inspect(mtxt(hstack([a, b])), content="Matrix([[1, 2, 5, 6], [3, 4, 7, 8]])")
  inspect(
    mtxt(vstack([a, b])),
    content="Matrix([[1, 2], [3, 4], [5, 6], [7, 8]])",
  )
}

///|
test "matrices dense zeros ones eye diag reshape extract trace" {
  inspect(
    mtxt(zeros(2, cols=Some(3))),
    content="Matrix([[0, 0, 0], [0, 0, 0]])",
  )
  inspect(mtxt(ones(2, cols=Some(2))), content="Matrix([[1, 1], [1, 1]])")
  inspect(mtxt(eye(3)), content="Matrix([[1, 0, 0], [0, 1, 0], [0, 0, 1]])")
  inspect(
    mtxt(diag([@symcore.int(2), @symcore.int(5)])),
    content="Matrix([[2, 0], [0, 5]])",
  )
  let m = matrix([
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(4), @symcore.int(5), @symcore.int(6)],
  ])
  inspect(mtxt(m.reshape(3, 2)), content="Matrix([[1, 2], [3, 4], [5, 6]])")
  inspect(mtxt(m.extract([0, 1], [1, 2])), content="Matrix([[2, 3], [5, 6]])")
  inspect(
    @symprint.to_string(diag([@symcore.int(2), @symcore.int(5)]).trace()),
    content="7",
  )
}

///|
test "matrices dense insertion deletion diagonal and vec" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let row = matrix([[@symcore.int(9), @symcore.int(8)]])
  let col = matrix([[@symcore.int(7)], [@symcore.int(6)]])
  inspect(
    mtxt(a.row_insert(1, row)),
    content="Matrix([[1, 2], [9, 8], [3, 4]])",
  )
  inspect(mtxt(a.col_insert(1, col)), content="Matrix([[1, 7, 2], [3, 6, 4]])")
  inspect(mtxt(a.row_del(0)), content="Matrix([[3, 4]])")
  inspect(mtxt(a.col_del(1)), content="Matrix([[1], [3]])")
  inspect(a.diagonal().map(@symprint.to_string).join(","), content="1,4")
  inspect(a.vec().to_string(), content="Matrix([[1], [3], [2], [4]])")
}

///|
test "matrices dense predicates and sparse conversions" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(2)],
  ])
  assert_true(a.is_square())
  assert_true(a.is_diagonal())
  assert_true(a.is_symmetric())
  assert_true(a.is_upper())
  assert_true(a.is_lower())
  assert_false(
    matrix([
      [@symcore.int(1), @symcore.int(2)],
      [@symcore.int(0), @symcore.int(1)],
    ]).is_diagonal(),
  )
  assert_eq(a.nnz(), 2)
  inspect(a.to_sparse().to_string(), content="Matrix([[1, 0], [0, 2]])")
  inspect(a.todok().length(), content="2")
}
