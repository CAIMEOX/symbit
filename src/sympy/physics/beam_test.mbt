///|
fn beam_test_sf(start : @symcore.Expr, order : Int) -> @symcore.Expr {
  cm_singularity(Symbol("x"), start, order)
}

///|
test "physics.continuum_mechanics.beam: reactions and fields" {
  let e = @symcore.Expr::NumberSymbol(Exp1)
  let i = @symcore.Expr::NumberSymbol(ImaginaryUnit)
  let a = @symcore.Expr::Symbol("A")
  let r1 = @symcore.Expr::Symbol("R1")
  let r2 = @symcore.Expr::Symbol("R2")

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
  let beam_r1 = b.reaction_loads()["R1"]
  let beam_r2 = b.reaction_loads()["R2"]

  assert_true(cm_numeric_expr_eq(beam_r1, @symcore.int(6)))
  assert_true(cm_numeric_expr_eq(beam_r2, @symcore.int(2)))

  let expected_load = @symcore.int(-8) * beam_test_sf(@symcore.int(0), -1) +
    @symcore.int(6) * beam_test_sf(@symcore.int(10), -1) +
    @symcore.int(2) * beam_test_sf(@symcore.int(30), -1) +
    @symcore.int(120) * beam_test_sf(@symcore.int(30), -2)
  assert_true(cm_numeric_expr_eq(b.load(), expected_load))

  let expected_shear = @symcore.int(8) * beam_test_sf(@symcore.int(0), 0) +
    @symcore.int(-6) * beam_test_sf(@symcore.int(10), 0) +
    @symcore.int(-2) * beam_test_sf(@symcore.int(30), 0) +
    @symcore.int(-120) * beam_test_sf(@symcore.int(30), -1)
  assert_true(cm_numeric_expr_eq(b.shear_force(), expected_shear))

  let expected_moment = @symcore.int(8) * beam_test_sf(@symcore.int(0), 1) +
    @symcore.int(-6) * beam_test_sf(@symcore.int(10), 1) +
    @symcore.int(-2) * beam_test_sf(@symcore.int(30), 1) +
    @symcore.int(-120) * beam_test_sf(@symcore.int(30), 0)
  assert_true(cm_numeric_expr_eq(b.bending_moment(), expected_moment))

  let expected_stress = expected_shear * (a ^ @symcore.int(-1))
  assert_true(cm_numeric_expr_eq(b.shear_stress(), expected_stress))
}

///|
test "physics.continuum_mechanics.beam: distributed end load and support application" {
  let e = @symcore.Expr::NumberSymbol(Exp1)
  let i = @symcore.Expr::NumberSymbol(ImaginaryUnit)
  let b = beam(@symcore.int(9), e, i, area=@symcore.int(2))
  let supports = b.apply_support(@symcore.int(0), kind="fixed")
  assert_eq(supports.length(), 2)
  b.apply_load(@symcore.int(-2), @symcore.int(2), 2, end=Some(@symcore.int(3)))

  let expected_load = @symcore.int(-2) * beam_test_sf(@symcore.int(2), 2) +
    @symcore.int(2) * beam_test_sf(@symcore.int(3), 0) +
    @symcore.int(4) * beam_test_sf(@symcore.int(3), 1) +
    @symcore.int(2) * beam_test_sf(@symcore.int(3), 2) +
    supports[0] * beam_test_sf(@symcore.int(0), -1) +
    supports[1] * beam_test_sf(@symcore.int(0), -2)
  assert_true(cm_numeric_expr_eq(b.load(), expected_load))

  b.remove_load(@symcore.int(-2), @symcore.int(2), 2, end=Some(@symcore.int(3)))
  let support_only = supports[0] * beam_test_sf(@symcore.int(0), -1) +
    supports[1] * beam_test_sf(@symcore.int(0), -2)
  assert_true(cm_numeric_expr_eq(b.load(), support_only))
}
