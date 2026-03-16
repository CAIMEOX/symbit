///|
fn py_sparse_matrix_expr(m : SparseMatrix) -> String {
  let items : Array[String] = []
  for key, value in m.todok() {
    items.push("(\{key.0}, \{key.1}): " + @symprint.to_string(value))
  }
  "sympy.SparseMatrix(\{m.rows}, \{m.cols}, {" + items.join(", ") + "})"
}

///|
fn py_exact_matrix_expr(m : Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    let items : Array[String] = []
    for value in row {
      items.push(
        "sympy.sympify('" +
        @symprint.to_string(value) +
        "', locals={'sqrt': sympy.sqrt})",
      )
    }
    rows.push("[" + items.join(", ") + "]")
  }
  "sympy.Matrix([" + rows.join(", ") + "])"
}

///|
test "matrices parity sparse structural helpers" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(1)
  entries[(1, 1)] = @symcore.int(2)
  let s = try! sparse_matrix(2, 2, entries)
  assert_eq(
    local_matrix_list_text(try! s.to_dense()),
    try! py_matrix_list_text(py_sparse_matrix_expr(s)),
  )
  assert_eq(
    local_matrix_list_text(try! (try! s.reshape(1, 4)).to_dense()),
    try! py_matrix_list_text(py_sparse_matrix_expr(s) + ".reshape(1, 4)"),
  )
  assert_eq(
    local_matrix_list_text(try! (try! s.extract([0, 1], [1])).to_dense()),
    try! py_matrix_list_text(py_sparse_matrix_expr(s) + ".extract([0, 1], [1])"),
  )
  let join_entries : Map[(Int, Int), Expr] = {}
  join_entries[(0, 0)] = @symcore.int(3)
  let right = try! sparse_matrix(2, 1, join_entries)
  let inserted = right
  assert_eq(
    local_matrix_list_text(try! (try! s.row_join(right)).to_dense()),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(s) +
      ".row_join(" +
      py_sparse_matrix_expr(right) +
      ")",
    ),
  )
  assert_eq(
    local_matrix_list_text(try! (try! s.col_insert(1, inserted)).to_dense()),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(s) +
      ".col_insert(1, " +
      py_sparse_matrix_expr(inserted) +
      ")",
    ),
  )
}

///|
test "matrices parity sparse triangular solve" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(2)
  entries[(1, 0)] = @symcore.int(1)
  entries[(1, 1)] = @symcore.int(3)
  let lower = try! sparse_matrix(2, 2, entries)
  let rhs = try! matrix([[@symcore.int(2)], [@symcore.int(7)]])
  assert_eq(
    local_matrix_list_text(try! lower.lower_triangular_solve(rhs)),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(lower) +
      ".lower_triangular_solve(" +
      py_matrix_expr(rhs) +
      ")",
    ),
  )
  let upper_entries : Map[(Int, Int), Expr] = {}
  upper_entries[(0, 0)] = @symcore.int(2)
  upper_entries[(0, 1)] = @symcore.int(1)
  upper_entries[(1, 1)] = @symcore.int(3)
  let upper = try! sparse_matrix(2, 2, upper_entries)
  assert_eq(
    local_matrix_list_text(try! upper.upper_triangular_solve(rhs)),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(upper) +
      ".upper_triangular_solve(" +
      py_matrix_expr(rhs) +
      ")",
    ),
  )
}

///|
test "matrices parity sparse decomposition helpers" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(2)
  entries[(1, 1)] = @symcore.int(3)
  let s = try! sparse_matrix(2, 2, entries)
  assert_eq(
    @symprint.to_string(try! s.det()),
    try! py_list_text("sympy.sstr(" + py_sparse_matrix_expr(s) + ".det())"),
  )
  assert_eq(
    local_matrix_list_text(try! s.inv()),
    try! py_matrix_list_text(py_sparse_matrix_expr(s) + ".inv()"),
  )
  assert_eq(
    local_matrix_list_text((try! s.rref()).0),
    try! py_matrix_list_text(py_sparse_matrix_expr(s) + ".rref()[0]"),
  )
  assert_eq(
    local_matrix_list_text(try! s.jordan_form(calc_transform=false).1),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(s) + ".jordan_form(calc_transform=False)",
    ),
  )
}

