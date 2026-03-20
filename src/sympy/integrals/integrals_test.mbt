///|
fn approx_double(lhs : Double, rhs : Double, eps? : Double = 1.0e-4) -> Bool {
  (lhs - rhs).abs() <= eps
}

///|
fn unit_square_polygon() -> @symgeometry.Polygon raise {
  match
    (@symgeometry.polygon([
      @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
      @symgeometry.point2d(@symcore.int(0), @symcore.int(1)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
      @symgeometry.point2d(@symcore.int(1), @symcore.int(0)),
    ])) {
    @symgeometry.GeometryEntity::Polygon(poly) => poly
    _ => panic()
  }
}

///|
test "symintegrals integral constructors and doit" {
  let x = @symcore.symbol("x")
  inspect(
    @symprint.to_string(integral(x, limits=[integral_limit([x])])),
    content="Integral(x, Tuple(x))",
  )
  inspect(
    @symprint.to_string(
      doit(integral(x ^ @symcore.int(2), limits=[integral_limit([x])])),
    ),
    content="1/3*x**3",
  )
  inspect(
    @symprint.to_string(laplace_transform(x, x, @symcore.symbol("s"))),
    content="LaplaceTransform(x, x, s)",
  )
}

///|
test "symintegrals integrate main entrypoint handles core indefinite families" {
  let x = @symcore.symbol("x")
  inspect(
    @symprint.to_string(integrate(x, limits=[integral_limit([x])])),
    content="1/2*x**2",
  )
  inspect(
    @symprint.to_string(
      integrate(@symelem.exp(@symcore.int(2) * x), limits=[integral_limit([x])]),
    ),
    content="1/2*exp((2*x))",
  )
  inspect(
    @symprint.to_string(
      integrate(@symelem.sin(@symcore.int(3) * x), limits=[integral_limit([x])]),
    ),
    content="-1/3*cos((3*x))",
  )
  inspect(
    @symprint.to_string(
      integrate(x ^ @symcore.int(-1), limits=[integral_limit([x])]),
    ),
    content="log(x)",
  )
  inspect(
    @symprint.to_string(
      integrate(
        @symelem.sqrt(@symcore.int(1) - (x ^ @symcore.int(2))) ^
        @symcore.int(-1),
        limits=[integral_limit([x])],
      ),
    ),
    content="asin(x)",
  )
  inspect(
    @symprint.to_string(
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
  let x = @symcore.symbol("x")
  let delta_expr = @symspec.dirac_delta(x - @symcore.int(2)) * x
  inspect(
    @symprint.to_string(
      integrate(delta_expr, limits=[
        integral_limit([x, @symcore.int(0), @symcore.int(5)]),
      ]),
    ),
    content="2",
  )
  inspect(
    @symprint.to_string(
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
  let x = @symcore.symbol("x")
  inspect(
    @symprint.to_string(manualintegrate(@symelem.log(x), x)),
    content="x*log(x) + -1*x",
  )
  inspect(
    @symprint.to_string(heurisch_integrate(x * @symelem.exp(x), x)),
    content="exp(x)*(x + -1)",
  )
  inspect(
    @symprint.to_string(risch_integrate(@symelem.sin(x), "x").unwrap()),
    content="-1*cos(x)",
  )
  inspect(
    @symprint.to_string(
      rde_integrate(
        @symcore.int(1) *
        (((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
        "x",
      ).unwrap(),
    ),
    content="atan(x)",
  )
  inspect(
    @symprint.to_string(heurisch_wrapper(x * @symelem.exp(x), "x")),
    content="exp(x)*(x + -1)",
  )
  let comps = components(
    @symelem.sin(x) * @symelem.exp(x ^ @symcore.int(2)),
    "x",
  )
  inspect(
    if comps.any(fn(item) { @symprint.to_string(item) == "x**2" }) {
      "true"
    } else {
      "false"
    },
    content="true",
  )
  inspect(
    if comps.any(fn(item) { @symprint.to_string(item) == "exp((x**2))" }) {
      "true"
    } else {
      "false"
    },
    content="true",
  )
}

///|
test "symintegrals singularity integration keeps symbolic singularity family" {
  let x = @symcore.symbol("x")
  let a = @symcore.symbol("a")
  inspect(
    @symprint.to_string(
      integrate(@symspec.singularity_function(x, a, @symcore.int(0)), limits=[
        integral_limit([x]),
      ]),
    ),
    content="SingularityFunction(x, a, 1)",
  )
}

///|
test "symintegrals line integrate and delta symbolic bounds keep stage 1 objects usable" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let t = @symcore.symbol("t")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let c = @symgeometry.curve(
    [@symelem.exp(t) + @symcore.int(1), @symelem.exp(t) + @symcore.int(-1)],
    t,
    @symcore.int(0),
    @symelem.log(@symcore.int(2)),
  )
  inspect(
    @symprint.to_string(line_integrate(x + y, c, [x, y])),
    content="3*sqrt(2)",
  )
  inspect(
    if @symprint.to_string(
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
  let x = @symcore.symbol("x")
  let r = @symcore.symbol("r")
  let k = @symcore.symbol("k")
  let a = @symcore.symbol("a")
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
    @symprint.to_string(sine_transform(x, x, k)),
    "SineTransform(x, x, k)",
  )
  assert_eq(
    @symprint.to_string(cosine_transform(x, x, k)),
    "CosineTransform(x, x, k)",
  )
  assert_eq(
    @symprint.to_string(hankel_transform(r, r, k, @symcore.int(1))),
    "HankelTransform(r, r, k, 1)",
  )

  let sine_eval = @symprint.to_string(
    sine_transform_eval(@symelem.exp(@symcore.int(-2) * x), x, k),
  )
  let cosine_eval = @symprint.to_string(
    cosine_transform_eval(@symelem.exp(@symcore.int(-2) * x), x, k),
  )
  let hankel_eval = @symprint.to_string(
    hankel_transform_eval(
      r * @symelem.exp(@symcore.int(-2) * r),
      r,
      k,
      @symcore.int(1),
    ),
  )
  let shifted_fourier_eval = @symprint.to_string(
    fourier_transform_eval(shifted_gaussian, x, k),
  )
  let shifted_inverse_fourier_eval = @symprint.to_string(
    doit(
      inverse_fourier_transform(
        doit(fourier_transform(shifted_gaussian, x, k)),
        k,
        x,
      ),
    ),
  )
  let half_line_fourier_eval = @symprint.to_string(
    doit(fourier_transform(half_line_exp, x, k)),
  )
  let half_line_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(half_line_exp, x, k)),
      k,
      x,
    ),
  )
  let half_line_x_fourier_eval = @symprint.to_string(
    doit(fourier_transform(half_line_x_exp, x, k)),
  )
  let half_line_x_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(half_line_x_exp, x, k)),
      k,
      x,
    ),
  )
  let half_line_sin_fourier_eval = @symprint.to_string(
    doit(fourier_transform(half_line_sin, x, k)),
  )
  let half_line_sin_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(half_line_sin, x, k)),
      k,
      x,
    ),
  )
  let abs_decay_fourier_eval = @symprint.to_string(
    doit(fourier_transform(abs_decay, x, k)),
  )
  let abs_decay_inverse_fourier = doit(
    inverse_fourier_transform(doit(fourier_transform(abs_decay, x, k)), k, x),
  )
  let symbolic_half_line_fourier_eval = @symprint.to_string(
    doit(
      fourier_transform(
        @symelem.exp(@symcore.int(-1) * a * x) * @symspec.heaviside(x),
        x,
        k,
      ),
    ),
  )
  let box_window_fourier_eval = @symprint.to_string(
    doit(fourier_transform(box_window, x, k)),
  )
  let box_window_inverse_fourier = doit(
    inverse_fourier_transform(doit(fourier_transform(box_window, x, k)), k, x),
  )
  let triangle_window_fourier_eval = @symprint.to_string(
    doit(fourier_transform(triangle_window, x, k)),
  )
  let triangle_window_inverse_fourier = doit(
    inverse_fourier_transform(
      doit(fourier_transform(triangle_window, x, k)),
      k,
      x,
    ),
  )
  let triangle_window_inverse_fourier_eval = @symprint.to_string(
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
  let symbolic_sinc_box_eval = @symprint.to_string(symbolic_sinc_box)
  let symbolic_sinc_triangle_eval = @symprint.to_string(symbolic_sinc_triangle)
  let symbolic_cosine_gaussian_eval = @symprint.to_string(
    doit(
      cosine_transform(
        @symelem.exp(@symcore.int(-1) * a * (x ^ @symcore.int(2))),
        x,
        k,
      ),
    ),
  )
  let cosine_shifted_recip_eval = @symprint.to_string(
    doit(cosine_transform(cosine_shifted_recip, x, k)),
  )
  let cosine_sqrt_recip_eval = @symprint.to_string(
    doit(cosine_transform(cosine_sqrt_recip, x, k)),
  )
  let sine_half_power_eval = @symprint.to_string(
    doit(sine_transform(@symelem.sqrt(x) ^ @symcore.int(-1), x, k)),
  )
  let inverse_sine_half_power_eval = @symprint.to_string(
    doit(inverse_sine_transform(@symelem.sqrt(k) ^ @symcore.int(-1), k, x)),
  )
  let sine_three_halves_eval = @symprint.to_string(
    doit(
      sine_transform(
        @symelem.sqrt(x) ^ @symcore.int(-1) ^ @symcore.int(3),
        x,
        k,
      ),
    ),
  )
  let sine_gaussian_eval = @symprint.to_string(
    doit(sine_transform(sine_gaussian, x, k)),
  )
  let inverse_sine_gaussian_eval = @symprint.to_string(
    doit(
      inverse_sine_transform(doit(sine_transform(sine_gaussian, x, k)), k, x),
    ),
  )
  let cosine_gaussian_eval = @symprint.to_string(
    cosine_transform_eval(cosine_gaussian, x, k),
  )
  let inverse_cosine_gaussian_eval = @symprint.to_string(
    doit(
      inverse_cosine_transform(
        doit(cosine_transform(cosine_gaussian, x, k)),
        k,
        x,
      ),
    ),
  )
  let inverse_cosine_sqrt_recip_eval = @symprint.to_string(
    doit(
      inverse_cosine_transform(
        doit(cosine_transform(cosine_sqrt_recip, x, k)),
        k,
        x,
      ),
    ),
  )
  let sine_log_over_x_eval = @symprint.to_string(
    doit(sine_transform(sine_log_over_x, x, k)),
  )
  let cosine_sqrt_decay_eval = @symprint.to_string(
    doit(cosine_transform(cosine_sqrt_decay, x, k)),
  )
  let hankel_gaussian_eval = @symprint.to_string(
    hankel_transform_eval(
      @symelem.exp(@symcore.int(-2) * (r ^ @symcore.int(2))),
      r,
      k,
      @symcore.int(0),
    ),
  )
  let inverse_hankel_gaussian_eval = @symprint.to_string(
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
    !triangle_window_inverse_fourier_eval.contains(
        "InverseFourierTransform",
      )
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
  assert_true(!inverse_cosine_sqrt_recip_eval.contains("InverseCosineTransform"))
  assert_true(!sine_log_over_x_eval.contains("SineTransform"))
  assert_true(!cosine_sqrt_decay_eval.contains("CosineTransform"))
  assert_true(!hankel_gaussian_eval.contains("HankelTransform"))
  assert_true(!inverse_hankel_gaussian_eval.contains("InverseHankelTransform"))
}

///|
test "symintegrals Mellin special-function rules evaluate" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let bp = @symcore.symbol("bp")
  let rho = @symcore.symbol("rho")
  let f_of_x = @symcore.raw_function("f", [x])
  let half = @symcore.rational_from_ints(1, 2)

  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform((x + @symcore.int(1)) ^ (@symcore.int(-1) * rho), x, s),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            ((@symcore.int(1) - x) ^ (b - @symcore.int(1))) *
            @symspec.heaviside(@symcore.int(1) - x),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            ((x - @symcore.int(1)) ^ (b - @symcore.int(1))) *
            @symspec.heaviside(x - @symcore.int(1)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(mellin_transform(@symspec.erf(@symelem.sqrt(x)), x, s)),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symelem.abs(@symcore.int(1) - x) ^ (@symcore.int(-1) * rho),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            (@symelem.log(x) ^ @symcore.int(4)) *
            @symspec.heaviside(@symcore.int(1) - x),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            (@symelem.log(x) ^ @symcore.int(3)) *
            @symspec.heaviside(x - @symcore.int(1)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(mellin_transform(@symelem.log(x + @symcore.int(1)), x, s)),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symelem.log((x ^ @symcore.int(-1)) + @symcore.int(1)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            ((x ^ a) - (bp ^ a)) * ((x - bp) ^ @symcore.int(-1)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  let sqrt_shift = @symelem.sqrt(x + (bp ^ @symcore.int(2))) + bp
  assert_true(
    !@symprint.to_string(doit(mellin_transform(sqrt_shift ^ a, x, s))).contains(
        "MellinTransform",
      )
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            (sqrt_shift ^ a) *
            (@symelem.sqrt(x + (bp ^ @symcore.int(2))) ^ @symcore.int(-1)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(@symelem.log(@symelem.abs(@symcore.int(1) - x)), x, s),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symelem.log(@symelem.abs(@symcore.int(1) - (x ^ @symcore.int(-1)))),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(doit(mellin_transform(@symspec.e1(x), x, s))).contains(
        "MellinTransform",
      )
  )
  assert_true(
    !@symprint.to_string(
        doit(mellin_transform(@symspec.expint(@symcore.int(2), x), x, s)),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(doit(mellin_transform(@symspec.si(x), x, s))).contains(
        "MellinTransform",
      )
  )
  assert_true(
    !@symprint.to_string(
        doit(mellin_transform(@symspec.ci(@symelem.sqrt(x)), x, s)),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselj(a, @symcore.int(2) * @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.bessely(a, @symcore.int(2) * @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselk(a, @symcore.int(2) * @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besseli(a, @symelem.sqrt(x)) *
            @symspec.besselk(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselj(a, @symelem.sqrt(x)) ^ @symcore.int(2),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselj(a, @symelem.sqrt(x)) *
            @symspec.besselj(@symcore.int(-1) * a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselj(a, @symelem.sqrt(x)) *
            @symspec.bessely(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselj(a, @symelem.sqrt(x)) *
            @symspec.besselj(b, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselj(a - @symcore.int(1), @symelem.sqrt(x)) *
            @symspec.besselj(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besselj(a, @symelem.sqrt(x)) *
            @symspec.bessely(b, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symspec.besseli(b, @symelem.sqrt(x)) *
            @symspec.besselk(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symelem.sin(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symelem.cos(@symelem.sqrt(x)) * @symspec.besselj(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symelem.sin(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          mellin_transform(
            @symelem.cos(@symelem.sqrt(x)) * @symspec.bessely(a, @symelem.sqrt(x)),
            x,
            s,
          ),
        ),
      ).contains("MellinTransform")
  )

  let generic_mellin_eval = @symprint.to_string(
    mellin_transform_eval(f_of_x, x, s),
  )
  assert_true(generic_mellin_eval.contains("MellinTransform(f(x), x, s)"))

  let partial_generic_mellin_eval = @symprint.to_string(
    mellin_transform_eval(f_of_x + @symelem.exp(@symcore.int(-1) * x), x, s),
  )
  assert_true(
    partial_generic_mellin_eval.contains("MellinTransform(f(x), x, s)") &&
        partial_generic_mellin_eval.contains("gamma(s)")
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
          @symelem.sqrt(@symcore.symbol("pi")) *
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
        (@symelem.sqrt(@symcore.symbol("pi")) * @symspec.gamma(s))
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
      ((@symelem.sqrt(@symcore.symbol("pi")) * s) ^ @symcore.int(-1)),
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
      @symcore.symbol("pi") *
      ((s * @symelem.sin(@symcore.symbol("pi") * s * half)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_sec = doit(
    inverse_mellin_transform(
      @symcore.symbol("pi") *
      (@symelem.cos(@symcore.symbol("pi") * s) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_log_piecewise = doit(
    inverse_mellin_transform(
      @symcore.symbol("pi") *
      ((s * @symelem.sin(@symcore.symbol("pi") * s)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_sqrt_piecewise = doit(
    inverse_mellin_transform(
      @symcore.symbol("pi") *
      (
        (s * @symelem.sin(@symcore.int(2) * @symcore.symbol("pi") * s)) ^
        @symcore.int(-1)
      ),
      s,
      x,
    ),
  )
  let inv_tan_piecewise = doit(
    inverse_mellin_transform(
      @symcore.symbol("pi") *
      ((s * @symelem.tan(@symcore.symbol("pi") * s)) ^ @symcore.int(-1)),
      s,
      x,
    ),
  )
  let inv_cot_piecewise = doit(
    inverse_mellin_transform(
      @symcore.symbol("pi") *
      @symelem.cot(@symcore.symbol("pi") * s) *
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
      (@symcore.symbol("pi") ^ @symcore.int(-1)) *
      @symelem.cos(@symcore.symbol("pi") * (a * half - s)) *
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
      (@symelem.sqrt(@symcore.symbol("pi")) ^ @symcore.int(-1)) *
      (@symcore.int(4) ^ s) *
      @symelem.sin(@symcore.symbol("pi") * (a * half - s)) *
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
      (@symelem.sqrt(@symcore.symbol("pi")) ^ @symcore.int(-1)) *
      (@symcore.int(4) ^ s) *
      @symelem.cos(@symcore.symbol("pi") * (a * half - s)) *
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
      (@symelem.sqrt(@symcore.symbol("pi")) ^ @symcore.int(-1)) *
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
      (@symelem.sqrt(@symcore.symbol("pi")) ^ @symcore.int(-1)) *
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
      (@symcore.symbol("pi") ^ @symcore.int(-1)) *
      (@symcore.int(4) ^ s) *
      @symelem.cos(@symcore.symbol("pi") * ((a - b) * half + s)) *
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
      (@symcore.symbol("pi") ^ @symcore.int(-1)) *
      (@symelem.sqrt(@symcore.symbol("pi")) ^ @symcore.int(-1)) *
      @symelem.cos(@symcore.symbol("pi") * s) *
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
      @symelem.sin(@symcore.symbol("pi") * a) *
      @symspec.gamma(s) *
      @symspec.gamma(a + s) *
      @symspec.gamma(@symcore.int(1) - s) *
      @symspec.gamma(@symcore.int(1) - a - s) *
      (@symcore.symbol("pi") ^ @symcore.int(-1)),
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
  assert_eq(@symprint.to_string(inv_si), @symprint.to_string(@symspec.si(x)))
  assert_eq(
    @symprint.to_string(inv_ci_sqrt),
    @symprint.to_string(@symspec.ci(@symelem.sqrt(x))),
  )
  assert_eq(
    @symprint.to_string(inv_erf_sqrt),
    @symprint.to_string(@symspec.erf(@symelem.sqrt(x))),
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
  assert_true(@symprint.to_string(inv_sqrt_shift_recip).contains("sqrt"))
  assert_true(!@symprint.to_string(inv_besselj).contains("InverseMellinTransform"))
  assert_true(!@symprint.to_string(inv_bessely).contains("InverseMellinTransform"))
  assert_true(@symprint.to_string(inv_bessely).contains("bessely"))
  assert_true(!@symprint.to_string(inv_besselk).contains("InverseMellinTransform"))
  assert_true(!@symprint.to_string(inv_sin_besselj).contains("InverseMellinTransform"))
  assert_true(!@symprint.to_string(inv_cos_besselj).contains("InverseMellinTransform"))
  assert_true(!@symprint.to_string(inv_sin_bessely).contains("InverseMellinTransform"))
  assert_true(!@symprint.to_string(inv_cos_bessely).contains("InverseMellinTransform"))
  assert_true(
    @symprint.to_string(inv_sin_bessely).contains("sin") &&
        @symprint.to_string(inv_sin_bessely).contains("bessely")
  )
  assert_true(
    @symprint.to_string(inv_cos_bessely).contains("cos") &&
        @symprint.to_string(inv_cos_bessely).contains("bessely")
  )
  assert_true(!@symprint.to_string(inv_besselj_sq).contains("InverseMellinTransform"))
  assert_true(!@symprint.to_string(inv_besselj_pm).contains("InverseMellinTransform"))
  assert_true(!@symprint.to_string(inv_besselj_ab).contains("InverseMellinTransform"))
  assert_true(
    !@symprint.to_string(inv_besselj_bessely).contains(
        "InverseMellinTransform",
      )
  )
  assert_true(
    !@symprint.to_string(inv_besselj_bessely_same).contains(
        "InverseMellinTransform",
      )
  )
  assert_true(
    @symprint.to_string(inv_besselj_bessely_same).contains("besselj") &&
        @symprint.to_string(inv_besselj_bessely_same).contains("bessely")
  )
  assert_true(
    @symprint.to_string(inv_besselj_bessely).contains("besselj") &&
        @symprint.to_string(inv_besselj_bessely).contains("bessely")
  )
  assert_true(
    !@symprint.to_string(inv_difference_quotient).contains(
        "InverseMellinTransform",
      )
  )
  assert_true(!@symprint.to_string(inv_sqrt_shift).contains("InverseMellinTransform"))
  assert_true(
    !@symprint.to_string(inv_sqrt_shift_recip).contains(
        "InverseMellinTransform",
      )
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
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
  let a = @symcore.symbol("a")
  let f_of_x = @symcore.raw_function("f", [x])

  inspect(
    @symprint.to_string(
      doit(laplace_transform(@symspec.dirac_delta(x - @symcore.int(2)), x, s)),
    ),
    content="exp((-2*s))",
  )
  inspect(
    @symprint.to_string(
      doit(laplace_transform(@symspec.heaviside(x - @symcore.int(2)), x, s)),
    ),
    content="s**-1*exp((-2*s))",
  )
  inspect(
    @symprint.to_string(
      doit(
        laplace_transform(
          (x - @symcore.int(2)) * @symspec.heaviside(x - @symcore.int(2)),
          x,
          s,
        ),
      ),
    ),
    content="s**-2*exp((-2*s))",
  )

  let deriv_eval = @symprint.to_string(
    laplace_transform_eval(
      @symcore.raw_function("Derivative", [f_of_x, x]),
      x,
      s,
    ),
  )
  assert_true(deriv_eval.contains("LaplaceTransform(f(x), x, s)"))
  assert_true(deriv_eval.contains("f(0)"))

  assert_true(
    !@symprint.to_string(doit(laplace_transform(@symelem.sinh(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(doit(laplace_transform(@symelem.cosh(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(doit(laplace_transform(x * @symelem.sin(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(doit(laplace_transform(x * @symelem.cos(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(
        doit(laplace_transform(x * @symelem.sinh(x), x, s)),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(laplace_transform(x * @symelem.cosh(x), x, s)),
      ).contains("LaplaceTransform")
  )

  let generic_eval = @symprint.to_string(laplace_transform_eval(f_of_x, x, s))
  assert_true(generic_eval.contains("LaplaceTransform(f(x), x, s)"))
  assert_true(generic_eval.contains("oo"))

  let scaled_eval = @symprint.to_string(
    laplace_transform_eval(a * f_of_x, x, s),
  )
  assert_true(scaled_eval.contains("a*LaplaceTransform(f(x), x, s)"))

  let shifted_generic_eval = @symprint.to_string(
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
        )
  )

  let x_generic_eval = @symprint.to_string(
    laplace_transform_eval(x * f_of_x, x, s),
  )
  assert_true(x_generic_eval.contains("Derivative(LaplaceTransform(f(x), x, s), s)"))

  let poly_generic_eval = @symprint.to_string(
    laplace_transform_eval(
      (
        @symcore.int(2) * (x ^ @symcore.int(2)) +
        @symcore.int(3) * x +
        @symcore.int(4)
      ) *
      f_of_x,
      x,
      s,
    ),
  )
  assert_true(
    poly_generic_eval.contains(
          "Derivative(LaplaceTransform(f(x), x, s), s, 2)",
        ) ||
        poly_generic_eval.contains(
          "Derivative(LaplaceTransform(f(x), x, s), (s, 2))",
        )
  )
  assert_true(
    poly_generic_eval.contains(
        "Derivative(LaplaceTransform(f(x), x, s), s)",
      )
  )

  let sinh_generic_eval = @symprint.to_string(
    laplace_transform_eval(@symelem.sinh(a * x) * f_of_x, x, s),
  )
  let sinh_transform_count = sinh_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(sinh_transform_count >= 3 && sinh_generic_eval.contains("a"))

  let cosh_generic_eval = @symprint.to_string(
    laplace_transform_eval(@symelem.cosh(a * x) * f_of_x, x, s),
  )
  let cosh_transform_count = cosh_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(cosh_transform_count >= 3 && cosh_generic_eval.contains("a"))

  let sin_generic_eval = @symprint.to_string(
    laplace_transform_eval(@symelem.sin(a * x) * f_of_x, x, s),
  )
  let sin_transform_count = sin_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(
    sin_transform_count >= 3 &&
        sin_generic_eval.contains("I") &&
        sin_generic_eval.contains("a")
  )

  let cos_generic_eval = @symprint.to_string(
    laplace_transform_eval(@symelem.cos(a * x) * f_of_x, x, s),
  )
  let cos_transform_count = cos_generic_eval
    .split("LaplaceTransform(f(x), x,")
    .to_array()
    .length()
  assert_true(
    cos_transform_count >= 3 &&
        cos_generic_eval.contains("I") &&
        cos_generic_eval.contains("a")
  )
}

///|
test "symintegrals Laplace special-function rules evaluate" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
  let a = @symcore.symbol("a")
  let neg_half = @symcore.rational_from_ints(-1, 2)

  assert_true(
    !@symprint.to_string(doit(laplace_transform(@symspec.ci(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(doit(laplace_transform(@symspec.si(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(doit(laplace_transform(@symspec.shi(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(doit(laplace_transform(@symspec.chi(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(doit(laplace_transform(@symspec.e1(x), x, s))).contains(
        "LaplaceTransform",
      )
  )
  assert_true(
    !@symprint.to_string(
        doit(laplace_transform(@symspec.expint(@symcore.int(2), x), x, s)),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(laplace_transform(@symspec.expint(a, x), x, s)),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(laplace_transform(@symspec.erf(@symcore.int(2) * x), x, s)),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          laplace_transform(
            @symspec.besselj(@symcore.int(0), @symcore.int(2) * x),
            x,
            s,
          ),
        ),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          laplace_transform(
            x * @symspec.besselj(@symcore.int(0), @symcore.int(2) * x),
            x,
            s,
          ),
        ),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          laplace_transform(
            @symspec.besseli(@symcore.int(0), @symcore.int(2) * x),
            x,
            s,
          ),
        ),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          laplace_transform(
            x * @symspec.besseli(@symcore.int(0), @symcore.int(2) * x),
            x,
            s,
          ),
        ),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(laplace_transform(@symspec.fresnels(x), x, s)),
      ).contains("LaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(laplace_transform(@symspec.fresnelc(x), x, s)),
      ).contains("LaplaceTransform")
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

  assert_true(!@symprint.to_string(inv_ci).contains("InverseLaplaceTransform"))
  assert_true(!@symprint.to_string(inv_e1).contains("InverseLaplaceTransform"))
  assert_true(!@symprint.to_string(inv_expint2).contains("InverseLaplaceTransform"))

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
}

///|
test "symintegrals inverse Laplace transform objects roundtrip" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
  let t = @symcore.symbol("t")
  let f_t = @symcore.raw_function("f", [t])

  let same_var = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), s, t),
  )
  let renamed_var = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), s, x),
  )
  let wrong_freq = doit(
    inverse_laplace_transform(laplace_transform(f_t, t, s), x, t),
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
      @symsimplify.simplify(renamed_var),
      @symsimplify.simplify(
        @symcore.raw_function("f", [x]) * @symspec.heaviside(x),
      ),
    ),
    0,
  )
  assert_eq(
    @symprint.to_string(wrong_freq),
    @symprint.to_string(laplace_transform(f_t, t, s) * @symspec.dirac_delta(t)),
  )
}

///|
test "symintegrals inverse Laplace stage 5 delay and repeated linear poles" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")

  let delayed = @symprint.to_string(
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
  assert_true(delayed.contains("x + -2"))

  inspect(
    @symprint.to_string(
      doit(
        inverse_laplace_transform(
          (@symcore.int(2) * s + @symcore.int(4)) ^ @symcore.int(-3),
          s,
          x,
        ),
      ),
    ),
    content="1/16*x**2*exp((-2*x))*Heaviside(x)",
  )

  let shifted_quad = @symprint.to_string(
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
        shifted_quad.contains("Heaviside")
  )

  let shifted_quad_num = @symprint.to_string(
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
        shifted_quad_num.contains("Heaviside")
  )

  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            (((s + @symcore.int(1)) ^ @symcore.int(2)) - @symcore.int(4)) ^
            @symcore.int(-1),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
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
      ).contains("InverseLaplaceTransform")
  )

  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            ((s ^ @symcore.int(2)) - @symcore.int(1)) ^ @symcore.int(-1),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            ((s + @symcore.int(1)) * (s + @symcore.int(2))) ^ @symcore.int(-1),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            s * (((s + @symcore.int(1)) * (s + @symcore.int(2))) ^ @symcore.int(-1)),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            ((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-2),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            s * (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-2)),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            ((s ^ @symcore.int(2)) - @symcore.int(1)) ^ @symcore.int(-2),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            s * (((s ^ @symcore.int(2)) - @symcore.int(1)) ^ @symcore.int(-2)),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            (((s + @symcore.int(1)) ^ @symcore.int(2)) - @symcore.int(4)) ^
            @symcore.int(2) ^
            @symcore.int(-1),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
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
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
        doit(
          inverse_laplace_transform(
            (((s + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(4)) ^
            @symcore.int(2) ^
            @symcore.int(-1),
            s,
            x,
          ),
        ),
      ).contains("InverseLaplaceTransform")
  )
  assert_true(
    !@symprint.to_string(
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
      ).contains("InverseLaplaceTransform")
  )
}

///|
test "symintegrals quadrature and intpoly exact stage 6 paths" {
  let (leg_nodes, leg_weights) = gauss_legendre(3, n_digits=5)
  assert_true(leg_nodes.length() == 3 && leg_weights.length() == 3)
  assert_true(
    approx_double(leg_nodes[0], -0.7746, eps=1.0e-3) &&
        approx_double(leg_nodes[1], 0.0, eps=1.0e-8) &&
        approx_double(leg_nodes[2], 0.7746, eps=1.0e-3)
  )
  assert_true(
    approx_double(leg_weights[0], 0.55556, eps=1.0e-4) &&
        approx_double(leg_weights[1], 0.88889, eps=1.0e-4) &&
        approx_double(leg_weights[2], 0.55556, eps=1.0e-4)
  )

  let (lob_nodes, lob_weights) = gauss_lobatto(4, n_digits=5)
  assert_true(
    approx_double(lob_nodes[0], -1.0, eps=1.0e-8) &&
        approx_double(lob_nodes[3], 1.0, eps=1.0e-8) &&
        approx_double(lob_weights[0], 1.0 / 6.0, eps=1.0e-4) &&
        approx_double(lob_weights[3], 1.0 / 6.0, eps=1.0e-4)
  )

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let square = unit_square_polygon()
  assert_eq(
    @symprint.to_string(
      polytope_integrate(square, @symcore.int(1), vars=[x, y]),
    ),
    "1",
  )
  assert_eq(
    @symprint.to_string(polytope_integrate(square, x * y, vars=[x, y])),
    "1/4",
  )
  let bulk = polytope_integrate_many(square, [@symcore.int(1), x, y, x * y], vars=[
    x, y,
  ])
  assert_eq(@symprint.to_string(bulk[x]), "1/2")
  assert_eq(@symprint.to_string(bulk[y]), "1/2")
  let upto = polytope_integrate_upto(square, 2, vars=[x, y])
  assert_eq(@symprint.to_string(upto[x ^ @symcore.int(2)]), "1/3")
  assert_eq(@symprint.to_string(upto[y ^ @symcore.int(2)]), "1/3")

  let seg = @symgeometry.segment(
    @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
    @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
  )
  assert_eq(
    @symprint.to_string(segment_integrate(seg, x + y, vars=[x, y])),
    "sqrt(2)",
  )
}
