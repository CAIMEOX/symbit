///|
test "physics.continuum_mechanics.cable: oracle parity" {
  let c = try! cable(
    ("A", @symcore.int(0), @symcore.int(10)),
    ("B", try! @symcore.rational_from_ints(11, 2), @symcore.int(8)),
  )
  try! c.apply_point_load(
    (
      "Z",
      @symcore.int(2),
      try! @symcore.rational_from_ints(363, 50),
      @symcore.int(3),
      @symcore.int(270),
    ),
  )
  try! c.apply_point_load(
    ("X", @symcore.int(4), @symcore.int(6), @symcore.int(8), @symcore.int(270)),
  )
  try! c.solve()

  let d = try! cable(
    ("A", @symcore.int(0), @symcore.int(40)),
    ("B", @symcore.int(100), @symcore.int(20)),
  )
  try! d.apply_distributed_load("X", @symcore.int(850))
  try! d.solve(
    lowest_x=Some(try! @symcore.rational_from_ints(2929, 50)),
    lowest_y=Some(@symcore.int(0)),
  )

  let oracle = continuum_oracle_lines(
    "c = Cable(('A', 0, 10), ('B', Rational(11, 2), 8))\n" +
    "c.apply_load(-1, ('Z', 2, Rational(363, 50), 3, 270))\n" +
    "c.apply_load(-1, ('X', 4, 6, 8, 270))\n" +
    "c.solve()\n" +
    "print(c.tension[Symbol('A_Z')])\n" +
    "print(c.tension[Symbol('Z_X')])\n" +
    "print(c.tension[Symbol('X_B')])\n" +
    "print(c.reaction_loads[Symbol('R_A_x')])\n" +
    "print(c.reaction_loads[Symbol('R_A_y')])\n" +
    "print(c.reaction_loads[Symbol('R_B_x')])\n" +
    "print(c.reaction_loads[Symbol('R_B_y')])\n" +
    "print(c.length)\n" +
    "d = Cable(('A', 0, 40), ('B', 100, 20))\n" +
    "d.apply_load(0, ('X', 850))\n" +
    "d.solve(Rational(2929, 50), 0)\n" +
    "print(N(d.tension_at(0), 30))\n" +
    "print(N(d.tension_at(40), 30))\n" +
    "print(N(d.reaction_loads[Symbol('R_A_x')], 30))\n" +
    "print(N(d.reaction_loads[Symbol('R_A_y')], 30))\n" +
    "print(N(d.reaction_loads[Symbol('R_B_x')], 30))\n" +
    "print(N(d.reaction_loads[Symbol('R_B_y')], 30))\n",
  )
  guard oracle.length() == 14 else { fail("unexpected oracle cable output") }
  guard continuum_expr_eq(c.tension()["A_Z"], oracle[0]) else {
    fail("cable A_Z")
  }
  guard continuum_expr_eq(c.tension()["Z_X"], oracle[1]) else {
    fail("cable Z_X")
  }
  guard continuum_expr_eq(c.tension()["X_B"], oracle[2]) else {
    fail("cable X_B")
  }
  guard continuum_expr_eq(c.reaction_loads()["R_A_x"], oracle[3]) else {
    fail("cable R_A_x")
  }
  guard continuum_expr_eq(c.reaction_loads()["R_A_y"], oracle[4]) else {
    fail("cable R_A_y")
  }
  guard continuum_expr_eq(c.reaction_loads()["R_B_x"], oracle[5]) else {
    fail("cable R_B_x")
  }
  guard continuum_expr_eq(c.reaction_loads()["R_B_y"], oracle[6]) else {
    fail("cable R_B_y")
  }
  guard continuum_expr_eq(c.length(), oracle[7]) else { fail("cable length") }
  guard continuum_float_close(d.tension_at(@symcore.int(0)), oracle[8]) else {
    fail("distributed tension 0")
  }
  guard continuum_float_close(d.tension_at(@symcore.int(40)), oracle[9]) else {
    fail("distributed tension 40")
  }
  guard continuum_float_close(d.reaction_loads()["R_A_x"], oracle[10]) else {
    fail("distributed R_A_x")
  }
  guard continuum_float_close(d.reaction_loads()["R_A_y"], oracle[11]) else {
    fail("distributed R_A_y")
  }
  guard continuum_float_close(d.reaction_loads()["R_B_x"], oracle[12]) else {
    fail("distributed R_B_x")
  }
  guard continuum_float_close(d.reaction_loads()["R_B_y"], oracle[13]) else {
    fail("distributed R_B_y")
  }
}
