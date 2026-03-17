///|
fn approx_double(lhs : Double, rhs : Double, eps? : Double = 1.0e-4) -> Bool {
  (lhs - rhs).abs() <= eps
}

///|
fn unit_square_polygon() -> @symgeometry.Polygon {
  match
    (try! @symgeometry.polygon([
      try! @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
      try! @symgeometry.point2d(@symcore.int(0), @symcore.int(1)),
      try! @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
      try! @symgeometry.point2d(@symcore.int(1), @symcore.int(0)),
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
  let c = try! @symgeometry.curve(
    [@symelem.exp(t) + @symcore.int(1), @symelem.exp(t) + @symcore.int(-1)],
    t,
    @symcore.int(0),
    @symelem.log(@symcore.int(2)),
  )
  inspect(
    @symprint.to_string(try! line_integrate(x + y, c, [x, y])),
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
  guard !sine_eval.contains("SineTransform") else {
    fail("sine transform stayed unevaluated")
  }
  guard !cosine_eval.contains("CosineTransform") else {
    fail("cosine transform stayed unevaluated")
  }
  guard !hankel_eval.contains("HankelTransform") else {
    fail("hankel transform stayed unevaluated")
  }
}

///|
test "symintegrals Laplace stage 5 shift and derivative rules evaluate" {
  let x = @symcore.symbol("x")
  let s = @symcore.symbol("s")
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
  guard deriv_eval.contains("LaplaceTransform(f(x), x, s)") else {
    fail("missing generic LaplaceTransform object in derivative rule")
  }
  guard deriv_eval.contains("f(0)") else {
    fail("missing initial value term in derivative rule")
  }

  guard !@symprint.to_string(doit(laplace_transform(@symelem.sinh(x), x, s))).contains(
    "LaplaceTransform",
  ) else {
    fail("sinh Laplace transform stayed unevaluated")
  }
  guard !@symprint.to_string(doit(laplace_transform(@symelem.cosh(x), x, s))).contains(
    "LaplaceTransform",
  ) else {
    fail("cosh Laplace transform stayed unevaluated")
  }
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
  guard delayed.contains("Heaviside") else {
    fail("delayed inverse Laplace missed Heaviside shift")
  }
  guard delayed.contains("x + -2") else {
    fail("delayed inverse Laplace missed time shift")
  }

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
  guard !shifted_quad.contains("InverseLaplaceTransform") &&
    shifted_quad.contains("Heaviside") else {
    fail("shifted quadratic inverse Laplace stayed unevaluated")
  }

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
  guard !shifted_quad_num.contains("InverseLaplaceTransform") &&
    shifted_quad_num.contains("Heaviside") else {
    fail("shifted quadratic numerator inverse Laplace stayed unevaluated")
  }

  guard !@symprint.to_string(
    doit(
      inverse_laplace_transform(
        ((s ^ @symcore.int(2)) - @symcore.int(1)) ^ @symcore.int(-1),
        s,
        x,
      ),
    ),
  ).contains("InverseLaplaceTransform") else {
    fail("hyperbolic inverse Laplace stayed unevaluated")
  }
}

///|
test "symintegrals quadrature and intpoly exact stage 6 paths" {
  let (leg_nodes, leg_weights) = try! gauss_legendre(3, n_digits=5)
  guard leg_nodes.length() == 3 && leg_weights.length() == 3 else {
    fail("gauss_legendre size mismatch")
  }
  guard approx_double(leg_nodes[0], -0.7746, eps=1.0e-3) &&
    approx_double(leg_nodes[1], 0.0, eps=1.0e-8) &&
    approx_double(leg_nodes[2], 0.7746, eps=1.0e-3) else {
    fail("gauss_legendre nodes mismatch")
  }
  guard approx_double(leg_weights[0], 0.55556, eps=1.0e-4) &&
    approx_double(leg_weights[1], 0.88889, eps=1.0e-4) &&
    approx_double(leg_weights[2], 0.55556, eps=1.0e-4) else {
    fail("gauss_legendre weights mismatch")
  }

  let (lob_nodes, lob_weights) = try! gauss_lobatto(4, n_digits=5)
  guard approx_double(lob_nodes[0], -1.0, eps=1.0e-8) &&
    approx_double(lob_nodes[3], 1.0, eps=1.0e-8) &&
    approx_double(lob_weights[0], 1.0 / 6.0, eps=1.0e-4) &&
    approx_double(lob_weights[3], 1.0 / 6.0, eps=1.0e-4) else {
    fail("gauss_lobatto edge data mismatch")
  }

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let square = unit_square_polygon()
  assert_eq(
    @symprint.to_string(
      try! polytope_integrate(square, @symcore.int(1), vars=[x, y]),
    ),
    "1",
  )
  assert_eq(
    @symprint.to_string(try! polytope_integrate(square, x * y, vars=[x, y])),
    "1/4",
  )
  let bulk = try! polytope_integrate_many(
    square,
    [@symcore.int(1), x, y, x * y],
    vars=[x, y],
  )
  assert_eq(@symprint.to_string(bulk[x]), "1/2")
  assert_eq(@symprint.to_string(bulk[y]), "1/2")
  let upto = try! polytope_integrate_upto(square, 2, vars=[x, y])
  assert_eq(@symprint.to_string(upto[x ^ @symcore.int(2)]), "1/3")
  assert_eq(@symprint.to_string(upto[y ^ @symcore.int(2)]), "1/3")

  let seg = try! @symgeometry.segment(
    try! @symgeometry.point2d(@symcore.int(0), @symcore.int(0)),
    try! @symgeometry.point2d(@symcore.int(1), @symcore.int(1)),
  )
  assert_eq(
    @symprint.to_string(try! segment_integrate(seg, x + y, vars=[x, y])),
    "sqrt(2)",
  )
}
