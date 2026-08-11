///|
fn approx_double(lhs : Double, rhs : Double, eps? : Double = 1.0e-4) -> Bool {
  (lhs - rhs).abs() <= eps
}

///|
fn unit_square_polygon() -> @symgeometry.Polygon raise {
  match
    @symgeometry.polygon([
      @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
      @symgeometry.point2d(@symcore.int(0), @symcore.int(1)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(0)),
    ]) {
    @symgeometry.GeometryEntity::Polygon(poly) => poly
    _ => fail("expected polygon from unit square vertices")
  }
}

///|
test "symintegrals integral constructors and doit" {
  let x = @symcore.Expr::Symbol("x")
  inspect(
    @symprint.pretty_string(integral(x, limits=[integral_limit([x])])),
    content="Integral(x, (x,))",
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        doit(integral(x ^ @symcore.int(2), limits=[integral_limit([x])])) -
        @symcore.rational_from_ints(1, 3) * (x ^ @symcore.int(3)),
      ),
      @symcore.int(0),
    ),
    0,
  )
  inspect(
    @symprint.pretty_string(laplace_transform(x, x, @symcore.Expr::Symbol("s"))),
    content="LaplaceTransform(x, x, s)",
  )
}

///|
test "symintegrals Laplace helper utilities align with SymPy helper semantics" {
  let t = @symcore.Expr::Symbol("t")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let y_t = @symcore.raw_function("y", [t])
  let exp_poly = @symelem.exp((t + a) * (t + b))
  let nested = @symspec.besselj(
    @symcore.int(2),
    @symelem.exp((t + a) * (t + b) - (t ^ @symcore.int(2))),
  )
  let deep_collected = @symintegrals._laplace_deep_collect(exp_poly + nested, t)
  let expected_collect = @symelem.exp(
      a * b + (t ^ @symcore.int(2)) + t * (a + b),
    ) +
    @symspec.besselj(@symcore.int(2), @symelem.exp(a * b + t * (a + b)))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(deep_collected - expected_collect),
      @symcore.int(0),
    ),
    0,
  )

  let mut third_deriv = y_t
  for _ in 0..<3 {
    third_deriv = @symcalculus.diff(third_deriv, t)
  }
  let transformed = laplace_transform_eval(third_deriv, t, s, noconds=true)
  let correspondence : Map[String, String] = Map([])
  correspondence["y"] = "Y"
  let transformed_named = @symintegrals.laplace_correspondence(
    transformed, correspondence,
  )
  let initial_conds : Map[String, Array[Expr]] = Map([])
  initial_conds["y"] = [
    @symcore.int(2),
    @symcore.int(4),
    @symcore.int(8),
    @symcore.int(16),
    @symcore.int(32),
  ]
  let with_ics = @symintegrals.laplace_initial_conds(
    transformed_named, t, initial_conds,
  )
  let expected = (s ^ @symcore.int(3)) * @symcore.raw_function("Y", [s]) -
    @symcore.int(2) * (s ^ @symcore.int(2)) -
    @symcore.int(4) * s -
    @symcore.int(8)
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(with_ics - expected),
      @symcore.int(0),
    ),
    0,
  )

  let inverse_named = @symintegrals.laplace_correspondence(
    inverse_laplace_transform(@symcore.raw_function("Y", [s]), s, t),
    correspondence,
  )
  assert_eq(@symcore.compare_expr(inverse_named, y_t), 0)
}

///|
test "symintegrals integrate main entrypoint handles core indefinite families" {
  let x = @symcore.Expr::Symbol("x")
  let int_x = integrate(x, limits=[integral_limit([x])])
  assert_eq(
    @symcore.compare_expr(int_x, @symcore.rational_from_ints(1, 2) * x * x),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        integrate(@symelem.exp(@symcore.int(2) * x), limits=[
          integral_limit([x]),
        ]) -
        @symcore.rational_from_ints(1, 2) * @symelem.exp(@symcore.int(2) * x),
      ),
      @symcore.int(0),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        integrate(@symelem.sin(@symcore.int(3) * x), limits=[
          integral_limit([x]),
        ]) -
        @symcore.rational_from_ints(-1, 3) * @symelem.cos(@symcore.int(3) * x),
      ),
      @symcore.int(0),
    ),
    0,
  )
  inspect(
    @symprint.pretty_string(
      integrate(x ^ @symcore.int(-1), limits=[integral_limit([x])]),
    ),
    content="log(x)",
  )
  inspect(
    @symprint.pretty_string(
      integrate(
        @symelem.sqrt(@symcore.int(1) - (x ^ @symcore.int(2))) ^
        @symcore.int(-1),
        limits=[integral_limit([x])],
      ),
    ),
    content="asin(x)",
  )
  inspect(
    @symprint.pretty_string(
      integrate(
        @symelem.sqrt((x ^ @symcore.int(2)) + @symcore.int(1)) ^
        @symcore.int(-1),
        limits=[integral_limit([x])],
      ),
    ),
    content="asinh(x)",
  )
}

///|
test "symintegrals integrate handles definite delta and rational families" {
  let x = @symcore.Expr::Symbol("x")
  let delta_expr = @symspec.dirac_delta(x - @symcore.int(2)) * x
  inspect(
    @symprint.pretty_string(
      integrate(delta_expr, limits=[
        integral_limit([x, @symcore.int(0), @symcore.int(5)]),
      ]),
    ),
    content="2",
  )
  inspect(
    @symprint.pretty_string(
      integrate(
        @symcore.int(1) *
        (((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
        limits=[integral_limit([x])],
      ),
    ),
    content="atan(x)",
  )
}

///|
test "symintegrals manual heurisch and risch wrappers cover stage 0-3 core" {
  let x = @symcore.Expr::Symbol("x")
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        manualintegrate(@symelem.log(x), x) - (x * @symelem.log(x) - x),
      ),
      @symcore.int(0),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        heurisch_integrate(x * @symelem.exp(x), x) -
        @symelem.exp(x) * (x - @symcore.int(1)),
      ),
      @symcore.int(0),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        risch_integrate(@symelem.sin(x), "x").unwrap() + @symelem.cos(x),
      ),
      @symcore.int(0),
    ),
    0,
  )
  inspect(
    @symprint.pretty_string(
      rde_integrate(
        @symcore.int(1) *
        (((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
        "x",
      ).unwrap(),
    ),
    content="atan(x)",
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        heurisch_wrapper(x * @symelem.exp(x), "x") -
        @symelem.exp(x) * (x - @symcore.int(1)),
      ),
      @symcore.int(0),
    ),
    0,
  )
  let comps = components(
    @symelem.sin(x) * @symelem.exp(x ^ @symcore.int(2)),
    "x",
  )
  inspect(
    if comps.any(fn(item) { @symprint.pretty_string(item) == "x**2" }) {
      "true"
    } else {
      "false"
    },
    content="true",
  )
  inspect(
    if comps.any(fn(item) {
        let text = @symprint.pretty_string(item)
        text == "exp((x**2))" || text == "exp(x**2)"
      }) {
      "true"
    } else {
      "false"
    },
    content="true",
  )
}

///|
test "symintegrals singularity integration keeps symbolic singularity family" {
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  inspect(
    @symprint.pretty_string(
      integrate(@symspec.singularity_function(x, a, @symcore.int(0)), limits=[
        integral_limit([x]),
      ]),
    ),
    content="SingularityFunction(x, a, 1)",
  )
}

///|
test "symintegrals line integrate and delta symbolic bounds keep stage 1 objects usable" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let t = @symcore.Expr::Symbol("t")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symgeometry.curve(
    [@symelem.exp(t) + @symcore.int(1), @symelem.exp(t) + @symcore.int(-1)],
    t,
    @symcore.int(0),
    @symelem.log(@symcore.int(2)),
  )
  inspect(
    @symprint.pretty_string(line_integrate(x + y, c, [x, y])),
    content="3*sqrt(2)",
  )
  inspect(
    if @symprint.pretty_string(
        integrate(@symspec.dirac_delta(x - a) * x, limits=[
          integral_limit([x, @symcore.int(0), b]),
        ]),
      ).contains("Heaviside") {
      "true"
    } else {
      "false"
    },
    content="true",
  )
}

///|
test "symintegrals auxiliary transforms evaluate and stay out of unevaluated objects" {
  let x = @symcore.Expr::Symbol("x")
  let r = @symcore.Expr::Symbol("r")
  let k = @symcore.Expr::Symbol("k")
  let a = @symcore.Expr::Symbol("a")
  let third = @symcore.rational_from_ints(1, 3)
  let two_thirds = @symcore.rational_from_ints(2, 3)
  let shifted_gaussian = @symelem.exp(
    @symcore.int(-1) * ((x - @symcore.int(1)) ^ @symcore.int(2)),
  )
  let cosine_gaussian = @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2)))
  let sine_log_over_x = @symelem.log(x) * (x ^ @symcore.int(-1))
  let sine_gaussian = x * @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2)))
  let cosine_shifted_recip = (x + @symcore.int(2)) ^ @symcore.int(-1)
  let cosine_sqrt_recip = @symelem.sqrt((x ^ @symcore.int(2)) + @symcore.int(4)) ^
    @symcore.int(-1)
  let cosine_sqrt_decay = @symelem.exp(@symcore.int(-2) * @symelem.sqrt(x)) *
    @symelem.cos(@symcore.int(2) * @symelem.sqrt(x))
  let half_line_exp = @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x)
  let half_line_x_exp = x * half_line_exp
  let half_line_sin = @symelem.exp(@symcore.int(-2) * x) *
    @symelem.sin(@symcore.int(3) * x) *
    @symspec.heaviside(x)
  let abs_decay = @symelem.exp(@symcore.int(-2) * @symelem.abs(x))
  let box_window = @symspec.heaviside(
    @symcore.int(1) - @symelem.abs(@symcore.int(2) * x),
  )
  let triangle_window = box_window *
    (@symcore.int(1) - @symelem.abs(@symcore.int(2) * x))
  assert_eq(
    @symprint.pretty_string(sine_transform(x, x, k)),
    "SineTransform(x, x, k)",
  )
  assert_eq(
    @symprint.pretty_string(cosine_transform(x, x, k)),
    "CosineTransform(x, x, k)",
  )
  assert_eq(
    @symprint.pretty_string(hankel_transform(r, r, k, @symcore.int(1))),
    "HankelTransform(r, r, k, 1)",
  )

  let sine_eval = @symprint.pretty_string(
    sine_transform_eval(@symelem.exp(@symcore.int(-2) * x), x, k),
  )
  let cosine_eval = @symprint.pretty_string(
    cosine_transform_eval(@symelem.exp(@symcore.int(-2) * x), x, k),
  )
  let hankel_eval = @symprint.pretty_string(
    hankel_transform_eval(
      r * @symelem.exp(@symcore.int(-2) * r),
      r,
      k,
      @symcore.int(1),
    ),
  )
  let shifted_fourier_eval = @symprint.pretty_string(
    fourier_transform_eval(shifted_gaussian, x, k),
  )
  let shifted_inverse_fourier_eval = @symprint.pretty_string(
    doit(
      inverse_fourier_transform(
        doit(fourier_transform(shifted_gaussian, x, k)),
        k,
        x,
      ),
    ),
  )
  let half_line_fourier_eval = @symprint.pretty_string(
    doit(fourier_transform(half_line_exp, x, k)),
  )
  let half_line_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(half_line_exp, x, k)),
      k,
      x,
    ),
  )
  let half_line_x_fourier_eval = @symprint.pretty_string(
    doit(fourier_transform(half_line_x_exp, x, k)),
  )
  let half_line_x_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(half_line_x_exp, x, k)),
      k,
      x,
    ),
  )
  let half_line_sin_fourier_eval = @symprint.pretty_string(
    doit(fourier_transform(half_line_sin, x, k)),
  )
  let half_line_sin_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(half_line_sin, x, k)),
      k,
      x,
    ),
  )
  let abs_decay_fourier_eval = @symprint.pretty_string(
    doit(fourier_transform(abs_decay, x, k)),
  )
  let abs_decay_inverse_fourier = doit(
    inverse_fourier_transform(doit(fourier_transform(abs_decay, x, k)), k, x),
  )
  let symbolic_half_line_fourier_eval = @symprint.pretty_string(
    doit(
      fourier_transform(
        @symelem.exp(@symcore.int(-1) * a * x) * @symspec.heaviside(x),
        x,
        k,
      ),
    ),
  )
  let box_window_fourier_eval = @symprint.pretty_string(
    doit(fourier_transform(box_window, x, k)),
  )
  let box_window_inverse_fourier = doit(
    inverse_fourier_transform(doit(fourier_transform(box_window, x, k)), k, x),
  )
  let triangle_window_fourier_eval = @symprint.pretty_string(
    doit(fourier_transform(triangle_window, x, k)),
  )
  let triangle_window_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(triangle_window, x, k)),
      k,
      x,
    ),
  )
  let triangle_window_inverse_fourier_eval = @symprint.pretty_string(
    triangle_window_inverse_fourier,
  )
  let direct_sinc_box = doit(
    inverse_fourier_transform(
      two_thirds * @symelem.sinc(@symcore.int(2) * k * third),
      k,
      x,
    ),
  )
  let direct_sinc_triangle = doit(
    inverse_fourier_transform(
      third * (@symelem.sinc(k * third) ^ @symcore.int(2)),
      k,
      x,
    ),
  )
  let symbolic_sinc_box = doit(
    inverse_fourier_transform(
      (a ^ @symcore.int(-1)) * @symelem.sinc(k * (a ^ @symcore.int(-1))),
      k,
      x,
    ),
  )
  let symbolic_sinc_triangle = doit(
    inverse_fourier_transform(
      (a ^ @symcore.int(-1)) *
      (@symelem.sinc(k * (a ^ @symcore.int(-1))) ^ @symcore.int(2)),
      k,
      x,
    ),
  )
  let symbolic_sinc_box_eval = @symprint.pretty_string(symbolic_sinc_box)
  let symbolic_sinc_triangle_eval = @symprint.pretty_string(
    symbolic_sinc_triangle,
  )
  let symbolic_cosine_gaussian_eval = @symprint.pretty_string(
    doit(
      cosine_transform(
        @symelem.exp(@symcore.int(-1) * a * (x ^ @symcore.int(2))),
        x,
        k,
      ),
    ),
  )
  let cosine_shifted_recip_eval = @symprint.pretty_string(
    doit(cosine_transform(cosine_shifted_recip, x, k)),
  )
  let cosine_sqrt_recip_eval = @symprint.pretty_string(
    doit(cosine_transform(cosine_sqrt_recip, x, k)),
  )
  let sine_half_power_eval = @symprint.pretty_string(
    doit(sine_transform(@symelem.sqrt(x) ^ @symcore.int(-1), x, k)),
  )
  let inverse_sine_half_power_eval = @symprint.pretty_string(
    doit(inverse_sine_transform(@symelem.sqrt(k) ^ @symcore.int(-1), k, x)),
  )
  let sine_three_halves_eval = @symprint.pretty_string(
    doit(
      sine_transform(
        @symelem.sqrt(x) ^ @symcore.int(-1) ^ @symcore.int(3),
        x,
        k,
      ),
    ),
  )
  let sine_gaussian_eval = @symprint.pretty_string(
    doit(sine_transform(sine_gaussian, x, k)),
  )
  let inverse_sine_gaussian_eval = @symprint.pretty_string(
    doit(
      inverse_sine_transform(doit(sine_transform(sine_gaussian, x, k)), k, x),
    ),
  )
  let cosine_gaussian_eval = @symprint.pretty_string(
    cosine_transform_eval(cosine_gaussian, x, k),
  )
  let inverse_cosine_gaussian_eval = @symprint.pretty_string(
    doit(
      inverse_cosine_transform(
        doit(cosine_transform(cosine_gaussian, x, k)),
        k,
        x,
      ),
    ),
  )
  let inverse_cosine_sqrt_recip_eval = @symprint.pretty_string(
    doit(
      inverse_cosine_transform(
        doit(cosine_transform(cosine_sqrt_recip, x, k)),
        k,
        x,
      ),
    ),
  )
  let sine_log_over_x_eval = @symprint.pretty_string(
    doit(sine_transform(sine_log_over_x, x, k)),
  )
  let cosine_sqrt_decay_eval = @symprint.pretty_string(
    doit(cosine_transform(cosine_sqrt_decay, x, k)),
  )
  let hankel_gaussian_eval = @symprint.pretty_string(
    hankel_transform_eval(
      @symelem.exp(@symcore.int(-2) * (r ^ @symcore.int(2))),
      r,
      k,
      @symcore.int(0),
    ),
  )
  let inverse_hankel_gaussian_eval = @symprint.pretty_string(
    doit(
      inverse_hankel_transform(
        doit(
          hankel_transform(
            @symelem.exp(@symcore.int(-2) * (r ^ @symcore.int(2))),
            r,
            k,
            @symcore.int(0),
          ),
        ),
        k,
        r,
        @symcore.int(0),
      ),
    ),
  )
  assert_true(!sine_eval.contains("SineTransform"))
  assert_true(!cosine_eval.contains("CosineTransform"))
  assert_true(!hankel_eval.contains("HankelTransform"))
  assert_true(!shifted_fourier_eval.contains("FourierTransform"))
  assert_true(!shifted_inverse_fourier_eval.contains("InverseFourierTransform"))
  assert_true(!half_line_fourier_eval.contains("FourierTransform"))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(half_line_inverse_fourier),
      @symsimplify.simplify(half_line_exp),
    ),
    0,
  )
  assert_true(!half_line_x_fourier_eval.contains("FourierTransform"))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(half_line_x_inverse_fourier),
      @symsimplify.simplify(half_line_x_exp),
    ),
    0,
  )
  assert_true(!half_line_sin_fourier_eval.contains("FourierTransform"))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(half_line_sin_inverse_fourier),
      @symsimplify.simplify(half_line_sin),
    ),
    0,
  )
  assert_true(!abs_decay_fourier_eval.contains("FourierTransform"))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(abs_decay_inverse_fourier),
      @symsimplify.simplify(abs_decay),
    ),
    0,
  )
  assert_true(!symbolic_half_line_fourier_eval.contains("FourierTransform"))
  assert_true(!box_window_fourier_eval.contains("FourierTransform"))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(box_window_inverse_fourier),
      @symsimplify.simplify(box_window),
    ),
    0,
  )
  assert_true(!triangle_window_fourier_eval.contains("FourierTransform"))
  assert_true(
    !triangle_window_inverse_fourier_eval.contains("InverseFourierTransform"),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(triangle_window_inverse_fourier),
      @symsimplify.simplify(triangle_window),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(direct_sinc_box),
      @symsimplify.simplify(
        @symspec.heaviside(@symcore.int(1) - @symelem.abs(@symcore.int(3) * x)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(direct_sinc_triangle),
      @symsimplify.simplify(
        @symspec.heaviside(@symcore.int(1) - @symelem.abs(@symcore.int(3) * x)) *
        (@symcore.int(1) - @symelem.abs(@symcore.int(3) * x)),
      ),
    ),
    0,
  )
  assert_true(!symbolic_sinc_box_eval.contains("InverseFourierTransform"))
  assert_true(!symbolic_sinc_triangle_eval.contains("InverseFourierTransform"))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(symbolic_sinc_box),
      @symsimplify.simplify(
        @symspec.heaviside(
          @symcore.int(1) - @symelem.abs(@symcore.int(2) * a * x),
        ),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(symbolic_sinc_triangle),
      @symsimplify.simplify(
        @symspec.heaviside(@symcore.int(1) - @symelem.abs(a * x)) *
        (@symcore.int(1) - @symelem.abs(a * x)),
      ),
    ),
    0,
  )
  assert_true(!symbolic_cosine_gaussian_eval.contains("CosineTransform"))
  assert_true(!cosine_shifted_recip_eval.contains("CosineTransform"))
  assert_true(!cosine_sqrt_recip_eval.contains("CosineTransform"))
  assert_true(!sine_half_power_eval.contains("SineTransform"))
  assert_true(!inverse_sine_half_power_eval.contains("InverseSineTransform"))
  assert_true(!sine_three_halves_eval.contains("SineTransform"))
  assert_true(!sine_gaussian_eval.contains("SineTransform"))
  assert_true(!inverse_sine_gaussian_eval.contains("InverseSineTransform"))
  assert_true(!cosine_gaussian_eval.contains("CosineTransform"))
  assert_true(!inverse_cosine_gaussian_eval.contains("InverseCosineTransform"))
  assert_true(
    !inverse_cosine_sqrt_recip_eval.contains("InverseCosineTransform"),
  )
  assert_true(!sine_log_over_x_eval.contains("SineTransform"))
  assert_true(!cosine_sqrt_decay_eval.contains("CosineTransform"))
  assert_true(!hankel_gaussian_eval.contains("HankelTransform"))
  assert_true(!inverse_hankel_gaussian_eval.contains("InverseHankelTransform"))
}

