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
