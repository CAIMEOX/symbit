///|
/// Gaussian-optics helpers aligned with `sympy.physics.optics.gaussopt`.
///
/// The module models paraxial optical elements with 2x2 ABCD matrices, then
/// applies them to either geometric rays or Gaussian beam parameters.

///|
fn optics_simplify(expr : @symcore.Expr) -> @symcore.Expr {
  @symsimplify.ratsimp(@symsimplify.simplify(expr, max_passes=6), max_passes=4)
}

///|
pub struct RayTransferMatrix {
  matrix_ : ExplicitMatrix
} derive(Eq)

///|
pub struct GeometricRay {
  matrix_ : ExplicitMatrix
} derive(Eq)

///|
pub struct BeamParameter {
  wavelen_ : @symcore.Expr
  z_ : @symcore.Expr
  z_r_ : @symcore.Expr
  n_ : @symcore.Expr
} derive(Eq)

///|
fn ray_transfer_components(
  matrix : RayTransferMatrix,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr, @symcore.Expr) {
  (
    matrix.matrix_.rows[0][0],
    matrix.matrix_.rows[0][1],
    matrix.matrix_.rows[1][0],
    matrix.matrix_.rows[1][1],
  )
}

///|
fn ray_transfer_det(matrix : RayTransferMatrix) -> @symcore.Expr {
  let (a, b, c, d) = ray_transfer_components(matrix)
  optics_simplify(a * d - b * c)
}

