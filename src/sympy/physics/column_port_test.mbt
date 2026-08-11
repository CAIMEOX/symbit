///|
test "physics.continuum_mechanics.column: oracle parity" {
  let c = column(@symcore.int(10), NumberSymbol(Exp1), Symbol("A"))
  ignore(c.apply_support(@symcore.int(0)))
  ignore(c.apply_support(@symcore.int(10)))
  c.apply_load(@symcore.int(-1), @symcore.int(5), -1)
  c.solve_for_reaction_loads()

  let oracle = continuum_oracle_lines(
    "c = Column(10, E, A)\n" +
    "c.apply_support(0)\n" +
    "c.apply_support(10)\n" +
    "c.apply_load(-1, 5, -1)\n" +
    "c.solve_for_reaction_loads()\n" +
    "print(c.reaction_loads[Symbol('R_0')])\n" +
    "print(c.reaction_loads[Symbol('R_10')])\n" +
    "print(c.load)\n" +
    "print(c.axial_force())\n" +
    "print(c.extension())\n",
  )
  assert_eq(oracle.length(), 5)
  assert_true(continuum_expr_eq(c.reaction_loads()["R_0"], oracle[0]))
  assert_true(continuum_expr_eq(c.reaction_loads()["R_10"], oracle[1]))
  assert_true(continuum_expr_eq(c.load(), oracle[2]))
  assert_true(continuum_expr_eq(c.axial_force(), oracle[3]))
  assert_true(continuum_expr_eq(c.extension(), oracle[4]))
}
