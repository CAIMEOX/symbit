///|
fn gaussopt_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = @symprint.pretty_string(lhs)
  assert_true(expr_equal(ours, rhs))
}

///|
fn gaussopt_port_assert_matrix_equal(
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
    @symcore.Expr::Symbol("d"),
    @symcore.Expr::Symbol("f"),
    @symcore.Expr::Symbol("h"),
    @symcore.Expr::Symbol("angle"),
    @symcore.Expr::Symbol("n1"),
    @symcore.Expr::Symbol("n2"),
    @symcore.Expr::Symbol("R"),
    @symcore.Expr::Symbol("a"),
    @symcore.Expr::Symbol("b"),
    @symcore.Expr::Symbol("s_in"),
    @symcore.Expr::Symbol("z_r_in"),
    @symcore.Expr::Symbol("l"),
    @symcore.Expr::Symbol("w_i"),
    @symcore.Expr::Symbol("w_o"),
    @symcore.Expr::Symbol("z"),
    @symcore.Expr::Symbol("wavelen"),
  )
}

///|
test "physics.optics.gaussopt: matrix parity" {
  let (d, f, h, angle, n1, n2, radius, _, _, _, _, _, _, _, _, _) = gaussopt_symbols()
  gaussopt_port_assert_matrix_equal(
    ray_transfer_matrix(
      @symcore.int(1),
      @symcore.int(2),
      @symcore.int(3),
      @symcore.int(4),
    ).matrix(),
    optics_gaussopt_matrix("RayTransferMatrix(1, 2, 3, 4)"),
    "RayTransferMatrix parity",
  )
  gaussopt_port_assert_matrix_equal(
    free_space(d).matrix(),
    optics_gaussopt_matrix("FreeSpace(d)"),
    "FreeSpace parity",
  )
  gaussopt_port_assert_matrix_equal(
    flat_refraction(n1, n2).matrix(),
    optics_gaussopt_matrix("FlatRefraction(n1, n2)"),
    "FlatRefraction parity",
  )
  gaussopt_port_assert_matrix_equal(
    curved_refraction(radius, n1, n2).matrix(),
    optics_gaussopt_matrix("CurvedRefraction(R, n1, n2)"),
    "CurvedRefraction parity",
  )
  gaussopt_port_assert_matrix_equal(
    curved_mirror(radius).matrix(),
    optics_gaussopt_matrix("CurvedMirror(R)"),
    "CurvedMirror parity",
  )
  gaussopt_port_assert_matrix_equal(
    thin_lens(f).matrix(),
    optics_gaussopt_matrix("ThinLens(f)"),
    "ThinLens parity",
  )
  gaussopt_port_assert_matrix_equal(
    free_space(d).apply_geometric_ray(geometric_ray(h, angle)).matrix(),
    optics_gaussopt_matrix("FreeSpace(d)*GeometricRay(h, angle)"),
    "GeometricRay transform parity",
  )
}

///|
test "physics.optics.gaussopt: beam property parity" {
  let (_, _, _, _, _, _, _, _, _, _, _, _, _, _, z, wavelen) = gaussopt_symbols()
  let w0 = @symcore.Expr::Symbol("w_0")
  let beam = beam_parameter(wavelen, z, w=Some(w0))
  gaussopt_port_assert_expr_equal(
    beam.q(),
    optics_gaussopt_eval("BeamParameter(wavelen, z, w=w_0).q"),
    "BeamParameter.q parity",
  )
  gaussopt_port_assert_expr_equal(
    beam.radius(),
    optics_gaussopt_eval("BeamParameter(wavelen, z, w=w_0).radius"),
    "BeamParameter.radius parity",
  )
  gaussopt_port_assert_expr_equal(
    beam.w(),
    optics_gaussopt_eval("BeamParameter(wavelen, z, w=w_0).w"),
    "BeamParameter.w parity",
  )
  gaussopt_port_assert_expr_equal(
    beam.w_0(),
    optics_gaussopt_eval("BeamParameter(wavelen, z, w=w_0).w_0"),
    "BeamParameter.w_0 parity",
  )
  gaussopt_port_assert_expr_equal(
    beam.divergence(),
    optics_gaussopt_eval("BeamParameter(wavelen, z, w=w_0).divergence"),
    "BeamParameter.divergence parity",
  )
  gaussopt_port_assert_expr_equal(
    beam.gouy(),
    optics_gaussopt_eval("BeamParameter(wavelen, z, w=w_0).gouy"),
    "BeamParameter.gouy parity",
  )
  gaussopt_port_assert_expr_equal(
    beam.waist_approximation_limit(),
    optics_gaussopt_eval(
      "BeamParameter(wavelen, z, w=w_0).waist_approximation_limit",
    ),
    "BeamParameter.waist_approximation_limit parity",
  )
}

