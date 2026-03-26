///|
test "physics.continuum_mechanics.arch: oracle parity" {
  let a = arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(40), @symcore.int(0)),
    @symcore.int(20),
    crown_y=Some(@symcore.int(12)),
  )
  a.apply_load(
    -1,
    "C",
    @symcore.int(8),
    @symcore.int(150),
    angle=Some(@symcore.int(270)),
  )
  a.apply_load(
    0,
    "D",
    @symcore.int(20),
    @symcore.int(-4),
    end=Some(@symcore.int(40)),
  )
  a.solve()

  let b = arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(16), @symcore.int(0)),
    @symcore.int(8),
    crown_y=Some(@symcore.int(5)),
  )
  let t = @symcore.Expr::Symbol("t")
  b.apply_load(0, "C", @symcore.int(3), t, end=Some(@symcore.int(5)))
  b.solve()
  let near_eight = @symcore.rational_from_ints(7_999_999, 1_000_000)

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
  assert_eq(oracle.length(), 11)
  assert_true(continuum_expr_eq(a.reaction_force()["R_A_x"], oracle[0]))
  assert_true(continuum_expr_eq(a.reaction_force()["R_A_y"], oracle[1]))
  assert_true(continuum_expr_eq(a.reaction_force()["R_B_x"], oracle[2]))
  assert_true(continuum_expr_eq(a.reaction_force()["R_B_y"], oracle[3]))
  assert_true(
    continuum_expr_eq(a.axial_force_at(pos=Some(near_eight)), oracle[4]),
  )
  assert_true(
    continuum_expr_eq(a.shear_force_at(pos=Some(near_eight)), oracle[5]),
  )
  assert_true(continuum_expr_eq(b.reaction_force()["R_A_x"], oracle[6]))
  assert_true(continuum_expr_eq(b.reaction_force()["R_A_y"], oracle[7]))
  assert_true(continuum_expr_eq(b.reaction_force()["R_B_x"], oracle[8]))
  assert_true(continuum_expr_eq(b.reaction_force()["R_B_y"], oracle[9]))
  assert_true(
    continuum_expr_eq(
      b.bending_moment_at(pos=Some(@symcore.int(4))),
      oracle[10],
    ),
  )
}
