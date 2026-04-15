///|
/// Wrapping geometry helpers aligned with the high-value surface of
/// `sympy.physics.mechanics.wrapping_geometry`.

///|
pub struct WrappingSphere {
  radius_ : Expr
  point_ : @symvector.Point
} derive(Eq)

///|
pub struct WrappingCylinder {
  radius_ : Expr
  point_ : @symvector.Point
  axis_ : @symvector.Vector
} derive(Eq)

///|
pub struct WrappingCone {
  alpha_ : Expr
  apex_ : @symvector.Point
  axis_ : @symvector.Vector
} derive(Eq)

///|
pub enum WrappingGeometryLike {
  Sphere(WrappingSphere)
  Cylinder(WrappingCylinder)
  Cone(WrappingCone)
} derive(Eq)

///|
fn mechanics_eq_expr(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.function("Eq", [lhs, rhs])
}

///|
fn mechanics_pi_expr() -> Expr {
  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
}

///|
fn mechanics_two_expr() -> Expr {
  int(2)
}

///|
fn mechanics_is_zero(expr : Expr) -> Bool {
  mech_expr_is_zero(expr)
}

///|
fn mechanics_is_negative_one(expr : Expr) -> Bool {
  @symcore.compare_expr(expr, int(-1)) == 0
}

///|
fn mechanics_bigint_sqrt_floor(n : BigInt) -> BigInt? {
  if n.op_lt(BigInt::from_int(0)) {
    return None
  }
  let zero = BigInt::from_int(0)
  let one = BigInt::from_int(1)
  let two = BigInt::from_int(2)
  let mut low = zero
  let mut high = n.add(one)
  while low.add(one).compare(high) < 0 {
    let mid = low.add(high).div(two)
    let sq = mid.mul(mid)
    if sq.compare(n) <= 0 {
      low = mid
    } else {
      high = mid
    }
  }
  Some(low)
}

