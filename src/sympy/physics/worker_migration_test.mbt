///|
test "physics worker preserves punctuation-rich expression symbols" {
  assert_eq(physics_expr_str(Symbol("x y,z")), "x y,z")
}

///|
test "physics worker shares expression identity within one request" {
  let marker = @symcore.dummy(name="d")
  assert_eq(hydrogen_e_nl(marker, z=marker), "-1/2")
}

///|
test "physics worker preserves curated physics scope" {
  assert_eq(physics_eval_str("m"), "m")
  assert_eq(physics_eval_str("Z"), "Z")
  assert_eq(physics_eval_str("q.is_commutative"), "False")
  assert_eq(physics_eval_str("hbar"), "hbar")
  assert_eq(
    physics_eval_str("RouthHurwitz"),
    "<class 'sympy.physics.control.routh_table.RouthHurwitz'>",
  )
}

///|
test "physics worker preserves exact comparisons and matrix codecs" {
  assert_true(expr_equal("sin(x)**2 + cos(x)**2", "1"))
  assert_false(expr_equal("x", "x + 1"))
  assert_eq(msigma(1), ["0", "1", "1", "0"])
  assert_eq(physics_eval_matrix("Matrix(0, 0, [])"), [])
  assert_eq(physics_eval_matrix("Matrix([[x]])"), ["x"])
}

///|
test "physics worker binds source strings as data" {
  assert_eq(quantum_eval_str("Symbol('line\\nname')"), "line\nname")
  assert_eq(quantum_eval_str("Symbol('tab\\tname')"), "tab\tname")
  assert_eq(quantum_eval_str("Symbol('slash\\\\name')"), "slash\\name")
}

///|
test "physics worker contains script failures then recovers" {
  let rejected = try {
    quantum_eval_str("(") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(quantum_eval_str("2 + 2"), "4")
}