///|
test "symintegrals Mellin special-function rules evaluate" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let bp = @symcore.Expr::Symbol("bp")
  let rho = @symcore.Expr::Symbol("rho")
  let f_of_x = @symcore.raw_function("f", [x])
  let half = @symcore.rational_from_ints(1, 2)

  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform((x + @symcore.int(1)) ^ (@symcore.int(-1) * rho), x, s),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          ((@symcore.int(1) - x) ^ (b - @symcore.int(1))) *
          @symspec.heaviside(@symcore.int(1) - x),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          ((x - @symcore.int(1)) ^ (b - @symcore.int(1))) *
          @symspec.heaviside(x - @symcore.int(1)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(mellin_transform(@symspec.erf(@symelem.sqrt(x)), x, s)),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symelem.abs(@symcore.int(1) - x) ^ (@symcore.int(-1) * rho),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          (@symelem.log(x) ^ @symcore.int(4)) *
          @symspec.heaviside(@symcore.int(1) - x),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          (@symelem.log(x) ^ @symcore.int(3)) *
          @symspec.heaviside(x - @symcore.int(1)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(mellin_transform(@symelem.log(x + @symcore.int(1)), x, s)),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symelem.log((x ^ @symcore.int(-1)) + @symcore.int(1)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          ((x ^ a) - (bp ^ a)) * ((x - bp) ^ @symcore.int(-1)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  let sqrt_shift = @symelem.sqrt(x + (bp ^ @symcore.int(2))) + bp
  assert_true(
    !@symprint.pretty_string(doit(mellin_transform(sqrt_shift ^ a, x, s))).contains(
      "MellinTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          (sqrt_shift ^ a) *
          (@symelem.sqrt(x + (bp ^ @symcore.int(2))) ^ @symcore.int(-1)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(@symelem.log(@symelem.abs(@symcore.int(1) - x)), x, s),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symelem.log(@symelem.abs(@symcore.int(1) - (x ^ @symcore.int(-1)))),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(doit(mellin_transform(@symspec.e1(x), x, s))).contains(
      "MellinTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(mellin_transform(@symspec.expint(@symcore.int(2), x), x, s)),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(doit(mellin_transform(@symspec.si(x), x, s))).contains(
      "MellinTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(mellin_transform(@symspec.ci(@symelem.sqrt(x)), x, s)),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselj(a, @symcore.int(2) * @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.bessely(a, @symcore.int(2) * @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselk(a, @symcore.int(2) * @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besseli(a, @symelem.sqrt(x)) *
          @symspec.besselk(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselj(a, @symelem.sqrt(x)) ^ @symcore.int(2),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselj(a, @symelem.sqrt(x)) *
          @symspec.besselj(@symcore.int(-1) * a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselj(a, @symelem.sqrt(x)) *
          @symspec.bessely(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselj(a, @symelem.sqrt(x)) *
          @symspec.besselj(b, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselj(a - @symcore.int(1), @symelem.sqrt(x)) *
          @symspec.besselj(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besselj(a, @symelem.sqrt(x)) *
          @symspec.bessely(b, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symspec.besseli(b, @symelem.sqrt(x)) *
          @symspec.besselk(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symelem.sin(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symelem.cos(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symelem.sin(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        mellin_transform(
          @symelem.cos(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
          x,
          s,
        ),
      ),
    ).contains("MellinTransform"),
  )

  let generic_mellin_eval = @symprint.pretty_string(
    mellin_transform_eval(f_of_x, x, s),
  )
  assert_true(generic_mellin_eval.contains("MellinTransform(f(x), x, s)"))

  let partial_generic_mellin_eval = @symprint.pretty_string(
    mellin_transform_eval(f_of_x + @symelem.exp(@symcore.int(-1) * x), x, s),
  )
  assert_true(
    partial_generic_mellin_eval.contains("MellinTransform(f(x), x, s)") &&
    partial_generic_mellin_eval.contains("gamma(s)"),
  )

  let inv_e1 = doit(
    inverse_mellin_transform(@symspec.gamma(s) * (s ^ @symcore.int(-1)), s, x),
  )
  let inv_gamma_shift = doit(
    inverse_mellin_transform(@symspec.gamma(s - @symcore.int(1)), s, x),
  )
  let inv_gamma_sum = doit(
    inverse_mellin_transform(
      @symspec.gamma(s) + @symspec.gamma(s - @symcore.int(1)),
      s,
      x,
    ),
  )
  let inv_beta_left = doit(
    inverse_mellin_transform(
      @symspec.gamma(b) *
      @symspec.gamma(s) *
      (@symspec.gamma(s + b) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_beta_right = doit(
    inverse_mellin_transform(
      @symspec.gamma(b) *
      @symspec.gamma(@symcore.int(1) - b - s) *
      (@symspec.gamma(@symcore.int(1) - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_shifted_power = doit(
    inverse_mellin_transform(
      @symspec.gamma(s) *
      @symspec.gamma(rho - s) *
      (@symspec.gamma(rho) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_expint2 = doit(
    inverse_mellin_transform(
      @symspec.gamma(s) * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_si = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      (
        (@symcore.int(2) ^ s) *
        (
          @symelem.sqrt(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          ) *
          @symspec.gamma((s + @symcore.int(1)) * half)
        )
      ) *
      (
        (@symcore.int(2) * (s * @symspec.gamma(@symcore.int(1) - s * half))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_ci_sqrt = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      (
        (@symcore.int(2) ^ (@symcore.int(2) * s - @symcore.int(1))) *
        (
          @symelem.sqrt(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          ) *
          @symspec.gamma(s)
        )
      ) *
      ((s * @symspec.gamma(half - s)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_erf_sqrt = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      @symspec.gamma(s + half) *
      (
        (
          @symelem.sqrt(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          ) *
          s
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_log_left = doit(
    inverse_mellin_transform(@symcore.int(24) * (s ^ @symcore.int(-5)), s, x),
  )
  let inv_log_right = doit(
    inverse_mellin_transform(@symcore.int(6) * (s ^ @symcore.int(-4)), s, x),
  )
  let inv_log_quadratic = doit(
    inverse_mellin_transform(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (
        (
          s *
          @symelem.sin(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
            s *
            half,
          )
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_sec = doit(
    inverse_mellin_transform(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (
        @symelem.cos(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_log_piecewise = doit(
    inverse_mellin_transform(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (
        (
          s *
          @symelem.sin(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
          )
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_sqrt_piecewise = doit(
    inverse_mellin_transform(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (
        (
          s *
          @symelem.sin(
            @symcore.int(2) *
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
            s,
          )
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_tan_piecewise = doit(
    inverse_mellin_transform(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      (
        (
          s *
          @symelem.tan(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
          )
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_cot_piecewise = doit(
    inverse_mellin_transform(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
      @symelem.cot(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
      ) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_besselj = doit(
    inverse_mellin_transform(
      @symspec.gamma(s + a * half) *
      (@symspec.gamma(@symcore.int(1) - s + a * half) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_bessely = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      (
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
        @symcore.int(-1)
      ) *
      @symelem.cos(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
        (a * half - s),
      ) *
      @symspec.gamma(s - a * half) *
      @symspec.gamma(s + a * half),
      s,
      x,
    ),
  )
  let inv_besselk = doit(
    inverse_mellin_transform(
      half * @symspec.gamma(s - a * half) * @symspec.gamma(s + a * half),
      s,
      x,
    ),
  )
  let inv_sin_besselj = doit(
    inverse_mellin_transform(
      (@symcore.int(2) ^ a) *
      @symspec.gamma(half - @symcore.int(2) * s) *
      @symspec.gamma(s + (a + @symcore.int(1)) * half) *
      (@symspec.gamma(@symcore.int(1) - s - a * half) ^ @symcore.int(-1)) *
      (
        @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s + a) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_cos_besselj = doit(
    inverse_mellin_transform(
      (@symcore.int(2) ^ a) *
      @symspec.gamma(a * half + s) *
      @symspec.gamma(half - @symcore.int(2) * s) *
      (@symspec.gamma(half - s - a * half) ^ @symcore.int(-1)) *
      (
        @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s + a) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_sin_bessely = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) ^
        @symcore.int(-1)
      ) *
      (@symcore.int(4) ^ s) *
      @symelem.sin(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
        (a * half - s),
      ) *
      @symspec.gamma(half - @symcore.int(2) * s) *
      @symspec.gamma((@symcore.int(1) - a) * half + s) *
      @symspec.gamma((@symcore.int(1) + a) * half + s) *
      (@symspec.gamma(@symcore.int(1) - s - a * half) ^ @symcore.int(-1)) *
      (@symspec.gamma(@symcore.int(1) - s + a * half) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_cos_bessely = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) ^
        @symcore.int(-1)
      ) *
      (@symcore.int(4) ^ s) *
      @symelem.cos(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
        (a * half - s),
      ) *
      @symspec.gamma(s - a * half) *
      @symspec.gamma(s + a * half) *
      @symspec.gamma(half - @symcore.int(2) * s) *
      (@symspec.gamma(half - s - a * half) ^ @symcore.int(-1)) *
      (@symspec.gamma(half - s + a * half) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_besselj_sq = doit(
    inverse_mellin_transform(
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) ^
        @symcore.int(-1)
      ) *
      @symspec.gamma(a + s) *
      @symspec.gamma(half - s) *
      (@symspec.gamma(@symcore.int(1) - s) ^ @symcore.int(-1)) *
      (@symspec.gamma(@symcore.int(1) + a - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_besselj_pm = doit(
    inverse_mellin_transform(
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) ^
        @symcore.int(-1)
      ) *
      @symspec.gamma(s) *
      @symspec.gamma(half - s) *
      (@symspec.gamma(@symcore.int(1) - s - a) ^ @symcore.int(-1)) *
      (@symspec.gamma(@symcore.int(1) + a - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_besselj_ab = doit(
    inverse_mellin_transform(
      (@symcore.int(4) ^ s) *
      @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s) *
      @symspec.gamma((a + b) * half + s) *
      (@symspec.gamma(@symcore.int(1) + (b - a) * half - s) ^ @symcore.int(-1)) *
      (@symspec.gamma(@symcore.int(1) + (a - b) * half - s) ^ @symcore.int(-1)) *
      (@symspec.gamma(@symcore.int(1) + (a + b) * half - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_besselj_bessely = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      (
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
        @symcore.int(-1)
      ) *
      (@symcore.int(4) ^ s) *
      @symelem.cos(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
        ((a - b) * half + s),
      ) *
      @symspec.gamma(@symcore.int(1) - @symcore.int(2) * s) *
      @symspec.gamma((a - b) * half + s) *
      @symspec.gamma((a + b) * half + s) *
      (@symspec.gamma(@symcore.int(1) + (a - b) * half - s) ^ @symcore.int(-1)) *
      (@symspec.gamma(@symcore.int(1) + (a + b) * half - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_besselj_bessely_same = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      (
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
        @symcore.int(-1)
      ) *
      (
        @symelem.sqrt(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) ^
        @symcore.int(-1)
      ) *
      @symelem.cos(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * s,
      ) *
      @symspec.gamma(s) *
      @symspec.gamma(a + s) *
      @symspec.gamma(half - s) *
      (@symspec.gamma(@symcore.int(1) + a - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_difference_quotient = doit(
    inverse_mellin_transform(
      (bp ^ (a + s - @symcore.int(1))) *
      @symelem.sin(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) * a,
      ) *
      @symspec.gamma(s) *
      @symspec.gamma(a + s) *
      @symspec.gamma(@symcore.int(1) - s) *
      @symspec.gamma(@symcore.int(1) - a - s) *
      (
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_sqrt_shift = doit(
    inverse_mellin_transform(
      @symcore.int(-1) *
      a *
      (@symcore.int(2) ^ (a + @symcore.int(2) * s)) *
      (bp ^ (a + @symcore.int(2) * s)) *
      @symspec.gamma(s) *
      @symspec.gamma(@symcore.int(-1) * (a + @symcore.int(2) * s)) *
      (@symspec.gamma(@symcore.int(1) - a - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_sqrt_shift_recip = doit(
    inverse_mellin_transform(
      (@symcore.int(2) ^ (a + @symcore.int(2) * s)) *
      (bp ^ (a + @symcore.int(2) * s - @symcore.int(1))) *
      @symspec.gamma(s) *
      @symspec.gamma(@symcore.int(1) - a - @symcore.int(2) * s) *
      (@symspec.gamma(@symcore.int(1) - a - s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_exp_subst = doit(
    inverse_mellin_transform(
      @symcore.function("factorial", [s * (a ^ @symcore.int(-1))]) *
      (b ^ (@symcore.int(-1) * s * (a ^ @symcore.int(-1)))) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_xpow_exp_subst = doit(
    inverse_mellin_transform(
      @symcore.function("factorial", [
        a * (b ^ @symcore.int(-1)) + s * (b ^ @symcore.int(-1)),
      ]) *
      ((a + s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )

  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_e1),
      @symsimplify.simplify(@symspec.e1(x)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_gamma_shift),
      @symsimplify.simplify(
        @symelem.exp(@symcore.int(-1) * x) * (x ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_gamma_sum),
      @symsimplify.simplify(
        @symelem.exp(@symcore.int(-1) * x) +
        @symelem.exp(@symcore.int(-1) * x) * (x ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_beta_left),
      @symsimplify.simplify(
        ((@symcore.int(1) - x) ^ (b - @symcore.int(1))) *
        @symspec.heaviside(@symcore.int(1) - x),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_beta_right),
      @symsimplify.simplify(
        ((x - @symcore.int(1)) ^ (b - @symcore.int(1))) *
        @symspec.heaviside(x - @symcore.int(1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_shifted_power),
      @symsimplify.simplify((x + @symcore.int(1)) ^ (@symcore.int(-1) * rho)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_expint2),
      @symsimplify.simplify(@symspec.expint(@symcore.int(2), x)),
    ),
    0,
  )
  assert_eq(
    @symprint.pretty_string(inv_si),
    @symprint.pretty_string(@symspec.si(x)),
  )
  assert_eq(
    @symprint.pretty_string(inv_ci_sqrt),
    @symprint.pretty_string(@symspec.ci(@symelem.sqrt(x))),
  )
  assert_eq(
    @symprint.pretty_string(inv_erf_sqrt),
    @symprint.pretty_string(@symspec.erf(@symelem.sqrt(x))),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_log_left),
      @symsimplify.simplify(
        (@symelem.log(x) ^ @symcore.int(4)) *
        @symspec.heaviside(@symcore.int(1) - x),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_log_right),
      @symsimplify.simplify(
        (@symelem.log(x) ^ @symcore.int(3)) *
        @symspec.heaviside(x - @symcore.int(1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_log_quadratic),
      @symsimplify.simplify(
        @symelem.log((x ^ @symcore.int(2)) + @symcore.int(1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_sec),
      @symsimplify.simplify(
        @symelem.sqrt(x) * ((x + @symcore.int(1)) ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  let log_piecewise_expected = @symelem.log(@symcore.int(1) + x) *
    @symspec.heaviside(@symcore.int(1) - x) +
    @symelem.log(@symcore.int(1) + (x ^ @symcore.int(-1))) *
    @symspec.heaviside(x - @symcore.int(1))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_log_piecewise),
      @symsimplify.simplify(log_piecewise_expected),
    ),
    0,
  )
  let sqrt_piecewise_expected = @symelem.log(@symcore.int(1) + @symelem.sqrt(x)) *
    @symspec.heaviside(@symcore.int(1) - x) +
    @symelem.log(@symcore.int(1) + (@symelem.sqrt(x) ^ @symcore.int(-1))) *
    @symspec.heaviside(x - @symcore.int(1))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_sqrt_piecewise),
      @symsimplify.simplify(sqrt_piecewise_expected),
    ),
    0,
  )
  let tan_piecewise_expected = @symelem.log(@symcore.int(1) - x) *
    @symspec.heaviside(@symcore.int(1) - x) +
    @symelem.log(x - @symcore.int(1)) * @symspec.heaviside(x - @symcore.int(1))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_tan_piecewise),
      @symsimplify.simplify(tan_piecewise_expected),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_cot_piecewise),
      @symsimplify.simplify(tan_piecewise_expected),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_difference_quotient),
      @symsimplify.simplify(
        ((x ^ a) - (bp ^ a)) * ((x - bp) ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  let sqrt_shift_target = @symelem.sqrt(x + (bp ^ @symcore.int(2))) + bp
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_sqrt_shift),
      @symsimplify.simplify(sqrt_shift_target ^ a),
    ),
    0,
  )
  assert_true(@symprint.pretty_string(inv_sqrt_shift_recip).contains("sqrt"))
  assert_true(
    !@symprint.pretty_string(inv_besselj).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_bessely).contains("InverseMellinTransform"),
  )
  assert_true(@symprint.pretty_string(inv_bessely).contains("bessely"))
  assert_true(
    !@symprint.pretty_string(inv_besselk).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_sin_besselj).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_cos_besselj).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_sin_bessely).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_cos_bessely).contains("InverseMellinTransform"),
  )
  assert_true(
    @symprint.pretty_string(inv_sin_bessely).contains("sin") &&
    @symprint.pretty_string(inv_sin_bessely).contains("bessely"),
  )
  assert_true(
    @symprint.pretty_string(inv_cos_bessely).contains("cos") &&
    @symprint.pretty_string(inv_cos_bessely).contains("bessely"),
  )
  assert_true(
    !@symprint.pretty_string(inv_besselj_sq).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_besselj_pm).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_besselj_ab).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_besselj_bessely).contains(
      "InverseMellinTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(inv_besselj_bessely_same).contains(
      "InverseMellinTransform",
    ),
  )
  assert_true(
    @symprint.pretty_string(inv_besselj_bessely_same).contains("besselj") &&
    @symprint.pretty_string(inv_besselj_bessely_same).contains("bessely"),
  )
  assert_true(
    @symprint.pretty_string(inv_besselj_bessely).contains("besselj") &&
    @symprint.pretty_string(inv_besselj_bessely).contains("bessely"),
  )
  assert_true(
    !@symprint.pretty_string(inv_difference_quotient).contains(
      "InverseMellinTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(inv_sqrt_shift).contains("InverseMellinTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_sqrt_shift_recip).contains(
      "InverseMellinTransform",
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_exp_subst),
      @symsimplify.simplify(@symelem.exp(@symcore.int(-1) * b * (x ^ a))),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_xpow_exp_subst),
      @symsimplify.simplify((x ^ a) * @symelem.exp(@symcore.int(-1) * (x ^ b))),
    ),
    0,
  )
}

///|
test "symintegrals Laplace stage 5 shift and derivative rules evaluate" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let np = @symcore.Expr::Symbol("np")
  let y = @symcore.Expr::Symbol("y")
  let f_of_x = @symcore.raw_function("f", [x])
  let g_of_x = @symcore.raw_function("g", [x])

  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        doit(laplace_transform(@symspec.dirac_delta(x - @symcore.int(2)), x, s)) -
        @symelem.exp(@symcore.int(-2) * s),
      ),
      @symcore.int(0),
    ),
    0,
  )
  inspect(
    @symprint.pretty_string(
      doit(
        laplace_transform(
          @symspec.dirac_delta(x * @symcore.rational_from_ints(1, 42)),
          x,
          s,
        ),
      ),
    ),
    content="42",
  )
  let delta_square_eval = doit(
    laplace_transform(
      @symspec.dirac_delta((x ^ @symcore.int(2)) - @symcore.int(1)),
      x,
      s,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      delta_square_eval,
      @symcore.rational_from_ints(1, 2) * @symelem.exp(@symcore.int(-1) * s),
    ),
    0,
  )
  let delta_quad_eval = doit(
    laplace_transform(@symspec.dirac_delta(x * (@symcore.int(1) - x)), x, s),
  )
  assert_eq(
    @symcore.compare_expr(
      delta_quad_eval,
      @symcore.int(1) - @symelem.exp(@symcore.int(-1) * s),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        doit(laplace_transform(@symspec.heaviside(x - @symcore.int(2)), x, s)) -
        @symelem.exp(@symcore.int(-2) * s) * (s ^ @symcore.int(-1)),
      ),
      @symcore.int(0),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      doit(
        laplace_transform(
          @symspec.singularity_function(x, a, @symcore.int(-1)),
          x,
          s,
        ),
      ),
      @symelem.exp(@symcore.int(-1) * a * s),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      doit(
        laplace_transform(
          @symspec.singularity_function(x, a, @symcore.int(0)),
          x,
          s,
        ),
      ),
      @symelem.exp(@symcore.int(-1) * a * s) * (s ^ @symcore.int(-1)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      doit(
        laplace_transform(
          @symspec.singularity_function(x, a, @symcore.int(1)),
          x,
          s,
        ),
      ),
      @symelem.exp(@symcore.int(-1) * a * s) * (s ^ @symcore.int(-2)),
    ),
    0,
  )
  assert_true(
    @symprint.pretty_string(
      laplace_transform_eval(@symspec.singularity_function(x, a, y), x, s),
    ).contains("LaplaceTransform(SingularityFunction(x, a, y), x, s)"),
  )
  assert_eq(
    @symcore.compare_expr(
      doit(
        laplace_transform(
          @symspec.dirac_delta(
            @symcore.int(2) * x - @symcore.int(2) * @symelem.exp(a),
          ),
          x,
          s,
        ),
      ),
      @symcore.rational_from_ints(1, 2) *
      @symelem.exp(@symcore.int(-1) * s * @symelem.exp(a)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      doit(
        laplace_transform(
          @symspec.dirac_delta(
            @symcore.int(-2) * x + @symcore.int(2) * @symelem.exp(a),
          ),
          x,
          s,
        ),
      ),
      @symcore.rational_from_ints(1, 2) *
      @symelem.exp(@symcore.int(-1) * s * @symelem.exp(a)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        doit(
          laplace_transform(
            (x - @symcore.int(2)) * @symspec.heaviside(x - @symcore.int(2)),
            x,
            s,
          ),
        ) -
        @symelem.exp(@symcore.int(-2) * s) * (s ^ @symcore.int(-2)),
      ),
      @symcore.int(0),
    ),
    0,
  )
  let square_piecewise = @symcore.raw_function("Piecewise", [
    @symcore.int(0),
    @symcore.function("Le", [x, @symcore.int(0)]),
    @symcore.int(1),
    @symcore.function("Le", [x, @symcore.int(1)]),
    @symcore.int(0),
    @symcore.Expr::Boolean(true),
  ])
  let square_piecewise_eval = doit(laplace_transform(square_piecewise, x, s))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(square_piecewise_eval),
      @symsimplify.simplify(
        (s ^ @symcore.int(-1)) -
        @symelem.exp(@symcore.int(-1) * s) * (s ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  let triangle_piecewise = @symcore.raw_function("Piecewise", [
    @symcore.int(0),
    @symcore.function("Le", [x, @symcore.int(0)]),
    x,
    @symcore.function("Le", [x, @symcore.int(1)]),
    @symcore.int(2) - x,
    @symcore.function("Le", [x, @symcore.int(2)]),
    @symcore.int(0),
    @symcore.Expr::Boolean(true),
  ])
  let triangle_piecewise_eval = doit(
    laplace_transform(triangle_piecewise, x, s),
  )
  assert_true(
    !@symprint.pretty_string(triangle_piecewise_eval).contains(
      "LaplaceTransform",
    ),
  )
  let middle_piecewise = a *
    @symcore.raw_function("Piecewise", [
      @symcore.int(1),
      @symcore.function("And", [
        @symcore.function("Gt", [x, @symcore.int(1)]),
        @symcore.function("Le", [x, @symcore.int(3)]),
      ]),
      @symcore.int(2),
      @symcore.Expr::Boolean(true),
    ])
  let middle_piecewise_eval = doit(laplace_transform(middle_piecewise, x, s))
  assert_true(
    !@symprint.pretty_string(middle_piecewise_eval).contains("LaplaceTransform"),
  )
  let eq_piecewise = @symcore.raw_function("Piecewise", [
    @symcore.int(1),
    @symcore.function("Eq", [x, @symcore.int(1)]),
    @symcore.int(2),
    @symcore.Expr::Boolean(true),
  ])
  assert_true(
    @symprint.pretty_string(doit(laplace_transform(eq_piecewise, x, s))).contains(
      "LaplaceTransform",
    ),
  )

  let deriv_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symcore.raw_function("Derivative", [f_of_x, x]),
      x,
      s,
    ),
  )
  assert_true(deriv_eval.contains("LaplaceTransform(f(x), x, s)"))
  assert_true(deriv_eval.contains("f(0)"))

  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(@symelem.sinh(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(@symelem.cosh(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(x * @symelem.sin(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(x * @symelem.cos(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(laplace_transform(x * @symelem.sinh(x), x, s)),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(laplace_transform(x * @symelem.cosh(x), x, s)),
    ).contains("LaplaceTransform"),
  )

  let generic_eval = @symprint.pretty_string(
    laplace_transform_eval(f_of_x, x, s),
  )
  assert_true(generic_eval.contains("LaplaceTransform(f(x), x, s)"))
  assert_true(generic_eval.contains("oo"))

  let scaled_eval = @symprint.pretty_string(
    laplace_transform_eval(a * f_of_x, x, s),
  )
  assert_true(scaled_eval.contains("a*LaplaceTransform(f(x), x, s)"))

  let shifted_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symelem.exp(a * (x * @symcore.int(-1))) * f_of_x,
      x,
      s,
    ),
  )
  assert_true(
    shifted_generic_eval.contains("LaplaceTransform(f(x), x,") &&
    (
      shifted_generic_eval.contains("a + s)") ||
      shifted_generic_eval.contains("s + a)")
    ),
  )

  let neg_heaviside_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      a *
      @symspec.heaviside(x + @symcore.int(1)) *
      @symcore.raw_function("f", [x + @symcore.int(1)]),
      x,
      s,
    ),
  )
  assert_true(
    neg_heaviside_generic_eval.contains("a*LaplaceTransform(f(x + 1), x, s)") ||
    neg_heaviside_generic_eval.contains("a*LaplaceTransform(f(1 + x), x, s)") ||
    neg_heaviside_generic_eval.contains("a*LaplaceTransform(f((x + 1)), x, s)"),
  )

  let pos_heaviside_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      a *
      @symspec.heaviside(x - @symcore.int(1)) *
      @symcore.raw_function("f", [x - @symcore.int(1)]),
      x,
      s,
    ),
  )
  assert_true(
    pos_heaviside_generic_eval.contains("exp((-1*s))") ||
    pos_heaviside_generic_eval.contains("exp(-s)"),
  )
  assert_true(
    pos_heaviside_generic_eval.contains("LaplaceTransform(f(x), x, s)"),
  )

  let scaled_arg_generic = laplace_transform_eval(
    b * @symcore.raw_function("f", [x * (a ^ @symcore.int(-1))]),
    x,
    s,
  )
  let scaled_arg_generic_eval = @symprint.pretty_string(scaled_arg_generic)
  assert_true(
    scaled_arg_generic_eval.contains("b*LaplaceTransform(f((a**-1*x)), x, s)") ||
    scaled_arg_generic_eval.contains("b*LaplaceTransform(f(x/a), x, s)"),
  )
  match @symcore.tuple_items(scaled_arg_generic) {
    Some([_, _, cond]) =>
      assert_eq(@symcore.compare_expr(cond, @symcore.Expr::Boolean(true)), 0)
    _ => fail("expected LaplaceTransform tuple for generic scaling case")
  }

  let scaled_numeric_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      b * @symcore.raw_function("f", [@symcore.int(2) * x]),
      x,
      s,
    ),
  )
  assert_true(
    scaled_numeric_generic_eval.contains(
      "b*LaplaceTransform(f(x), x, (2**-1*s))/2",
    ) ||
    scaled_numeric_generic_eval.contains("b*LaplaceTransform(f(x), x, (s/2))/2") ||
    scaled_numeric_generic_eval.contains("b*LaplaceTransform(f(x), x, s/2)/2") ||
    scaled_numeric_generic_eval.contains(
      "1/2*b*LaplaceTransform(f(x), x, (1/2*s))",
    ),
  )

  let scaled_numeric_sum_eval = @symprint.pretty_string(
    laplace_transform_eval(
      a * @symcore.raw_function("f", [@symcore.int(2) * x]) +
      @symcore.raw_function("g", [@symcore.int(3) * x]),
      x,
      s,
    ),
  )
  assert_true(scaled_numeric_sum_eval.contains("LaplaceTransform(f(x), x,"))
  assert_true(scaled_numeric_sum_eval.contains("LaplaceTransform(g(x), x,"))

  let heaviside_pos_affine_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symspec.heaviside(@symcore.int(2) * x - @symcore.int(4)),
      x,
      s,
    ),
  )
  assert_true(
    (
      heaviside_pos_affine_eval.contains("exp((-2*s))") ||
      heaviside_pos_affine_eval.contains("exp(-2*s)")
    ) &&
    (
      heaviside_pos_affine_eval.contains("s**-1") ||
      heaviside_pos_affine_eval.contains("1/s") ||
      heaviside_pos_affine_eval.contains("/s")
    ),
  )

  let heaviside_pos_past_zero_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symspec.heaviside(@symcore.int(2) * x + @symcore.int(4)),
      x,
      s,
    ),
  )
  assert_true(
    heaviside_pos_past_zero_eval.contains("s**-1") ||
    heaviside_pos_past_zero_eval.contains("1/s") ||
    heaviside_pos_past_zero_eval.contains("/s"),
  )

  let heaviside_neg_affine_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symspec.heaviside(@symcore.int(-2) * x + @symcore.int(4)),
      x,
      s,
    ),
  )
  assert_true(
    heaviside_neg_affine_eval.contains("exp((-1*(2*s)))") ||
    heaviside_neg_affine_eval.contains("exp((-2*s))") ||
    heaviside_neg_affine_eval.contains("exp(-2*s)"),
  )
  assert_true(
    heaviside_neg_affine_eval.contains("s**-1") ||
    heaviside_neg_affine_eval.contains("1/s") ||
    heaviside_neg_affine_eval.contains("/s"),
  )

  let lower_window_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symspec.heaviside(@symcore.int(2) * x - @symcore.int(4)) * g_of_x,
      x,
      s,
    ),
  )
  assert_true(
    lower_window_generic_eval.contains("LaplaceTransform") &&
    lower_window_generic_eval.contains("Heaviside") &&
    lower_window_generic_eval.contains("g(x)"),
  )

  let upper_window_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symspec.heaviside(@symcore.int(-1) * x + @symcore.int(2)) * g_of_x,
      x,
      s,
    ),
  )
  assert_true(
    upper_window_generic_eval.contains("LaplaceTransform(g(x), x, s)"),
  )
  assert_true(
    upper_window_generic_eval.contains("exp((-2*s))") ||
    upper_window_generic_eval.contains("exp(-2*s)"),
  )

  let upper_window_zero = laplace_transform_eval(
    @symspec.heaviside(@symcore.int(-1) * x - @symcore.int(2)) * g_of_x,
    x,
    s,
  )
  match @symcore.tuple_items(upper_window_zero) {
    Some([value, plane, cond]) => {
      assert_eq(@symcore.compare_expr(value, @symcore.int(0)), 0)
      assert_eq(@symcore.compare_expr(plane, @symcore.int(0)), 0)
      assert_eq(@symcore.compare_expr(cond, @symcore.Expr::Boolean(true)), 0)
    }
    _ => fail("expected zero-valued LaplaceTransform tuple for upper window")
  }

  let x_generic_eval = laplace_transform_eval(x * f_of_x, x, s, noconds=true)
  let expected_x_generic = @symcore.int(-1) *
    @symcore.raw_derivative(
      @symcore.raw_function("LaplaceTransform", [f_of_x, x, s]),
      [s],
    )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(x_generic_eval - expected_x_generic),
      @symcore.int(0),
    ),
    0,
  )
  let xn_generic_eval = @symprint.pretty_string(
    laplace_transform_eval((x ^ np) * g_of_x, x, s),
  )
  assert_true(
    xn_generic_eval.contains("LaplaceTransform(g(x), x, s)") &&
    xn_generic_eval.contains("Derivative") &&
    xn_generic_eval.contains("np"),
  )

  let external_exp_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      @symelem.exp(@symcore.int(-1) * @symcore.raw_function("f", [y]) * x),
      x,
      s,
    ),
  )
  assert_true(
    external_exp_generic_eval.contains("(s + f(y))") ||
    external_exp_generic_eval.contains("(f(y) + s)"),
  )
  assert_true(
    external_exp_generic_eval.contains("-re(f(y))") ||
    external_exp_generic_eval.contains("0 + -re(f(y))") ||
    external_exp_generic_eval.contains("re((-1*f(y)))") ||
    (
      external_exp_generic_eval.contains("re(") &&
      external_exp_generic_eval.contains("f(y)")
    ),
  )

  let sin_sq_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(
      (@symelem.sin(a * x + b) ^ @symcore.int(2)) * f_of_x,
      x,
      s,
    ),
  )
  assert_true(sin_sq_generic_eval.contains("LaplaceTransform(f(x), x, s)"))
  assert_true(
    (
      sin_sq_generic_eval.contains("exp((2*I*b))") ||
      sin_sq_generic_eval.contains("exp(2*I*b)")
    ) &&
    (
      sin_sq_generic_eval.contains("exp(((-2*I)*b))") ||
      sin_sq_generic_eval.contains("exp((-2*I*b))") ||
      sin_sq_generic_eval.contains("exp(-2*I*b)")
    ),
  )

  let poly_generic_eval = laplace_transform_eval(
    (
      @symcore.int(2) * (x ^ @symcore.int(2)) +
      @symcore.int(3) * x +
      @symcore.int(4)
    ) *
    f_of_x,
    x,
    s,
    noconds=true,
  )
  let expected_poly_generic = @symcore.int(2) *
    @symcore.raw_derivative(
      @symcore.raw_function("LaplaceTransform", [f_of_x, x, s]),
      [s, @symcore.int(2)],
    ) +
    @symcore.int(-3) *
    @symcore.raw_derivative(
      @symcore.raw_function("LaplaceTransform", [f_of_x, x, s]),
      [s],
    ) +
    @symcore.int(4) * @symcore.raw_function("LaplaceTransform", [f_of_x, x, s])
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(poly_generic_eval - expected_poly_generic),
      @symcore.int(0),
    ),
    0,
  )

  let sinh_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(@symelem.sinh(a * x) * f_of_x, x, s),
  )
  let sinh_transform_count = sinh_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(sinh_transform_count >= 3 && sinh_generic_eval.contains("a"))

  let cosh_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(@symelem.cosh(a * x) * f_of_x, x, s),
  )
  let cosh_transform_count = cosh_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(cosh_transform_count >= 3 && cosh_generic_eval.contains("a"))

  let sin_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(@symelem.sin(a * x) * f_of_x, x, s),
  )
  let sin_transform_count = sin_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(
    sin_transform_count >= 3 &&
    sin_generic_eval.contains("I") &&
    sin_generic_eval.contains("a"),
  )

  let cos_generic_eval = @symprint.pretty_string(
    laplace_transform_eval(@symelem.cos(a * x) * f_of_x, x, s),
  )
  let cos_transform_count = cos_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(
    cos_transform_count >= 3 &&
    cos_generic_eval.contains("I") &&
    cos_generic_eval.contains("a"),
  )

  let mt = @symmatrices.matrix([
    [@symelem.exp(x), x * @symelem.exp(@symcore.int(-1) * x)],
    [x * @symelem.exp(@symcore.int(-1) * x), @symelem.exp(x)],
  ]) catch {
    _ => fail("matrix lt failed")
  }
  let (matrix_laplace, matrix_plane, matrix_cond) = @symintegrals.laplace_transform_matrix_result(
    mt, x, s,
  ) catch {
    _ => fail("matrix lt result failed")
  }
  assert_eq(
    @symcore.compare_expr(
      matrix_laplace.getitem(0, 0) catch {
        _ => fail("getitem failed")
      },
      (@symcore.int(-1) + s) ^ @symcore.int(-1),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      matrix_laplace.getitem(0, 1) catch {
        _ => fail("getitem failed")
      },
      (@symcore.int(1) + s) ^ @symcore.int(-2),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(matrix_plane - @symcore.int(1)),
      @symcore.int(0),
    ),
    0,
  )
  assert_eq(@symcore.compare_expr(matrix_cond, @symcore.Expr::Boolean(true)), 0)
}

///|
test "symintegrals Laplace special-function rules evaluate" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let neg_half = @symcore.rational_from_ints(-1, 2)

  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(@symspec.ci(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(@symspec.si(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(@symspec.shi(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(@symspec.chi(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(doit(laplace_transform(@symspec.e1(x), x, s))).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(laplace_transform(@symspec.expint(@symcore.int(2), x), x, s)),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(laplace_transform(@symspec.expint(a, x), x, s)),
    ).contains("LaplaceTransform"),
  )
  let gaussian_laplace = doit(
    laplace_transform(
      @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2))),
      x,
      s,
    ),
  )
  let x_gaussian_laplace = doit(
    laplace_transform(
      x * @symelem.exp(@symcore.int(-2) * (x ^ @symcore.int(2))),
      x,
      s,
    ),
  )
  let x2_gaussian_laplace = doit(
    laplace_transform(
      (x ^ @symcore.int(2)) *
      @symelem.exp(@symcore.int(-1) * (x ^ @symcore.int(2))),
      x,
      s,
    ),
  )
  let sin_sq_phase_laplace = doit(
    laplace_transform(@symelem.sin(a * x + b) ^ @symcore.int(2), x, s),
  )
  let cos_sq_laplace = doit(
    laplace_transform(@symelem.cos(@symcore.int(2) * x) ^ @symcore.int(2), x, s),
  )
  let sinh_sq_laplace = doit(
    laplace_transform(
      @symelem.sinh(@symcore.int(2) * x) ^ @symcore.int(2),
      x,
      s,
    ),
  )
  let cosh_sq_laplace = doit(
    laplace_transform(
      @symelem.cosh(@symcore.int(2) * x) ^ @symcore.int(2),
      x,
      s,
    ),
  )
  let sin_fourth_laplace = doit(
    laplace_transform(@symelem.sin(@symcore.int(2) * x) ^ @symcore.int(4), x, s),
  )
  let sinh_cosh_laplace = doit(
    laplace_transform(
      @symelem.sinh(@symcore.int(2) * x) * @symelem.cosh(@symcore.int(2) * x),
      x,
      s,
    ),
  )
  let sin_cubic_cosh_laplace = doit(
    laplace_transform(
      (@symelem.sin(@symcore.int(2) * x) ^ @symcore.int(3)) *
      @symelem.cosh(@symcore.int(3) * x),
      x,
      s,
    ),
  )
  let abs_sin_laplace = doit(
    laplace_transform(@symelem.abs(@symelem.sin(@symcore.int(2) * x)), x, s),
  )
  let sin_sq_over_x_laplace = doit(
    laplace_transform(
      (@symelem.sin(@symcore.int(2) * x) ^ @symcore.int(2)) *
      (x ^ @symcore.int(-1)),
      x,
      s,
    ),
  )
  let sin_sq_over_x2_laplace = doit(
    laplace_transform(
      (@symelem.sin(@symcore.int(2) * x) ^ @symcore.int(2)) *
      (x ^ @symcore.int(-2)),
      x,
      s,
    ),
  )
  assert_true(
    !@symprint.pretty_string(gaussian_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(x_gaussian_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(x2_gaussian_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(sin_sq_phase_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(cos_sq_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(sinh_sq_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(cosh_sq_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(sin_fourth_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(sinh_cosh_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(sin_cubic_cosh_laplace).contains(
      "LaplaceTransform",
    ),
  )
  assert_true(
    !@symprint.pretty_string(abs_sin_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(sin_sq_over_x_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(sin_sq_over_x2_laplace).contains(
      "LaplaceTransform",
    ),
  )
  let log_laplace = doit(laplace_transform(@symelem.log(x), x, s))
  let log_one_plus_laplace = doit(
    laplace_transform(@symelem.log(@symcore.int(1) + a * x), x, s),
  )
  let log_shifted_laplace = doit(laplace_transform(@symelem.log(x + a), x, s))
  let log_square_laplace = doit(
    laplace_transform(@symelem.log(x) ^ @symcore.int(2), x, s),
  )
  let power_laplace = doit(laplace_transform(x ^ a, x, s))
  let damped_power_laplace = doit(
    laplace_transform(@symelem.exp(@symcore.int(-1) * b * x) * (x ^ a), x, s),
  )
  let sin_over_x_laplace = doit(
    laplace_transform(@symelem.sin(a * x) * (x ^ @symcore.int(-1)), x, s),
  )
  let sinh_over_x_laplace = doit(
    laplace_transform(@symelem.sinh(a * x) * (x ^ @symcore.int(-1)), x, s),
  )
  let bessely0_laplace = doit(
    laplace_transform(@symspec.bessely(@symcore.int(0), a * x), x, s),
  )
  let besselk0_laplace = doit(
    laplace_transform(@symspec.besselk(@symcore.int(0), a * x), x, s),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(laplace_transform(@symspec.erf(@symcore.int(2) * x), x, s)),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        laplace_transform(
          @symspec.besselj(@symcore.int(0), @symcore.int(2) * x),
          x,
          s,
        ),
      ),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        laplace_transform(
          x * @symspec.besselj(@symcore.int(0), @symcore.int(2) * x),
          x,
          s,
        ),
      ),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        laplace_transform(
          @symspec.besseli(@symcore.int(0), @symcore.int(2) * x),
          x,
          s,
        ),
      ),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        laplace_transform(
          x * @symspec.besseli(@symcore.int(0), @symcore.int(2) * x),
          x,
          s,
        ),
      ),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(laplace_transform(@symspec.fresnels(x), x, s)),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(laplace_transform(@symspec.fresnelc(x), x, s)),
    ).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(bessely0_laplace).contains("LaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(besselk0_laplace).contains("LaplaceTransform"),
  )

  let inv_ci = doit(
    inverse_laplace_transform(
      neg_half *
      @symelem.log(@symcore.int(1) + (s ^ @symcore.int(2))) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_e1 = doit(
    inverse_laplace_transform(
      @symelem.log(s + @symcore.int(1)) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_expint2 = doit(
    inverse_laplace_transform(
      (s - @symelem.log(s + @symcore.int(1))) * (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )

  assert_true(
    !@symprint.pretty_string(inv_ci).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_e1).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(inv_expint2).contains("InverseLaplaceTransform"),
  )
  let inv_log = doit(
    inverse_laplace_transform(
      @symcore.int(-1) *
      (
        @symelem.log(s) +
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma)
      ) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_log_one_plus = doit(
    inverse_laplace_transform(
      @symcore.int(-1) *
      @symelem.exp(s * (a ^ @symcore.int(-1))) *
      @symspec.ei(@symcore.int(-1) * s * (a ^ @symcore.int(-1))) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_atan = doit(
    inverse_laplace_transform(@symelem.atan(a * (s ^ @symcore.int(-1))), s, x),
  )
  let inv_sinh_over_x = doit(
    inverse_laplace_transform(
      @symcore.rational_from_ints(1, 2) *
      @symelem.log((a + s) * ((s - a) ^ @symcore.int(-1))),
      s,
      x,
    ),
  )

  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(log_laplace),
      @symsimplify.simplify(
        @symcore.int(-1) *
        (
          @symelem.log(s) +
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma)
        ) *
        (s ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(log_one_plus_laplace),
      @symsimplify.simplify(
        @symcore.int(-1) *
        @symelem.exp(s * (a ^ @symcore.int(-1))) *
        @symspec.ei(@symcore.int(-1) * s * (a ^ @symcore.int(-1))) *
        (s ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(log_shifted_laplace),
      @symsimplify.simplify(
        (
          s * @symelem.log(a) -
          @symelem.exp(s * (a ^ @symcore.int(-1))) *
          @symspec.ei(@symcore.int(-1) * s * (a ^ @symcore.int(-1)))
        ) *
        (s ^ @symcore.int(-2)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(log_square_laplace),
      @symsimplify.simplify(
        (
          (
            (
              @symelem.log(s) +
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma)
            ) ^
            @symcore.int(2)
          ) +
          (
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
            @symcore.int(2)
          ) *
          @symcore.rational_from_ints(1, 6)
        ) *
        (s ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(power_laplace),
      @symsimplify.simplify(
        @symspec.gamma(a + @symcore.int(1)) *
        (s ^ (a + @symcore.int(1)) ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(damped_power_laplace),
      @symsimplify.simplify(
        @symspec.gamma(a + @symcore.int(1)) *
        ((s + b) ^ (a + @symcore.int(1)) ^ @symcore.int(-1)),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(sin_over_x_laplace),
      @symsimplify.simplify(@symelem.atan(a * (s ^ @symcore.int(-1)))),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(sinh_over_x_laplace),
      @symsimplify.simplify(
        @symcore.rational_from_ints(1, 2) *
        @symelem.log((a + s) * ((s - a) ^ @symcore.int(-1))),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(bessely0_laplace),
      @symsimplify.simplify(
        @symcore.rational_from_ints(-2, 1) *
        (
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^
          @symcore.int(-1)
        ) *
        @symelem.asinh(s * (a ^ @symcore.int(-1))) *
        (
          @symelem.sqrt((a ^ @symcore.int(2)) + (s ^ @symcore.int(2))) ^
          @symcore.int(-1)
        ),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(besselk0_laplace),
      @symsimplify.simplify(
        @symelem.log(
          (s + @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2)))) *
          (a ^ @symcore.int(-1)),
        ) *
        (
          @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2))) ^
          @symcore.int(-1)
        ),
      ),
    ),
    0,
  )

  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_ci),
      @symsimplify.simplify(@symspec.heaviside(x) * @symspec.ci(x)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_e1),
      @symsimplify.simplify(@symspec.heaviside(x) * @symspec.e1(x)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_expint2),
      @symsimplify.simplify(
        @symspec.heaviside(x) * @symspec.expint(@symcore.int(2), x),
      ),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(inv_log),
      @symsimplify.simplify(@symspec.heaviside(x) * @symelem.log(x)),
    ),
    0,
  )
  assert_true(
    @symprint.pretty_string(inv_log_one_plus).contains(
      "InverseLaplaceTransform",
    ),
  )
  assert_true(
    @symprint.pretty_string(inv_atan).contains("InverseLaplaceTransform"),
  )
  assert_true(
    @symprint.pretty_string(inv_sinh_over_x).contains("InverseLaplaceTransform"),
  )
}

///|
test "symintegrals inverse Laplace transform objects roundtrip" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let t = @symcore.Expr::Symbol("t")
  let q = @symcore.Expr::Symbol("q")
  let f_t = @symcore.raw_function("f", [t])
  let f_s = @symcore.raw_function("f", [s])

  let same_var = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), s, t),
  )
  let scaled_same_var = doit(
    inverse_laplace_transform(
      @symcore.int(2) * laplace_transform(f_t, t, s),
      s,
      t,
    ),
  )
  let renamed_var = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), s, x),
  )
  let wrong_freq = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), x, t),
  )
  let wrong_freq_dependent = doit(
    inverse_laplace_transform(laplace_transform(f_s, s, q), s, t),
  )

  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(same_var),
      @symsimplify.simplify(f_t * @symspec.heaviside(t)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(scaled_same_var),
      @symsimplify.simplify(@symcore.int(2) * f_t * @symspec.heaviside(t)),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(renamed_var),
      @symsimplify.simplify(
        @symcore.raw_function("f", [x]) * @symspec.heaviside(x),
      ),
    ),
    0,
  )
  assert_eq(
    @symprint.pretty_string(wrong_freq),
    @symprint.pretty_string(
      laplace_transform(f_t, t, s) * @symspec.dirac_delta(t),
    ),
  )
  assert_eq(
    @symprint.pretty_string(wrong_freq_dependent),
    @symprint.pretty_string(
      inverse_laplace_transform(laplace_transform(f_s, s, q), s, t),
    ),
  )

  let plane = @symcore.int(7)
  let explicit_plane_object = doit(
    inverse_laplace_transform(@symelem.cos(s), s, x, plane=Some(plane)),
  )
  match
    @symintegrals.inverse_laplace_transform_fundamental_plane(
      inverse_laplace_transform(f_s, s, x),
    ) {
    None => ()
    Some(_) => fail("expected default inverse Laplace plane to read as None")
  }
  let recovered_plane = match
    @symintegrals.inverse_laplace_transform_fundamental_plane(
      inverse_laplace_transform(f_s, s, x, plane=Some(plane)),
    ) {
    Some(value) => value
    None => fail("expected explicit inverse Laplace plane")
  }
  assert_eq(@symcore.compare_expr(recovered_plane, plane), 0)
  match @symintegrals.inverse_laplace_transform_fundamental_plane(f_s) {
    None => ()
    Some(_) => fail("expected non inverse-Laplace object to have no plane")
  }
  assert_eq(
    @symcore.compare_expr(
      explicit_plane_object,
      @symcore.raw_function("InverseLaplaceTransform", [
        @symelem.cos(s),
        s,
        x,
        plane,
      ]),
    ),
    0,
  )

  let explicit_plane_time_diff = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(2)) * f_s,
      s,
      x,
      plane=Some(plane),
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      explicit_plane_time_diff,
      @symcore.raw_function("Derivative", [
        @symcore.raw_function("InverseLaplaceTransform", [f_s, s, x, plane]),
        x,
        @symcore.int(2),
      ]),
    ),
    0,
  )

  let explicit_plane_frequency_diff = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative(f_s, [s]),
      s,
      x,
      plane=Some(plane),
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      explicit_plane_frequency_diff,
      @symcore.int(-1) *
      x *
      @symcore.raw_function("InverseLaplaceTransform", [f_s, s, x, plane]),
    ),
    0,
  )

  let rewritten_integral = match
    @symintegrals.inverse_laplace_transform_as_integral(
      inverse_laplace_transform(f_s, s, x),
    ) {
    Some(value) => value
    None => fail("expected inverse Laplace integral rewrite")
  }
  let contour = @symcore.Expr::Symbol("_c")
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let infinity = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::Infinity,
  )
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let expected_integral = integral(@symelem.exp(s * x) * f_s, limits=[
      integral_limit([s, contour - imag * infinity, contour + imag * infinity]),
    ]) *
    ((@symcore.int(2) * pi * imag) ^ @symcore.int(-1))
  assert_eq(@symcore.compare_expr(rewritten_integral, expected_integral), 0)

  let explicit_plane_rewritten_integral = match
    @symintegrals.inverse_laplace_transform_as_integral(
      inverse_laplace_transform(f_s, s, x, plane=Some(plane)),
    ) {
    Some(value) => value
    None => fail("expected explicit-plane inverse Laplace integral rewrite")
  }
  assert_eq(
    @symcore.compare_expr(explicit_plane_rewritten_integral, rewritten_integral),
    0,
  )
}

///|
test "symintegrals fast inverse Laplace helper matches source shapes" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")

  let shifted_power = match
    @symintegrals._fast_inverse_laplace(
      (s + @symcore.int(2)) ^ @symcore.int(-3),
      s,
      x,
    ) {
    Some(value) => value
    None => fail("expected fast inverse Laplace shifted power")
  }
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        shifted_power -
        (x ^ @symcore.int(2)) *
        @symelem.exp(@symcore.int(-2) * x) *
        (@symspec.gamma(@symcore.int(3)) ^ @symcore.int(-1)),
      ),
      @symcore.int(0),
    ),
    0,
  )

  let linear_power_sum = match
    @symintegrals._fast_inverse_laplace(
      a +
      @symcore.int(3) *
      ((@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-2)),
      s,
      x,
    ) {
    Some(value) => value
    None => fail("expected fast inverse Laplace sum")
  }
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        linear_power_sum -
        (
          a +
          @symcore.rational_from_ints(3, 4) *
          x *
          @symelem.exp(@symcore.int(-2) * x)
        ),
      ),
      @symcore.int(0),
    ),
    0,
  )

  let explicit_power_one = match
    @symintegrals._fast_inverse_laplace(
      @symcore.Expr::Pow(@symcore.int(2) * s + @symcore.int(4), @symcore.int(1)),
      s,
      x,
    ) {
    Some(value) => value
    None => fail("expected fast inverse Laplace power-one branch")
  }
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        explicit_power_one -
        @symcore.rational_from_ints(1, 2) * @symelem.exp(@symcore.int(-2) * x),
      ),
      @symcore.int(0),
    ),
    0,
  )

  match
    @symintegrals._fast_inverse_laplace(
      ((s + @symcore.int(1)) ^ @symcore.int(-1)) *
      ((s + @symcore.int(2)) ^ @symcore.int(-1)),
      s,
      x,
    ) {
    None => ()
    Some(_) => fail("expected dependent product to remain unsupported")
  }
  assert_eq(@symprint.pretty_string(shifted_power).contains("Heaviside"), false)
}

///|
test "symintegrals inverse Laplace stage 5 delay and repeated linear poles" {
  let x = @symcore.Expr::Symbol("x")
  let s = @symcore.Expr::Symbol("s")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let k = @symcore.Expr::Symbol("k")
  let u = @symcore.Expr::Symbol("u")
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let f_big_of_s = @symcore.raw_function("F", [s])
  let generic_fdict : Map[String, String] = { "f": "F" }

  let delayed = @symprint.pretty_string(
    doit(
      inverse_laplace_transform(
        @symelem.exp(@symcore.int(-2) * s) *
        ((s + @symcore.int(1)) ^ @symcore.int(-2)),
        s,
        x,
      ),
    ),
  )
  assert_true(delayed.contains("Heaviside"))
  assert_true(delayed.contains("x - 2"))

  let generic_delay = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symelem.exp(@symcore.int(-2) * s) * f_big_of_s,
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    @symcore.compare_expr(
      generic_delay,
      @symcore.raw_function("f", [x - @symcore.int(2)]),
    ),
    0,
  )

  let generic_shift = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        k * @symcore.raw_function("F", [s - @symcore.int(2)]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(generic_shift),
      @symsimplify.simplify(
        k * @symelem.exp(@symcore.int(-2) * x) * @symcore.raw_function("f", [x]),
      ),
    ),
    0,
  )

  let generic_complex_frequency_shift = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.raw_function("F", [s - @symcore.int(1) - imag]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(generic_complex_frequency_shift),
      @symsimplify.simplify(
        @symelem.exp((@symcore.int(-1) - imag) * x) *
        @symcore.raw_function("f", [x]),
      ),
    ),
    0,
  )

  let generic_negative_real_frequency_shift = doit(
    inverse_laplace_transform(
      @symcore.raw_function("F", [s + @symcore.int(1) - imag]),
      s,
      x,
    ),
  )
  assert_eq(
    @symprint.pretty_string(generic_negative_real_frequency_shift),
    @symprint.pretty_string(
      inverse_laplace_transform(
        @symcore.raw_function("F", [s + @symcore.int(1) - imag]),
        s,
        x,
      ),
    ),
  )

  let generic_applied_undef_square = doit(
    inverse_laplace_transform(k * (f_big_of_s ^ @symcore.int(2)), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      generic_applied_undef_square,
      k * inverse_laplace_transform(f_big_of_s ^ @symcore.int(2), s, x),
    ),
    0,
  )

  let generic_applied_undef_product = doit(
    inverse_laplace_transform(f_big_of_s * @symelem.sin(s), s, x),
  )
  assert_eq(
    @symprint.pretty_string(generic_applied_undef_product),
    @symprint.pretty_string(
      inverse_laplace_transform(f_big_of_s * @symelem.sin(s), s, x),
    ),
  )

  let reciprocal_frequency_diff = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative(s ^ @symcore.int(-1), [s]),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(reciprocal_frequency_diff),
      @symsimplify.simplify(@symcore.int(-1) * x * @symspec.heaviside(x)),
    ),
    0,
  )

  let scaled_generic_diff = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.int(2) * @symcore.raw_function("Derivative", [f_big_of_s, s]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    @symcore.compare_expr(
      scaled_generic_diff,
      @symcore.int(-2) * x * @symcore.raw_function("f", [x]),
    ),
    0,
  )

  let generic_diff3 = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.raw_function("Derivative", [f_big_of_s, s, @symcore.int(3)]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    @symcore.compare_expr(
      generic_diff3,
      @symcore.int(-1) * (x ^ @symcore.int(3)) * @symcore.raw_function("f", [x]),
    ),
    0,
  )

  let generic_diff4 = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.raw_function("Derivative", [f_big_of_s, s, @symcore.int(4)]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  assert_eq(
    @symcore.compare_expr(
      generic_diff4,
      (x ^ @symcore.int(4)) * @symcore.raw_function("f", [x]),
    ),
    0,
  )

  let ni = @symcore.Expr::Symbol("ni")
  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_integer(ni))
  let symbolic_integer_frequency_diff = @symintegrals.laplace_correspondence(
    doit(
      inverse_laplace_transform(
        @symcore.Expr::Derivative(f_big_of_s, [s, ni]),
        s,
        x,
      ),
    ),
    generic_fdict,
  )
  @symassume.clear_global_assumptions()
  let symbolic_integer_frequency_diff_str = @symprint.pretty_string(
    symbolic_integer_frequency_diff,
  )
  assert_true(
    !symbolic_integer_frequency_diff_str.contains("Derivative") &&
    !symbolic_integer_frequency_diff_str.contains("InverseLaplaceTransform") &&
    symbolic_integer_frequency_diff_str.contains("ni") &&
    symbolic_integer_frequency_diff_str.contains("f"),
  )

  let generic_mixed_source_diff = @symcore.raw_function("Derivative", [
    f_big_of_s, s, u,
  ])
  assert_eq(
    @symcore.compare_expr(
      doit(inverse_laplace_transform(generic_mixed_source_diff, s, x)),
      inverse_laplace_transform(generic_mixed_source_diff, s, x),
    ),
    0,
  )

  let generic_other_var_diff = @symcore.raw_function("Derivative", [
    f_big_of_s, u,
  ])
  assert_eq(
    @symcore.compare_expr(
      doit(inverse_laplace_transform(generic_other_var_diff, s, x)),
      inverse_laplace_transform(generic_other_var_diff, s, x),
    ),
    0,
  )

  let unknown_nested_source = @symelem.sin(f_big_of_s)
  assert_eq(
    @symcore.compare_expr(
      doit(inverse_laplace_transform(unknown_nested_source, s, x)),
      inverse_laplace_transform(unknown_nested_source, s, x),
    ),
    0,
  )

  let unknown_exp_source_over_pole = @symelem.exp(f_big_of_s) *
    ((s + @symcore.int(1)) ^ @symcore.int(-1))
  assert_eq(
    @symcore.compare_expr(
      doit(inverse_laplace_transform(unknown_exp_source_over_pole, s, x)),
      inverse_laplace_transform(unknown_exp_source_over_pole, s, x),
    ),
    0,
  )

  let f_of_u = @symcore.raw_function("F", [u])
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        doit(
          inverse_laplace_transform(
            f_of_u * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
            s,
            x,
          ),
        ),
      ),
      @symsimplify.simplify(
        f_of_u * @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let generic_expanded_sum = doit(
    inverse_laplace_transform((s + @symcore.int(1)) * f_big_of_s, s, x),
  )
  let generic_base_inverse = inverse_laplace_transform(f_big_of_s, s, x)
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(generic_expanded_sum),
      @symsimplify.simplify(
        @symcore.raw_function("Derivative", [generic_base_inverse, x]) +
        generic_base_inverse,
      ),
    ),
    0,
  )

  let generic_additive_expanded_terms = doit(
    inverse_laplace_transform(
      (s + @symcore.int(1)) * f_big_of_s + (s + @symcore.int(2)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(generic_additive_expanded_terms),
      @symsimplify.simplify(
        @symcore.int(3) * generic_base_inverse +
        @symcore.int(2) *
        @symcore.raw_function("Derivative", [generic_base_inverse, x]),
      ),
    ),
    0,
  )

  let generic_expanded_power = doit(
    inverse_laplace_transform(
      ((s + @symcore.int(1)) ^ @symcore.int(2)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(generic_expanded_power),
      @symsimplify.simplify(
        @symcore.raw_function("Derivative", [
          generic_base_inverse,
          x,
          @symcore.int(2),
        ]) +
        @symcore.int(2) *
        @symcore.raw_function("Derivative", [generic_base_inverse, x]) +
        generic_base_inverse,
      ),
    ),
    0,
  )

  let generic_expanded_product = doit(
    inverse_laplace_transform(
      (s + @symcore.int(1)) * (s + @symcore.int(2)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(generic_expanded_product),
      @symsimplify.simplify(
        @symcore.int(2) * generic_base_inverse +
        @symcore.int(3) *
        @symcore.raw_function("Derivative", [generic_base_inverse, x]) +
        @symcore.raw_function("Derivative", [
          generic_base_inverse,
          x,
          @symcore.int(2),
        ]),
      ),
    ),
    0,
  )

  let generic_expanded_cubic = doit(
    inverse_laplace_transform(
      ((s + @symcore.int(1)) ^ @symcore.int(3)) * f_big_of_s,
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(generic_expanded_cubic),
      @symsimplify.simplify(
        generic_base_inverse +
        @symcore.int(3) *
        @symcore.raw_function("Derivative", [generic_base_inverse, x]) +
        @symcore.int(3) *
        @symcore.raw_function("Derivative", [
          generic_base_inverse,
          x,
          @symcore.int(2),
        ]) +
        @symcore.raw_function("Derivative", [
          generic_base_inverse,
          x,
          @symcore.int(3),
        ]),
      ),
    ),
    0,
  )

  let symbolic_power = doit(
    inverse_laplace_transform(s ^ (@symcore.int(-1) * b), s, x),
  )
  let symbolic_power_str = @symprint.pretty_string(symbolic_power)
  assert_true(
    !symbolic_power_str.contains("InverseLaplaceTransform") &&
    !symbolic_power_str.contains("lowergamma") &&
    symbolic_power_str.contains("gamma") &&
    symbolic_power_str.contains("Heaviside"),
  )

  let symbolic_shifted_single_power = doit(
    inverse_laplace_transform(
      @symcore.int(3) * ((s + a) ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let symbolic_shifted_single_power_str = @symprint.pretty_string(
    symbolic_shifted_single_power,
  )
  assert_true(
    !symbolic_shifted_single_power_str.contains("InverseLaplaceTransform") &&
    symbolic_shifted_single_power_str.contains("gamma") &&
    symbolic_shifted_single_power_str.contains("exp") &&
    symbolic_shifted_single_power_str.contains("Heaviside"),
  )

  let symbolic_shifted_time_diff = doit(
    inverse_laplace_transform(s * ((s + a) ^ (@symcore.int(-1) * b)), s, x),
  )
  let symbolic_shifted_time_diff_str = @symprint.pretty_string(
    symbolic_shifted_time_diff,
  )
  assert_true(
    !symbolic_shifted_time_diff_str.contains("InverseLaplaceTransform") &&
    !symbolic_shifted_time_diff_str.contains("Derivative") &&
    !symbolic_shifted_time_diff_str.contains("DiracDelta") &&
    symbolic_shifted_time_diff_str.contains("gamma") &&
    symbolic_shifted_time_diff_str.contains("exp") &&
    symbolic_shifted_time_diff_str.contains("Heaviside"),
  )

  let np = @symcore.Expr::Symbol("np")
  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(np))
  @symassume.add_global_assumption(@symassume.q_integer(np))
  let symbolic_integer_time_diff = doit(
    inverse_laplace_transform(
      (s ^ np) * ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let symbolic_integer_unknown_time_diff = doit(
    inverse_laplace_transform((s ^ np) * @symcore.raw_function("f", [s]), s, x),
  )
  @symassume.clear_global_assumptions()
  assert_true(symbolic_integer_time_diff == @symcore.int(0))
  assert_true(symbolic_integer_unknown_time_diff == @symcore.int(0))

  let shifted_power_frequency_diff = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative((s + @symcore.int(1)) ^ @symcore.int(-2), [s]),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(shifted_power_frequency_diff),
      @symsimplify.simplify(
        @symcore.int(-1) *
        (x ^ @symcore.int(2)) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let symbolic_shifted_frequency_diff = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative((s + a) ^ (@symcore.int(-1) * b), [s]),
      s,
      x,
    ),
  )
  let symbolic_shifted_frequency_diff_str = @symprint.pretty_string(
    symbolic_shifted_frequency_diff,
  )
  assert_true(
    !symbolic_shifted_frequency_diff_str.contains("InverseLaplaceTransform") &&
    !symbolic_shifted_frequency_diff_str.contains("Derivative") &&
    symbolic_shifted_frequency_diff_str.contains("gamma") &&
    symbolic_shifted_frequency_diff_str.contains("exp") &&
    symbolic_shifted_frequency_diff_str.contains("Heaviside"),
  )

  let symbolic_shifted_power = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) * ((s + a) ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let symbolic_shifted_power_str = @symprint.pretty_string(
    symbolic_shifted_power,
  )
  assert_true(
    !symbolic_shifted_power_str.contains("InverseLaplaceTransform") &&
    symbolic_shifted_power_str.contains("lowergamma") &&
    symbolic_shifted_power_str.contains("gamma") &&
    symbolic_shifted_power_str.contains("Heaviside"),
  )

  let delayed_symbolic_power = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let delayed_symbolic_power_str = @symprint.pretty_string(
    delayed_symbolic_power,
  )
  assert_true(delayed_symbolic_power_str.contains("InverseLaplaceTransform"))

  @symassume.clear_global_assumptions()
  @symassume.add_global_assumption(@symassume.q_positive(a))
  @symassume.add_global_assumption(@symassume.q_positive(b))
  let delayed_positive_symbolic_power = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let delayed_positive_symbolic_power_str = @symprint.pretty_string(
    delayed_positive_symbolic_power,
  )
  let delayed_scaled_positive_symbolic_power = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-2) * a * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let delayed_scaled_positive_symbolic_power_str = @symprint.pretty_string(
    delayed_scaled_positive_symbolic_power,
  )
  let delayed_product_positive_symbolic_power = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * b * s) * (s ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let delayed_product_positive_symbolic_power_str = @symprint.pretty_string(
    delayed_product_positive_symbolic_power,
  )
  let sqrt_linear_positive_const = doit(
    inverse_laplace_transform((@symelem.sqrt(s) + a) ^ @symcore.int(-1), s, x),
  )
  let sqrt_linear_positive_const_str = @symprint.pretty_string(
    sqrt_linear_positive_const,
  )
  @symassume.clear_global_assumptions()
  assert_true(
    !delayed_positive_symbolic_power_str.contains("InverseLaplaceTransform") &&
    delayed_positive_symbolic_power_str.contains("gamma") &&
    delayed_positive_symbolic_power_str.contains("Heaviside"),
  )
  assert_true(
    !delayed_scaled_positive_symbolic_power_str.contains(
      "InverseLaplaceTransform",
    ) &&
    delayed_scaled_positive_symbolic_power_str.contains("gamma") &&
    delayed_scaled_positive_symbolic_power_str.contains("Heaviside"),
  )
  assert_true(
    !delayed_product_positive_symbolic_power_str.contains(
      "InverseLaplaceTransform",
    ) &&
    delayed_product_positive_symbolic_power_str.contains("gamma") &&
    delayed_product_positive_symbolic_power_str.contains("Heaviside"),
  )
  assert_true(
    !sqrt_linear_positive_const_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_positive_const_str.contains("erfc") &&
    sqrt_linear_positive_const_str.contains("Heaviside"),
  )

  let bessel_i_branch = doit(
    inverse_laplace_transform(
      (a ^ b) *
      (
        (s + @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2)))) ^
        (@symcore.int(-1) * b)
      ) *
      (
        @symelem.sqrt((s ^ @symcore.int(2)) - (a ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let bessel_i_branch_str = @symprint.pretty_string(bessel_i_branch)
  assert_true(
    !bessel_i_branch_str.contains("InverseLaplaceTransform") &&
    bessel_i_branch_str.contains("besseli") &&
    bessel_i_branch_str.contains("Heaviside"),
  )

  let bessel_j_branch = doit(
    inverse_laplace_transform(
      (a ^ b) *
      (
        (s + @symelem.sqrt((s ^ @symcore.int(2)) + (a ^ @symcore.int(2)))) ^
        (@symcore.int(-1) * b)
      ) *
      (
        @symelem.sqrt((s ^ @symcore.int(2)) + (a ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let bessel_j_branch_str = @symprint.pretty_string(bessel_j_branch)
  assert_true(
    !bessel_j_branch_str.contains("InverseLaplaceTransform") &&
    bessel_j_branch_str.contains("besselj") &&
    bessel_j_branch_str.contains("Heaviside"),
  )

  let repeated_linear = doit(
    inverse_laplace_transform(
      (@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-3),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(repeated_linear),
      @symsimplify.simplify(
        @symcore.rational_from_ints(1, 16) *
        (x ^ @symcore.int(2)) *
        @symelem.exp(@symcore.int(-2) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let scaled_symbolic_power = doit(
    inverse_laplace_transform(
      (@symcore.int(2) * s + @symcore.int(4)) ^ (@symcore.int(-1) * b),
      s,
      x,
    ),
  )
  let scaled_symbolic_power_str = @symprint.pretty_string(scaled_symbolic_power)
  assert_true(
    !scaled_symbolic_power_str.contains("InverseLaplaceTransform") &&
    scaled_symbolic_power_str.contains("gamma") &&
    scaled_symbolic_power_str.contains("exp") &&
    scaled_symbolic_power_str.contains("Heaviside"),
  )

  let scaled_symbolic_lowergamma = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) *
      ((@symcore.int(2) * s + @symcore.int(4)) ^ (@symcore.int(-1) * b)),
      s,
      x,
    ),
  )
  let scaled_symbolic_lowergamma_str = @symprint.pretty_string(
    scaled_symbolic_lowergamma,
  )
  assert_true(
    !scaled_symbolic_lowergamma_str.contains("InverseLaplaceTransform") &&
    scaled_symbolic_lowergamma_str.contains("lowergamma") &&
    scaled_symbolic_lowergamma_str.contains("gamma") &&
    scaled_symbolic_lowergamma_str.contains("Heaviside"),
  )

  let repeated_linear_apart = doit(
    inverse_laplace_transform(
      (((s + @symcore.int(1)) ^ @symcore.int(3)) * (s + @symcore.int(2))) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(repeated_linear_apart),
      @symsimplify.simplify(
        @symcore.rational_from_ints(1, 2) *
        (x ^ @symcore.int(2)) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) -
        x * @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x) +
        @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x) -
        @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let repeated_linear_apart_frequency_diff = doit(
    inverse_laplace_transform(
      @symcore.raw_derivative(
        (((s + @symcore.int(1)) ^ @symcore.int(3)) * (s + @symcore.int(2))) ^
        @symcore.int(-1),
        [s],
      ),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(repeated_linear_apart_frequency_diff),
      @symsimplify.simplify(@symcore.int(-1) * x * repeated_linear_apart),
    ),
    0,
  )

  let double_repeated_linear_apart = doit(
    inverse_laplace_transform(
      (
        ((s + @symcore.int(1)) ^ @symcore.int(2)) *
        ((s + @symcore.int(2)) ^ @symcore.int(2))
      ) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(double_repeated_linear_apart),
      @symsimplify.simplify(
        x * @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x) +
        x * @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x) -
        @symcore.int(2) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) +
        @symcore.int(2) *
        @symelem.exp(@symcore.int(-2) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let double_repeated_linear_numerator_apart = doit(
    inverse_laplace_transform(
      (s + @symcore.int(3)) *
      (
        (
          ((s + @symcore.int(1)) ^ @symcore.int(2)) *
          ((s + @symcore.int(2)) ^ @symcore.int(2))
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(double_repeated_linear_numerator_apart),
      @symsimplify.simplify(
        @symcore.int(2) *
        x *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) +
        x * @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x) -
        @symcore.int(3) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) +
        @symcore.int(3) *
        @symelem.exp(@symcore.int(-2) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let quadratic_repeated_root_den = (s ^ @symcore.int(2)) +
    @symcore.int(2) * s +
    @symcore.int(1)
  let quadratic_repeated_root_inverse = doit(
    inverse_laplace_transform(
      quadratic_repeated_root_den ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(quadratic_repeated_root_inverse),
      @symsimplify.simplify(
        x * @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let quadratic_repeated_root_numerator_inverse = doit(
    inverse_laplace_transform(
      (s + @symcore.int(3)) * (quadratic_repeated_root_den ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(quadratic_repeated_root_numerator_inverse),
      @symsimplify.simplify(
        @symcore.int(2) *
        x *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) +
        @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let scaled_quadratic_repeated_root_inverse = doit(
    inverse_laplace_transform(
      (s + @symcore.int(3)) *
      (
        (
          @symcore.int(2) * (s ^ @symcore.int(2)) +
          @symcore.int(4) * s +
          @symcore.int(2)
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(scaled_quadratic_repeated_root_inverse),
      @symsimplify.simplify(
        x * @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x) +
        @symcore.rational_from_ints(1, 2) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let rational_half = @symcore.rational_from_ints(1, 2)
  let scaled_linear_lead_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(1) *
      ((@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(scaled_linear_lead_inverse),
      @symsimplify.simplify(
        rational_half *
        @symelem.exp(@symcore.int(-2) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let scaled_linear_improper_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * s + @symcore.int(5)) *
      ((@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(scaled_linear_improper_inverse),
      @symsimplify.simplify(
        @symcore.rational_from_ints(3, 2) * @symspec.dirac_delta(x) -
        rational_half *
        @symelem.exp(@symcore.int(-2) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let scaled_distinct_quadratic_inverse = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * s + @symcore.int(5)) *
      (
        (
          @symcore.int(2) * (s ^ @symcore.int(2)) +
          @symcore.int(4) * s +
          @symcore.int(10)
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let scaled_distinct_quadratic_str = @symprint.pretty_string(
    scaled_distinct_quadratic_inverse,
  )
  assert_true(
    !scaled_distinct_quadratic_str.contains("InverseLaplaceTransform") &&
    scaled_distinct_quadratic_str.contains("sin") &&
    scaled_distinct_quadratic_str.contains("cos") &&
    scaled_distinct_quadratic_str.contains("Heaviside"),
  )

  let improper_linear_inverse = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(2)) + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(improper_linear_inverse),
      @symsimplify.simplify(
        @symcore.raw_function("DiracDelta", [x, @symcore.int(1)]) -
        @symspec.dirac_delta(x) +
        @symcore.int(2) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let improper_quadratic_inverse = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(3)) + @symcore.int(2) * s + @symcore.int(1)) *
      (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(improper_quadratic_inverse),
      @symsimplify.simplify(
        @symcore.raw_function("DiracDelta", [x, @symcore.int(1)]) +
        (@symelem.sin(x) + @symelem.cos(x)) * @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let linear_quadratic_apart_inverse = doit(
    inverse_laplace_transform(
      (s + @symcore.int(8)) *
      (
        (
          (s + @symcore.int(2)) *
          ((s ^ @symcore.int(2)) + @symcore.int(2) * s + @symcore.int(10))
        ) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let linear_quadratic_apart_str = @symprint.pretty_string(
    linear_quadratic_apart_inverse,
  )
  assert_true(
    !linear_quadratic_apart_str.contains("InverseLaplaceTransform") &&
    linear_quadratic_apart_str.contains("sin") &&
    linear_quadratic_apart_str.contains("cos") &&
    linear_quadratic_apart_str.contains("exp") &&
    linear_quadratic_apart_str.contains("Heaviside"),
  )

  let gamma_mellin_fallback = doit(
    inverse_laplace_transform(@symspec.gamma(s), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(gamma_mellin_fallback),
      @symsimplify.simplify(
        @symelem.exp(@symcore.int(-1) * @symelem.exp(@symcore.int(-1) * x)),
      ),
    ),
    0,
  )

  let gamma_shift_mellin_fallback = doit(
    inverse_laplace_transform(@symspec.gamma(s + @symcore.int(1)), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(gamma_shift_mellin_fallback),
      @symsimplify.simplify(
        @symelem.exp(@symcore.int(-1) * x) *
        @symelem.exp(@symcore.int(-1) * @symelem.exp(@symcore.int(-1) * x)),
      ),
    ),
    0,
  )

  let scaled_gamma_mellin_fallback = doit(
    inverse_laplace_transform(@symcore.int(2) * @symspec.gamma(s), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(scaled_gamma_mellin_fallback),
      @symsimplify.simplify(
        @symcore.int(2) *
        @symelem.exp(@symcore.int(-1) * @symelem.exp(@symcore.int(-1) * x)),
      ),
    ),
    0,
  )

  let symbolic_scaled_gamma_shift = doit(
    inverse_laplace_transform(a * @symspec.gamma(s + @symcore.int(1)), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(symbolic_scaled_gamma_shift),
      @symsimplify.simplify(
        a *
        @symelem.exp(@symcore.int(-1) * x) *
        @symelem.exp(@symcore.int(-1) * @symelem.exp(@symcore.int(-1) * x)),
      ),
    ),
    0,
  )

  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let gamma_minus_i_mellin_fallback = doit(
    inverse_laplace_transform(@symspec.gamma(s - imag), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(gamma_minus_i_mellin_fallback),
      @symsimplify.simplify(
        (imag * @symelem.sin(x) + @symelem.cos(x)) *
        @symelem.exp(@symcore.int(-1) * @symelem.exp(@symcore.int(-1) * x)),
      ),
    ),
    0,
  )

  let gamma_plus_i_mellin_fallback = doit(
    inverse_laplace_transform(@symspec.gamma(s + imag), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(gamma_plus_i_mellin_fallback),
      @symsimplify.simplify(
        (@symcore.int(-1) * imag * @symelem.sin(x) + @symelem.cos(x)) *
        @symelem.exp(@symcore.int(-1) * @symelem.exp(@symcore.int(-1) * x)),
      ),
    ),
    0,
  )
  let gamma_ratio_source = @symspec.gamma(s) *
    (@symspec.gamma(s + a) ^ @symcore.int(-1))
  let gamma_ratio_with_conditions = @symintegrals.inverse_laplace_transform_eval(
    gamma_ratio_source,
    s,
    x,
    noconds=false,
  )
  match @symcore.tuple_items(gamma_ratio_with_conditions) {
    Some([value, cond]) => {
      let gamma_ratio_base = @symcore.int(1) -
        @symelem.exp(@symcore.int(-1) * x)
      let expected = (gamma_ratio_base ^ (a - @symcore.int(1))) *
        @symspec.heaviside(x) *
        (@symspec.gamma(a) ^ @symcore.int(-1))
      assert_eq(
        @symcore.compare_expr(
          @symsimplify.simplify(value),
          @symsimplify.simplify(expected),
        ),
        0,
      )
      assert_eq(
        @symcore.compare_expr(
          cond,
          @symcore.function("Le", [
            @symcore.int(1) - @symelem.re(a),
            @symcore.int(0),
          ]),
        ),
        0,
      )
    }
    _ =>
      fail("expected Tuple from inverse_laplace_transform_eval noconds=false")
  }

  let z = @symcore.Expr::Symbol("z")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let sqrt_kernel = @symelem.sqrt(pi) *
    (@symelem.sqrt(z) ^ @symcore.int(-1)) *
    @symelem.exp(@symcore.int(-2) * @symelem.sqrt(z) * @symelem.sqrt(s))
  let sqrt_kernel_public = doit(inverse_laplace_transform(sqrt_kernel, s, x))
  let sqrt_kernel_phase = @symcore.int(-1) *
    @symelem.im(z) *
    (x ^ @symcore.int(-1))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(sqrt_kernel_public),
      @symsimplify.simplify(
        @symelem.exp(@symcore.int(-1) * @symelem.re(z) * (x ^ @symcore.int(-1))) *
        (
          @symelem.cos(sqrt_kernel_phase) +
          imag * @symelem.sin(sqrt_kernel_phase)
        ) *
        @symspec.heaviside(x) *
        (x ^ @symcore.rational_from_ints(-3, 2)),
      ),
    ),
    0,
  )
  let sqrt_kernel_public_with_conditions = @symintegrals.inverse_laplace_transform_eval(
    sqrt_kernel,
    s,
    x,
    noconds=false,
  )
  match @symcore.tuple_items(sqrt_kernel_public_with_conditions) {
    Some([value, cond]) => {
      assert_eq(
        @symcore.compare_expr(
          @symsimplify.simplify(value),
          @symsimplify.simplify(sqrt_kernel_public),
        ),
        0,
      )
      assert_true(
        @symcore.compare_expr(cond, @symcore.Expr::Boolean(true)) != 0,
      )
      let cond_str = @symprint.pretty_string(cond)
      assert_true(
        cond_str.contains("polar_lift") &&
        cond_str.contains("Ne") &&
        cond_str.contains(">"),
      )
    }
    _ =>
      fail("expected Tuple from inverse_laplace_transform_eval noconds=false")
  }

  let one_half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let scaled_mellin_left = doit(
    inverse_laplace_transform(
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      scaled_mellin_left,
      @symspec.heaviside(x + @symelem.log(one_half)),
    ),
    0,
  )

  let scaled_mellin_denominator = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) ^ s) * s) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(scaled_mellin_denominator, scaled_mellin_left),
    0,
  )

  let scaled_mellin_right = doit(
    inverse_laplace_transform(
      (@symcore.int(2) ^ s) * (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      scaled_mellin_right,
      @symspec.heaviside(x + @symelem.log(@symcore.int(2))),
    ),
    0,
  )

  let symbolic_base_mellin_right = @symintegrals.inverse_laplace_transform_eval(
    (a ^ s) * (s ^ @symcore.int(-1)),
    s,
    x,
  )
  assert_true(
    @symprint.pretty_string(symbolic_base_mellin_right).contains(
      "InverseLaplaceTransform",
    ),
  )

  let symbolic_base_mellin_left = @symintegrals.inverse_laplace_transform_eval(
    (a ^ (@symcore.int(-1) * s)) * (s ^ @symcore.int(-1)),
    s,
    x,
  )
  assert_true(
    @symprint.pretty_string(symbolic_base_mellin_left).contains(
      "InverseLaplaceTransform",
    ),
  )

  let scaled_mellin_shift = doit(
    inverse_laplace_transform(
      (@symcore.int(2) ^ (@symcore.int(-1) * s)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(scaled_mellin_shift),
      @symsimplify.simplify(
        @symcore.int(2) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x + @symelem.log(one_half)),
      ),
    ),
    0,
  )

  let shifted_quad = @symprint.pretty_string(
    doit(
      inverse_laplace_transform(
        (((s + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(4)) ^
        @symcore.int(-1),
        s,
        x,
      ),
    ),
  )
  assert_true(
    !shifted_quad.contains("InverseLaplaceTransform") &&
    shifted_quad.contains("Heaviside"),
  )

  let shifted_quad_num = @symprint.pretty_string(
    doit(
      inverse_laplace_transform(
        (s + @symcore.int(1)) *
        (
          (((s + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(4)) ^
          @symcore.int(-1)
        ),
        s,
        x,
      ),
    ),
  )
  assert_true(
    !shifted_quad_num.contains("InverseLaplaceTransform") &&
    shifted_quad_num.contains("Heaviside"),
  )

  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          (((s + @symcore.int(1)) ^ @symcore.int(2)) - @symcore.int(4)) ^
          @symcore.int(-1),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          (s + @symcore.int(1)) *
          (
            (((s + @symcore.int(1)) ^ @symcore.int(2)) - @symcore.int(4)) ^
            @symcore.int(-1)
          ),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )

  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          ((s ^ @symcore.int(2)) - @symcore.int(1)) ^ @symcore.int(-1),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          ((s + @symcore.int(1)) * (s + @symcore.int(2))) ^ @symcore.int(-1),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          s *
          (((s + @symcore.int(1)) * (s + @symcore.int(2))) ^ @symcore.int(-1)),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          ((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-2),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          s * (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-2)),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          ((s ^ @symcore.int(2)) - @symcore.int(1)) ^ @symcore.int(-2),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          s * (((s ^ @symcore.int(2)) - @symcore.int(1)) ^ @symcore.int(-2)),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          (((s + @symcore.int(1)) ^ @symcore.int(2)) - @symcore.int(4)) ^
          @symcore.int(2) ^
          @symcore.int(-1),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          s *
          (
            (((s + @symcore.int(1)) ^ @symcore.int(2)) - @symcore.int(4)) ^
            @symcore.int(2) ^
            @symcore.int(-1)
          ),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          (((s + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(4)) ^
          @symcore.int(2) ^
          @symcore.int(-1),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )
  assert_true(
    !@symprint.pretty_string(
      doit(
        inverse_laplace_transform(
          s *
          (
            (((s + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(4)) ^
            @symcore.int(2) ^
            @symcore.int(-1)
          ),
          s,
          x,
        ),
      ),
    ).contains("InverseLaplaceTransform"),
  )

  let reciprocal_sqrt_sum = doit(
    inverse_laplace_transform(
      @symelem.sqrt((s ^ @symcore.int(2)) + @symcore.int(4)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(reciprocal_sqrt_sum),
      @symsimplify.simplify(
        @symspec.heaviside(x) *
        @symspec.besselj(@symcore.int(0), @symcore.int(2) * x),
      ),
    ),
    0,
  )

  let reciprocal_scaled_sqrt_sum = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(3) * (s ^ @symcore.int(2)) + @symcore.int(12)) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(reciprocal_scaled_sqrt_sum),
      @symsimplify.simplify(
        @symspec.heaviside(x) *
        @symspec.besselj(@symcore.int(0), @symcore.int(2) * x) *
        (@symelem.sqrt(@symcore.int(3)) ^ @symcore.int(-1)),
      ),
    ),
    0,
  )

  let reciprocal_sqrt_diff = doit(
    inverse_laplace_transform(
      @symelem.sqrt((s ^ @symcore.int(2)) - @symcore.int(4)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(reciprocal_sqrt_diff),
      @symsimplify.simplify(
        @symspec.heaviside(x) *
        @symspec.besseli(@symcore.int(0), @symcore.int(2) * x),
      ),
    ),
    0,
  )

  let reciprocal_scaled_sqrt_diff = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(3) * (s ^ @symcore.int(2)) - @symcore.int(12)) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(reciprocal_scaled_sqrt_diff),
      @symsimplify.simplify(
        @symspec.heaviside(x) *
        @symspec.besseli(@symcore.int(0), @symcore.int(2) * x) *
        (@symelem.sqrt(@symcore.int(3)) ^ @symcore.int(-1)),
      ),
    ),
    0,
  )

  let reciprocal_sqrt_s = doit(
    inverse_laplace_transform(@symelem.sqrt(s) ^ @symcore.int(-1), s, x),
  )
  let reciprocal_sqrt_s_str = @symprint.pretty_string(reciprocal_sqrt_s)
  assert_true(!reciprocal_sqrt_s_str.contains("InverseLaplaceTransform"))

  let reciprocal_sqrt_shifted = doit(
    inverse_laplace_transform(
      @symelem.sqrt(s + @symcore.int(1)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  let reciprocal_sqrt_shifted_str = @symprint.pretty_string(
    reciprocal_sqrt_shifted,
  )
  assert_true(
    !reciprocal_sqrt_shifted_str.contains("InverseLaplaceTransform") &&
    reciprocal_sqrt_shifted_str.contains("exp") &&
    reciprocal_sqrt_shifted_str.contains("Heaviside"),
  )

  let sqrt_linear_plus_const = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(3) * s) + @symcore.int(2)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  let sqrt_linear_plus_const_str = @symprint.pretty_string(
    sqrt_linear_plus_const,
  )
  assert_true(
    !sqrt_linear_plus_const_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_plus_const_str.contains("erfc") &&
    sqrt_linear_plus_const_str.contains("Heaviside"),
  )

  let raw_scaled_sqrt_linear_plus_const = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  let raw_scaled_sqrt_linear_plus_const_str = @symprint.pretty_string(
    raw_scaled_sqrt_linear_plus_const,
  )
  assert_true(
    !raw_scaled_sqrt_linear_plus_const_str.contains("InverseLaplaceTransform") &&
    raw_scaled_sqrt_linear_plus_const_str.contains("erfc") &&
    raw_scaled_sqrt_linear_plus_const_str.contains("Heaviside"),
  )

  let sqrt_linear_negative_const_object = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_true(
    @symprint.pretty_string(sqrt_linear_negative_const_object).contains(
      "InverseLaplaceTransform",
    ),
  )

  let sqrt_linear_symbolic_const_object = doit(
    inverse_laplace_transform((@symelem.sqrt(s) + a) ^ @symcore.int(-1), s, x),
  )
  assert_true(
    @symprint.pretty_string(sqrt_linear_symbolic_const_object).contains(
      "InverseLaplaceTransform",
    ),
  )

  let sqrt_times_sqrt_linear = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      (
        (@symelem.sqrt(@symcore.int(5) * s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let sqrt_times_sqrt_linear_str = @symprint.pretty_string(
    sqrt_times_sqrt_linear,
  )
  assert_true(
    !sqrt_times_sqrt_linear_str.contains("InverseLaplaceTransform") &&
    sqrt_times_sqrt_linear_str.contains("erfc") &&
    sqrt_times_sqrt_linear_str.contains("Heaviside"),
  )

  let sqrt_times_scaled_sqrt_linear = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let sqrt_times_scaled_sqrt_linear_str = @symprint.pretty_string(
    sqrt_times_scaled_sqrt_linear,
  )
  assert_true(
    !sqrt_times_scaled_sqrt_linear_str.contains("InverseLaplaceTransform") &&
    sqrt_times_scaled_sqrt_linear_str.contains("erfc") &&
    sqrt_times_scaled_sqrt_linear_str.contains("Heaviside"),
  )

  let helper_rejected_negative_sqrt_fallback = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let helper_rejected_negative_sqrt_fallback_str = @symprint.pretty_string(
    helper_rejected_negative_sqrt_fallback,
  )
  assert_true(
    !helper_rejected_negative_sqrt_fallback_str.contains(
      "InverseLaplaceTransform",
    ) &&
    helper_rejected_negative_sqrt_fallback_str.contains("erfc") &&
    helper_rejected_negative_sqrt_fallback_str.contains("Heaviside"),
  )

  let reciprocal_sqrt_shifted_linear = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s + @symcore.int(3)) ^ @symcore.int(-1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reciprocal_sqrt_shifted_linear_str = @symprint.pretty_string(
    reciprocal_sqrt_shifted_linear,
  )
  assert_true(
    !reciprocal_sqrt_shifted_linear_str.contains("InverseLaplaceTransform") &&
    reciprocal_sqrt_shifted_linear_str.contains("erf") &&
    reciprocal_sqrt_shifted_linear_str.contains("Heaviside"),
  )

  let scaled_reciprocal_sqrt_shifted_linear = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s + @symcore.int(15)) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let scaled_reciprocal_sqrt_shifted_linear_str = @symprint.pretty_string(
    scaled_reciprocal_sqrt_shifted_linear,
  )
  assert_true(
    !scaled_reciprocal_sqrt_shifted_linear_str.contains(
      "InverseLaplaceTransform",
    ) &&
    scaled_reciprocal_sqrt_shifted_linear_str.contains("erf") &&
    scaled_reciprocal_sqrt_shifted_linear_str.contains("Heaviside"),
  )

  let reciprocal_sqrt_shifted_over_s = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s + @symcore.int(1)) ^ @symcore.int(-1)) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reciprocal_sqrt_shifted_over_s_str = @symprint.pretty_string(
    reciprocal_sqrt_shifted_over_s,
  )
  assert_true(
    !reciprocal_sqrt_shifted_over_s_str.contains("InverseLaplaceTransform") &&
    reciprocal_sqrt_shifted_over_s_str.contains("erf") &&
    reciprocal_sqrt_shifted_over_s_str.contains("Heaviside"),
  )

  let reciprocal_sqrt_affine_linear = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(-2)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reciprocal_sqrt_affine_linear_str = @symprint.pretty_string(
    reciprocal_sqrt_affine_linear,
  )
  assert_true(
    !reciprocal_sqrt_affine_linear_str.contains("InverseLaplaceTransform") &&
    reciprocal_sqrt_affine_linear_str.contains("erf") &&
    reciprocal_sqrt_affine_linear_str.contains("Heaviside"),
  )

  let reciprocal_sqrt_affine_linear_over_s = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(-2)) ^ @symcore.int(-1)) *
      (s ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reciprocal_sqrt_affine_linear_over_s_str = @symprint.pretty_string(
    reciprocal_sqrt_affine_linear_over_s,
  )
  assert_true(
    !reciprocal_sqrt_affine_linear_over_s_str.contains(
      "InverseLaplaceTransform",
    ) &&
    reciprocal_sqrt_affine_linear_over_s_str.contains("erf") &&
    reciprocal_sqrt_affine_linear_over_s_str.contains("Heaviside"),
  )

  let scaled_sqrt_over_s = doit(
    inverse_laplace_transform(
      @symcore.int(2) *
      (s ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_over_s_str = @symprint.pretty_string(scaled_sqrt_over_s)
  assert_true(
    !scaled_sqrt_over_s_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_over_s_str.contains("erfc") &&
    scaled_sqrt_over_s_str.contains("Heaviside"),
  )

  let unit_scaled_sqrt_over_s = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let unit_scaled_sqrt_over_s_str = @symprint.pretty_string(
    unit_scaled_sqrt_over_s,
  )
  assert_true(
    !unit_scaled_sqrt_over_s_str.contains("InverseLaplaceTransform") &&
    unit_scaled_sqrt_over_s_str.contains("erfc") &&
    unit_scaled_sqrt_over_s_str.contains("Heaviside"),
  )

  let numerator_scaled_s_over_sqrt = doit(
    inverse_laplace_transform(
      @symcore.int(7) *
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let numerator_scaled_s_over_sqrt_str = @symprint.pretty_string(
    numerator_scaled_s_over_sqrt,
  )
  assert_true(
    !numerator_scaled_s_over_sqrt_str.contains("InverseLaplaceTransform") &&
    numerator_scaled_s_over_sqrt_str.contains("erfc") &&
    numerator_scaled_s_over_sqrt_str.contains("Heaviside"),
  )

  let sqrt_linear_over_s_three_halves = doit(
    inverse_laplace_transform(
      (a ^ @symcore.int(2)) *
      (s ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + a) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let sqrt_linear_over_s_three_halves_str = @symprint.pretty_string(
    sqrt_linear_over_s_three_halves,
  )
  assert_true(
    !sqrt_linear_over_s_three_halves_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_over_s_three_halves_str.contains("erfc") &&
    sqrt_linear_over_s_three_halves_str.contains("Heaviside"),
  )

  let scaled_sqrt_linear_over_s_three_halves = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
      (@symelem.sqrt(@symcore.int(2) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_linear_over_s_three_halves_str = @symprint.pretty_string(
    scaled_sqrt_linear_over_s_three_halves,
  )
  assert_true(
    !scaled_sqrt_linear_over_s_three_halves_str.contains(
      "InverseLaplaceTransform",
    ) &&
    scaled_sqrt_linear_over_s_three_halves_str.contains("erfc") &&
    scaled_sqrt_linear_over_s_three_halves_str.contains("Heaviside"),
  )

  let scaled_sqrt_ratio = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(-2)) *
      (s ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_ratio_str = @symprint.pretty_string(scaled_sqrt_ratio)
  assert_true(
    !scaled_sqrt_ratio_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_ratio_str.contains("erfc") &&
    scaled_sqrt_ratio_str.contains("Heaviside"),
  )

  let scaled_sqrt_ratio_general = doit(
    inverse_laplace_transform(
      (@symcore.int(6) * @symelem.sqrt(s) + @symcore.int(-4)) *
      ((@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_ratio_general_str = @symprint.pretty_string(
    scaled_sqrt_ratio_general,
  )
  assert_true(
    !scaled_sqrt_ratio_general_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_ratio_general_str.contains("erfc") &&
    scaled_sqrt_ratio_general_str.contains("Heaviside"),
  )

  let mixed_sqrt_shifted_linear = doit(
    inverse_laplace_transform(
      (a - b) *
      @symelem.sqrt(s) *
      ((@symelem.sqrt(s) + @symelem.sqrt(a)) ^ @symcore.int(-1)) *
      ((s - b) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let mixed_sqrt_shifted_linear_str = @symprint.pretty_string(
    mixed_sqrt_shifted_linear,
  )
  assert_true(
    !mixed_sqrt_shifted_linear_str.contains("InverseLaplaceTransform") &&
    (
      mixed_sqrt_shifted_linear_str.contains("erf") ||
      mixed_sqrt_shifted_linear_str.contains("erfc")
    ) &&
    mixed_sqrt_shifted_linear_str.contains("Heaviside"),
  )

  let scaled_mixed_sqrt_shifted_linear = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(5) * s) *
      ((@symcore.int(7) * s + @symcore.int(-14)) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let scaled_mixed_sqrt_shifted_linear_str = @symprint.pretty_string(
    scaled_mixed_sqrt_shifted_linear,
  )
  assert_true(
    !scaled_mixed_sqrt_shifted_linear_str.contains("InverseLaplaceTransform") &&
    (
      scaled_mixed_sqrt_shifted_linear_str.contains("erf") ||
      scaled_mixed_sqrt_shifted_linear_str.contains("erfc")
    ) &&
    scaled_mixed_sqrt_shifted_linear_str.contains("Heaviside"),
  )

  let mixed_recip_sqrt_shifted_linear = doit(
    inverse_laplace_transform(
      (a - b) *
      @symelem.sqrt(b) *
      ((s - b) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symelem.sqrt(a)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let mixed_recip_sqrt_shifted_linear_str = @symprint.pretty_string(
    mixed_recip_sqrt_shifted_linear,
  )
  assert_true(
    !mixed_recip_sqrt_shifted_linear_str.contains("InverseLaplaceTransform") &&
    (
      mixed_recip_sqrt_shifted_linear_str.contains("erf") ||
      mixed_recip_sqrt_shifted_linear_str.contains("erfc")
    ) &&
    mixed_recip_sqrt_shifted_linear_str.contains("Heaviside"),
  )

  let sqrt_linear_squared = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2),
      s,
      x,
    ),
  )
  let sqrt_linear_squared_str = @symprint.pretty_string(sqrt_linear_squared)
  assert_true(
    !sqrt_linear_squared_str.contains("InverseLaplaceTransform") &&
    (
      sqrt_linear_squared_str.contains("erf") ||
      sqrt_linear_squared_str.contains("erfc")
    ) &&
    sqrt_linear_squared_str.contains("Heaviside"),
  )

  let sqrt_linear_squared_over_s = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let sqrt_linear_squared_over_s_str = @symprint.pretty_string(
    sqrt_linear_squared_over_s,
  )
  assert_true(
    !sqrt_linear_squared_over_s_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_squared_over_s_str.contains("erfc") &&
    sqrt_linear_squared_over_s_str.contains("Heaviside"),
  )

  let scaled_sqrt_linear_squared_over_s = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-2)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_linear_squared_over_s_str = @symprint.pretty_string(
    scaled_sqrt_linear_squared_over_s,
  )
  assert_true(
    !scaled_sqrt_linear_squared_over_s_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_linear_squared_over_s_str.contains("erfc") &&
    scaled_sqrt_linear_squared_over_s_str.contains("Heaviside"),
  )

  let sqrt_linear_squared_over_sqrt = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let sqrt_linear_squared_over_sqrt_str = @symprint.pretty_string(
    sqrt_linear_squared_over_sqrt,
  )
  assert_true(
    !sqrt_linear_squared_over_sqrt_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_squared_over_sqrt_str.contains("erfc") &&
    sqrt_linear_squared_over_sqrt_str.contains("Heaviside"),
  )

  let scaled_sqrt_linear_squared_over_sqrt = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-2)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_linear_squared_over_sqrt_str = @symprint.pretty_string(
    scaled_sqrt_linear_squared_over_sqrt,
  )
  assert_true(
    !scaled_sqrt_linear_squared_over_sqrt_str.contains(
      "InverseLaplaceTransform",
    ) &&
    scaled_sqrt_linear_squared_over_sqrt_str.contains("erfc") &&
    scaled_sqrt_linear_squared_over_sqrt_str.contains("Heaviside"),
  )

  let sqrt_linear_cubed = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3),
      s,
      x,
    ),
  )
  let sqrt_linear_cubed_str = @symprint.pretty_string(sqrt_linear_cubed)
  assert_true(
    !sqrt_linear_cubed_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_cubed_str.contains("erfc") &&
    sqrt_linear_cubed_str.contains("Heaviside"),
  )

  let sqrt_over_sqrt_linear_cubed = doit(
    inverse_laplace_transform(
      @symelem.sqrt(s) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  let sqrt_over_sqrt_linear_cubed_str = @symprint.pretty_string(
    sqrt_over_sqrt_linear_cubed,
  )
  assert_true(
    !sqrt_over_sqrt_linear_cubed_str.contains("InverseLaplaceTransform") &&
    sqrt_over_sqrt_linear_cubed_str.contains("erfc") &&
    sqrt_over_sqrt_linear_cubed_str.contains("Heaviside"),
  )

  let scaled_sqrt_over_sqrt_linear_cubed = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(5) * s) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-3)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_over_sqrt_linear_cubed_str = @symprint.pretty_string(
    scaled_sqrt_over_sqrt_linear_cubed,
  )
  assert_true(
    !scaled_sqrt_over_sqrt_linear_cubed_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_over_sqrt_linear_cubed_str.contains("erfc") &&
    scaled_sqrt_over_sqrt_linear_cubed_str.contains("Heaviside"),
  )

  let sqrt_linear_cubed_over_sqrt = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  let sqrt_linear_cubed_over_sqrt_str = @symprint.pretty_string(
    sqrt_linear_cubed_over_sqrt,
  )
  assert_true(
    !sqrt_linear_cubed_over_sqrt_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_cubed_over_sqrt_str.contains("erfc") &&
    sqrt_linear_cubed_over_sqrt_str.contains("Heaviside"),
  )

  let scaled_sqrt_linear_cubed_over_sqrt = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-3)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_linear_cubed_over_sqrt_str = @symprint.pretty_string(
    scaled_sqrt_linear_cubed_over_sqrt,
  )
  assert_true(
    !scaled_sqrt_linear_cubed_over_sqrt_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_linear_cubed_over_sqrt_str.contains("erfc") &&
    scaled_sqrt_linear_cubed_over_sqrt_str.contains("Heaviside"),
  )

  let sqrt_linear_quartic = doit(
    inverse_laplace_transform(
      @symcore.int(3) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-4)),
      s,
      x,
    ),
  )
  let sqrt_linear_quartic_str = @symprint.pretty_string(sqrt_linear_quartic)
  assert_true(
    !sqrt_linear_quartic_str.contains("InverseLaplaceTransform") &&
    sqrt_linear_quartic_str.contains("erfc") &&
    sqrt_linear_quartic_str.contains("Heaviside"),
  )

  let scaled_sqrt_linear_squared = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2),
      s,
      x,
    ),
  )
  let scaled_sqrt_linear_squared_str = @symprint.pretty_string(
    scaled_sqrt_linear_squared,
  )
  assert_true(
    !scaled_sqrt_linear_squared_str.contains("InverseLaplaceTransform") &&
    (
      scaled_sqrt_linear_squared_str.contains("erf") ||
      scaled_sqrt_linear_squared_str.contains("erfc")
    ) &&
    scaled_sqrt_linear_squared_str.contains("Heaviside"),
  )

  let scaled_sqrt_linear_cubed = doit(
    inverse_laplace_transform(
      (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3),
      s,
      x,
    ),
  )
  let scaled_sqrt_linear_cubed_str = @symprint.pretty_string(
    scaled_sqrt_linear_cubed,
  )
  assert_true(
    !scaled_sqrt_linear_cubed_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_linear_cubed_str.contains("erfc") &&
    scaled_sqrt_linear_cubed_str.contains("Heaviside"),
  )

  let scaled_sqrt_linear_quartic = doit(
    inverse_laplace_transform(
      @symcore.int(5) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-4)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_linear_quartic_str = @symprint.pretty_string(
    scaled_sqrt_linear_quartic,
  )
  assert_true(
    !scaled_sqrt_linear_quartic_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_linear_quartic_str.contains("erfc") &&
    scaled_sqrt_linear_quartic_str.contains("Heaviside"),
  )

  let shifted_sqrt_over_linear = doit(
    inverse_laplace_transform(
      @symelem.sqrt(s + @symcore.int(3)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let shifted_sqrt_over_linear_str = @symprint.pretty_string(
    shifted_sqrt_over_linear,
  )
  assert_true(
    !shifted_sqrt_over_linear_str.contains("InverseLaplaceTransform") &&
    shifted_sqrt_over_linear_str.contains("Heaviside") &&
    (
      shifted_sqrt_over_linear_str.contains("erf") ||
      shifted_sqrt_over_linear_str.contains("sqrt")
    ),
  )

  let scaled_shifted_sqrt_over_linear = doit(
    inverse_laplace_transform(
      @symelem.sqrt(@symcore.int(5) * s + @symcore.int(10)) *
      ((@symcore.int(3) * s + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let scaled_shifted_sqrt_over_linear_str = @symprint.pretty_string(
    scaled_shifted_sqrt_over_linear,
  )
  assert_true(
    !scaled_shifted_sqrt_over_linear_str.contains("InverseLaplaceTransform") &&
    scaled_shifted_sqrt_over_linear_str.contains("erf") &&
    scaled_shifted_sqrt_over_linear_str.contains("Heaviside"),
  )

  let scaled_sqrt_ratio_squared = doit(
    inverse_laplace_transform(
      ((@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(2)) *
      (s ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  let scaled_sqrt_ratio_squared_str = @symprint.pretty_string(
    scaled_sqrt_ratio_squared,
  )
  assert_true(
    !scaled_sqrt_ratio_squared_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_ratio_squared_str.contains("erfc") &&
    scaled_sqrt_ratio_squared_str.contains("Heaviside"),
  )

  let scaled_sqrt_ratio_squared_general = doit(
    inverse_laplace_transform(
      (
        (@symcore.int(6) * @symelem.sqrt(s) + @symcore.int(-4)) ^
        @symcore.int(2)
      ) *
      ((@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-2)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_ratio_squared_general_str = @symprint.pretty_string(
    scaled_sqrt_ratio_squared_general,
  )
  assert_true(
    !scaled_sqrt_ratio_squared_general_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_ratio_squared_general_str.contains("erfc") &&
    scaled_sqrt_ratio_squared_general_str.contains("Heaviside"),
  )

  let scaled_sqrt_ratio_cubed = doit(
    inverse_laplace_transform(
      ((@symelem.sqrt(s) + @symcore.int(-2)) ^ @symcore.int(3)) *
      (s ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(2)) ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  let scaled_sqrt_ratio_cubed_str = @symprint.pretty_string(
    scaled_sqrt_ratio_cubed,
  )
  assert_true(
    !scaled_sqrt_ratio_cubed_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_ratio_cubed_str.contains("erfc") &&
    scaled_sqrt_ratio_cubed_str.contains("Heaviside"),
  )

  let scaled_sqrt_ratio_cubed_general = doit(
    inverse_laplace_transform(
      (
        (@symcore.int(6) * @symelem.sqrt(s) + @symcore.int(-4)) ^
        @symcore.int(3)
      ) *
      ((@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-3)
      ),
      s,
      x,
    ),
  )
  let scaled_sqrt_ratio_cubed_general_str = @symprint.pretty_string(
    scaled_sqrt_ratio_cubed_general,
  )
  assert_true(
    !scaled_sqrt_ratio_cubed_general_str.contains("InverseLaplaceTransform") &&
    scaled_sqrt_ratio_cubed_general_str.contains("erfc") &&
    scaled_sqrt_ratio_cubed_general_str.contains("Heaviside"),
  )

  let root_then_linear = doit(
    inverse_laplace_transform(
      (@symelem.sqrt(s + @symcore.int(3)) ^ @symcore.int(-1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let linear_then_root = doit(
    inverse_laplace_transform(
      ((s + @symcore.int(1)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_true(
    !@symprint.pretty_string(linear_then_root).contains(
      "InverseLaplaceTransform",
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(root_then_linear),
      @symsimplify.simplify(linear_then_root),
    ),
    0,
  )

  let sorted_three_poles = doit(
    inverse_laplace_transform(
      ((s - @symcore.int(2)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)) *
      ((@symelem.sqrt(s) + @symcore.int(3)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let reordered_three_poles = doit(
    inverse_laplace_transform(
      ((@symelem.sqrt(s) + @symcore.int(3)) ^ @symcore.int(-1)) *
      ((s - @symcore.int(2)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_true(
    !@symprint.pretty_string(reordered_three_poles).contains(
      "InverseLaplaceTransform",
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(sorted_three_poles),
      @symsimplify.simplify(reordered_three_poles),
    ),
    0,
  )

  let scaled_three_poles = doit(
    inverse_laplace_transform(
      ((@symcore.int(9) * s + @symcore.int(-1)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)) *
      (
        (@symcore.int(3) * @symelem.sqrt(s) + @symcore.int(2)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let scaled_three_poles_str = @symprint.pretty_string(scaled_three_poles)
  assert_true(
    !scaled_three_poles_str.contains("InverseLaplaceTransform") &&
    scaled_three_poles_str.contains("erf") &&
    scaled_three_poles_str.contains("Heaviside"),
  )

  let scaled_s_linear_three_poles = doit(
    inverse_laplace_transform(
      ((@symcore.int(2) * s) ^ @symcore.int(-1)) *
      ((@symcore.int(3) * s + @symcore.int(-6)) ^ @symcore.int(-1)) *
      (@symelem.sqrt(@symcore.int(5) * s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let scaled_s_linear_three_poles_str = @symprint.pretty_string(
    scaled_s_linear_three_poles,
  )
  assert_true(
    !scaled_s_linear_three_poles_str.contains("InverseLaplaceTransform") &&
    scaled_s_linear_three_poles_str.contains("erf") &&
    scaled_s_linear_three_poles_str.contains("Heaviside"),
  )

  let f_of_s = @symcore.raw_function("f", [s])
  let delayed_constant_inverse = doit(
    inverse_laplace_transform(a * @symelem.exp(@symcore.int(-3) * s), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      delayed_constant_inverse,
      a * @symcore.raw_function("DiracDelta", [x - @symcore.int(3)]),
    ),
    0,
  )

  let constant_delta_inverse = doit(inverse_laplace_transform(a, s, x))
  assert_eq(
    @symcore.compare_expr(constant_delta_inverse, a * @symspec.dirac_delta(x)),
    0,
  )

  let reciprocal_simple_inverse = doit(
    inverse_laplace_transform(a * (s ^ @symcore.int(-1)), s, x),
  )
  assert_eq(
    @symcore.compare_expr(reciprocal_simple_inverse, a * @symspec.heaviside(x)),
    0,
  )

  let reciprocal_public_default = @symintegrals.inverse_laplace_transform_eval(
    a * (s ^ @symcore.int(-1)),
    s,
    x,
  )
  assert_eq(
    @symcore.compare_expr(reciprocal_public_default, a * @symspec.heaviside(x)),
    0,
  )
  assert_true(@symcore.tuple_items(reciprocal_public_default) is None)

  let reciprocal_public_simplified = @symintegrals.inverse_laplace_transform_eval(
    a * (s ^ @symcore.int(-1)),
    s,
    x,
    simplify=true,
  )
  assert_eq(
    @symcore.compare_expr(
      reciprocal_public_simplified,
      a * @symspec.heaviside(x),
    ),
    0,
  )

  let reciprocal_public_with_conditions = @symintegrals.inverse_laplace_transform_eval(
    a * (s ^ @symcore.int(-1)),
    s,
    x,
    noconds=false,
  )
  match @symcore.tuple_items(reciprocal_public_with_conditions) {
    Some([value, cond]) => {
      assert_eq(@symcore.compare_expr(value, a * @symspec.heaviside(x)), 0)
      assert_eq(@symcore.compare_expr(cond, @symcore.Expr::Boolean(true)), 0)
    }
    _ =>
      fail("expected Tuple from inverse_laplace_transform_eval noconds=false")
  }

  let polynomial_delta_inverse = doit(
    inverse_laplace_transform(
      @symcore.int(1) +
      @symcore.int(2) * s +
      @symcore.int(3) * (s ^ @symcore.int(2)) +
      @symcore.int(5) * (s ^ @symcore.int(3)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      polynomial_delta_inverse,
      @symspec.dirac_delta(x) +
      @symcore.int(2) *
      @symcore.raw_function("DiracDelta", [x, @symcore.int(1)]) +
      @symcore.int(3) *
      @symcore.raw_function("DiracDelta", [x, @symcore.int(2)]) +
      @symcore.int(5) *
      @symcore.raw_function("DiracDelta", [x, @symcore.int(3)]),
    ),
    0,
  )

  let sparse_polynomial_delta_inverse = doit(
    inverse_laplace_transform((s ^ @symcore.int(4)) + @symcore.int(2), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      sparse_polynomial_delta_inverse,
      @symcore.int(2) * @symspec.dirac_delta(x) +
      @symcore.raw_function("DiracDelta", [x, @symcore.int(4)]),
    ),
    0,
  )

  let time_diff_inverse = doit(
    inverse_laplace_transform((s ^ @symcore.int(42)) * f_of_s, s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      time_diff_inverse,
      @symcore.raw_function("Derivative", [
        inverse_laplace_transform(f_of_s, s, x),
        x,
        @symcore.int(42),
      ]),
    ),
    0,
  )

  let mixed_time_diff_inverse = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(2)) *
      (f_of_s + (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1))),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(
        mixed_time_diff_inverse -
        (
          @symcore.raw_function("Derivative", [
            inverse_laplace_transform(f_of_s, s, x),
            x,
            @symcore.int(2),
          ]) -
          @symelem.sin(x) * @symspec.heaviside(x) +
          @symspec.dirac_delta(x)
        ),
      ),
      @symcore.int(0),
    ),
    0,
  )

  let delayed_bessel_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-1) * a * s) *
      (
        @symelem.sqrt(@symcore.int(1) + (s ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  assert_eq(
    @symprint.pretty_string(delayed_bessel_inverse).contains(
      "InverseLaplaceTransform",
    ),
    true,
  )

  let delayed_numeric_bessel_inverse = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(-2) * s) *
      (
        @symelem.sqrt(@symcore.int(1) + (s ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let delayed_numeric_bessel_str = @symprint.pretty_string(
    delayed_numeric_bessel_inverse,
  )
  assert_true(!delayed_numeric_bessel_str.contains("InverseLaplaceTransform"))
  assert_true(delayed_numeric_bessel_str.contains("besselj"))
  assert_true(delayed_numeric_bessel_str.contains("x - 2"))

  let exp_normalized_inverse = doit(
    inverse_laplace_transform(
      (
        (s ^ @symcore.int(2)) * @symelem.exp(@symcore.int(2) * s) +
        @symcore.int(4) * @symelem.exp(s) +
        @symcore.int(-4)
      ) *
      @symelem.exp(@symcore.int(-2) * s) *
      (s ^ @symcore.int(-1)) *
      (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let exp_normalized_str = @symprint.pretty_string(exp_normalized_inverse)
  assert_true(!exp_normalized_str.contains("InverseLaplaceTransform"))
  assert_true(exp_normalized_str.contains("x - 2"))
  assert_true(exp_normalized_str.contains("x - 1"))
  assert_true(exp_normalized_str.contains("cos"))
  let exp_normalized_expected = @symelem.cos(x) * @symspec.heaviside(x) +
    @symcore.int(4) *
    @symelem.cos(x - @symcore.int(2)) *
    @symspec.heaviside(x - @symcore.int(2)) -
    @symcore.int(4) *
    @symelem.cos(x - @symcore.int(1)) *
    @symspec.heaviside(x - @symcore.int(1)) -
    @symcore.int(4) * @symspec.heaviside(x - @symcore.int(2)) +
    @symcore.int(4) * @symspec.heaviside(x - @symcore.int(1))
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(exp_normalized_inverse - exp_normalized_expected),
      @symcore.int(0),
    ),
    0,
  )

  let improper_quadratic_remainder_inverse = doit(
    inverse_laplace_transform(
      ((s ^ @symcore.int(2)) + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(improper_quadratic_remainder_inverse),
      @symsimplify.simplify(
        @symcore.raw_function("DiracDelta", [x, @symcore.int(1)]) -
        @symspec.dirac_delta(x) +
        @symcore.int(2) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let three_linear_apart_inverse = doit(
    inverse_laplace_transform(
      (s * (s + @symcore.int(1)) * (s + @symcore.int(2))) ^ @symcore.int(-1),
      s,
      x,
    ),
  )
  let half = @symcore.rational_from_ints(1, 2)
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(three_linear_apart_inverse),
      @symsimplify.simplify(
        half * @symspec.heaviside(x) +
        @symcore.int(-1) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) +
        half * @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let four_linear_apart_inverse = doit(
    inverse_laplace_transform(
      (
        s *
        (s + @symcore.int(1)) *
        (s + @symcore.int(2)) *
        (s + @symcore.int(3))
      ) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  let sixth = @symcore.rational_from_ints(1, 6)
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(four_linear_apart_inverse),
      @symsimplify.simplify(
        sixth * @symspec.heaviside(x) +
        @symcore.int(-1) *
        half *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) +
        half * @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x) +
        @symcore.int(-1) *
        sixth *
        @symelem.exp(@symcore.int(-3) * x) *
        @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let repeated_linear_apart_inverse = doit(
    inverse_laplace_transform(
      (((s + @symcore.int(1)) ^ @symcore.int(2)) * (s + @symcore.int(2))) ^
      @symcore.int(-1),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(repeated_linear_apart_inverse),
      @symsimplify.simplify(
        x * @symelem.exp(@symcore.int(-1) * x) * @symspec.heaviside(x) +
        @symcore.int(-1) *
        @symelem.exp(@symcore.int(-1) * x) *
        @symspec.heaviside(x) +
        @symelem.exp(@symcore.int(-2) * x) * @symspec.heaviside(x),
      ),
    ),
    0,
  )

  let eye2 = @symmatrices.eye(2) catch { _ => fail("eye failed") }
  let diagm = @symmatrices.matrix([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(2)],
  ]) catch {
    _ => fail("matrix failed")
  }
  let resolvent = (eye2.scalar_mul(s) - diagm).inv() catch {
    _ => fail("inverse failed")
  }
  let matrix_inverse = @symintegrals.inverse_laplace_transform_matrix(
    resolvent, s, x,
  ) catch {
    _ => fail("matrix ilt failed")
  }
  assert_eq(
    @symcore.compare_expr(
      matrix_inverse.getitem(0, 0) catch {
        _ => fail("getitem failed")
      },
      @symelem.exp(x) * @symspec.heaviside(x),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      matrix_inverse.getitem(0, 1) catch {
        _ => fail("getitem failed")
      },
      @symcore.int(0),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      matrix_inverse.getitem(1, 0) catch {
        _ => fail("getitem failed")
      },
      @symcore.int(0),
    ),
    0,
  )
  assert_eq(
    @symcore.compare_expr(
      matrix_inverse.getitem(1, 1) catch {
        _ => fail("getitem failed")
      },
      @symelem.exp(@symcore.int(2) * x) * @symspec.heaviside(x),
    ),
    0,
  )

  let r = @symcore.Expr::Symbol("r")
  let positive_shift_object = doit(
    inverse_laplace_transform(@symelem.exp(@symcore.int(2) * s), s, x),
  )
  assert_true(
    @symprint.pretty_string(positive_shift_object).contains(
      "InverseLaplaceTransform",
    ),
  )

  let positive_shift_product_object = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      positive_shift_product_object,
      inverse_laplace_transform(
        @symelem.exp(@symcore.int(2) * s) *
        ((s + @symcore.int(1)) ^ @symcore.int(-1)),
        s,
        x,
      ),
    ),
    0,
  )

  let positive_shift_scaled_object = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(1)) * @symelem.exp(@symcore.int(2) * s),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      positive_shift_scaled_object,
      @symelem.exp(@symcore.int(1)) *
      inverse_laplace_transform(@symelem.exp(@symcore.int(2) * s), s, x),
    ),
    0,
  )

  let positive_shift_offset_delta = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(positive_shift_offset_delta),
      @symsimplify.simplify(
        @symelem.exp(@symcore.int(1)) *
        @symcore.raw_function("DiracDelta", [x + @symcore.int(2)]),
      ),
    ),
    0,
  )

  let positive_shift_offset_product = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      @symsimplify.simplify(positive_shift_offset_product),
      @symsimplify.simplify(
        @symelem.exp(@symcore.int(-1) * x + @symcore.int(-1)) *
        @symspec.heaviside(x + @symcore.int(2)),
      ),
    ),
    0,
  )

  let positive_shift_offset_double_pole = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      (s ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      positive_shift_offset_double_pole,
      @symcore.int(-1) *
      @symelem.exp(@symcore.int(1)) *
      @symelem.log(
        @symelem.exp_polar(@symcore.int(-2)) *
        @symelem.exp(@symcore.int(-1) * x),
      ) *
      @symspec.heaviside(x + @symcore.int(2)),
    ),
    0,
  )

  let positive_shift_offset_shifted_double_pole = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      ((s + @symcore.int(1)) ^ @symcore.int(-2)),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      positive_shift_offset_shifted_double_pole,
      @symcore.int(-1) *
      @symelem.exp(@symcore.int(-1) * x + @symcore.int(-1)) *
      @symelem.log(
        @symelem.exp_polar(@symcore.int(-2)) *
        @symelem.exp(@symcore.int(-1) * x),
      ) *
      @symspec.heaviside(x + @symcore.int(2)),
    ),
    0,
  )

  let positive_shift_offset_triple_pole = doit(
    inverse_laplace_transform(
      @symelem.exp(@symcore.int(2) * s + @symcore.int(1)) *
      (s ^ @symcore.int(-3)),
      s,
      x,
    ),
  )
  let branch_log = @symelem.log(
    @symelem.exp_polar(@symcore.int(-2)) * @symelem.exp(@symcore.int(-1) * x),
  )
  assert_eq(
    @symcore.compare_expr(
      positive_shift_offset_triple_pole,
      @symcore.rational_from_ints(1, 2) *
      @symelem.exp(@symcore.int(1)) *
      (branch_log ^ @symcore.int(2)) *
      @symspec.heaviside(x + @symcore.int(2)),
    ),
    0,
  )

  let symbolic_shift_object = doit(
    inverse_laplace_transform(@symelem.exp(r * s), s, x),
  )
  assert_true(
    @symprint.pretty_string(symbolic_shift_object).contains(
      "InverseLaplaceTransform",
    ),
  )

  let symbolic_shift_noconds = @symintegrals.inverse_laplace_transform_eval(
    @symelem.exp(r * s),
    s,
    x,
    noconds=false,
  )
  match @symcore.tuple_items(symbolic_shift_noconds) {
    Some([value, cond]) => {
      assert_true(
        @symprint.pretty_string(value).contains("InverseLaplaceTransform"),
      )
      assert_eq(@symcore.compare_expr(cond, @symcore.Expr::Boolean(true)), 0)
    }
    _ =>
      fail("expected Tuple from inverse_laplace_transform_eval noconds=false")
  }

  let cos_object = doit(inverse_laplace_transform(@symelem.cos(s), s, x))
  assert_true(
    @symprint.pretty_string(cos_object).contains("InverseLaplaceTransform"),
  )

  let known_frequency_shift = doit(
    inverse_laplace_transform(@symelem.sin(s - @symcore.int(2)), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      known_frequency_shift,
      @symelem.exp(@symcore.int(-2) * x) *
      inverse_laplace_transform(@symelem.sin(s), s, x),
    ),
    0,
  )

  let gamma_frequency_shift = doit(
    inverse_laplace_transform(@symspec.gamma(s - @symcore.int(1)), s, x),
  )
  assert_eq(
    @symcore.compare_expr(
      gamma_frequency_shift,
      @symelem.exp(@symcore.int(-1) * x) *
      inverse_laplace_transform(@symspec.gamma(s), s, x),
    ),
    0,
  )

  let positive_arg_shift_object = doit(
    inverse_laplace_transform(@symelem.sin(s + @symcore.int(2)), s, x),
  )
  assert_true(
    @symprint.pretty_string(positive_arg_shift_object).contains(
      "InverseLaplaceTransform",
    ),
  )

  let unknown_arg_shift_source = @symcore.raw_function("F", [s - a])
  let unknown_arg_shift_object = doit(
    inverse_laplace_transform(unknown_arg_shift_source, s, x),
  )
  assert_eq(
    @symprint.pretty_string(unknown_arg_shift_object),
    @symprint.pretty_string(
      inverse_laplace_transform(unknown_arg_shift_source, s, x),
    ),
  )

  let binary_frequency_shift_object = doit(
    inverse_laplace_transform(
      @symspec.besselj(@symcore.int(0), s - @symcore.int(1)),
      s,
      x,
    ),
  )
  assert_eq(
    @symprint.pretty_string(binary_frequency_shift_object),
    @symprint.pretty_string(
      inverse_laplace_transform(
        @symspec.besselj(@symcore.int(0), s - @symcore.int(1)),
        s,
        x,
      ),
    ),
  )

  let z = @symcore.Expr::Symbol("z")
  let generic_complex_shift = doit(
    inverse_laplace_transform(@symelem.exp(z * s), s, x),
  )
  assert_true(
    @symprint.pretty_string(generic_complex_shift).contains(
      "InverseLaplaceTransform",
    ),
  )

  let mixed_shift_sum = doit(
    inverse_laplace_transform(
      @symcore.int(2) * @symelem.exp(@symcore.int(3) * s) +
      @symcore.int(-5) * @symelem.exp(@symcore.int(-7) * s),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      mixed_shift_sum,
      @symcore.int(2) *
      inverse_laplace_transform(@symelem.exp(@symcore.int(3) * s), s, x) +
      @symcore.int(-5) *
      @symcore.raw_function("DiracDelta", [@symcore.int(-7) + x]),
    ),
    0,
  )

  let additive_time_diff = doit(
    inverse_laplace_transform(
      (s ^ @symcore.int(2)) *
      (
        f_of_s +
        (((a ^ @symcore.int(2)) + (s ^ @symcore.int(2))) ^ @symcore.int(-1))
      ),
      s,
      x,
    ),
  )
  assert_eq(
    @symcore.compare_expr(
      additive_time_diff,
      @symcore.raw_function("Derivative", [
        inverse_laplace_transform(f_of_s, s, x),
        x,
        @symcore.int(2),
      ]) +
      (
        @symcore.raw_function("DiracDelta", [x]) +
        @symcore.int(-1) *
        @symelem.sqrt(a ^ @symcore.int(2)) *
        @symelem.sin(x * @symelem.sqrt(a ^ @symcore.int(2))) *
        @symspec.heaviside(x)
      ),
    ),
    0,
  )
}

///|
test "symintegrals quadrature and intpoly exact stage 6 paths" {
  let (leg_nodes, leg_weights) = gauss_legendre(3, n_digits=5)
  assert_true(leg_nodes.length() == 3 && leg_weights.length() == 3)
  assert_true(
    approx_double(leg_nodes[0], -0.7746, eps=1.0e-3) &&
    approx_double(leg_nodes[1], 0.0, eps=1.0e-8) &&
    approx_double(leg_nodes[2], 0.7746, eps=1.0e-3),
  )
  assert_true(
    approx_double(leg_weights[0], 0.55556, eps=1.0e-4) &&
    approx_double(leg_weights[1], 0.88889, eps=1.0e-4) &&
    approx_double(leg_weights[2], 0.55556, eps=1.0e-4),
  )

  let (lob_nodes, lob_weights) = gauss_lobatto(4, n_digits=5)
  assert_true(
    approx_double(lob_nodes[0], -1.0, eps=1.0e-8) &&
    approx_double(lob_nodes[3], 1.0, eps=1.0e-8) &&
    approx_double(lob_weights[0], 1.0 / 6.0, eps=1.0e-4) &&
    approx_double(lob_weights[3], 1.0 / 6.0, eps=1.0e-4),
  )

  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let square = unit_square_polygon()
  assert_eq(
    @symprint.pretty_string(
      polytope_integrate(square, @symcore.int(1), vars=[x, y]),
    ),
    "1",
  )
  assert_eq(
    @symprint.pretty_string(polytope_integrate(square, x * y, vars=[x, y])),
    "1/4",
  )
  let bulk = polytope_integrate_many(square, [@symcore.int(1), x, y, x * y], vars=[
    x, y,
  ])
  assert_eq(@symprint.pretty_string(bulk[x]), "1/2")
  assert_eq(@symprint.pretty_string(bulk[y]), "1/2")
  let upto = polytope_integrate_upto(square, 2, vars=[x, y])
  assert_eq(@symprint.pretty_string(upto[x ^ @symcore.int(2)]), "1/3")
  assert_eq(@symprint.pretty_string(upto[y ^ @symcore.int(2)]), "1/3")

  let seg = @symgeometry.segment(
    @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
    @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
  )
  assert_eq(
    @symprint.pretty_string(segment_integrate(seg, x + y, vars=[x, y])),
    "sqrt(2)",
  )
}
