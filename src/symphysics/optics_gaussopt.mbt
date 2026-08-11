///|
/// Gaussian-optics helpers aligned with `sympy.physics.optics.gaussopt`.
///
/// The module models paraxial optical elements with 2x2 ABCD matrices, then
/// applies them to either geometric rays or Gaussian beam parameters.

///|
fn optics_simplify(expr : Expr) -> Expr {
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
  wavelen_ : Expr
  z_ : Expr
  z_r_ : Expr
  n_ : Expr
} derive(Eq)

///|
fn ray_transfer_components(
  matrix : RayTransferMatrix,
) -> (Expr, Expr, Expr, Expr) {
  (
    matrix.matrix_.rows[0][0],
    matrix.matrix_.rows[0][1],
    matrix.matrix_.rows[1][0],
    matrix.matrix_.rows[1][1],
  )
}

///|
fn ray_transfer_det(matrix : RayTransferMatrix) -> Expr {
  let (a, b, c, d) = ray_transfer_components(matrix)
  optics_simplify(a * d - b * c)
}

///|
pub fn ray_transfer_matrix(
  a : Expr,
  b : Expr,
  c : Expr,
  d : Expr,
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
pub fn free_space(distance : Expr) -> RayTransferMatrix {
  ray_transfer_matrix(int(1), distance, int(0), int(1))
}

///|
pub fn flat_refraction(n1 : Expr, n2 : Expr) -> RayTransferMatrix {
  ray_transfer_matrix(int(1), int(0), int(0), expr_div(n1, n2))
}

///|
pub fn curved_refraction(
  radius : Expr,
  n1 : Expr,
  n2 : Expr,
) -> RayTransferMatrix {
  ray_transfer_matrix(
    int(1),
    int(0),
    optics_simplify(expr_div(n1 - n2, radius * n2)),
    optics_simplify(expr_div(n1, n2)),
  )
}

///|
pub fn flat_mirror() -> RayTransferMatrix {
  ray_transfer_matrix(int(1), int(0), int(0), int(1))
}

///|
pub fn curved_mirror(radius : Expr) -> RayTransferMatrix {
  ray_transfer_matrix(
    int(1),
    int(0),
    optics_simplify(int(-2) * (radius ^ int(-1))),
    int(1),
  )
}

///|
pub fn thin_lens(focal_length : Expr) -> RayTransferMatrix {
  ray_transfer_matrix(
    int(1),
    int(0),
    optics_simplify(int(-1) * (focal_length ^ int(-1))),
    int(1),
  )
}

///|
pub fn RayTransferMatrix::matrix(self : RayTransferMatrix) -> ExplicitMatrix {
  self.matrix_
}

///|
pub fn RayTransferMatrix::a(self : RayTransferMatrix) -> Expr {
  self.matrix_.rows[0][0]
}

///|
pub fn RayTransferMatrix::b(self : RayTransferMatrix) -> Expr {
  self.matrix_.rows[0][1]
}

///|
pub fn RayTransferMatrix::c(self : RayTransferMatrix) -> Expr {
  self.matrix_.rows[1][0]
}

///|
pub fn RayTransferMatrix::d(self : RayTransferMatrix) -> Expr {
  self.matrix_.rows[1][1]
}

///|
pub impl Show for RayTransferMatrix with fn to_string(self) {
  explicit_matrix_rows_string(self.matrix_)
}

///|
pub impl Show for RayTransferMatrix with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn RayTransferMatrix::apply_matrix(
  self : RayTransferMatrix,
  other : RayTransferMatrix,
) -> RayTransferMatrix raise PhysicsError {
  ray_transfer_matrix_from_matrix(self.matrix_.mul(other.matrix_))
}

///|
pub fn RayTransferMatrix::apply_geometric_ray(
  self : RayTransferMatrix,
  ray : GeometricRay,
) -> GeometricRay raise PhysicsError {
  geometric_ray_from_matrix(self.matrix_.mul(ray.matrix_))
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
  let den = optics_simplify(((c_z + d) ^ int(2)) + (c_z_r ^ int(2)))
  let z_out = optics_simplify(
    ((a * z + b) * (c_z + d) + a * c * (z_r ^ int(2))) * (den ^ int(-1)),
  )
  let z_r_out = optics_simplify(z_r * ray_transfer_det(self) * (den ^ int(-1)))
  beam_parameter(beam.wavelen_, z_out, z_r=Some(z_r_out), n=beam.n_)
}

///|
pub fn geometric_ray(height : Expr, angle : Expr) -> GeometricRay {
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
pub fn GeometricRay::height(self : GeometricRay) -> Expr {
  self.matrix_.rows[0][0]
}

///|
pub fn GeometricRay::angle(self : GeometricRay) -> Expr {
  self.matrix_.rows[1][0]
}

///|
pub impl Show for GeometricRay with fn to_string(self) {
  explicit_matrix_rows_string(self.matrix_)
}

///|
pub impl Show for GeometricRay with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn beam_parameter(
  wavelen : Expr,
  z : Expr,
  z_r? : Expr? = None,
  w? : Expr? = None,
  n? : Expr = int(1),
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
pub fn BeamParameter::wavelen(self : BeamParameter) -> Expr {
  self.wavelen_
}

///|
pub fn BeamParameter::z(self : BeamParameter) -> Expr {
  self.z_
}

///|
pub fn BeamParameter::z_r(self : BeamParameter) -> Expr {
  self.z_r_
}

///|
pub fn BeamParameter::n(self : BeamParameter) -> Expr {
  self.n_
}

///|
pub fn BeamParameter::q(self : BeamParameter) -> Expr {
  self.z_ + i_expr() * self.z_r_
}

///|
pub fn BeamParameter::radius(self : BeamParameter) -> Expr {
  optics_simplify(
    self.z_ * (int(1) + ((self.z_r_ * (self.z_ ^ int(-1))) ^ int(2))),
  )
}

///|
pub fn BeamParameter::w(self : BeamParameter) -> Expr {
  self.w_0() *
  @symelem.sqrt(int(1) + ((self.z_ * (self.z_r_ ^ int(-1))) ^ int(2)))
}

///|
pub fn BeamParameter::w_0(self : BeamParameter) -> Expr {
  @symelem.sqrt(expr_div(self.z_r_ * self.wavelen_, pi_expr() * self.n_))
}

///|
pub fn BeamParameter::divergence(self : BeamParameter) -> Expr {
  expr_div(self.wavelen_, pi_expr() * self.w_0())
}

///|
pub fn BeamParameter::gouy(self : BeamParameter) -> Expr {
  @symelem.atan2(self.z_, self.z_r_)
}

///|
pub fn BeamParameter::waist_approximation_limit(self : BeamParameter) -> Expr {
  optics_simplify(expr_div(int(2) * self.wavelen_, pi_expr()))
}

///|
pub impl Show for BeamParameter with fn to_string(self) {
  [
    "BeamParameter(",
    @symprint.pretty_string(self.wavelen_),
    ", ",
    @symprint.pretty_string(self.z_),
    ", ",
    @symprint.pretty_string(self.z_r_),
    ", ",
    @symprint.pretty_string(self.n_),
    ")",
  ].join("")
}

///|
pub impl Show for BeamParameter with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn waist2rayleigh(waist : Expr, wavelen : Expr, n? : Expr = int(1)) -> Expr {
  optics_simplify(expr_div((waist ^ int(2)) * n * pi_expr(), wavelen))
}

///|
pub fn rayleigh2waist(z_r : Expr, wavelen : Expr) -> Expr {
  optics_simplify(@symelem.sqrt(expr_div(z_r * wavelen, pi_expr())))
}

///|
pub fn geometric_conj_ab(a : Expr, b : Expr) -> Expr {
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
pub fn geometric_conj_af(a : Expr, f : Expr) -> Expr {
  optics_simplify(int(-1) * geometric_conj_ab(a, int(-1) * f))
}

///|
pub fn geometric_conj_bf(b : Expr, f : Expr) -> Expr {
  geometric_conj_af(b, f)
}

///|
pub fn gaussian_conj(
  s_in : Expr,
  z_r_in : Expr,
  f : Expr,
) -> (Expr, Expr, Expr) {
  let s_out = optics_simplify(
    expr_div(
      int(1),
      int(-1) * expr_div(int(1), s_in + expr_div(z_r_in ^ int(2), s_in - f)) +
      expr_div(int(1), f),
    ),
  )
  let denom = optics_simplify(
    int(1) -
    ((s_in * (f ^ int(-1))) ^ int(2)) +
    ((z_r_in * (f ^ int(-1))) ^ int(2)),
  )
  let z_r_out = optics_simplify(z_r_in * (denom ^ int(-1)))
  let mag = optics_simplify(@symelem.sqrt(denom) ^ int(-1))
  (s_out, z_r_out, mag)
}

///|
pub fn conjugate_gauss_beams(
  wavelen : Expr,
  waist_in : Expr,
  waist_out : Expr,
  f? : Expr? = None,
) -> (Expr, Expr, Expr) raise PhysicsError {
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
      int(1) -
      @symelem.sqrt(
        (magnification ^ int(-2)) - ((z * (focal ^ int(-1))) ^ int(2)),
      )
    ),
  )
  let s_out = gaussian_conj(s_in, z, focal).0
  (s_in, s_out, focal)
}
