///|
/// Pathway helpers aligned with the high-value surface of
/// `sympy.physics.mechanics.pathway`.

///|
pub struct LinearPathway {
  attachment_1_ : @symvector.Point
  attachment_2_ : @symvector.Point
} derive(Eq)

///|
pub struct ObstacleSetPathway {
  attachments_ : Array[@symvector.Point]
} derive(Eq)

///|
pub struct WrappingPathway {
  attachment_1_ : @symvector.Point
  attachment_2_ : @symvector.Point
  geometry_ : WrappingGeometryLike
} derive(Eq)

///|
pub enum PathwayLike {
  Linear(LinearPathway)
  Obstacle(ObstacleSetPathway)
  Wrapping(WrappingPathway)
} derive(Eq)

///|
fn pathway_validate_pair(
  attachment_1 : @symvector.Point,
  attachment_2 : @symvector.Point,
) -> Unit {
  ignore(attachment_1)
  ignore(attachment_2)
}

///|
fn point_pair_relative_position(
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> @symvector.Vector raise @symvector.VectorError {
  point_2.pos_from(point_1)
}

///|
fn point_pair_length(
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> Expr raise @symvector.VectorError {
  try! point_pair_relative_position(point_1, point_2).magnitude()
}

///|
fn point_pair_extension_velocity(
  point_1 : @symvector.Point,
  point_2 : @symvector.Point,
) -> Expr raise @symvector.VectorError {
  @symcalculus.diff(
    try! point_pair_length(point_1, point_2),
    @symvector.dynamicsymbols_t,
  )
}

///|
pub fn linear_pathway(
  attachment_1 : @symvector.Point,
  attachment_2 : @symvector.Point,
) -> LinearPathway {
  pathway_validate_pair(attachment_1, attachment_2)
  LinearPathway::{ attachment_1_: attachment_1, attachment_2_: attachment_2 }
}

///|
pub fn LinearPathway::attachments(
  self : LinearPathway,
) -> Array[@symvector.Point] {
  [self.attachment_1_, self.attachment_2_]
}

///|
pub fn LinearPathway::length(
  self : LinearPathway,
) -> Expr raise @symvector.VectorError {
  point_pair_length(self.attachment_1_, self.attachment_2_)
}

///|
pub fn LinearPathway::extension_velocity(
  self : LinearPathway,
) -> Expr raise @symvector.VectorError {
  point_pair_extension_velocity(self.attachment_1_, self.attachment_2_)
}

///|
pub fn LinearPathway::to_loads(
  self : LinearPathway,
  force_value : Expr,
) -> Array[Force] raise @symvector.VectorError {
  let relative_position = try! point_pair_relative_position(
    self.attachment_1_,
    self.attachment_2_,
  )
  let length = try! self.length()
  [
    force(
      self.attachment_1_,
      try! relative_position.truediv(length).scale(force_value).neg(),
    ),
    force(
      self.attachment_2_,
      try! relative_position.truediv(length).scale(force_value),
    ),
  ]
}

///|
pub fn LinearPathway::repr(self : LinearPathway) -> String {
  "LinearPathway(" +
  self.attachment_1_.name() +
  ", " +
  self.attachment_2_.name() +
  ")"
}

///|
pub fn LinearPathway::as_pathway(self : LinearPathway) -> PathwayLike {
  PathwayLike::Linear(self)
}

///|
pub fn obstacle_set_pathway(
  attachments : Array[@symvector.Point],
) -> ObstacleSetPathway raise @symphysics.PhysicsError {
  if attachments.length() < 3 {
    raise @symphysics.PhysicsError::ValueError(
      "obstacle set pathway requires at least three attachment points",
    )
  }
  ObstacleSetPathway::{ attachments_: attachments.copy() }
}

///|
pub fn ObstacleSetPathway::attachments(
  self : ObstacleSetPathway,
) -> Array[@symvector.Point] {
  self.attachments_.copy()
}

///|
pub fn ObstacleSetPathway::length(
  self : ObstacleSetPathway,
) -> Expr raise @symvector.VectorError {
  let mut total = int(0)
  for i in 0..<(self.attachments_.length() - 1) {
    total = mech_simplify_expr(
      total +
      (try! point_pair_length(self.attachments_[i], self.attachments_[i + 1])),
    )
  }
  total
}

///|
pub fn ObstacleSetPathway::extension_velocity(
  self : ObstacleSetPathway,
) -> Expr raise @symvector.VectorError {
  let mut total = int(0)
  for i in 0..<(self.attachments_.length() - 1) {
    total = mech_simplify_expr(
      total +
      (try! point_pair_extension_velocity(
        self.attachments_[i],
        self.attachments_[i + 1],
      )),
    )
  }
  total
}

///|
pub fn ObstacleSetPathway::to_loads(
  self : ObstacleSetPathway,
  force_value : Expr,
) -> Array[Force] raise @symvector.VectorError {
  let loads : Array[Force] = []
  for i in 0..<(self.attachments_.length() - 1) {
    let p0 = self.attachments_[i]
    let p1 = self.attachments_[i + 1]
    let relative_position = try! point_pair_relative_position(p0, p1)
    let length = try! point_pair_length(p0, p1)
    loads.push(
      force(p0, try! relative_position.truediv(length).scale(force_value).neg()),
    )
    loads.push(
      force(p1, try! relative_position.truediv(length).scale(force_value)),
    )
  }
  loads
}

///|
pub fn ObstacleSetPathway::repr(self : ObstacleSetPathway) -> String {
  "ObstacleSetPathway(" +
  self.attachments_.map(fn(p) { p.name() }).join(", ") +
  ")"
}

///|
pub fn ObstacleSetPathway::as_pathway(self : ObstacleSetPathway) -> PathwayLike {
  PathwayLike::Obstacle(self)
}

///|
pub fn wrapping_pathway(
  attachment_1 : @symvector.Point,
  attachment_2 : @symvector.Point,
  geometry : WrappingGeometryLike,
) -> WrappingPathway {
  pathway_validate_pair(attachment_1, attachment_2)
  WrappingPathway::{
    attachment_1_: attachment_1,
    attachment_2_: attachment_2,
    geometry_: geometry,
  }
}

///|
pub fn WrappingPathway::attachments(
  self : WrappingPathway,
) -> Array[@symvector.Point] {
  [self.attachment_1_, self.attachment_2_]
}

///|
pub fn WrappingPathway::geometry(
  self : WrappingPathway,
) -> WrappingGeometryLike {
  self.geometry_
}

///|
pub fn WrappingPathway::length(
  self : WrappingPathway,
) -> Expr raise @symvector.VectorError {
  self.geometry_.geodesic_length(self.attachment_1_, self.attachment_2_)
}

///|
pub fn WrappingPathway::extension_velocity(
  self : WrappingPathway,
) -> Expr raise @symvector.VectorError {
  @symcalculus.diff(try! self.length(), @symvector.dynamicsymbols_t)
}

///|
pub fn WrappingPathway::to_loads(
  self : WrappingPathway,
  force_value : Expr,
) -> Array[Force] raise @symvector.VectorError {
  let p0 = self.attachment_1_
  let p1 = self.attachment_2_
  let origin = self.geometry_.point()
  let (end0, end1) = try! self.geometry_.geodesic_end_vectors(p0, p1)
  let center = (end0 + end1).neg()
  [
    force(p0, end0.scale(force_value)),
    force(p1, end1.scale(force_value)),
    force(origin, center.scale(force_value)),
  ]
}

///|
pub fn WrappingPathway::repr(self : WrappingPathway) -> String {
  "WrappingPathway(" +
  self.attachment_1_.name() +
  ", " +
  self.attachment_2_.name() +
  ", geometry=" +
  self.geometry_.repr() +
  ")"
}

///|
pub fn WrappingPathway::as_pathway(self : WrappingPathway) -> PathwayLike {
  PathwayLike::Wrapping(self)
}

///|
pub fn PathwayLike::length(
  self : PathwayLike,
) -> Expr raise @symvector.VectorError {
  match self {
    PathwayLike::Linear(value) => value.length()
    PathwayLike::Obstacle(value) => value.length()
    PathwayLike::Wrapping(value) => value.length()
  }
}

///|
pub fn PathwayLike::extension_velocity(
  self : PathwayLike,
) -> Expr raise @symvector.VectorError {
  match self {
    PathwayLike::Linear(value) => value.extension_velocity()
    PathwayLike::Obstacle(value) => value.extension_velocity()
    PathwayLike::Wrapping(value) => value.extension_velocity()
  }
}

///|
pub fn PathwayLike::to_loads(
  self : PathwayLike,
  force_value : Expr,
) -> Array[Force] raise @symvector.VectorError {
  match self {
    PathwayLike::Linear(value) => value.to_loads(force_value)
    PathwayLike::Obstacle(value) => value.to_loads(force_value)
    PathwayLike::Wrapping(value) => value.to_loads(force_value)
  }
}

///|
pub fn PathwayLike::repr(self : PathwayLike) -> String {
  match self {
    PathwayLike::Linear(value) => value.repr()
    PathwayLike::Obstacle(value) => value.repr()
    PathwayLike::Wrapping(value) => value.repr()
  }
}
