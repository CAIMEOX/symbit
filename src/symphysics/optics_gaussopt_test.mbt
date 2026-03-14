///|
fn gaussopt_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  guard (try! @sympy_physics.expr_equal(ours, rhs)) else {
    fail("\{context}: ours=\{ours}; expected=\{rhs}")
  }
}

///|
fn gaussopt_assert_matrix_equal(
  lhs : ExplicitMatrix,
  rhs : Array[String],
  context : String,
) -> Unit raise {
  let mut idx = 0
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      let ours = @symprint.to_string(try! lhs.get(i, j))
      guard (try! @sympy_physics.expr_equal(ours, rhs[idx])) else {
        fail("\{context}[\{idx}]: ours=\{ours}; expected=\{rhs[idx]}")
      }
      idx = idx + 1
    }
  }
}

///|
fn gaussopt_rational(num : Int, den : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
test "physics.optics.gaussopt: matrix surface and transforms" {
  let mat = ray_transfer_matrix(
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  )
  try! gaussopt_assert_matrix_equal(
    mat.matrix(),
    ["1", "2", "3", "4"],
    "RayTransferMatrix rows",
  )
  try! gaussopt_assert_matrix_equal(
    try! ray_transfer_matrix_from_matrix(
      explicit_matrix_from_ints([[1, 2], [3, 4]]),
    ).matrix(),
    ["1", "2", "3", "4"],
    "RayTransferMatrix from matrix",
  )
  try! gaussopt_assert_expr_equal(mat.a(), "1", "RayTransferMatrix.A")
  try! gaussopt_assert_expr_equal(mat.b(), "2", "RayTransferMatrix.B")
  try! gaussopt_assert_expr_equal(mat.c(), "3", "RayTransferMatrix.C")
  try! gaussopt_assert_expr_equal(mat.d(), "4", "RayTransferMatrix.D")

  let d = @symcore.symbol("d")
  let f = @symcore.symbol("f")
  let h = @symcore.symbol("h")
  let angle = @symcore.symbol("angle")
  let n1 = @symcore.symbol("n1")
  let n2 = @symcore.symbol("n2")
  let radius = @symcore.symbol("R")

  try! gaussopt_assert_matrix_equal(
    free_space(d).matrix(),
    ["1", "d", "0", "1"],
    "FreeSpace",
  )
  try! gaussopt_assert_matrix_equal(
    flat_refraction(n1, n2).matrix(),
    ["1", "0", "0", "n1/n2"],
    "FlatRefraction",
  )
  try! gaussopt_assert_matrix_equal(
    curved_refraction(radius, n1, n2).matrix(),
    ["1", "0", "(n1 - n2)/(R*n2)", "n1/n2"],
    "CurvedRefraction",
  )
  try! gaussopt_assert_matrix_equal(
    flat_mirror().matrix(),
    ["1", "0", "0", "1"],
    "FlatMirror",
  )
  try! gaussopt_assert_matrix_equal(
    curved_mirror(radius).matrix(),
    ["1", "0", "-2/R", "1"],
    "CurvedMirror",
  )
  try! gaussopt_assert_matrix_equal(
    thin_lens(f).matrix(),
    ["1", "0", "-1/f", "1"],
    "ThinLens",
  )

  let mul = try! curved_mirror(radius).apply_matrix(free_space(d))
  try! gaussopt_assert_matrix_equal(
    mul.matrix(),
    ["1", "d", "-2/R", "1 - 2*d/R"],
    "CurvedMirror*FreeSpace",
  )

  let ray = geometric_ray(h, angle)
  try! gaussopt_assert_matrix_equal(
    ray.matrix(),
    ["h", "angle"],
    "GeometricRay",
  )
  let pushed = try! free_space(d).apply_geometric_ray(ray)
  try! gaussopt_assert_expr_equal(
    pushed.height(),
    "angle*d + h",
    "GeometricRay height",
  )
  try! gaussopt_assert_expr_equal(pushed.angle(), "angle", "GeometricRay angle")
}

///|
test "physics.optics.gaussopt: beam and conjugation formulas" {
  let z = @symcore.symbol("z")
  let wavelen = @symcore.symbol("wavelen")
  let w0 = @symcore.symbol("w_0")
  let s_in = @symcore.symbol("s_in")
  let z_r_in = @symcore.symbol("z_r_in")
  let f = @symcore.symbol("f")
  let l = @symcore.symbol("l")
  let w_i = @symcore.symbol("w_i")
  let w_o = @symcore.symbol("w_o")

  try! gaussopt_assert_expr_equal(
    waist2rayleigh(@symcore.symbol("w"), wavelen),
    "pi*w**2/wavelen",
    "waist2rayleigh",
  )
  try! gaussopt_assert_expr_equal(
    rayleigh2waist(@symcore.symbol("z_r"), wavelen),
    "sqrt(wavelen*z_r)/sqrt(pi)",
    "rayleigh2waist",
  )

  let p = try! beam_parameter(l, z, w=Some(w0))
  try! gaussopt_assert_expr_equal(
    p.radius(),
    "z*(pi**2*w_0**4/(l**2*z**2) + 1)",
    "BeamParameter.radius",
  )
  try! gaussopt_assert_expr_equal(
    p.w(),
    "sqrt(l**2*z**2/(pi**2*w_0**4) + 1)*sqrt(w_0**2)",
    "BeamParameter.w",
  )
  try! gaussopt_assert_expr_equal(p.w_0(), "sqrt(w_0**2)", "BeamParameter.w_0")
  try! gaussopt_assert_expr_equal(
    p.divergence(),
    "l/(pi*sqrt(w_0**2))",
    "BeamParameter.divergence",
  )
  try! gaussopt_assert_expr_equal(
    p.gouy(),
    "atan2(z, pi*w_0**2/l)",
    "BeamParameter.gouy",
  )
  try! gaussopt_assert_expr_equal(
    p.waist_approximation_limit(),
    "2*l/pi",
    "BeamParameter.waist_approximation_limit",
  )

  try! gaussopt_assert_expr_equal(
    geometric_conj_ab(@symcore.symbol("a"), @symcore.symbol("b")),
    "a*b/(a + b)",
    "geometric_conj_ab",
  )
  try! gaussopt_assert_expr_equal(
    geometric_conj_af(@symcore.symbol("a"), f),
    "a*f/(a - f)",
    "geometric_conj_af",
  )
  try! gaussopt_assert_expr_equal(
    geometric_conj_bf(@symcore.symbol("b"), f),
    "b*f/(b - f)",
    "geometric_conj_bf",
  )
  try! gaussopt_assert_expr_equal(
    geometric_conj_ab(@symcore.symbol("oo"), @symcore.symbol("b")),
    "b",
    "geometric_conj_ab oo",
  )
  try! gaussopt_assert_expr_equal(
    geometric_conj_ab(@symcore.symbol("a"), @symcore.symbol("oo")),
    "a",
    "geometric_conj_ab oo rhs",
  )

  let conj = gaussian_conj(s_in, z_r_in, f)
  try! gaussopt_assert_expr_equal(
    conj.0,
    "1/(-1/(s_in + z_r_in**2/(-f + s_in)) + 1/f)",
    "gaussian_conj s_out",
  )
  try! gaussopt_assert_expr_equal(
    conj.1,
    "z_r_in/(1 - s_in**2/f**2 + z_r_in**2/f**2)",
    "gaussian_conj z_r_out",
  )
  try! gaussopt_assert_expr_equal(
    conj.2,
    "1/sqrt(1 - s_in**2/f**2 + z_r_in**2/f**2)",
    "gaussian_conj m",
  )

  let gb = try! conjugate_gauss_beams(l, w_i, w_o, f=Some(f))
  try! gaussopt_assert_expr_equal(
    gb.0,
    "f*(1 - sqrt(w_i**2/w_o**2 - pi**2*w_i**4/(f**2*l**2)))",
    "conjugate_gauss_beams s_in",
  )
  try! gaussopt_assert_expr_equal(
    gb.1,
    "1/(-1/(f*(1 - sqrt(w_i**2/w_o**2 - pi**2*w_i**4/(f**2*l**2))) + pi**2*w_i**4/(l**2*(f*(1 - sqrt(w_i**2/w_o**2 - pi**2*w_i**4/(f**2*l**2))) - f))) + 1/f)",
    "conjugate_gauss_beams s_out",
  )
  try! gaussopt_assert_expr_equal(gb.2, "f", "conjugate_gauss_beams f")

  let p_num = try! beam_parameter(
    gaussopt_rational(53, 100000000),
    @symcore.int(1),
    w=Some(gaussopt_rational(1, 1000)),
    n=@symcore.int(2),
  )
  try! gaussopt_assert_expr_equal(
    p_num.q(),
    "1 + 20000000*I*pi/5300000",
    "BeamParameter numeric q",
  )
}