///|
test "matrices parity sparse arithmetic paths" {
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
  assert_eq(
    local_matrix_list_text(try! (lhs * rhs).to_dense()),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(lhs) + " * " + py_sparse_matrix_expr(rhs),
    ),
  )
  let add_left_entries : Map[(Int, Int), Expr] = {}
  add_left_entries[(0, 0)] = @symcore.int(1)
  let add_right_entries : Map[(Int, Int), Expr] = {}
  add_right_entries[(0, 1)] = @symcore.int(4)
  let add_left = try! sparse_matrix(2, 2, add_left_entries)
  let add_right = try! sparse_matrix(2, 2, add_right_entries)
  assert_eq(
    local_matrix_list_text(try! (add_left + add_right).to_dense()),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(add_left) + " + " + py_sparse_matrix_expr(add_right),
    ),
  )
}

///|
test "matrices parity sparse native rref echelon and rank" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(1)
  entries[(0, 2)] = @symcore.int(2)
  entries[(1, 1)] = @symcore.int(1)
  entries[(1, 2)] = @symcore.int(3)
  entries[(2, 0)] = @symcore.int(2)
  entries[(2, 2)] = @symcore.int(4)
  let s = try! sparse_matrix(3, 3, entries)
  assert_eq(
    local_matrix_list_text(try! s.echelon_form()),
    try! py_matrix_list_text(py_sparse_matrix_expr(s) + ".echelon_form()"),
  )
  assert_eq(
    local_matrix_list_text((try! s.rref()).0),
    try! py_matrix_list_text(py_sparse_matrix_expr(s) + ".rref()[0]"),
  )
  assert_eq(
    (try! s.rank()).to_string(),
    try! py_list_text("sympy.sstr(" + py_sparse_matrix_expr(s) + ".rank())"),
  )
}

///|
test "matrices parity sparse solve inverse cholesky and ldl" {
  let entries : Map[(Int, Int), Expr] = {}
  entries[(0, 0)] = @symcore.int(4)
  entries[(0, 1)] = @symcore.int(1)
  entries[(1, 0)] = @symcore.int(2)
  entries[(1, 1)] = @symcore.int(3)
  let s = try! sparse_matrix(2, 2, entries)
  let rhs = try! matrix([[@symcore.int(1)], [@symcore.int(0)]])
  assert_eq(
    local_matrix_list_text(try! s.solve(rhs)),
    try! py_matrix_list_text(
      py_sparse_matrix_expr(s) + ".solve(" + py_matrix_expr(rhs) + ")",
    ),
  )
  assert_eq(
    local_matrix_list_text(try! s.inv()),
    try! py_matrix_list_text(py_sparse_matrix_expr(s) + ".inv()"),
  )
  let spd_entries : Map[(Int, Int), Expr] = {}
  spd_entries[(0, 0)] = @symcore.int(4)
  spd_entries[(0, 1)] = @symcore.int(2)
  spd_entries[(1, 0)] = @symcore.int(2)
  spd_entries[(1, 1)] = @symcore.int(5)
  let spd = try! sparse_matrix(2, 2, spd_entries)
  let chol = try! spd.cholesky()
  assert_eq(
    "ok",
    try! py_list_text(
      "(lambda ours, ref: 'ok' if sympy.simplify(ours - ref) == sympy.Matrix.zeros(ref.rows, ref.cols) else sympy.sstr(sympy.simplify(ours - ref)))(" +
      py_exact_matrix_expr(chol) +
      ", " +
      py_sparse_matrix_expr(spd) +
      ".cholesky())",
    ),
  )
  let ldl = try! spd.ldl()
  assert_eq(
    "ok",
    try! py_list_text(
      "(lambda ours_l, ours_d, ref: 'ok' if sympy.simplify(ours_l - ref[0]) == sympy.Matrix.zeros(ref[0].rows, ref[0].cols) and sympy.simplify(ours_d - ref[1]) == sympy.Matrix.zeros(ref[1].rows, ref[1].cols) else 'mismatch')(" +
      py_exact_matrix_expr(ldl.0) +
      ", " +
      py_exact_matrix_expr(ldl.1) +
      ", " +
      py_sparse_matrix_expr(spd) +
      ".LDLdecomposition())",
    ),
  )
}
