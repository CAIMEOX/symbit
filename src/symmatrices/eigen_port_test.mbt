///|
fn local_eigenvals_py(items : Array[EigenValueMult]) -> String {
  "[" +
  items
  .map(fn(item) {
    "(sympy.sympify('" +
    @symprint.to_string(item.0) +
    "', locals={'sqrt': sympy.sqrt}), " +
    item.1.to_string() +
    ")"
  })
  .join(", ") +
  "]"
}

///|
test "matrices parity charpoly eigenvals and diagonalize" {
  let a = try! matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let lam = @symcore.symbol("lam")
  assert_eq(
    "0",
    try! py_list_text(
      "(lambda lam: sympy.sstr(sympy.expand((" +
      @symprint.to_string(try! a.charpoly(x=lam)) +
      ") - (" +
      py_matrix_expr(a) +
      ".charpoly(lam).as_expr()))))(sympy.Symbol('lam'))",
    ),
  )
  assert_eq(
    "ok",
    try! py_list_text(
      "(lambda loc, ref: (lambda loc2, ref2: 'ok' if len(loc2) == len(ref2) and all(sympy.simplify(loc2[i][0] - ref2[i][0]) == 0 and loc2[i][1] == int(ref2[i][1]) for i in range(len(ref2))) else 'mismatch')(sorted(loc, key=lambda kv: float(sympy.N(kv[0], 30))), sorted(ref, key=lambda kv: float(sympy.N(kv[0], 30)))))(" +
      local_eigenvals_py(try! a.eigenvals()) +
      ", sorted(" +
      py_matrix_expr(a) +
      ".eigenvals().items(), key=lambda kv: sympy.sstr(kv[0])))",
    ),
  )
  let d = try! matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let ours = try! d.diagonalize()
  assert_eq(
    local_matrix_list_text(ours.0),
    try! py_matrix_list_text(py_matrix_expr(d) + ".diagonalize()[0]"),
  )
  assert_eq(
    local_matrix_list_text(ours.1),
    try! py_matrix_list_text(py_matrix_expr(d) + ".diagonalize()[1]"),
  )
}

///|
test "matrices parity jordan form on defective 2x2" {
  let a = try! matrix([
    [@symcore.int(4), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(4)],
  ])
  let ours = try! a.jordan_form()
  assert_eq(
    local_matrix_list_text(ours.1),
    try! py_matrix_list_text(py_matrix_expr(a) + ".jordan_form()[1]"),
  )
  assert_eq(
    local_matrix_list_text(a * ours.0),
    local_matrix_list_text(ours.0 * ours.1),
  )
}

///|
test "matrices parity jordan form on defective 3x3 chain" {
  let a = try! matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let ours = try! a.jordan_form()
  assert_eq(
    local_matrix_list_text(ours.1),
    try! py_matrix_list_text(py_matrix_expr(a) + ".jordan_form()[1]"),
  )
  assert_eq(
    local_matrix_list_text(a * ours.0),
    local_matrix_list_text(ours.0 * ours.1),
  )
}

///|
test "matrices parity jordan form on mixed 3x3 blocks" {
  let a = try! matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let ours = try! a.jordan_form()
  assert_eq(
    local_matrix_list_text(ours.1),
    try! py_matrix_list_text(py_matrix_expr(a) + ".jordan_form()[1]"),
  )
  assert_eq(
    local_matrix_list_text(a * ours.0),
    local_matrix_list_text(ours.0 * ours.1),
  )
}