///|
pub fn ray_transfer_matrix(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> RayTransferMatrix {
  RayTransferMatrix::{ matrix_: ExplicitMatrix::{ rows: [[a, b], [c, d]] } }
}

///|
pub fn ray_transfer_matrix_from_matrix(
  matrix : ExplicitMatrix,
) -> RayTransferMatrix raise PhysicsError {
  guard matrix.height() == 2 && matrix.width() == 2 else {
    raise PhysicsError::ShapeError("RayTransferMatrix expects a 2x2 matrix")
  }
  RayTransferMatrix::{ matrix_: matrix }
}

///|
pub fn free_space(distance : @symcore.Expr) -> RayTransferMatrix {
  ray_transfer_matrix(
    @symcore.int(1),
    distance,
    @symcore.int(0),
    @symcore.int(1),
  )
}

///|
pub fn flat_refraction(
  n1 : @symcore.Expr,
  n2 : @symcore.Expr,
) -> RayTransferMatrix {
  ray_transfer_matrix(
    @symcore.int(1),
    @symcore.int(0),
    @symcore.int(0),
    expr_div(n1, n2),
  )
}

///|
pub fn curved_refraction(
  radius : @symcore.Expr,
  n1 : @symcore.Expr,
  n2 : @symcore.Expr,
) -> RayTransferMatrix {
  ray_transfer_matrix(
    @symcore.int(1),
    @symcore.int(0),
    optics_simplify(expr_div(n1 - n2, radius * n2)),
    optics_simplify(expr_div(n1, n2)),
  )
}

///|
pub fn flat_mirror() -> RayTransferMatrix {
  ray_transfer_matrix(
    @symcore.int(1),
    @symcore.int(0),
    @symcore.int(0),
    @symcore.int(1),
  )
}

///|
pub fn curved_mirror(radius : @symcore.Expr) -> RayTransferMatrix {
  ray_transfer_matrix(
    @symcore.int(1),
    @symcore.int(0),
    optics_simplify(@symcore.int(-2) * (radius ^ @symcore.int(-1))),
    @symcore.int(1),
  )
}

///|
pub fn thin_lens(focal_length : @symcore.Expr) -> RayTransferMatrix {
  ray_transfer_matrix(
    @symcore.int(1),
    @symcore.int(0),
    optics_simplify(@symcore.int(-1) * (focal_length ^ @symcore.int(-1))),
    @symcore.int(1),
  )
}

///|
pub fn RayTransferMatrix::matrix(self : RayTransferMatrix) -> ExplicitMatrix {
  self.matrix_
}

///|
pub fn RayTransferMatrix::a(self : RayTransferMatrix) -> @symcore.Expr {
  self.matrix_.rows[0][0]
}

///|
pub fn RayTransferMatrix::b(self : RayTransferMatrix) -> @symcore.Expr {
  self.matrix_.rows[0][1]
}

///|
pub fn RayTransferMatrix::c(self : RayTransferMatrix) -> @symcore.Expr {
  self.matrix_.rows[1][0]
}

///|
pub fn RayTransferMatrix::d(self : RayTransferMatrix) -> @symcore.Expr {
  self.matrix_.rows[1][1]
}

///|
pub fn RayTransferMatrix::to_string(self : RayTransferMatrix) -> String {
  explicit_matrix_rows_string(self.matrix_)
}

///|
pub fn RayTransferMatrix::apply_matrix(
  self : RayTransferMatrix,
  other : RayTransferMatrix,
) -> RayTransferMatrix raise PhysicsError {
  ray_transfer_matrix_from_matrix(try! self.matrix_.mul(other.matrix_))
}

///|
pub fn RayTransferMatrix::apply_geometric_ray(
  self : RayTransferMatrix,
  ray : GeometricRay,
) -> GeometricRay raise PhysicsError {
  geometric_ray_from_matrix(try! self.matrix_.mul(ray.matrix_))
}

///|
pub fn RayTransferMatrix::apply_beam(
  self : RayTransferMatrix,
  beam : BeamParameter,
) -> BeamParameter raise PhysicsError {
  let (a, b, c, d) = ray_transfer_components(self)
  let z = beam.z_
  let z_r = beam.z_r_
  let c_z = c * z
  let c_z_r = c * z_r
  let den = optics_simplify(
    ((c_z + d) ^ @symcore.int(2)) + (c_z_r ^ @symcore.int(2)),
  )
  let z_out = optics_simplify(
    ((a * z + b) * (c_z + d) + a * c * (z_r ^ @symcore.int(2))) *
    (den ^ @symcore.int(-1)),
  )
  let z_r_out = optics_simplify(
    z_r * ray_transfer_det(self) * (den ^ @symcore.int(-1)),
  )
  beam_parameter(beam.wavelen_, z_out, z_r=Some(z_r_out), n=beam.n_)
}

///|
pub fn geometric_ray(
  height : @symcore.Expr,
  angle : @symcore.Expr,
) -> GeometricRay {
  GeometricRay::{ matrix_: ExplicitMatrix::{ rows: [[height], [angle]] } }
}

///|
pub fn geometric_ray_from_matrix(
  matrix : ExplicitMatrix,
) -> GeometricRay raise PhysicsError {
  guard matrix.height() == 2 && matrix.width() == 1 else {
    raise PhysicsError::ShapeError("GeometricRay expects a 2x1 matrix")
  }
  GeometricRay::{ matrix_: matrix }
}

///|
pub fn GeometricRay::matrix(self : GeometricRay) -> ExplicitMatrix {
  self.matrix_
}

///|
pub fn GeometricRay::height(self : GeometricRay) -> @symcore.Expr {
  self.matrix_.rows[0][0]
}

///|
pub fn GeometricRay::angle(self : GeometricRay) -> @symcore.Expr {
  self.matrix_.rows[1][0]
}

///|
pub fn GeometricRay::to_string(self : GeometricRay) -> String {
  explicit_matrix_rows_string(self.matrix_)
}

///|
pub fn beam_parameter(
  wavelen : @symcore.Expr,
  z : @symcore.Expr,
  z_r? : @symcore.Expr? = None,
  w? : @symcore.Expr? = None,
  n? : @symcore.Expr = @symcore.int(1),
) -> BeamParameter raise PhysicsError {
  let rayleigh = match (z_r, w) {
    (Some(value), _) => value
    (None, Some(waist)) => waist2rayleigh(waist, wavelen, n~)
    (None, None) =>
      raise PhysicsError::ValueError("Must specify one of w and z_r.")
  }
  BeamParameter::{ wavelen_: wavelen, z_: z, z_r_: rayleigh, n_: n }
}

///|
pub fn BeamParameter::wavelen(self : BeamParameter) -> @symcore.Expr {
  self.wavelen_
}

///|
pub fn BeamParameter::z(self : BeamParameter) -> @symcore.Expr {
  self.z_
}

///|
pub fn BeamParameter::z_r(self : BeamParameter) -> @symcore.Expr {
  self.z_r_
}

///|
pub fn BeamParameter::n(self : BeamParameter) -> @symcore.Expr {
  self.n_
}

///|
pub fn BeamParameter::q(self : BeamParameter) -> @symcore.Expr {
  self.z_ + i_expr() * self.z_r_
}

///|
pub fn BeamParameter::radius(self : BeamParameter) -> @symcore.Expr {
  optics_simplify(
    self.z_ *
    (
      @symcore.int(1) +
      ((self.z_r_ * (self.z_ ^ @symcore.int(-1))) ^ @symcore.int(2))
    ),
  )
}

///|
pub fn BeamParameter::w(self : BeamParameter) -> @symcore.Expr {
  self.w_0() *
  @symelem.sqrt(
    @symcore.int(1) +
    ((self.z_ * (self.z_r_ ^ @symcore.int(-1))) ^ @symcore.int(2)),
  )
}

///|
pub fn BeamParameter::w_0(self : BeamParameter) -> @symcore.Expr {
  @symelem.sqrt(expr_div(self.z_r_ * self.wavelen_, pi_expr() * self.n_))
}

///|
pub fn BeamParameter::divergence(self : BeamParameter) -> @symcore.Expr {
  expr_div(self.wavelen_, pi_expr() * self.w_0())
}

///|
pub fn BeamParameter::gouy(self : BeamParameter) -> @symcore.Expr {
  @symelem.atan2(self.z_, self.z_r_)
}

///|
pub fn BeamParameter::waist_approximation_limit(
  self : BeamParameter,
) -> @symcore.Expr {
  optics_simplify(expr_div(@symcore.int(2) * self.wavelen_, pi_expr()))
}

///|
pub fn BeamParameter::to_string(self : BeamParameter) -> String {
  [
    "BeamParameter(",
    @symprint.to_string(self.wavelen_),
    ", ",
    @symprint.to_string(self.z_),
    ", ",
    @symprint.to_string(self.z_r_),
    ", ",
    @symprint.to_string(self.n_),
    ")",
  ].join("")
}

///|
pub fn waist2rayleigh(
  waist : @symcore.Expr,
  wavelen : @symcore.Expr,
  n? : @symcore.Expr = @symcore.int(1),
) -> @symcore.Expr {
  optics_simplify(expr_div((waist ^ @symcore.int(2)) * n * pi_expr(), wavelen))
}

///|
pub fn rayleigh2waist(
  z_r : @symcore.Expr,
  wavelen : @symcore.Expr,
) -> @symcore.Expr {
  optics_simplify(@symelem.sqrt(expr_div(z_r * wavelen, pi_expr())))
}

///|
pub fn geometric_conj_ab(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if is_infinite_expr(a) || is_infinite_expr(b) {
    if is_infinite_expr(b) {
      a
    } else {
      b
    }
  } else {
    optics_simplify(expr_div(a * b, a + b))
  }
}

///|
pub fn geometric_conj_af(a : @symcore.Expr, f : @symcore.Expr) -> @symcore.Expr {
  optics_simplify(@symcore.int(-1) * geometric_conj_ab(a, @symcore.int(-1) * f))
}

///|
pub fn geometric_conj_bf(b : @symcore.Expr, f : @symcore.Expr) -> @symcore.Expr {
  geometric_conj_af(b, f)
}

///|
pub fn gaussian_conj(
  s_in : @symcore.Expr,
  z_r_in : @symcore.Expr,
  f : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) {
  let s_out = optics_simplify(
    expr_div(
      @symcore.int(1),
      @symcore.int(-1) *
      expr_div(
        @symcore.int(1),
        s_in + expr_div(z_r_in ^ @symcore.int(2), s_in - f),
      ) +
      expr_div(@symcore.int(1), f),
    ),
  )
  let denom = optics_simplify(
    @symcore.int(1) -
    ((s_in * (f ^ @symcore.int(-1))) ^ @symcore.int(2)) +
    ((z_r_in * (f ^ @symcore.int(-1))) ^ @symcore.int(2)),
  )
  let z_r_out = optics_simplify(z_r_in * (denom ^ @symcore.int(-1)))
  let mag = optics_simplify(@symelem.sqrt(denom) ^ @symcore.int(-1))
  (s_out, z_r_out, mag)
}

///|
pub fn conjugate_gauss_beams(
  wavelen : @symcore.Expr,
  waist_in : @symcore.Expr,
  waist_out : @symcore.Expr,
  f? : @symcore.Expr? = None,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise PhysicsError {
  let focal = match f {
    Some(value) => value
    None =>
      raise PhysicsError::ValueError(
        "The function expects the focal length as a named argument",
      )
  }
  let magnification = optics_simplify(expr_div(waist_out, waist_in))
  let z = waist2rayleigh(waist_in, wavelen)
  let s_in = optics_simplify(
    focal *
    (
      @symcore.int(1) -
      @symelem.sqrt(
        (magnification ^ @symcore.int(-2)) -
        ((z * (focal ^ @symcore.int(-1))) ^ @symcore.int(2)),
      )
    ),
  )
  let s_out = gaussian_conj(s_in, z, focal).0
  (s_in, s_out, focal)
}
