///|
test "geometry worker scope exposes geometry names symbols and constants" {
  assert_eq(
    @geometry.geometry_eval_str("Point2D(0, 0).distance(Point2D(3, 4))"),
    "5",
  )
  assert_eq(
    @geometry.geometry_eval_repr("Point3D(x, y, z)"),
    "Point3D(x, y, z)",
  )
  assert_eq(
    @geometry.geometry_eval_str("(a, b, c, x, y, z, t, u, v)"),
    "(a, b, c, x, y, z, t, u, v)",
  )
  assert_eq(@geometry.geometry_eval_str("(pi, oo, E, I)"), "(pi, oo, E, I)")
}

///|
test "geometry summary evaluates source as one bound expression" {
  assert_eq(
    @geometry.geometry_summary("Point2D(1, 2), Point2D(3, 4)"),
    "(Point2D(1, 2), Point2D(3, 4))",
  )
  assert_eq(
    @geometry.geometry_summary("{Point2D(3, 4), Point2D(0, 0)}"),
    "{Point2D(0, 0), Point2D(3, 4)}",
  )
}

///|
test "geometry expression equality shares the fixed scope" {
  assert_true(
    @geometry.geometry_expr_equal("Point2D(x, y).x + Point2D(x, y).y", "x + y"),
  )
  assert_false(@geometry.geometry_expr_equal("Point2D(x, y).x", "y"))
}

///|
test "geometry worker preserves quoted source and recovers after errors" {
  assert_eq(@geometry.geometry_eval_repr("'Point2D(9, 9)'"), "'Point2D(9, 9)'")
  let rejected = try {
    @geometry.geometry_eval_str("Point2D(") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let str_none_rejected = try {
    @geometry.geometry_eval_str("None") |> ignore
    false
  } catch {
    _ => true
  }
  let repr_none_rejected = try {
    @geometry.geometry_eval_repr("None") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(str_none_rejected)
  assert_true(repr_none_rejected)
  assert_eq(@geometry.geometry_summary("None"), "None")
  assert_eq(@geometry.geometry_eval_str("Point2D(1, 2).x"), "1")
}

///|
test "geometry worker does not leak unrelated SymPy names into scope" {
  let hidden = try {
    @geometry.geometry_eval_str("Matrix([[1]])") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(hidden)
  assert_eq(@geometry.geometry_eval_str("Point2D(2, 3).y"), "3")
}

///|
test "geometry worker hides request plumbing from evaluated expressions" {
  let eval_binding_hidden = try {
    @geometry.geometry_eval_str("expr_source") |> ignore
    false
  } catch {
    _ => true
  }
  let summary_binding_hidden = try {
    @geometry.geometry_summary("expr_source") |> ignore
    false
  } catch {
    _ => true
  }
  let summary_helper_hidden = try {
    @geometry.geometry_summary("_symbit_geometry_summary") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(eval_binding_hidden)
  assert_true(summary_binding_hidden)
  assert_true(summary_helper_hidden)
  assert_eq(@geometry.geometry_summary("Point2D(4, 5)"), "Point2D(4, 5)")
}
