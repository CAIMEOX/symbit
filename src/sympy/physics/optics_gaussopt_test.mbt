///|
fn gaussopt_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = @symprint.pretty_string(lhs)
  assert_true(expr_equal(ours, rhs))
}

///|
fn gaussopt_assert_matrix_equal(
  lhs : ExplicitMatrix,
  rhs : Array[String],
  _context : String,
) -> Unit raise {
  let mut idx = 0
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      let ours = @symprint.pretty_string(lhs.get(i, j))
      assert_true(expr_equal(ours, rhs[idx]))
      idx = idx + 1
    }
  }
}

///|
fn gaussopt_rational(num : Int, den : Int) -> @symcore.Expr {
  @symcore.rational_from_ints(num, den) catch {
    _ => @symcore.function("Rational", [@symcore.int(num), @symcore.int(den)])
  }
}

///|
test "physics.optics.gaussopt: matrix surface and transforms" {
  let mat = ray_transfer_matrix(
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  )
  gaussopt_assert_matrix_equal(
    mat.matrix(),
    ["1", "2", "3", "4"],
    "RayTransferMatrix rows",
  )
  gaussopt_assert_matrix_equal(
    ray_transfer_matrix_from_matrix(explicit_matrix_from_ints([[1, 2], [3, 4]])).matrix(),
    ["1", "2", "3", "4"],
    "RayTransferMatrix from matrix",
  )
  gaussopt_assert_expr_equal(mat.a(), "1", "RayTransferMatrix.A")
  gaussopt_assert_expr_equal(mat.b(), "2", "RayTransferMatrix.B")
  gaussopt_assert_expr_equal(mat.c(), "3", "RayTransferMatrix.C")
  gaussopt_assert_expr_equal(mat.d(), "4", "RayTransferMatrix.D")

  let d = @symcore.Expr::Symbol("d")
  let f = @symcore.Expr::Symbol("f")
  let h = @symcore.Expr::Symbol("h")
  let angle = @symcore.Expr::Symbol("angle")
  let n1 = @symcore.Expr::Symbol("n1")
  let n2 = @symcore.Expr::Symbol("n2")
  let radius = @symcore.Expr::Symbol("R")

  gaussopt_assert_matrix_equal(
    free_space(d).matrix(),
    ["1", "d", "0", "1"],
    "FreeSpace",
  )
  gaussopt_assert_matrix_equal(
    flat_refraction(n1, n2).matrix(),
    ["1", "0", "0", "n1/n2"],
    "FlatRefraction",
  )
  gaussopt_assert_matrix_equal(
    curved_refraction(radius, n1, n2).matrix(),
    ["1", "0", "(n1 - n2)/(R*n2)", "n1/n2"],
    "CurvedRefraction",
  )
  gaussopt_assert_matrix_equal(
    flat_mirror().matrix(),
    ["1", "0", "0", "1"],
    "FlatMirror",
  )
  gaussopt_assert_matrix_equal(
    curved_mirror(radius).matrix(),
    ["1", "0", "-2/R", "1"],
    "CurvedMirror",
  )
  gaussopt_assert_matrix_equal(
    thin_lens(f).matrix(),
    ["1", "0", "-1/f", "1"],
    "ThinLens",
  )

  let mul = curved_mirror(radius).apply_matrix(free_space(d))
  gaussopt_assert_matrix_equal(
    mul.matrix(),
    ["1", "d", "-2/R", "1 - 2*d/R"],
    "CurvedMirror*FreeSpace",
  )

  let ray = geometric_ray(h, angle)
  gaussopt_assert_matrix_equal(ray.matrix(), ["h", "angle"], "GeometricRay")
  let pushed = free_space(d).apply_geometric_ray(ray)
  gaussopt_assert_expr_equal(
    pushed.height(),
    "angle*d + h",
    "GeometricRay height",
  )
  gaussopt_assert_expr_equal(pushed.angle(), "angle", "GeometricRay angle")
}

