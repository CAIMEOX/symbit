///|
test "physics.continuum_mechanics.arch: oracle parity" {
  let a = try! arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(40), @symcore.int(0)),
    @symcore.int(20),
    crown_y=Some(@symcore.int(12)),
  )
  try! a.apply_load(
    -1,
    "C",
    @symcore.int(8),
    @symcore.int(150),
    angle=Some(@symcore.int(270)),
  )
  try! a.apply_load(
    0,
    "D",
    @symcore.int(20),
    @symcore.int(-4),
    end=Some(@symcore.int(40)),
  )
  try! a.solve()

  let b = try! arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(16), @symcore.int(0)),
    @symcore.int(8),
    crown_y=Some(@symcore.int(5)),
  )
  let t = @symcore.symbol("t")
  try! b.apply_load(0, "C", @symcore.int(3), t, end=Some(@symcore.int(5)))
  try! b.solve()
  let near_eight = try! @symcore.rational_from_ints(7_999_999, 1_000_000)

  let oracle = continuum_oracle_lines(
    "a = Arch((0, 0), (40, 0), crown_x=20, crown_y=12)\n" +
    "a.apply_load(-1, 'C', 8, 150, angle=270)\n" +
    "a.apply_load(0, 'D', 20, -4, end=40)\n" +
    "a.solve()\n" +
    "print(a.reaction_force[Symbol('R_A_x')])\n" +
    "print(a.reaction_force[Symbol('R_A_y')])\n" +
    "print(a.reaction_force[Symbol('R_B_x')])\n" +
    "print(a.reaction_force[Symbol('R_B_y')])\n" +
    "print(a.axial_force_at(Rational(7999999, 1000000)))\n" +
    "print(a.shear_force_at(Rational(7999999, 1000000)))\n" +
    "b = Arch((0, 0), (16, 0), crown_x=8, crown_y=5)\n" +
    "b.apply_load(0, 'C', 3, t, end=5)\n" +
    "b.solve()\n" +
    "print(b.reaction_force[Symbol('R_A_x')])\n" +
    "print(b.reaction_force[Symbol('R_A_y')])\n" +
    "print(b.reaction_force[Symbol('R_B_x')])\n" +
    "print(b.reaction_force[Symbol('R_B_y')])\n" +
    "print(b.bending_moment_at(4))\n",
  )
  guard oracle.length() == 11 else { fail("unexpected oracle arch output") }
  guard continuum_expr_eq(a.reaction_force()["R_A_x"], oracle[0]) else {
    fail("arch R_A_x")
  }
  guard continuum_expr_eq(a.reaction_force()["R_A_y"], oracle[1]) else {
    fail("arch R_A_y")
  }
  guard continuum_expr_eq(a.reaction_force()["R_B_x"], oracle[2]) else {
    fail("arch R_B_x")
  }
  guard continuum_expr_eq(a.reaction_force()["R_B_y"], oracle[3]) else {
    fail("arch R_B_y")
  }
  guard continuum_expr_eq(
    try! a.axial_force_at(pos=Some(near_eight)),
    oracle[4],
  ) else {
    fail("arch axial")
  }
  guard continuum_expr_eq(
    try! a.shear_force_at(pos=Some(near_eight)),
    oracle[5],
  ) else {
    fail("arch shear")
  }
  guard continuum_expr_eq(b.reaction_force()["R_A_x"], oracle[6]) else {
    fail("arch symbolic R_A_x")
  }
  guard continuum_expr_eq(b.reaction_force()["R_A_y"], oracle[7]) else {
    fail("arch symbolic R_A_y")
  }
  guard continuum_expr_eq(b.reaction_force()["R_B_x"], oracle[8]) else {
    fail("arch symbolic R_B_x")
  }
  guard continuum_expr_eq(b.reaction_force()["R_B_y"], oracle[9]) else {
    fail("arch symbolic R_B_y")
  }
  guard continuum_expr_eq(
    try! b.bending_moment_at(pos=Some(@symcore.int(4))),
    oracle[10],
  ) else {
    fail("arch symbolic moment")
  }
}
