///|
test "polys linsolve worker preserves sympy_dict_to_dm codecs" {
  assert_eq(
    linsolve_sympy_dict_to_dm_summary(
      [{ "x": "1", "y": "2" }, { "y": "1" }],
      ["3", "1"],
      ["x", "y"],
    ),
    "[[1, 2, -3], [0, 1, -1]]@QQ|sparse",
  )
}

///|
test "polys linsolve worker reuses literal symbols for eqs_to_matrix" {
  assert_eq(
    solvers_eqs_to_matrix_summary(
      [{ "x": "1", "y": "1" }, { "x": "1", "y": "-1" }],
      ["0", "-1"],
      ["x", "y"],
      "ZZ",
    ),
    "Matrix([[1, 1, 0], [1, -1, 1]])@ZZ",
  )
  assert_eq(
    solvers_eqs_to_matrix_summary([{ "x y,z": "2" }], ["3"], ["x y,z"], "ZZ"),
    "Matrix([[2, -3]])@ZZ",
  )
}

///|
test "polys linsolve worker preserves ring and linear-dict outputs" {
  let eqs = ["x - y", "x + y - 2"]
  let syms = ["x", "y"]
  assert_eq(
    solvers_sympy_eqs_to_ring_summary(eqs, syms),
    "[x - y, x + y - 2]||QQ[x,y]",
  )
  assert_eq(
    linsolve_linear_eq_to_dict_summary(eqs, syms),
    "x:1,y:-1||0|x:1,y:1||-2",
  )
}

///|
test "polys linsolve worker preserves solver result shapes" {
  let syms = ["x", "y"]
  assert_eq(linsolve_internal_summary(["x - y", "x + y - 2"], syms), "x:1|y:1")
  assert_eq(linsolve_internal_summary(["x + y"], syms), "x:-y|y:y")
  assert_eq(
    solvers_solve_lin_sys_summary(["x - y", "x + y - 2"], syms),
    "x:1,y:1",
  )
  assert_eq(solvers_solve_lin_sys_summary(["x + y"], syms), "x:-y")
}

///|
test "polys linsolve worker preserves intentional None" {
  let inconsistent = ["x + y - 1", "x + y - 2"]
  let syms = ["x", "y"]
  assert_eq(linsolve_internal_summary(inconsistent, syms), "None")
  assert_eq(solvers_solve_lin_sys_summary(inconsistent, syms), "None")
}

///|
test "polys linsolve worker propagates errors and recovers" {
  let matrix_rejected = try {
    solvers_eqs_to_matrix_summary([{ "z": "1" }], ["0"], ["x"], "ZZ") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(matrix_rejected)
  let internal_rejected = try {
    linsolve_internal_summary(["x*y"], ["x", "y"]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(internal_rejected)
  let solve_rejected = try {
    solvers_solve_lin_sys_summary(["x*y"], ["x", "y"]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(solve_rejected)
  assert_eq(linsolve_internal_summary([], ["x", "y"]), "x:x|y:y")
  assert_eq(solvers_solve_lin_sys_summary([], ["x", "y"]), "")
}