///|
test "physics.optics.gaussopt: beam and conjugation formulas" {
  let z = @symcore.Expr::Symbol("z")
  let wavelen = @symcore.Expr::Symbol("wavelen")
  let w0 = @symcore.Expr::Symbol("w_0")
  let s_in = @symcore.Expr::Symbol("s_in")
  let z_r_in = @symcore.Expr::Symbol("z_r_in")
  let f = @symcore.Expr::Symbol("f")
  let l = @symcore.Expr::Symbol("l")
  let w_i = @symcore.Expr::Symbol("w_i")
  let w_o = @symcore.Expr::Symbol("w_o")

  gaussopt_assert_expr_equal(
    waist2rayleigh(@symcore.Expr::Symbol("w"), wavelen),
    "pi*w**2/wavelen",
    "waist2rayleigh",
  )
  gaussopt_assert_expr_equal(
    rayleigh2waist(@symcore.Expr::Symbol("z_r"), wavelen),
    "sqrt(wavelen*z_r)/sqrt(pi)",
    "rayleigh2waist",
  )

  let p = beam_parameter(l, z, w=Some(w0))
  gaussopt_assert_expr_equal(
    p.radius(),
    "z*(pi**2*w_0**4/(l**2*z**2) + 1)",
    "BeamParameter.radius",
  )
  gaussopt_assert_expr_equal(
    p.w(),
    "sqrt(l**2*z**2/(pi**2*w_0**4) + 1)*sqrt(w_0**2)",
    "BeamParameter.w",
  )
  gaussopt_assert_expr_equal(p.w_0(), "sqrt(w_0**2)", "BeamParameter.w_0")
  gaussopt_assert_expr_equal(
    p.divergence(),
    "l/(pi*sqrt(w_0**2))",
    "BeamParameter.divergence",
  )
  gaussopt_assert_expr_equal(
    p.gouy(),
    "atan2(z, pi*w_0**2/l)",
    "BeamParameter.gouy",
  )
  gaussopt_assert_expr_equal(
    p.waist_approximation_limit(),
    "2*l/pi",
    "BeamParameter.waist_approximation_limit",
  )

  gaussopt_assert_expr_equal(
    geometric_conj_ab(@symcore.Expr::Symbol("a"), @symcore.Expr::Symbol("b")),
    "a*b/(a + b)",
    "geometric_conj_ab",
  )
  gaussopt_assert_expr_equal(
    geometric_conj_af(@symcore.Expr::Symbol("a"), f),
    "a*f/(a - f)",
    "geometric_conj_af",
  )
  gaussopt_assert_expr_equal(
    geometric_conj_bf(@symcore.Expr::Symbol("b"), f),
    "b*f/(b - f)",
    "geometric_conj_bf",
  )
  gaussopt_assert_expr_equal(
    geometric_conj_ab(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
      @symcore.Expr::Symbol("b"),
    ),
    "b",
    "geometric_conj_ab oo",
  )
  gaussopt_assert_expr_equal(
    geometric_conj_ab(
      @symcore.Expr::Symbol("a"),
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
    ),
    "a",
    "geometric_conj_ab oo rhs",
  )

  let conj = gaussian_conj(s_in, z_r_in, f)
  gaussopt_assert_expr_equal(
    conj.0,
    "1/(-1/(s_in + z_r_in**2/(-f + s_in)) + 1/f)",
    "gaussian_conj s_out",
  )
  gaussopt_assert_expr_equal(
    conj.1,
    "z_r_in/(1 - s_in**2/f**2 + z_r_in**2/f**2)",
    "gaussian_conj z_r_out",
  )
  gaussopt_assert_expr_equal(
    conj.2,
    "1/sqrt(1 - s_in**2/f**2 + z_r_in**2/f**2)",
    "gaussian_conj m",
  )

  let gb = conjugate_gauss_beams(l, w_i, w_o, f=Some(f))
  gaussopt_assert_expr_equal(
    gb.0,
    "f*(1 - sqrt(w_i**2/w_o**2 - pi**2*w_i**4/(f**2*l**2)))",
    "conjugate_gauss_beams s_in",
  )
  gaussopt_assert_expr_equal(
    gb.1,
    "1/(-1/(f*(1 - sqrt(w_i**2/w_o**2 - pi**2*w_i**4/(f**2*l**2))) + pi**2*w_i**4/(l**2*(f*(1 - sqrt(w_i**2/w_o**2 - pi**2*w_i**4/(f**2*l**2))) - f))) + 1/f)",
    "conjugate_gauss_beams s_out",
  )
  gaussopt_assert_expr_equal(gb.2, "f", "conjugate_gauss_beams f")

  let p_num = beam_parameter(
    gaussopt_rational(53, 100000000),
    @symcore.int(1),
    w=Some(gaussopt_rational(1, 1000)),
    n=@symcore.int(2),
  )
  gaussopt_assert_expr_equal(
    p_num.q(),
    "1 + 20000000*I*pi/5300000",
    "BeamParameter numeric q",
  )
}
