///|
test "physics.continuum_mechanics.column: oracle parity" {
  let c = column(@symcore.int(10), @symcore.symbol("E"), @symcore.symbol("A"))
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
  guard oracle.length() == 5 else { fail("unexpected oracle column output") }
  guard continuum_expr_eq(c.reaction_loads()["R_0"], oracle[0]) else {
    fail("column R_0")
  }
  guard continuum_expr_eq(c.reaction_loads()["R_10"], oracle[1]) else {
    fail("column R_10")
  }
  guard continuum_expr_eq(c.load(), oracle[2]) else { fail("column load") }
  guard continuum_expr_eq(c.axial_force(), oracle[3]) else {
    fail("column axial force")
  }
  guard continuum_expr_eq(c.extension(), oracle[4]) else {
    fail("column extension")
  }
}
