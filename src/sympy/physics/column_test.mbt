///|
fn column_test_sf(start : @symcore.Expr, order : Int) -> @symcore.Expr {
  cm_singularity(Symbol("x"), start, order)
}

///|
test "physics.continuum_mechanics.column: loads and reactions" {
  let e = @symcore.Expr::NumberSymbol(Exp1)
  let a = @symcore.Expr::Symbol("A")
  let c = column(@symcore.int(10), e, a)
  let r0 = c.apply_support(@symcore.int(0))
  let r10 = c.apply_support(@symcore.int(10))
  c.apply_load(@symcore.int(-1), @symcore.int(5), -1)
  c.solve_for_reaction_loads(reactions=[r0, r10])
  let col_r0 = c.reaction_loads()["R_0"]
  let col_r10 = c.reaction_loads()["R_10"]

  assert_true(cm_numeric_expr_eq(col_r0, cm_rat_expr(1, 2)))
  assert_true(cm_numeric_expr_eq(col_r10, cm_rat_expr(1, 2)))

  let expected_load = cm_rat_expr(1, 2) * column_test_sf(@symcore.int(0), -1) +
    cm_rat_expr(1, 2) * column_test_sf(@symcore.int(10), -1) +
    @symcore.int(-1) * column_test_sf(@symcore.int(5), -1)
  assert_true(cm_numeric_expr_eq(c.load(), expected_load))

  assert_true(cm_expr_is_zero(cm_eval_at(c.extension(), "x", @symcore.int(0))))
  assert_true(cm_expr_is_zero(cm_eval_at(c.extension(), "x", @symcore.int(10))))
}

///|
test "physics.continuum_mechanics.column: distributed and ramp loads" {
  let e = @symcore.Expr::NumberSymbol(Exp1)
  let a = @symcore.Expr::Symbol("A")
  let c = column(@symcore.int(10), e, a)
  c.apply_load(@symcore.int(5), @symcore.int(0), -1)
  c.apply_load(@symcore.int(5), @symcore.int(2), 0, end=Some(@symcore.int(4)))
  c.apply_load(@symcore.int(5), @symcore.int(4), 1, end=Some(@symcore.int(6)))

  let expected = @symcore.int(5) * column_test_sf(@symcore.int(0), -1) +
    @symcore.int(5) * column_test_sf(@symcore.int(2), 0) +
    @symcore.int(-5) * column_test_sf(@symcore.int(4), 0) +
    @symcore.int(5) * column_test_sf(@symcore.int(4), 1) +
    @symcore.int(-10) * column_test_sf(@symcore.int(6), 0) +
    @symcore.int(-5) * column_test_sf(@symcore.int(6), 1)
  assert_true(cm_numeric_expr_eq(c.load(), expected))

  c.remove_load(@symcore.int(5), @symcore.int(4), 1, end=Some(@symcore.int(6)))
  let after_remove = @symcore.int(5) * column_test_sf(@symcore.int(0), -1) +
    @symcore.int(5) * column_test_sf(@symcore.int(2), 0) +
    @symcore.int(-5) * column_test_sf(@symcore.int(4), 0)
  assert_true(cm_numeric_expr_eq(c.load(), after_remove))
}
