///|
/// Jones and Stokes optics aligned with the matrix-valued core of
/// `sympy.physics.optics.polarization`.

///|
fn optics_column(
  values : Array[@symcore.Expr],
) -> ExplicitMatrix raise PhysicsError {
  let rows : Array[Array[@symcore.Expr]] = Array::new()
  for value in values {
    rows.push([value])
  }
  explicit_matrix_from_rows(rows)
}

///|
pub fn jones_vector(
  psi : @symcore.Expr,
  chi : @symcore.Expr,
) -> ExplicitMatrix raise PhysicsError {
  optics_column([
    @symcore.int(-1) * i_expr() * @symelem.sin(chi) * @symelem.sin(psi) +
    @symelem.cos(chi) * @symelem.cos(psi),
    i_expr() * @symelem.sin(chi) * @symelem.cos(psi) +
    @symelem.sin(psi) * @symelem.cos(chi),
  ])
}

///|
pub fn stokes_vector(
  psi : @symcore.Expr,
  chi : @symcore.Expr,
  p? : @symcore.Expr = @symcore.int(1),
  intensity? : @symcore.Expr = @symcore.int(1),
) -> ExplicitMatrix raise PhysicsError {
  let s0 = intensity
  let s1 = intensity *
    p *
    @symelem.cos(@symcore.int(2) * psi) *
    @symelem.cos(@symcore.int(2) * chi)
  let s2 = intensity *
    p *
    @symelem.sin(@symcore.int(2) * psi) *
    @symelem.cos(@symcore.int(2) * chi)
  let s3 = intensity * p * @symelem.sin(@symcore.int(2) * chi)
  optics_column([s0, s1, s2, s3])
}

///|
pub fn jones_2_stokes(e : ExplicitMatrix) -> ExplicitMatrix raise PhysicsError {
  guard e.height() == 2 && e.width() == 1 else {
    raise PhysicsError::ShapeError("jones_2_stokes expects a 2x1 Jones vector")
  }
  let ex = try! e.get(0, 0)
  let ey = try! e.get(1, 0)
  let eyc = @symelem.conjugate(ey)
  optics_column([
    (@symelem.abs(ex) ^ @symcore.int(2)) + (@symelem.abs(ey) ^ @symcore.int(2)),
    (@symelem.abs(ex) ^ @symcore.int(2)) - (@symelem.abs(ey) ^ @symcore.int(2)),
    @symcore.int(2) * @symelem.re(ex * eyc),
    @symcore.int(-2) * @symelem.im(ex * eyc),
  ])
}

///|
pub fn linear_polarizer(
  theta? : @symcore.Expr = @symcore.int(0),
) -> ExplicitMatrix raise PhysicsError {
  explicit_matrix_from_rows([
    [
      @symelem.cos(theta) ^ @symcore.int(2),
      @symelem.sin(theta) * @symelem.cos(theta),
    ],
    [
      @symelem.sin(theta) * @symelem.cos(theta),
      @symelem.sin(theta) ^ @symcore.int(2),
    ],
  ])
}

///|
pub fn phase_retarder(
  theta? : @symcore.Expr = @symcore.int(0),
  delta? : @symcore.Expr = @symcore.int(0),
) -> ExplicitMatrix {
  let phase = @symelem.exp(i_expr() * delta)
  let mat = try! explicit_matrix_from_rows([
    [
      (@symelem.cos(theta) ^ @symcore.int(2)) +
      phase * (@symelem.sin(theta) ^ @symcore.int(2)),
      (@symcore.int(1) - phase) * @symelem.cos(theta) * @symelem.sin(theta),
    ],
    [
      (@symcore.int(1) - phase) * @symelem.cos(theta) * @symelem.sin(theta),
      (@symelem.sin(theta) ^ @symcore.int(2)) +
      phase * (@symelem.cos(theta) ^ @symcore.int(2)),
    ],
  ])
  mat.scale(
    @symelem.exp(@symcore.int(-1) * i_expr() * delta * rational_expr(1, 2)),
  )
}

///|
pub fn half_wave_retarder(theta : @symcore.Expr) -> ExplicitMatrix {
  phase_retarder(theta~, delta=pi_expr())
}

