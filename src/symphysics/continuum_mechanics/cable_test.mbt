///|
fn cable_is_close(expr : @symcore.Expr, value : Double) -> Bool {
  match cm_expr_eval(expr, {}) {
    Some(actual) =>
      actual.is_close(
        value,
        relative_tolerance=1.0e-9,
        absolute_tolerance=1.0e-9,
      )
    None => false
  }
}

///|
test "physics.continuum_mechanics.cable: point loads and distributed loads" {
  let c0 = cable(
    ("A", @symcore.int(0), @symcore.int(10)),
    ("B", @symcore.int(10), @symcore.int(10)),
  )
  assert_true(c0.supports()["A"] == [@symcore.int(0), @symcore.int(10)])
  assert_true(c0.left_support() == [@symcore.int(0), @symcore.int(10)])
  assert_true(c0.right_support() == [@symcore.int(10), @symcore.int(10)])

  c0.change_support("A", ("C", @symcore.int(12), @symcore.int(3)))
  assert_true(c0.supports().get("A") is None)
  assert_true(c0.supports()["C"] == [@symcore.int(12), @symcore.int(3)])

  let c = cable(
    ("A", @symcore.int(0), @symcore.int(10)),
    ("B", @symcore.rational_from_ints(11, 2), @symcore.int(8)),
  )
  c.apply_point_load(
    (
      "Z",
      @symcore.int(2),
      @symcore.rational_from_ints(363, 50),
      @symcore.int(3),
      @symcore.int(270),
    ),
  )
  c.apply_point_load(
    ("X", @symcore.int(4), @symcore.int(6), @symcore.int(8), @symcore.int(270)),
  )
  c.solve()
  assert_true(cable_is_close(c.tension()["A_Z"], 6.89488895397307))
  assert_true(cable_is_close(c.tension()["Z_X"], 4.79150773600774))
  assert_true(cable_is_close(c.tension()["X_B"], 6.78571428571429))
  assert_true(cable_is_close(c.reaction_loads()["R_A_x"], -4.06504065040650))
  assert_true(cable_is_close(c.reaction_loads()["R_A_y"], 5.56910569105691))
  assert_true(cable_is_close(c.reaction_loads()["R_B_x"], 4.06504065040650))
  assert_true(cable_is_close(c.reaction_loads()["R_B_y"], 5.43089430894309))
  assert_true(cable_is_close(c.length(), 8.25609584845190))

  let d = cable(
    ("A", @symcore.int(0), @symcore.int(40)),
    ("B", @symcore.int(100), @symcore.int(20)),
  )
  d.apply_distributed_load("X", @symcore.int(850))
  d.solve(
    lowest_x=Some(@symcore.rational_from_ints(2929, 50)),
    lowest_y=Some(@symcore.int(0)),
  )
  assert_true(cable_is_close(d.tension_at(@symcore.int(0)), 61717.4130533677))
  assert_true(cable_is_close(d.tension_at(@symcore.int(40)), 39738.0809048449))
  assert_true(cable_is_close(d.reaction_loads()["R_A_x"], 36465.0))
  assert_true(cable_is_close(d.reaction_loads()["R_A_y"], -49793.0))
  assert_true(cable_is_close(d.reaction_loads()["R_B_x"], 44399.9537590861))
  assert_true(cable_is_close(d.reaction_loads()["R_B_y"], 42868.2071025955))
}
