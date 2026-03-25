///|
test "physics.continuum_mechanics.beam: oracle parity" {
  let e = @symcore.exp1()
  let i = @symcore.imag_unit()
  let a = @symcore.symbol("A")
  let r1 = @symcore.symbol("R1")
  let r2 = @symcore.symbol("R2")
  let b = beam(@symcore.int(30), e, i, area=a)
  b.set_bc_deflection([
    (@symcore.int(10), @symcore.int(0)),
    (@symcore.int(30), @symcore.int(0)),
  ])
  b.apply_load(@symcore.int(-8), @symcore.int(0), -1)
  b.apply_load(r1, @symcore.int(10), -1)
  b.apply_load(r2, @symcore.int(30), -1)
  b.apply_load(@symcore.int(120), @symcore.int(30), -2)
  b.solve_for_reaction_loads(reactions=[r1, r2])

  let oracle = continuum_oracle_lines(
    "b = Beam(30, E, I)\n" +
    "b.bc_deflection = [(10, 0), (30, 0)]\n" +
    "b.apply_load(-8, 0, -1)\n" +
    "b.apply_load(R1, 10, -1)\n" +
    "b.apply_load(R2, 30, -1)\n" +
    "b.apply_load(120, 30, -2)\n" +
    "b.solve_for_reaction_loads(R1, R2)\n" +
    "print(b.reaction_loads[R1])\n" +
    "print(b.reaction_loads[R2])\n" +
    "print(b.load)\n" +
    "print(b.shear_force())\n" +
    "print(b.bending_moment())\n",
  )
  assert_eq(oracle.length(), 5)
  assert_true(continuum_expr_eq(b.reaction_loads()["R1"], oracle[0]))
  assert_true(continuum_expr_eq(b.reaction_loads()["R2"], oracle[1]))
  assert_true(continuum_expr_eq(b.load(), oracle[2]))
  assert_true(continuum_expr_eq(b.shear_force(), oracle[3]))
  assert_true(continuum_expr_eq(b.bending_moment(), oracle[4]))
}