///|
pub fn quarter_wave_retarder(theta : @symcore.Expr) -> ExplicitMatrix {
  phase_retarder(theta~, delta=pi_expr() * rational_expr(1, 2))
}

///|
pub fn transmissive_filter(
  t : @symcore.Expr,
) -> ExplicitMatrix raise PhysicsError {
  let s = @symelem.sqrt(t)
  explicit_matrix_from_rows([[s, @symcore.int(0)], [@symcore.int(0), s]])
}

///|
pub fn reflective_filter(
  r : @symcore.Expr,
) -> ExplicitMatrix raise PhysicsError {
  let s = @symelem.sqrt(r)
  explicit_matrix_from_rows([
    [s, @symcore.int(0)],
    [@symcore.int(0), @symcore.int(-1) * s],
  ])
}

///|
pub fn mueller_matrix(j : ExplicitMatrix) -> ExplicitMatrix raise PhysicsError {
  guard j.height() == 2 && j.width() == 2 else {
    raise PhysicsError::ShapeError("mueller_matrix expects a 2x2 Jones matrix")
  }
  let i = i_expr()
  let half = rational_expr(1, 2)
  let a = try! j.get(0, 0)
  let b = try! j.get(0, 1)
  let c = try! j.get(1, 0)
  let d = try! j.get(1, 1)
  let ac = @symelem.conjugate(a)
  let bc = @symelem.conjugate(b)
  let cc = @symelem.conjugate(c)
  let dc = @symelem.conjugate(d)
  explicit_matrix_from_rows([
    [
      half * (a * ac + b * bc + c * cc + d * dc),
      half * (a * ac - b * bc + c * cc - d * dc),
      half * (a * bc + b * ac + c * dc + d * cc),
      half * i * (a * bc - b * ac + c * dc - d * cc),
    ],
    [
      half * (a * ac + b * bc - c * cc - d * dc),
      half * (a * ac - b * bc - c * cc + d * dc),
      half * (a * bc + b * ac - c * dc - d * cc),
      half * i * (a * bc - b * ac - c * dc + d * cc),
    ],
    [
      half * (a * cc + b * dc + c * ac + d * bc),
      half * (a * cc - b * dc + c * ac - d * bc),
      half * (a * dc + b * cc + c * bc + d * ac),
      half * i * (a * dc - b * cc + c * bc - d * ac),
    ],
    [
      half * i * (@symcore.int(-1) * a * cc - b * dc + c * ac + d * bc),
      half * i * (@symcore.int(-1) * a * cc + b * dc + c * ac - d * bc),
      half * i * (@symcore.int(-1) * a * dc - b * cc + c * bc + d * ac),
      half * (a * dc - b * cc - c * bc + d * ac),
    ],
  ])
}

///|
pub fn polarizing_beam_splitter(
  tp? : @symcore.Expr = @symcore.int(1),
  rs? : @symcore.Expr = @symcore.int(1),
  ts? : @symcore.Expr = @symcore.int(0),
  rp? : @symcore.Expr = @symcore.int(0),
  phia? : @symcore.Expr = @symcore.int(0),
  phib? : @symcore.Expr = @symcore.int(0),
) -> ExplicitMatrix raise PhysicsError {
  explicit_matrix_from_rows([
    [
      @symelem.sqrt(tp),
      @symcore.int(0),
      i_expr() * @symelem.sqrt(rp),
      @symcore.int(0),
    ],
    [
      @symcore.int(0),
      @symelem.sqrt(ts),
      @symcore.int(0),
      @symcore.int(-1) *
      i_expr() *
      @symelem.sqrt(rs) *
      @symelem.exp(i_expr() * phia),
    ],
    [
      i_expr() * @symelem.sqrt(rp),
      @symcore.int(0),
      @symelem.sqrt(tp),
      @symcore.int(0),
    ],
    [
      @symcore.int(0),
      @symcore.int(-1) *
      i_expr() *
      @symelem.sqrt(rs) *
      @symelem.exp(i_expr() * phib),
      @symcore.int(0),
      @symelem.sqrt(ts),
    ],
  ])
}
