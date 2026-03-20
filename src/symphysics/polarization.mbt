///|
/// Jones and Stokes optics aligned with the matrix-valued core of
/// `sympy.physics.optics.polarization`.

///|
fn optics_column(
  values : Array[Expr],
) -> ExplicitMatrix raise PhysicsError {
  let rows : Array[Array[Expr]] = Array::new()
  for value in values {
    rows.push([value])
  }
  explicit_matrix_from_rows(rows)
}

///|
pub fn jones_vector(
  psi : Expr,
  chi : Expr,
) -> ExplicitMatrix raise PhysicsError {
  optics_column([
    int(-1) * i_expr() * @symelem.sin(chi) * @symelem.sin(psi) +
    @symelem.cos(chi) * @symelem.cos(psi),
    i_expr() * @symelem.sin(chi) * @symelem.cos(psi) +
    @symelem.sin(psi) * @symelem.cos(chi),
  ])
}

///|
pub fn stokes_vector(
  psi : Expr,
  chi : Expr,
  p? : Expr = int(1),
  intensity? : Expr = int(1),
) -> ExplicitMatrix raise PhysicsError {
  let s0 = intensity
  let s1 = intensity *
    p *
    @symelem.cos(int(2) * psi) *
    @symelem.cos(int(2) * chi)
  let s2 = intensity *
    p *
    @symelem.sin(int(2) * psi) *
    @symelem.cos(int(2) * chi)
  let s3 = intensity * p * @symelem.sin(int(2) * chi)
  optics_column([s0, s1, s2, s3])
}

///|
pub fn jones_2_stokes(e : ExplicitMatrix) -> ExplicitMatrix raise PhysicsError {
  guard e.height() == 2 && e.width() == 1 else {
    raise PhysicsError::ShapeError("jones_2_stokes expects a 2x1 Jones vector")
  }
  let ex = e.get(0, 0)
  let ey = e.get(1, 0)
  let eyc = @symelem.conjugate(ey)
  optics_column([
    (@symelem.abs(ex) ^ int(2)) + (@symelem.abs(ey) ^ int(2)),
    (@symelem.abs(ex) ^ int(2)) - (@symelem.abs(ey) ^ int(2)),
    int(2) * @symelem.re(ex * eyc),
    int(-2) * @symelem.im(ex * eyc),
  ])
}

///|
pub fn linear_polarizer(
  theta? : Expr = int(0),
) -> ExplicitMatrix raise PhysicsError {
  explicit_matrix_from_rows([
    [
      @symelem.cos(theta) ^ int(2),
      @symelem.sin(theta) * @symelem.cos(theta),
    ],
    [
      @symelem.sin(theta) * @symelem.cos(theta),
      @symelem.sin(theta) ^ int(2),
    ],
  ])
}

///|
pub fn phase_retarder(
  theta? : Expr = int(0),
  delta? : Expr = int(0),
) -> ExplicitMatrix {
  let phase = @symelem.exp(i_expr() * delta)
  let mat = ExplicitMatrix::{ rows: [
    [
      (@symelem.cos(theta) ^ int(2)) +
      phase * (@symelem.sin(theta) ^ int(2)),
      (int(1) - phase) * @symelem.cos(theta) * @symelem.sin(theta),
    ],
    [
      (int(1) - phase) * @symelem.cos(theta) * @symelem.sin(theta),
      (@symelem.sin(theta) ^ int(2)) +
      phase * (@symelem.cos(theta) ^ int(2)),
    ],
  ] }
  mat.scale(
    @symelem.exp(int(-1) * i_expr() * delta * rational_expr(1, 2)),
  )
}

///|
pub fn half_wave_retarder(theta : Expr) -> ExplicitMatrix {
  phase_retarder(theta~, delta=pi_expr())
}

///|
pub fn quarter_wave_retarder(theta : Expr) -> ExplicitMatrix {
  phase_retarder(theta~, delta=pi_expr() * rational_expr(1, 2))
}

///|
pub fn transmissive_filter(
  t : Expr,
) -> ExplicitMatrix raise PhysicsError {
  let s = @symelem.sqrt(t)
  explicit_matrix_from_rows([[s, int(0)], [int(0), s]])
}

///|
pub fn reflective_filter(
  r : Expr,
) -> ExplicitMatrix raise PhysicsError {
  let s = @symelem.sqrt(r)
  explicit_matrix_from_rows([
    [s, int(0)],
    [int(0), int(-1) * s],
  ])
}

///|
pub fn mueller_matrix(j : ExplicitMatrix) -> ExplicitMatrix raise PhysicsError {
  guard j.height() == 2 && j.width() == 2 else {
    raise PhysicsError::ShapeError("mueller_matrix expects a 2x2 Jones matrix")
  }
  let i = i_expr()
  let half = rational_expr(1, 2)
  let a = j.get(0, 0)
  let b = j.get(0, 1)
  let c = j.get(1, 0)
  let d = j.get(1, 1)
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
      half * i * (int(-1) * a * cc - b * dc + c * ac + d * bc),
      half * i * (int(-1) * a * cc + b * dc + c * ac - d * bc),
      half * i * (int(-1) * a * dc - b * cc + c * bc + d * ac),
      half * (a * dc - b * cc - c * bc + d * ac),
    ],
  ])
}

///|
pub fn polarizing_beam_splitter(
  tp? : Expr = int(1),
  rs? : Expr = int(1),
  ts? : Expr = int(0),
  rp? : Expr = int(0),
  phia? : Expr = int(0),
  phib? : Expr = int(0),
) -> ExplicitMatrix raise PhysicsError {
  explicit_matrix_from_rows([
    [
      @symelem.sqrt(tp),
      int(0),
      i_expr() * @symelem.sqrt(rp),
      int(0),
    ],
    [
      int(0),
      @symelem.sqrt(ts),
      int(0),
      int(-1) *
      i_expr() *
      @symelem.sqrt(rs) *
      @symelem.exp(i_expr() * phia),
    ],
    [
      i_expr() * @symelem.sqrt(rp),
      int(0),
      @symelem.sqrt(tp),
      int(0),
    ],
    [
      int(0),
      int(-1) *
      i_expr() *
      @symelem.sqrt(rs) *
      @symelem.exp(i_expr() * phib),
      int(0),
      @symelem.sqrt(ts),
    ],
  ])
}
