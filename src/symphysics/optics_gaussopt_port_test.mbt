///|
fn gaussopt_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  guard (try! @sympy_physics.expr_equal(ours, rhs)) else {
    fail("\{context}: ours=\{ours}; oracle=\{rhs}")
  }
}

///|
fn gaussopt_port_assert_matrix_equal(
  lhs : ExplicitMatrix,
  rhs : Array[String],
  context : String,
) -> Unit raise {
  let mut idx = 0
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      let ours = @symprint.to_string(try! lhs.get(i, j))
      guard (try! @sympy_physics.expr_equal(ours, rhs[idx])) else {
        fail("\{context}[\{idx}]: ours=\{ours}; oracle=\{rhs[idx]}")
      }
      idx = idx + 1
    }
  }
}

///|
fn gaussopt_symbols() -> (
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
) {
  (
    @symcore.symbol("d"),
    @symcore.symbol("f"),
    @symcore.symbol("h"),
    @symcore.symbol("angle"),
    @symcore.symbol("n1"),
    @symcore.symbol("n2"),
    @symcore.symbol("R"),
    @symcore.symbol("a"),
    @symcore.symbol("b"),
    @symcore.symbol("s_in"),
    @symcore.symbol("z_r_in"),
    @symcore.symbol("l"),
    @symcore.symbol("w_i"),
    @symcore.symbol("w_o"),
    @symcore.symbol("z"),
    @symcore.symbol("wavelen"),
  )
}

///|
test "physics.optics.gaussopt: matrix parity" {
  let (d, f, h, angle, n1, n2, radius, _, _, _, _, _, _, _, _, _) = gaussopt_symbols()
  try! gaussopt_port_assert_matrix_equal(
    ray_transfer_matrix(
      @symcore.int(1),
      @symcore.int(2),
      @symcore.int(3),
      @symcore.int(4),
    ).matrix(),
    try! @sympy_physics.optics_gaussopt_matrix("RayTransferMatrix(1, 2, 3, 4)"),
    "RayTransferMatrix parity",
  )
  try! gaussopt_port_assert_matrix_equal(
    free_space(d).matrix(),
    try! @sympy_physics.optics_gaussopt_matrix("FreeSpace(d)"),
    "FreeSpace parity",
  )
  try! gaussopt_port_assert_matrix_equal(
    flat_refraction(n1, n2).matrix(),
    try! @sympy_physics.optics_gaussopt_matrix("FlatRefraction(n1, n2)"),
    "FlatRefraction parity",
  )
  try! gaussopt_port_assert_matrix_equal(
    curved_refraction(radius, n1, n2).matrix(),
    try! @sympy_physics.optics_gaussopt_matrix("CurvedRefraction(R, n1, n2)"),
    "CurvedRefraction parity",
  )
  try! gaussopt_port_assert_matrix_equal(
    curved_mirror(radius).matrix(),
    try! @sympy_physics.optics_gaussopt_matrix("CurvedMirror(R)"),
    "CurvedMirror parity",
  )
  try! gaussopt_port_assert_matrix_equal(
    thin_lens(f).matrix(),
    try! @sympy_physics.optics_gaussopt_matrix("ThinLens(f)"),
    "ThinLens parity",
  )
  try! gaussopt_port_assert_matrix_equal(
    (try! free_space(d).apply_geometric_ray(geometric_ray(h, angle))).matrix(),
    try! @sympy_physics.optics_gaussopt_matrix(
      "FreeSpace(d)*GeometricRay(h, angle)",
    ),
    "GeometricRay transform parity",
  )
}

///|
test "physics.optics.gaussopt: beam property parity" {
  let (_, _, _, _, _, _, _, _, _, _, _, _, _, _, z, wavelen) = gaussopt_symbols()
  let w0 = @symcore.symbol("w_0")
  let beam = try! beam_parameter(wavelen, z, w=Some(w0))
  try! gaussopt_port_assert_expr_equal(
    beam.q(),
    try! @sympy_physics.optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).q",
    ),
    "BeamParameter.q parity",
  )
  try! gaussopt_port_assert_expr_equal(
    beam.radius(),
    try! @sympy_physics.optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).radius",
    ),
    "BeamParameter.radius parity",
  )
  try! gaussopt_port_assert_expr_equal(
    beam.w(),
    try! @sympy_physics.optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).w",
    ),
    "BeamParameter.w parity",
  )
  try! gaussopt_port_assert_expr_equal(
    beam.w_0(),
    try! @sympy_physics.optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).w_0",
    ),
    "BeamParameter.w_0 parity",
  )
  try! gaussopt_port_assert_expr_equal(
    beam.divergence(),
    try! @sympy_physics.optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).divergence",
    ),
    "BeamParameter.divergence parity",
  )
  try! gaussopt_port_assert_expr_equal(
    beam.gouy(),
    try! @sympy_physics.optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).gouy",
    ),
    "BeamParameter.gouy parity",
  )
  try! gaussopt_port_assert_expr_equal(
    beam.waist_approximation_limit(),
    try! @sympy_physics.optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).waist_approximation_limit",
    ),
    "BeamParameter.waist_approximation_limit parity",
  )
}

