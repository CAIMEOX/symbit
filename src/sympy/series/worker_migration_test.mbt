///|
test "series worker preserves punctuation-rich variable names" {
  let variable = @symcore.Expr::Symbol("x y,z")
  assert_eq(series_str(variable, "x y,z", @symcore.int(0), 2), "x y,z")
}

///|
test "series worker distinguishes None and exceptions then recovers" {
  let none_rejected = try {
    sympy_normalize_str("None") |> ignore
    false
  } catch {
    _ => true
  }
  let source_rejected = try {
    sympy_simplify_str("(") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(none_rejected)
  assert_true(source_rejected)
  assert_eq(sympy_normalize_str("2 + 2"), "4")
}

///|
test "series worker treats singleton-like variable names as literal symbols" {
  assert_eq(difference_delta_str(Symbol("x"), "Reals"), "0")
  assert_eq(residue_str(Symbol("x"), "EmptySet", @symcore.int(0)), "0")
}

///|
test "series worker preserves Pade and FPS positional contracts" {
  let x = @symcore.Expr::Symbol("x")
  let exponential = @symcore.function("exp", [x])
  assert_true(
    sympy_equiv_str(
      pade_approximant_str(exponential, "x", @symcore.int(0), 2),
      "(x**2/4 + 3*x/2 + 3)/(x**2/4 - 3*x/2 + 3)",
    ),
  )
  assert_true(
    sympy_equiv_str(
      pade_approximant_str(exponential, "x", @symcore.int(0), 1, n=3),
      "(24*x + 96)/(-4*x**3 + 24*x**2 - 72*x + 96)",
    ),
  )
  assert_eq(
    fps_slice_str(exponential, "x", @symcore.int(0), 0, 6, step=2),
    "[1, x**2/2, x**4/24]",
  )
}
