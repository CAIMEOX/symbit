///|
test "calculus worker transports exact boundary values and quoted data" {
  let half = @symnum.BigRational::from_ints(1, 2)
  assert_eq(finite_diff_weights_str(0, [half], x0=half), "[[[1]]]")
  assert_eq(
    finite_diff_weights_str(0, [
      @symnum.BigRational::from_int(0),
      @symnum.BigRational::from_int(2),
    ]),
    "[[[1, 0], [1, 0]]]",
  )
  let quoted = @symcore.Expr::Symbol("q'quoted")
  assert_eq(apply_finite_diff_str(0, [half], [quoted], x0=half), "q'quoted")
  assert_eq(sympy_normalize("Symbol(\"q'quoted\")"), "q'quoted")
}

///|
test "calculus worker distinguishes Python None from errors and recovers" {
  let x = @symcore.Expr::Symbol("x")
  let exponential = @symcore.function("exp", [x])
  let invalid_symbol = @symcore.function("sin", [x])
  let rejected = try {
    periodicity_str(exponential, invalid_symbol) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(periodicity_str(exponential, x), "None")
}

///|
test "calculus worker rejects invalid parameters and recovers" {
  let bad_lengths = try {
    apply_finite_diff_str(
      1,
      [@symnum.BigRational::from_int(0), @symnum.BigRational::from_int(1)],
      [@symcore.int(0)],
    )
    |> ignore
    false
  } catch {
    _ => true
  }
  let bad_source = try {
    sympy_normalize("(") |> ignore
    false
  } catch {
    _ => true
  }
  let none_source = try {
    sympy_normalize("None") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(bad_lengths)
  assert_true(bad_source)
  assert_true(none_source)
  assert_eq(sympy_normalize("1 + 1"), "2")
}

///|
test "calculus worker preserves collapsed bounds and list results" {
  assert_eq(
    accum_add(
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(2),
      @symcore.int(2),
    ),
    "3",
  )
  let missing_delta = try {
    accum_delta(@symcore.int(1), @symcore.int(1)) |> ignore
    false
  } catch {
    _ => true
  }
  let missing_mid = try {
    accum_mid(@symcore.int(1), @symcore.int(1)) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(missing_delta)
  assert_true(missing_mid)
  let t = @symcore.Expr::Symbol("t")
  let ft = @symcore.function("f", [t])
  assert_eq(euler_equations_str(@symcore.int(0), [ft], [t]), [])
  let derivative = @symcore.derivative(ft, t)
  let equations = euler_equations_str(
    @symcore.pow(derivative, @symcore.int(2)),
    [],
    [],
  )
  assert_eq(equations.length(), 1)
}

///|
test "calculus worker preserves singularity and constant-period formats" {
  let x = @symcore.Expr::Symbol("x")
  let denominator = @symcore.add([
    @symcore.pow(x, @symcore.int(2)),
    @symcore.int(1),
  ])
  let reciprocal = @symcore.pow(denominator, @symcore.int(-1))
  assert_eq(singularities_str(reciprocal, x), "{-I, I}")
  let infinity : @symcore.Expr = NumberSymbol(Infinity)
  let unsupported = try {
    singularities_str(@symcore.pow(x, infinity), x) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(unsupported)
  assert_eq(periodicity_str(@symcore.int(5), x), "0")
}