///|
test "physics.optics.gaussopt: beam transform parity" {
  let beam = try! beam_parameter(
    @symcore.int(3),
    @symcore.int(4),
    z_r=Some(@symcore.int(5)),
  )
  let pushed = try! thin_lens(@symcore.int(2)).apply_beam(beam)
  try! gaussopt_port_assert_expr_equal(
    pushed.q(),
    try! @sympy_physics.optics_gaussopt_eval(
      "(ThinLens(2)*BeamParameter(3, 4, z_r=5)).q",
    ),
    "ThinLens*BeamParameter q parity",
  )
  try! gaussopt_port_assert_expr_equal(
    pushed.z(),
    try! @sympy_physics.optics_gaussopt_eval(
      "(ThinLens(2)*BeamParameter(3, 4, z_r=5)).z",
    ),
    "ThinLens*BeamParameter z parity",
  )
  try! gaussopt_port_assert_expr_equal(
    pushed.z_r(),
    try! @sympy_physics.optics_gaussopt_eval(
      "(ThinLens(2)*BeamParameter(3, 4, z_r=5)).z_r",
    ),
    "ThinLens*BeamParameter z_r parity",
  )
}

///|
test "physics.optics.gaussopt: utility parity" {
  let (_, f, _, _, _, _, _, a, b, s_in, z_r_in, l, w_i, w_o, _, wavelen) = gaussopt_symbols()
  try! gaussopt_port_assert_expr_equal(
    waist2rayleigh(@symcore.symbol("w"), wavelen),
    try! @sympy_physics.optics_gaussopt_eval("waist2rayleigh(w, wavelen)"),
    "waist2rayleigh parity",
  )
  try! gaussopt_port_assert_expr_equal(
    rayleigh2waist(@symcore.symbol("z_r"), wavelen),
    try! @sympy_physics.optics_gaussopt_eval("rayleigh2waist(z_r, wavelen)"),
    "rayleigh2waist parity",
  )
  try! gaussopt_port_assert_expr_equal(
    geometric_conj_ab(a, b),
    try! @sympy_physics.optics_gaussopt_eval("geometric_conj_ab(a, b)"),
    "geometric_conj_ab parity",
  )
  try! gaussopt_port_assert_expr_equal(
    geometric_conj_af(a, f),
    try! @sympy_physics.optics_gaussopt_eval("geometric_conj_af(a, f)"),
    "geometric_conj_af parity",
  )
  try! gaussopt_port_assert_expr_equal(
    geometric_conj_bf(b, f),
    try! @sympy_physics.optics_gaussopt_eval("geometric_conj_bf(b, f)"),
    "geometric_conj_bf parity",
  )
  let conj = gaussian_conj(s_in, z_r_in, f)
  try! gaussopt_port_assert_expr_equal(
    conj.0,
    try! @sympy_physics.optics_gaussopt_eval(
      "gaussian_conj(s_in, z_r_in, f)[0]",
    ),
    "gaussian_conj[0] parity",
  )
  try! gaussopt_port_assert_expr_equal(
    conj.1,
    try! @sympy_physics.optics_gaussopt_eval(
      "gaussian_conj(s_in, z_r_in, f)[1]",
    ),
    "gaussian_conj[1] parity",
  )
  try! gaussopt_port_assert_expr_equal(
    conj.2,
    try! @sympy_physics.optics_gaussopt_eval(
      "gaussian_conj(s_in, z_r_in, f)[2]",
    ),
    "gaussian_conj[2] parity",
  )
  let gb = try! conjugate_gauss_beams(l, w_i, w_o, f=Some(f))
  try! gaussopt_port_assert_expr_equal(
    gb.0,
    try! @sympy_physics.optics_gaussopt_eval(
      "conjugate_gauss_beams(l, w_i, w_o, f=f)[0]",
    ),
    "conjugate_gauss_beams[0] parity",
  )
  try! gaussopt_port_assert_expr_equal(
    gb.1,
    try! @sympy_physics.optics_gaussopt_eval(
      "conjugate_gauss_beams(l, w_i, w_o, f=f)[1]",
    ),
    "conjugate_gauss_beams[1] parity",
  )
  try! gaussopt_port_assert_expr_equal(
    gb.2,
    try! @sympy_physics.optics_gaussopt_eval(
      "conjugate_gauss_beams(l, w_i, w_o, f=f)[2]",
    ),
    "conjugate_gauss_beams[2] parity",
  )
}
