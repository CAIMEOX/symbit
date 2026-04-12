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
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let lam = @symcore.Expr::Symbol("lam")
  assert_eq(
    "0",
    py_list_text(
      "(lambda lam: sympy.sstr(sympy.expand((" +
      @symprint.to_string(a.charpoly(x=lam)) +
      ") - (" +
      py_matrix_expr(a) +
      ".charpoly(lam).as_expr()))))(sympy.Symbol('lam'))",
    ),
  )
  assert_eq(
    "ok",
    py_list_text(
      "(lambda loc, ref: (lambda loc2, ref2: 'ok' if len(loc2) == len(ref2) and all(sympy.simplify(loc2[i][0] - ref2[i][0]) == 0 and loc2[i][1] == int(ref2[i][1]) for i in range(len(ref2))) else 'mismatch')(sorted(loc, key=lambda kv: float(sympy.N(kv[0], 30))), sorted(ref, key=lambda kv: float(sympy.N(kv[0], 30)))))(" +
      local_eigenvals_py(a.eigenvals()) +
      ", sorted(" +
      py_matrix_expr(a) +
      ".eigenvals().items(), key=lambda kv: sympy.sstr(kv[0])))",
    ),
  )
  let d = matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let ours = d.diagonalize()
  assert_eq(
    local_matrix_list_text(ours.0),
    py_matrix_list_text(py_matrix_expr(d) + ".diagonalize()[0]"),
  )
  assert_eq(
    local_matrix_list_text(ours.1),
    py_matrix_list_text(py_matrix_expr(d) + ".diagonalize()[1]"),
  )
}

///|
test "matrices parity charpoly on dense diagonally dominant exact matrix" {
  let a = matrix([
    [@symcore.int(17), @symcore.int(2), @symcore.int(1), @symcore.int(2)],
    [@symcore.int(2), @symcore.int(18), @symcore.int(2), @symcore.int(1)],
    [@symcore.int(1), @symcore.int(2), @symcore.int(19), @symcore.int(2)],
    [@symcore.int(2), @symcore.int(1), @symcore.int(2), @symcore.int(20)],
  ])
  let lam = @symcore.Expr::Symbol("lam")
  assert_eq(
    "0",
    py_list_text(
      "(lambda lam: sympy.sstr(sympy.expand((" +
      @symprint.to_string(a.charpoly(x=lam)) +
      ") - (" +
      py_matrix_expr(a) +
      ".charpoly(lam).as_expr()))))(sympy.Symbol('lam'))",
    ),
  )
}

///|
test "matrices parity jordan form on defective 2x2" {
  let a = matrix([
    [@symcore.int(4), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(4)],
  ])
  let ours = a.jordan_form()
  assert_eq(
    local_matrix_list_text(ours.1),
    py_matrix_list_text(py_matrix_expr(a) + ".jordan_form()[1]"),
  )
  assert_eq(
    local_matrix_list_text(a * ours.0),
    local_matrix_list_text(ours.0 * ours.1),
  )
}

///|
test "matrices parity jordan form on defective 3x3 chain" {
  let a = matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let ours = a.jordan_form()
  assert_eq(
    local_matrix_list_text(ours.1),
    py_matrix_list_text(py_matrix_expr(a) + ".jordan_form()[1]"),
  )
  assert_eq(
    local_matrix_list_text(a * ours.0),
    local_matrix_list_text(ours.0 * ours.1),
  )
}

///|
test "matrices parity jordan form on mixed 3x3 blocks" {
  let a = matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let ours = a.jordan_form()
  assert_eq(
    local_matrix_list_text(ours.1),
    py_matrix_list_text(py_matrix_expr(a) + ".jordan_form()[1]"),
  )
  assert_eq(
    local_matrix_list_text(a * ours.0),
    local_matrix_list_text(ours.0 * ours.1),
  )
}

///|
test "matrices parity eigenvals on general non-triangular 3x3" {
  let a = matrix([
    [@symcore.int(0), @symcore.int(0), @symcore.int(6)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(-11)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(6)],
  ])
  assert_eq(
    "ok",
    py_list_text(
      "(lambda loc, ref: (lambda loc2, ref2: 'ok' if len(loc2) == len(ref2) and all(sympy.simplify(loc2[i][0] - ref2[i][0]) == 0 and loc2[i][1] == int(ref2[i][1]) for i in range(len(ref2))) else 'mismatch')(sorted(loc, key=lambda kv: float(sympy.N(kv[0], 30))), sorted(ref, key=lambda kv: float(sympy.N(kv[0], 30)))))(" +
      local_eigenvals_py(a.eigenvals()) +
      ", sorted(" +
      py_matrix_expr(a) +
      ".eigenvals().items(), key=lambda kv: sympy.sstr(kv[0])))",
    ),
  )
  let (p, d) = a.diagonalize()
  inspect((a * p).to_string(), content=(p * d).to_string())
}

///|
test "matrices parity eigenvals on general non-triangular 4x4 companion" {
  let a = matrix([
    [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(-24)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(50)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(-35)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(1), @symcore.int(10)],
  ])
  assert_eq(
    "ok",
    py_list_text(
      "(lambda loc, ref: (lambda loc2, ref2: 'ok' if len(loc2) == len(ref2) and all(sympy.simplify(loc2[i][0] - ref2[i][0]) == 0 and loc2[i][1] == int(ref2[i][1]) for i in range(len(ref2))) else 'mismatch')(sorted(loc, key=lambda kv: float(sympy.N(kv[0], 30))), sorted(ref, key=lambda kv: float(sympy.N(kv[0], 30)))))(" +
      local_eigenvals_py(a.eigenvals()) +
      ", sorted(" +
      py_matrix_expr(a) +
      ".eigenvals().items(), key=lambda kv: sympy.sstr(kv[0])))",
    ),
  )
}

///|
test "matrices parity eigenvals on general non-companion algebraic 3x3" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(1), @symcore.int(0)],
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(1)],
  ])
  assert_eq(
    "ok",
    py_list_text(
      "(lambda loc, ref: (lambda loc2, ref2: 'ok' if len(loc2) == len(ref2) and all(sympy.simplify(loc2[i][0] - ref2[i][0]) == 0 and loc2[i][1] == int(ref2[i][1]) for i in range(len(ref2))) else 'mismatch')(sorted(loc, key=lambda kv: sympy.sstr(kv[0])), sorted(ref, key=lambda kv: sympy.sstr(kv[0]))))(" +
      local_eigenvals_py(a.eigenvals()) +
      ", sorted(" +
      py_matrix_expr(a) +
      ".eigenvals().items(), key=lambda kv: sympy.sstr(kv[0])))",
    ),
  )
}

///|
test "matrices parity jordan form on defective non-triangular 3x3" {
  let a = matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(0)],
    [
      @symcore.rational_from_ints(-1, 2),
      @symcore.rational_from_ints(11, 2),
      @symcore.rational_from_ints(1, 2),
    ],
    [
      @symcore.rational_from_ints(1, 2),
      @symcore.rational_from_ints(1, 2),
      @symcore.rational_from_ints(9, 2),
    ],
  ])
  let ours = a.jordan_form()
  assert_eq(
    local_matrix_list_text(ours.1),
    py_list_text(
      "'[' + ', '.join('[' + ', '.join(sympy.sstr(sympy.nsimplify(v)) for v in row) + ']' for row in (" +
      py_matrix_expr(a) +
      ".jordan_form()[1]).tolist()) + ']'",
    ),
  )
  assert_eq(
    local_matrix_list_text(a * ours.0),
    local_matrix_list_text(ours.0 * ours.1),
  )
}