///|
test "physics.optics.gaussopt: beam transform parity" {
  let beam = beam_parameter(
    @symcore.int(3),
    @symcore.int(4),
    z_r=Some(@symcore.int(5)),
  )
  let pushed = thin_lens(@symcore.int(2)).apply_beam(beam)
  gaussopt_port_assert_expr_equal(
    pushed.q(),
    optics_gaussopt_eval("(ThinLens(2)*BeamParameter(3, 4, z_r=5)).q"),
    "ThinLens*BeamParameter q parity",
  )
  gaussopt_port_assert_expr_equal(
    pushed.z(),
    optics_gaussopt_eval("(ThinLens(2)*BeamParameter(3, 4, z_r=5)).z"),
    "ThinLens*BeamParameter z parity",
  )
  gaussopt_port_assert_expr_equal(
    pushed.z_r(),
    optics_gaussopt_eval("(ThinLens(2)*BeamParameter(3, 4, z_r=5)).z_r"),
    "ThinLens*BeamParameter z_r parity",
  )
}

///|
test "physics.optics.gaussopt: utility parity" {
  let (_, f, _, _, _, _, _, a, b, s_in, z_r_in, l, w_i, w_o, _, wavelen) = gaussopt_symbols()
  gaussopt_port_assert_expr_equal(
    waist2rayleigh(@symcore.Expr::Symbol("w"), wavelen),
    optics_gaussopt_eval("waist2rayleigh(w, wavelen)"),
    "waist2rayleigh parity",
  )
  gaussopt_port_assert_expr_equal(
    rayleigh2waist(@symcore.Expr::Symbol("z_r"), wavelen),
    optics_gaussopt_eval("rayleigh2waist(z_r, wavelen)"),
    "rayleigh2waist parity",
  )
  gaussopt_port_assert_expr_equal(
    geometric_conj_ab(a, b),
    optics_gaussopt_eval("geometric_conj_ab(a, b)"),
    "geometric_conj_ab parity",
  )
  gaussopt_port_assert_expr_equal(
    geometric_conj_af(a, f),
    optics_gaussopt_eval("geometric_conj_af(a, f)"),
    "geometric_conj_af parity",
  )
  gaussopt_port_assert_expr_equal(
    geometric_conj_bf(b, f),
    optics_gaussopt_eval("geometric_conj_bf(b, f)"),
    "geometric_conj_bf parity",
  )
  let conj = gaussian_conj(s_in, z_r_in, f)
  gaussopt_port_assert_expr_equal(
    conj.0,
    optics_gaussopt_eval("gaussian_conj(s_in, z_r_in, f)[0]"),
    "gaussian_conj[0] parity",
  )
  gaussopt_port_assert_expr_equal(
    conj.1,
    optics_gaussopt_eval("gaussian_conj(s_in, z_r_in, f)[1]"),
    "gaussian_conj[1] parity",
  )
  gaussopt_port_assert_expr_equal(
    conj.2,
    optics_gaussopt_eval("gaussian_conj(s_in, z_r_in, f)[2]"),
    "gaussian_conj[2] parity",
  )
  let gb = conjugate_gauss_beams(l, w_i, w_o, f=Some(f))
  gaussopt_port_assert_expr_equal(
    gb.0,
    optics_gaussopt_eval("conjugate_gauss_beams(l, w_i, w_o, f=f)[0]"),
    "conjugate_gauss_beams[0] parity",
  )
  gaussopt_port_assert_expr_equal(
    gb.1,
    optics_gaussopt_eval("conjugate_gauss_beams(l, w_i, w_o, f=f)[1]"),
    "conjugate_gauss_beams[1] parity",
  )
  gaussopt_port_assert_expr_equal(
    gb.2,
    optics_gaussopt_eval("conjugate_gauss_beams(l, w_i, w_o, f=f)[2]"),
    "conjugate_gauss_beams[2] parity",
  )
}
