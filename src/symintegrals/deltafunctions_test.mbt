///|
test "symintegrals expand_dirac_delta extracts additive delta coefficients" {
  let t = @symcore.Expr::Symbol("t")
  let a = @symcore.Expr::Symbol("a")
  let delta_t = @symspec.dirac_delta(t)
  let delta_shift = @symspec.dirac_delta(t - a)
  let out = expand_dirac_delta(@symcore.int(3) * delta_t - a * delta_shift)
  let mut count = 0
  for _ in out.keys() {
    count += 1
  }
  assert_true(count == 2)
  match out.get(delta_t) {
    Some(coeff) =>
      assert_true(@symcore.compare_expr(coeff, @symcore.int(3)) == 0)
    None => fail("expected DiracDelta(t) coefficient")
  }
  match out.get(delta_shift) {
    Some(coeff) =>
      assert_true(
        @symcore.compare_expr(@symsimplify.simplify(coeff + a), @symcore.int(0)) ==
        0,
      )
    None => fail("expected shifted DiracDelta coefficient")
  }
}
