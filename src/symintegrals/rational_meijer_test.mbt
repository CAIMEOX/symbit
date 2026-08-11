///|
test "symintegrals rationaltools public helpers cover simple rational descriptors" {
  let x = @symcore.Expr::Symbol("x")
  let t = @symcore.Expr::Symbol("t")
  guard ratint_ratpart(@symcore.int(1), x + @symcore.int(1), "x") is Some(parts) else {
    fail("expected rational/log split")
  }
  assert_true(@symcore.compare_expr(parts.0, @symcore.int(0)) == 0)
  let reciprocal = (x + @symcore.int(1)) ^ @symcore.int(-1)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(parts.1 - reciprocal),
      @symcore.int(0),
    ) ==
    0,
  )

  let atan_value = log_to_atan(x, @symcore.int(1))
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(atan_value - @symcore.int(2) * @symelem.atan(x)),
      @symcore.int(0),
    ) ==
    0,
  )

  guard log_to_real(x + t, @symcore.int(-2) * t + @symcore.int(1), x, t)
    is Some(real_value) else {
    fail("expected real log conversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        real_value -
        @symcore.rational_from_ints(1, 2) *
        @symelem.log(x + @symcore.rational_from_ints(1, 2)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals inverse Laplace rational fallback square quadratic kernels" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let plus_quad = (s ^ @symcore.int(2)) + @symcore.int(4)
  let minus_quad = (s ^ @symcore.int(2)) - @symcore.int(4)

  guard do_inverse_laplace_doit(
      (s ^ @symcore.int(2)) * (plus_quad ^ @symcore.int(-2)),
      s,
      t,
    )
    is Some(square_plus) else {
    fail("expected inverse for s**2/(s**2 + 4)**2")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        square_plus -
        @symspec.heaviside(t) *
        (
          @symcore.rational_from_ints(1, 2) *
          t *
          @symelem.cos(@symcore.int(2) * t) +
          @symcore.rational_from_ints(1, 4) * @symelem.sin(@symcore.int(2) * t)
        ),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard do_inverse_laplace_doit(
      (s ^ @symcore.int(2)) * (minus_quad ^ @symcore.int(-2)),
      s,
      t,
    )
    is Some(square_minus) else {
    fail("expected inverse for s**2/(s**2 - 4)**2")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        square_minus -
        @symspec.heaviside(t) *
        (
          @symcore.rational_from_ints(1, 2) *
          t *
          @symelem.cosh(@symcore.int(2) * t) +
          @symcore.rational_from_ints(1, 4) * @symelem.sinh(@symcore.int(2) * t)
        ),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard do_inverse_laplace_doit(
      (s ^ @symcore.int(-2)) *
      (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      t,
    )
    is Some(symbol_square_plus) else {
    fail("expected inverse for 1/(s**2*(s**2 + 1))")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        symbol_square_plus - @symspec.heaviside(t) * (t - @symelem.sin(t)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard do_inverse_laplace_doit(
      (s ^ @symcore.int(-2)) * (minus_quad ^ @symcore.int(-1)),
      s,
      t,
    )
    is Some(symbol_square_minus) else {
    fail("expected inverse for 1/(s**2*(s**2 - 4))")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        symbol_square_minus -
        @symspec.heaviside(t) *
        (
          @symcore.rational_from_ints(1, 8) * @symelem.sinh(@symcore.int(2) * t) -
          @symcore.rational_from_ints(1, 4) * t
        ),
      ),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals inverse Laplace special table erf kernel" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let kernel = @symelem.exp(
      (s ^ @symcore.int(2)) * @symcore.rational_from_ints(1, 16),
    ) *
    @symspec.erfc(s * @symcore.rational_from_ints(1, 4)) *
    (s ^ @symcore.int(-1))

  guard do_inverse_laplace_doit(kernel, s, t) is Some(erf_value) else {
    fail("expected inverse for exp(s**2/16)*erfc(s/4)/s")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        erf_value - @symspec.heaviside(t) * @symspec.erf(@symcore.int(2) * t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard do_inverse_laplace_doit(@symcore.int(5) * kernel, s, t)
    is Some(scaled_erf_value) else {
    fail("expected scaled inverse for exp(s**2/16)*erfc(s/4)/s")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        scaled_erf_value -
        @symcore.int(5) *
        @symspec.heaviside(t) *
        @symspec.erf(@symcore.int(2) * t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals inverse Laplace integration sqrt exponential over s" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let kernel = @symelem.exp(@symcore.int(-1) * @symelem.sqrt(s)) *
    (s ^ @symcore.int(-1))

  guard do_inverse_laplace_doit(kernel, s, t) is Some(value) else {
    fail("expected inverse for exp(-sqrt(s))/s")
  }
  let expected = @symspec.heaviside(t) *
    (
      @symcore.int(1) -
      @symspec.erf((@symcore.int(2) * @symelem.sqrt(t)) ^ @symcore.int(-1))
    )
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(value - expected),
      @symcore.int(0),
    ) ==
    0,
  )

  let scaled_kernel = @symelem.exp(@symcore.int(-2) * @symelem.sqrt(s)) *
    (s ^ @symcore.int(-1))
  guard do_inverse_laplace_doit(scaled_kernel, s, t) is Some(scaled_value) else {
    fail("expected inverse for exp(-2*sqrt(s))/s")
  }
  let scaled_expected = @symspec.heaviside(t) *
    (@symcore.int(1) - @symspec.erf(@symelem.sqrt(t) ^ @symcore.int(-1)))
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(scaled_value - scaled_expected),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals inverse Laplace Bateman irrational s three halves form" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  guard do_inverse_laplace_doit(
      @symcore.int(4) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-1)) *
      (s ^ @symcore.rational_from_ints(-3, 2)),
      s,
      t,
    )
    is Some(value) else {
    fail("expected inverse for 4/(s**(3/2)*(sqrt(s) + 2))")
  }
  let expected = @symspec.heaviside(t) *
    (
      @symcore.int(4) *
      @symelem.sqrt(t) *
      (@symelem.sqrt(NumberSymbol(Pi)) ^ @symcore.int(-1)) +
      @symelem.exp(@symcore.int(4) * t) *
      @symspec.erfc(@symcore.int(2) * @symelem.sqrt(t)) -
      @symcore.int(1)
    )
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(value - expected),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals inverse Laplace Gaussian erfc kernel" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let pi = @symcore.Expr::NumberSymbol(Pi)
  let kernel = @symcore.rational_from_ints(1, 4) *
    @symelem.sqrt(pi) *
    @symelem.exp((s ^ @symcore.int(2)) * @symcore.rational_from_ints(1, 16)) *
    @symspec.erfc(s * @symcore.rational_from_ints(1, 4))
  guard do_inverse_laplace_doit(kernel, s, t) is Some(value) else {
    fail("expected inverse for Gaussian erfc kernel")
  }
  let expected = @symspec.heaviside(t) *
    @symelem.exp(@symcore.int(-4) * (t ^ @symcore.int(2)))
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(value - expected),
      @symcore.int(0),
    ) ==
    0,
  )
  guard do_inverse_laplace_doit(
      @symelem.exp(@symcore.int(-2) * s) * kernel,
      s,
      t,
    )
    is Some(delayed_value) else {
    fail("expected delayed inverse for Gaussian erfc kernel")
  }
  let shifted_t = t - @symcore.int(2)
  let delayed_expected = @symspec.heaviside(shifted_t) *
    @symelem.exp(@symcore.int(-4) * (shifted_t ^ @symcore.int(2)))
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(delayed_value - delayed_expected),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals inverse Laplace symbolic Bessel branch kernels" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let plus_root = @symelem.sqrt((s ^ @symcore.int(2)) + (a ^ @symcore.int(2)))
  let minus_root = @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2)))

  let j_kernel = (a ^ b) *
    ((s + plus_root) ^ (@symcore.int(-1) * b)) *
    (plus_root ^ @symcore.int(-1))
  guard do_inverse_laplace_doit(j_kernel, s, t) is Some(j_value) else {
    fail("expected inverse for symbolic besselj branch kernel")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        j_value - @symspec.heaviside(t) * @symspec.besselj(b, a * t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  let i_kernel = (a ^ b) *
    ((s + minus_root) ^ (@symcore.int(-1) * b)) *
    (minus_root ^ @symcore.int(-1))
  guard do_inverse_laplace_doit(i_kernel, s, t) is Some(i_value) else {
    fail("expected inverse for symbolic besseli branch kernel")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        i_value - @symspec.heaviside(t) * @symspec.besseli(b, a * t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals meijer public helpers delegate to local special integrator" {
  let x = @symcore.Expr::Symbol("x")
  guard meijerint_indefinite(@symelem.sin(x) * (x ^ @symcore.int(-1)), x)
    is Some(si_value) else {
    fail("expected sine integral result")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(si_value - @symspec.si(x)),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals meijer inversion smoke cases follow SymPy source tests" {
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let z = @symcore.Expr::Symbol("z")
  let imag = @symcore.Expr::NumberSymbol(ImaginaryUnit)
  let pi = @symcore.Expr::NumberSymbol(Pi)

  guard meijerint_inversion(
      ((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      t,
    )
    is Some(sin_value) else {
    fail("expected inverse of 1/(s**2 + 1)")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(sin_value - @symelem.sin(t) * @symspec.heaviside(t)),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      s * (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      t,
    )
    is Some(cos_value) else {
    fail("expected inverse of s/(s**2 + 1)")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(cos_value - @symelem.cos(t) * @symspec.heaviside(t)),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(@symelem.exp(@symcore.int(-1) * s), s, t)
    is Some(delayed_delta) else {
    fail("expected inverse of exp(-s)")
  }
  assert_true(
    @symcore.compare_expr(
      delayed_delta,
      @symcore.raw_function("DiracDelta", [t - @symcore.int(1)]),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symelem.exp(@symcore.int(1) + @symcore.int(-1) * s),
      s,
      t,
    )
    is Some(offset_delayed_delta) else {
    fail("expected inverse of exp(1 - s)")
  }
  assert_true(
    @symcore.compare_expr(
      offset_delayed_delta,
      @symelem.exp(@symcore.int(1)) *
      @symcore.raw_function("DiracDelta", [t - @symcore.int(1)]),
    ) ==
    0,
  )

  guard meijerint_inversion(@symelem.exp(@symcore.int(2) * s), s, t)
    is Some(advanced_delta) else {
    fail("expected inverse of exp(2*s)")
  }
  assert_true(
    @symcore.compare_expr(
      advanced_delta,
      @symcore.raw_function("DiracDelta", [t + @symcore.int(2)]),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symcore.int(3) * @symelem.exp(@symcore.int(2) * s),
      s,
      t,
    )
    is Some(scaled_advanced_delta) else {
    fail("expected inverse of 3*exp(2*s)")
  }
  assert_true(
    @symcore.compare_expr(
      scaled_advanced_delta,
      @symcore.int(3) *
      @symcore.raw_function("DiracDelta", [t + @symcore.int(2)]),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symelem.exp(s) * @symelem.exp(@symcore.int(2) * s),
      s,
      t,
    )
    is Some(combined_shift_delta) else {
    fail("expected inverse of exp(s)*exp(2*s)")
  }
  assert_true(
    @symcore.compare_expr(
      combined_shift_delta,
      @symcore.raw_function("DiracDelta", [t + @symcore.int(3)]),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symelem.exp(@symcore.int(-1) * s) * (s ^ @symcore.int(-1)),
      s,
      t,
    )
    is Some(delayed_value) else {
    fail("expected inverse of exp(-s)/s")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        delayed_value - @symspec.heaviside(t - @symcore.int(1)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(@symelem.exp(s) * (s ^ @symcore.int(-1)), s, t)
    is Some(advanced_value) else {
    fail("expected inverse of exp(s)/s")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        advanced_value - @symspec.heaviside(t + @symcore.int(1)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symelem.exp(@symcore.int(2) * s) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      t,
    )
    is Some(advanced_shifted_pole) else {
    fail("expected inverse of exp(2*s)/(s + 1)")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        advanced_shifted_pole -
        @symelem.exp(@symcore.int(-1) * (t + @symcore.int(2))) *
        @symspec.heaviside(t + @symcore.int(2)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  match
    meijerint_inversion(
      @symelem.exp(s) + @symelem.exp(@symcore.int(2) * s),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected source-dependent Add rejection")
  }
  match
    meijerint_inversion(
      (s ^ @symcore.int(-1)) + ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected rational Add rejection")
  }

  guard meijerint_inversion(
      @symelem.sqrt(@symcore.int(1) + (s ^ @symcore.int(2))) ^ @symcore.int(-1),
      s,
      t,
    )
    is Some(bessel_value) else {
    fail("expected inverse of 1/sqrt(1 + s**2)")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        bessel_value -
        @symspec.besselj(@symcore.int(0), t) * @symspec.heaviside(t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard do_inverse_laplace_doit(
      @symelem.sqrt(@symcore.int(8) + @symcore.int(2) * (s ^ @symcore.int(2))) ^
      @symcore.int(-1),
      s,
      t,
    )
    is Some(scaled_bessel_value) else {
    fail("expected inverse of 1/sqrt(2*s**2 + 8)")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        scaled_bessel_value -
        (@symelem.sqrt(@symcore.int(2)) ^ @symcore.int(-1)) *
        @symspec.besselj(@symcore.int(0), @symcore.int(2) * t) *
        @symspec.heaviside(t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg([@symcore.int(0)], [], [], [], s),
      s,
      t,
    )
    is Some(explicit_g_bessel) else {
    fail("expected explicit single-G bessel inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_bessel -
        @symspec.besselj(@symcore.int(0), @symcore.int(2) * @symelem.sqrt(t)) *
        @symspec.heaviside(t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [@symcore.int(0)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_exp) else {
    fail("expected explicit single-G exponential inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_exp -
        @symcore.rational_from_ints(1, 2) *
        @symelem.exp(@symcore.rational_from_ints(-1, 2) * t) *
        @symspec.heaviside(t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [@symcore.int(2)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_laguerre) else {
    fail("expected explicit single-G Laguerre inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_laguerre -
        (
          @symcore.int(1) -
          t +
          @symcore.rational_from_ints(1, 8) * (t ^ @symcore.int(2))
        ) *
        @symelem.exp(@symcore.rational_from_ints(-1, 2) * t) *
        @symspec.heaviside(t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [@symcore.rational_from_ints(-1, 2)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_b1_neg_half) else {
    fail("expected explicit single-G b1=-1/2 Bessel-I inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_b1_neg_half -
        @symelem.sqrt(NumberSymbol(Pi)) *
        @symelem.exp(@symcore.rational_from_ints(-1, 4) * t) *
        @symspec.besseli(@symcore.int(0), @symcore.rational_from_ints(1, 4) * t) *
        (@symcore.int(2) ^ @symcore.int(-1)) *
        @symspec.heaviside(t),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.int(0)],
        [],
        [],
        [@symcore.rational_from_ints(1, 2)],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_b2_pos_half) else {
    fail("expected explicit single-G b2=1/2 Bessel-I inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_b2_pos_half -
        ({
          let sqrt_pi_expr = @symelem.sqrt(NumberSymbol(Pi))
          let denominator_inverse = (@symcore.int(4) * sqrt_pi_expr) ^
            @symcore.int(-1)
          let i0 = @symspec.besseli(
            @symcore.int(0),
            @symcore.rational_from_ints(1, 4) * t,
          )
          let i1 = @symspec.besseli(
            @symcore.int(1),
            @symcore.rational_from_ints(1, 4) * t,
          )
          @symcore.int(-1) *
          @symelem.exp(@symcore.rational_from_ints(1, 4) * t) *
          (
            (@symcore.int(1) + @symcore.rational_from_ints(1, 2) * t) * i0 +
            @symcore.rational_from_ints(1, 2) * t * i1
          ) *
          denominator_inverse *
          @symspec.heaviside(t)
        }),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  let j_arg = @symcore.int(2) *
    @symelem.sqrt(t) *
    (@symelem.sqrt(@symcore.int(2)) ^ @symcore.int(-1))
  let sqrt_pi_expr = @symelem.sqrt(NumberSymbol(Pi))
  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.rational_from_ints(-1, 2)],
        [],
        [],
        [],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_a1_neg_half) else {
    fail("expected explicit single-G a1=-1/2 sine inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_a1_neg_half -
        @symspec.heaviside(t) *
        @symelem.sin(j_arg) *
        ((@symcore.int(2) * sqrt_pi_expr) ^ @symcore.int(-1)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.int(0)],
        [@symcore.int(0)],
        [@symcore.int(1)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_a2_zero_b1_one) else {
    fail("expected explicit single-G a2=0,b1=1 Bessel-J inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_a2_zero_b1_one -
        @symspec.heaviside(t) *
        (
          @symcore.rational_from_ints(1, 2) *
          @symspec.besselj(@symcore.int(0), j_arg) -
          @symcore.rational_from_ints(1, 2) *
          @symelem.sqrt(t) *
          (@symelem.sqrt(@symcore.int(2)) ^ @symcore.int(-1)) *
          @symspec.besselj(@symcore.int(1), j_arg)
        ),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.int(0)],
        [@symcore.rational_from_ints(1, 2)],
        [@symcore.int(0)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_a2_pos_half_b1_zero) else {
    fail("expected explicit single-G a2=1/2,b1=0 sine-over-root inversion")
  }
  let sine_over_root_scale = (
      sqrt_pi_expr * @symelem.sqrt(@symcore.int(2)) * @symelem.sqrt(t)
    ) ^
    @symcore.int(-1)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_a2_pos_half_b1_zero -
        @symspec.heaviside(t) * @symelem.sin(j_arg) * sine_over_root_scale,
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symspec.meijerg(
        [@symcore.int(0)],
        [@symcore.rational_from_ints(-1, 2)],
        [@symcore.int(0)],
        [],
        @symcore.int(2) * s,
      ),
      s,
      t,
    )
    is Some(explicit_g_a2_neg_half_b1_zero) else {
    fail("expected explicit single-G a2=-1/2,b1=0 cosine inversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_g_a2_neg_half_b1_zero -
        @symspec.heaviside(t) *
        @symelem.cos(j_arg) *
        ((@symcore.int(2) * sqrt_pi_expr) ^ @symcore.int(-1)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  match meijerint_inversion(@symelem.sqrt(s) ^ @symcore.int(-1), s, t) {
    None => ()
    Some(_) => fail("expected source rejection for 1/sqrt(s)")
  }
  match
    meijerint_inversion(
      @symelem.sqrt(s + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected source rejection for 1/sqrt(s + 1)")
  }
  match
    meijerint_inversion(
      (@symelem.sqrt(s) + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected source rejection for 1/(sqrt(s) + 1)")
  }
  guard meijerint_inversion(s ^ @symcore.rational_from_ints(-3, 2), s, t)
    is Some(three_half_power) else {
    fail("expected source acceptance for s**(-3/2)")
  }
  assert_true(
    !@symcore.has(three_half_power, FunctionHead("InverseLaplaceTransform")),
  )
  assert_true(@symcore.has(three_half_power, FunctionHead("Heaviside")))

  let base_power_cases : Array[(String, Expr)] = [
    ("2**s", @symcore.int(2) ^ s),
    ("2**(-s)", @symcore.int(2) ^ (@symcore.int(-1) * s)),
    ("2**s/s", (@symcore.int(2) ^ s) * (s ^ @symcore.int(-1))),
    (
      "2**(-s)/s",
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) * (s ^ @symcore.int(-1)),
    ),
    (
      "2**s/(s + 1)",
      (@symcore.int(2) ^ s) * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
    ),
    (
      "2**(-s)/(s + 1)",
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
    ),
  ]
  for item in base_power_cases {
    match meijerint_inversion(item.1, s, t) {
      None => ()
      Some(_) =>
        fail("expected source rejection for base-power shift " + item.0)
    }
  }

  match
    meijerint_inversion(
      @symelem.sqrt(s) *
      (
        @symelem.sqrt(@symcore.int(1) + (s ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected antecedent rejection for sqrt(s)/sqrt(1 + s**2)")
  }
  match meijerint_inversion(@symelem.exp(s ^ @symcore.int(2)), s, t) {
    None => ()
    Some(_) => fail("expected antecedent rejection for exp(s**2)")
  }
  match
    meijerint_inversion(
      @symelem.exp(@symcore.int(-1) * (s ^ @symcore.int(2))),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected antecedent rejection for exp(-s**2)")
  }
  match meijerint_inversion(@symelem.exp(imag * s), s, t) {
    None => ()
    Some(_) => fail("expected non-real shift rejection for exp(I*s)")
  }
  match
    meijerint_inversion(
      @symelem.exp((@symcore.int(1) + @symcore.int(2) * imag) * s),
      s,
      t,
    ) {
    None => ()
    Some(_) => fail("expected non-real shift rejection for exp((1+2*I)*s)")
  }
  guard meijerint_inversion(@symelem.exp(z * s), s, t) is Some(symbolic_shift) else {
    fail("expected conditional Piecewise for exp(z*s)")
  }
  assert_true(
    @symcore.compare_expr(
      symbolic_shift,
      @symcore.raw_function("Piecewise", [
        @symcore.raw_function("DiracDelta", [t + z]),
        @symcore.raw_function("Eq", [@symelem.im(z), @symcore.int(0)]),
      ]),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symelem.exp(@symcore.int(2) * s) * @symelem.exp(z * s),
      s,
      t,
    )
    is Some(symbolic_product_shift) else {
    fail("expected conditional Piecewise for exp(2*s)*exp(z*s)")
  }
  assert_true(
    @symcore.compare_expr(
      symbolic_product_shift,
      @symcore.raw_function("Piecewise", [
        @symcore.raw_function("DiracDelta", [t + z + @symcore.int(2)]),
        @symcore.raw_function("Eq", [@symelem.im(z), @symcore.int(0)]),
      ]),
    ) ==
    0,
  )

  match meijerint_inversion(@symelem.exp(s) * @symelem.exp(imag * s), s, t) {
    None => ()
    Some(_) => fail("expected non-real combined shift rejection")
  }

  guard meijerint_inversion(@symelem.exp((z + @symcore.int(2)) * s), s, t)
    is Some(symbolic_real_offset_shift) else {
    fail("expected conditional Piecewise for exp((z + 2)*s)")
  }
  assert_true(
    @symcore.compare_expr(
      symbolic_real_offset_shift,
      @symcore.raw_function("Piecewise", [
        @symcore.raw_function("DiracDelta", [t + z + @symcore.int(2)]),
        @symcore.raw_function("Eq", [@symelem.im(z), @symcore.int(0)]),
      ]),
    ) ==
    0,
  )

  guard meijerint_inversion(
      @symelem.exp((imag * z + @symcore.int(2)) * s),
      s,
      t,
    )
    is Some(symbolic_imag_offset_shift) else {
    fail("expected conditional Piecewise for exp((I*z + 2)*s)")
  }
  assert_true(
    @symcore.compare_expr(
      symbolic_imag_offset_shift,
      @symcore.raw_function("Piecewise", [
        @symcore.raw_function("DiracDelta", [t + imag * z + @symcore.int(2)]),
        @symcore.raw_function("Eq", [@symelem.re(z), @symcore.int(0)]),
      ]),
    ) ==
    0,
  )

  let sqrt_kernel = @symelem.sqrt(pi) *
    (@symelem.sqrt(z) ^ @symcore.int(-1)) *
    @symelem.exp(@symcore.int(-2) * @symelem.sqrt(z) * @symelem.sqrt(s))
  guard meijerint_inversion(sqrt_kernel, s, t) is Some(sqrt_kernel_result) else {
    fail(
      "expected conditional Piecewise for sqrt(pi/z)*exp(-2*sqrt(z)*sqrt(s))",
    )
  }
  let polar_z = @symcore.raw_function("polar_lift", [z])
  let polar_root = @symelem.sqrt(polar_z)
  let quarter_i_pi = imag * pi * (@symcore.int(4) ^ @symcore.int(-1))
  let sqrt_kernel_cond = @symcore.raw_function("And", [
    @symcore.raw_function("Ne", [polar_root, @symcore.int(0)]),
    @symcore.raw_function("Gt", [
      @symelem.re(@symelem.exp(@symcore.int(-1) * quarter_i_pi) * polar_root),
      @symcore.int(0),
    ]),
    @symcore.raw_function("Gt", [
      @symelem.re(@symelem.exp(quarter_i_pi) * polar_root),
      @symcore.int(0),
    ]),
  ])
  assert_true(
    @symcore.compare_expr(
      sqrt_kernel_result,
      @symcore.raw_function("Piecewise", [
        @symelem.exp(@symcore.int(-1) * z * (t ^ @symcore.int(-1))) *
        @symspec.heaviside(t) *
        (t ^ @symcore.rational_from_ints(-3, 2)),
        sqrt_kernel_cond,
        @symcore.raw_function("InverseLaplaceTransform", [
          sqrt_kernel,
          s,
          t,
          Symbol("_None"),
        ]),
        Boolean(true),
      ]),
    ) ==
    0,
  )
}