///|
fn mechanics_rational_exact_sqrt(
  value : @symnum.BigRational,
) -> @symnum.BigRational? {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    return None
  }
  let num = mechanics_bigint_sqrt_floor(value.numerator())
  let den = mechanics_bigint_sqrt_floor(value.denominator())
  match (num, den) {
    (Some(num_root), Some(den_root)) =>
      if num_root.mul(num_root).compare(value.numerator()) == 0 &&
        den_root.mul(den_root).compare(value.denominator()) == 0 {
        let rat : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
          num_root, den_root,
        )
        match rat {
          Ok(value) => Some(value)
          Err(_) => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn mechanics_rational_pow(
  base : @symnum.BigRational,
  exponent : Int,
) -> @symnum.BigRational? {
  if exponent == 0 {
    return Some(@symnum.BigRational::one())
  }
  if exponent < 0 {
    try base.reciprocal() catch {
      _ => return None
    } noraise {
      recip => return mechanics_rational_pow(recip, -exponent)
    }
  }
  let mut acc = @symnum.BigRational::one()
  let mut count = 0
  while count < exponent {
    acc = acc.mul_r(base)
    count = count + 1
  }
  Some(acc)
}

///|
fn mechanics_try_numeric(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(value) => Some(value)
    Expr::Add(args) => {
      let mut acc = @symnum.BigRational::zero()
      for arg in args {
        match mechanics_try_numeric(arg) {
          Some(value) => acc = acc.add_r(value)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = @symnum.BigRational::one()
      for arg in args {
        match mechanics_try_numeric(arg) {
          Some(value) => acc = acc.mul_r(value)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exponent) =>
      match (mechanics_try_numeric(base), mechanics_try_numeric(exponent)) {
        (Some(base_value), Some(exp_value)) if exp_value.is_integral() => {
          let num = exp_value.numerator()
          if num.compare(BigInt::from_int(0)) >= 0 {
            mechanics_rational_pow(base_value, num.to_int())
          } else {
            match mechanics_rational_pow(base_value, num.neg().to_int()) {
              Some(value) =>
                try value.reciprocal() catch {
                  _ => None
                } noraise {
                  recip => Some(recip)
                }
              None => None
            }
          }
        }
        _ => None
      }
    _ if @symcore.application_has_name(expr, "sqrt", arity=1) =>
      match
        mechanics_try_numeric(@symcore.application_args(expr).unwrap_or([])[0]) {
        Some(value) => mechanics_rational_exact_sqrt(value)
        None => None
      }
    _ => None
  }
}

///|
fn mechanics_directional_atan(
  numerator : Expr,
  denominator : Expr,
) -> Expr raise @symphysics.PhysicsError {
  let numerator = mech_simplify_expr(numerator)
  let denominator = mech_simplify_expr(denominator)
  match (mechanics_try_numeric(numerator), mechanics_try_numeric(denominator)) {
    (Some(num), Some(den)) => {
      if num.is_zero() && den.is_zero() {
        raise @symphysics.PhysicsError::ValueError(
          "directional atan undefined for zero numerator and denominator",
        )
      }
      if den.is_zero() {
        if num.compare(@symnum.BigRational::zero()) > 0 {
          return mech_simplify_expr(mech_half_expr() * mechanics_pi_expr())
        } else {
          return mech_simplify_expr(
            int(3) * mech_half_expr() * mechanics_pi_expr(),
          )
        }
      }
      if num.is_zero() {
        if den.compare(@symnum.BigRational::zero()) >= 0 {
          return int(0)
        } else {
          return mechanics_pi_expr()
        }
      }
      let angle = @symelem.atan2(numerator, denominator)
      if num.compare(@symnum.BigRational::zero()) < 0 {
        angle + mechanics_two_expr() * mechanics_pi_expr()
      } else {
        angle
      }
    }
    _ => {
      let ratio = @symsimplify.trigsimp(
        @symsimplify.simplify(numerator * (denominator ^ int(-1))),
        max_passes=8,
      )
      match ratio {
        _ if @symcore.application_has_name(ratio, "tan", arity=1) =>
          @symcore.application_args(ratio).unwrap_or([])[0]
        Expr::Mul(args) if args.length() == 2 &&
          mechanics_is_negative_one(args[0]) =>
          match args[1] {
            _ if @symcore.application_has_name(args[1], "tan", arity=1) =>
              mechanics_two_expr() * mechanics_pi_expr() -
              @symcore.application_args(args[1]).unwrap_or([])[0]
            _ =>
              raise @symphysics.PhysicsError::ValueError(
                "unsupported symbolic directional atan ratio",
              )
          }
        _ if mechanics_is_zero(ratio) => int(0)
        _ =>
          raise @symphysics.PhysicsError::ValueError(
            "unsupported symbolic directional atan ratio",
          )
      }
    }
  }
}

///|
pub fn wrapping_sphere(
  radius : Expr,
  point : @symvector.Point,
) -> WrappingSphere {
  WrappingSphere::{ radius_: radius, point_: point }
}

///|
pub fn WrappingSphere::radius(self : WrappingSphere) -> Expr {
  self.radius_
}

///|
pub fn WrappingSphere::point(self : WrappingSphere) -> @symvector.Point {
  self.point_
}

///|
pub fn WrappingSphere::point_on_surface(
  self : WrappingSphere,
  point : @symvector.Point,
) -> Expr raise @symvector.VectorError {
  let point_vector = point.pos_from(self.point_)
  let point_radius_squared = point_vector.dot(point_vector)
  mechanics_eq_expr(point_radius_squared, self.radius_ ^ mechanics_two_expr())
}

///|
pub fn WrappingSphere::geodesic_length(
  self : WrappingSphere,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> Expr raise @symvector.VectorError {
  let point_1_vector = point_1.pos_from(self.point_).normalize()
  let point_2_vector = point_2.pos_from(self.point_).normalize()
  let central_angle = @symelem.acos(point_2_vector.dot(point_1_vector))
  mech_simplify_expr(self.radius_ * central_angle)
}

///|
pub fn WrappingSphere::geodesic_end_vectors(
  self : WrappingSphere,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> (@symvector.Vector, @symvector.Vector) raise @symvector.VectorError {
  let p_a_vec = point_1.pos_from(self.point_)
  let p_b_vec = point_2.pos_from(self.point_)
  if p_a_vec.cross(p_b_vec).is_zero() {
    let impossible = @symvector.vector_zero().normalize()
    return (impossible, impossible)
  }
  let tangent_1 = p_a_vec.cross(point_2.pos_from(point_1))
  let tangent_2 = p_b_vec.cross(point_1.pos_from(point_2))
  (tangent_1.cross(p_a_vec).normalize(), tangent_2.cross(p_b_vec).normalize())
}

///|
pub fn WrappingSphere::repr(self : WrappingSphere) -> String {
  "WrappingSphere(radius=" +
  @symprint.pretty_string(self.radius_) +
  ", point=" +
  self.point_.name() +
  ")"
}

///|
pub fn WrappingSphere::as_geometry(
  self : WrappingSphere,
) -> WrappingGeometryLike {
  WrappingGeometryLike::Sphere(self)
}

///|
pub fn wrapping_cylinder(
  radius : Expr,
  point : @symvector.Point,
  axis : @symvector.Vector,
) -> WrappingCylinder raise @symvector.VectorError {
  WrappingCylinder::{ radius_: radius, point_: point, axis_: axis.normalize() }
}

///|
pub fn WrappingCylinder::radius(self : WrappingCylinder) -> Expr {
  self.radius_
}

///|
pub fn WrappingCylinder::point(self : WrappingCylinder) -> @symvector.Point {
  self.point_
}

///|
pub fn WrappingCylinder::axis(self : WrappingCylinder) -> @symvector.Vector {
  self.axis_
}

///|
pub fn WrappingCylinder::point_on_surface(
  self : WrappingCylinder,
  point : @symvector.Point,
) -> Expr raise @symvector.VectorError {
  let relative_position = point.pos_from(self.point_)
  let parallel = self.axis_.scale(relative_position.dot(self.axis_))
  let point_vector = relative_position - parallel
  let point_radius_squared = @symsimplify.trigsimp(
    point_vector.dot(point_vector),
    max_passes=8,
  )
  mechanics_eq_expr(point_radius_squared, self.radius_ ^ mechanics_two_expr())
}

///|
pub fn WrappingCylinder::geodesic_length(
  self : WrappingCylinder,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> Expr raise {
  let relative_position = point_2.pos_from(point_1)
  let parallel_length = relative_position.dot(self.axis_)

  let point_1_relative_position = point_1.pos_from(self.point_)
  let point_1_perpendicular_vector = (point_1_relative_position -
  self.axis_.scale(point_1_relative_position.dot(self.axis_))).normalize()

  let point_2_relative_position = point_2.pos_from(self.point_)
  let point_2_perpendicular_vector = (point_2_relative_position -
  self.axis_.scale(point_2_relative_position.dot(self.axis_))).normalize()

  let cross = point_1_perpendicular_vector.cross(point_2_perpendicular_vector)
  let central_angle = mechanics_directional_atan(
    @symsimplify.simplify(cross.dot(self.axis_), max_passes=8),
    @symsimplify.simplify(
      point_1_perpendicular_vector.dot(point_2_perpendicular_vector),
      max_passes=8,
    ),
  )
  let planar_arc_length = self.radius_ * central_angle
  mech_simplify_expr(
    @symelem.sqrt(
      (parallel_length ^ mechanics_two_expr()) +
      (planar_arc_length ^ mechanics_two_expr()),
    ),
  )
}

///|
pub fn WrappingCylinder::geodesic_end_vectors(
  self : WrappingCylinder,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> (@symvector.Vector, @symvector.Vector) raise {
  let point_1_from_origin_point = point_1.pos_from(self.point_)
  let point_2_from_origin_point = point_2.pos_from(self.point_)
  if point_1_from_origin_point == point_2_from_origin_point {
    let impossible = @symvector.vector_zero().normalize()
    return (impossible, impossible)
  }

  let point_1_parallel = self.axis_.scale(
    point_1_from_origin_point.dot(self.axis_),
  )
  let point_2_parallel = self.axis_.scale(
    point_2_from_origin_point.dot(self.axis_),
  )
  let point_1_normal = point_1_from_origin_point - point_1_parallel
  let point_2_normal = point_2_from_origin_point - point_2_parallel

  let point_1_perpendicular = if point_1_normal == point_2_normal {
    @symvector.vector_zero()
  } else {
    self.axis_.cross(point_1_normal).normalize()
  }
  let point_2_perpendicular = if point_1_normal == point_2_normal {
    @symvector.vector_zero()
  } else {
    self.axis_.cross(point_2_normal).normalize().neg()
  }

  let geodesic_length = self.geodesic_length(point_1, point_2)
  let relative_position = point_2.pos_from(point_1)
  let parallel_length = relative_position.dot(self.axis_)
  let planar_arc_length = @symelem.sqrt(
    (geodesic_length ^ mechanics_two_expr()) -
    (parallel_length ^ mechanics_two_expr()),
  )

  let point_1_vector = (point_1_perpendicular.scale(planar_arc_length) +
  self.axis_.scale(parallel_length)).normalize()
  let point_2_vector = (point_2_perpendicular.scale(planar_arc_length) -
  self.axis_.scale(parallel_length)).normalize()
  (point_1_vector, point_2_vector)
}

///|
pub fn WrappingCylinder::repr(self : WrappingCylinder) -> String {
  "WrappingCylinder(radius=" +
  @symprint.pretty_string(self.radius_) +
  ", point=" +
  self.point_.name() +
  ", axis=" +
  @symvector.vsprint(self.axis_) +
  ")"
}

///|
pub fn WrappingCylinder::as_geometry(
  self : WrappingCylinder,
) -> WrappingGeometryLike {
  WrappingGeometryLike::Cylinder(self)
}

///|
pub fn wrapping_cone(
  alpha : Expr,
  apex : @symvector.Point,
  axis : @symvector.Vector,
) -> WrappingCone raise @symvector.VectorError {
  WrappingCone::{ alpha_: alpha, apex_: apex, axis_: axis.normalize() }
}

///|
pub fn WrappingCone::alpha(self : WrappingCone) -> Expr {
  self.alpha_
}

///|
pub fn WrappingCone::apex(self : WrappingCone) -> @symvector.Point {
  self.apex_
}

///|
pub fn WrappingCone::point(self : WrappingCone) -> @symvector.Point {
  self.apex_
}

///|
pub fn WrappingCone::axis(self : WrappingCone) -> @symvector.Vector {
  self.axis_
}

///|
pub fn WrappingCone::point_on_surface(
  self : WrappingCone,
  point : @symvector.Point,
) -> Expr raise @symvector.VectorError {
  let position = point.pos_from(self.apex_)
  let axis_component = self.axis_.scale(position.dot(self.axis_))
  let radial_component = position - axis_component
  let lhs = radial_component.dot(radial_component)
  let rhs = axis_component.dot(axis_component) *
    (@symelem.tan(self.alpha_) ^ mechanics_two_expr())
  mechanics_eq_expr(lhs, rhs)
}

///|
pub fn WrappingCone::geodesic_length(
  self : WrappingCone,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> Expr raise {
  let pos1 = point_1.pos_from(self.apex_)
  let pos2 = point_2.pos_from(self.apex_)
  let z1 = pos1.dot(self.axis_)
  let z2 = pos2.dot(self.axis_)
  let s1 = mech_simplify_expr(z1 * (@symelem.cos(self.alpha_) ^ int(-1)))
  let s2 = mech_simplify_expr(z2 * (@symelem.cos(self.alpha_) ^ int(-1)))
  let n1 = (pos1 - self.axis_.scale(z1)).normalize()
  let n2 = (pos2 - self.axis_.scale(z2)).normalize()
  let cross = n1.cross(n2)
  let central = mechanics_directional_atan(
    @symsimplify.simplify(cross.dot(self.axis_), max_passes=8),
    @symsimplify.simplify(n1.dot(n2), max_passes=8),
  )
  let delta_u = mech_simplify_expr(central * @symelem.sin(self.alpha_))
  mech_simplify_expr(
    @symelem.sqrt(
      (s1 ^ mechanics_two_expr()) +
      (s2 ^ mechanics_two_expr()) -
      mechanics_two_expr() * s1 * s2 * @symelem.cos(delta_u),
    ),
  )
}

///|
pub fn WrappingCone::geodesic_end_vectors(
  self : WrappingCone,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> (@symvector.Vector, @symvector.Vector) raise {
  let pos1 = point_1.pos_from(self.apex_)
  let pos2 = point_2.pos_from(self.apex_)
  if pos1 == pos2 {
    let impossible = @symvector.vector_zero().normalize()
    return (impossible, impossible)
  }
  if pos1.is_zero() {
    let v = pos2.normalize()
    return (v, v.neg())
  }
  if pos2.is_zero() {
    let v = pos1.normalize()
    return (v.neg(), v)
  }

  let z1 = pos1.dot(self.axis_)
  let z2 = pos2.dot(self.axis_)
  let s1 = mech_simplify_expr(z1 * (@symelem.cos(self.alpha_) ^ int(-1)))
  let s2 = mech_simplify_expr(z2 * (@symelem.cos(self.alpha_) ^ int(-1)))
  let l = self.geodesic_length(point_1, point_2)
  let n1 = (pos1 - self.axis_.scale(z1)).normalize()
  let n2 = (pos2 - self.axis_.scale(z2)).normalize()
  let cross = n1.cross(n2)
  let central = mechanics_directional_atan(
    @symsimplify.simplify(cross.dot(self.axis_), max_passes=8),
    @symsimplify.simplify(n1.dot(n2), max_passes=8),
  )
  let delta_u = mech_simplify_expr(central * @symelem.sin(self.alpha_))
  let g1 = pos1.normalize()
  let c1 = self.axis_.cross(n1)
  let g2 = pos2.normalize()
  let c2 = self.axis_.cross(n2)

  let v1 = g1.scale(
      mech_simplify_expr((s2 * @symelem.cos(delta_u) - s1) * (l ^ int(-1))),
    ) +
    c1.scale(mech_simplify_expr(s2 * @symelem.sin(delta_u) * (l ^ int(-1))))
  let v2 = g2.scale(
      mech_simplify_expr((s1 * @symelem.cos(delta_u) - s2) * (l ^ int(-1))),
    ) +
    c2.scale(
      mech_simplify_expr(int(-1) * s1 * @symelem.sin(delta_u) * (l ^ int(-1))),
    )
  (v1, v2)
}

///|
pub fn WrappingCone::repr(self : WrappingCone) -> String {
  "WrappingCone(alpha=" +
  @symprint.pretty_string(self.alpha_) +
  ", apex=" +
  self.apex_.name() +
  ", axis=" +
  @symvector.vsprint(self.axis_) +
  ")"
}

///|
pub fn WrappingCone::as_geometry(self : WrappingCone) -> WrappingGeometryLike {
  WrappingGeometryLike::Cone(self)
}

///|
pub fn WrappingGeometryLike::point(
  self : WrappingGeometryLike,
) -> @symvector.Point {
  match self {
    WrappingGeometryLike::Sphere(value) => value.point()
    WrappingGeometryLike::Cylinder(value) => value.point()
    WrappingGeometryLike::Cone(value) => value.point()
  }
}

///|
pub fn WrappingGeometryLike::point_on_surface(
  self : WrappingGeometryLike,
  point : @symvector.Point,
) -> Expr raise @symvector.VectorError {
  match self {
    WrappingGeometryLike::Sphere(value) => value.point_on_surface(point)
    WrappingGeometryLike::Cylinder(value) => value.point_on_surface(point)
    WrappingGeometryLike::Cone(value) => value.point_on_surface(point)
  }
}

///|
pub fn WrappingGeometryLike::geodesic_length(
  self : WrappingGeometryLike,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> Expr raise {
  match self {
    WrappingGeometryLike::Sphere(value) =>
      value.geodesic_length(point_1, point_2)
    WrappingGeometryLike::Cylinder(value) =>
      value.geodesic_length(point_1, point_2)
    WrappingGeometryLike::Cone(value) => value.geodesic_length(point_1, point_2)
  }
}

///|
pub fn WrappingGeometryLike::geodesic_end_vectors(
  self : WrappingGeometryLike,
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> (@symvector.Vector, @symvector.Vector) raise {
  match self {
    WrappingGeometryLike::Sphere(value) =>
      value.geodesic_end_vectors(point_1, point_2)
    WrappingGeometryLike::Cylinder(value) =>
      value.geodesic_end_vectors(point_1, point_2)
    WrappingGeometryLike::Cone(value) =>
      value.geodesic_end_vectors(point_1, point_2)
  }
}

///|
pub fn WrappingGeometryLike::repr(self : WrappingGeometryLike) -> String {
  match self {
    WrappingGeometryLike::Sphere(value) => value.repr()
    WrappingGeometryLike::Cylinder(value) => value.repr()
    WrappingGeometryLike::Cone(value) => value.repr()
  }
}
