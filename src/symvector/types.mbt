///|
pub struct VectorKind {
  element_kind_ : String
}

///|
pub enum CoordTransform {
  Cartesian
  Cylindrical
  Spherical
  LambdaTransform(TransformFunction)
  TupleTransform(@symphysics.ExplicitMatrix, Vector)
} derive(Eq)

///|
pub struct TransformFunction {
  equations_ : Array[@symcore.Expr]
} derive(Eq)

///|
pub enum PointReference {
  PointObject(Point)
  CoordSystem(CoordSys3D)
}

///|
pub enum ScalarOrVector {
  ScalarExpr(@symcore.Expr)
  VectorExpr(Vector)
}

///|
pub enum GradientValue {
  VectorValue(Vector)
  DyadicValue(Dyadic)
}

///|
pub fn point_reference_point(point : Point) -> PointReference {
  PointObject(point)
}

///|
pub fn point_reference_coord_system(system : CoordSys3D) -> PointReference {
  CoordSystem(system)
}

///|
pub fn scalar_or_vector_scalar(expr : @symcore.Expr) -> ScalarOrVector {
  ScalarExpr(expr)
}

///|
pub fn scalar_or_vector_vector(vector : Vector) -> ScalarOrVector {
  VectorExpr(vector)
}

///|
pub struct Gradient {
  field_ : ScalarOrVector
}

///|
pub struct Divergence {
  field_ : Vector
}

///|
pub struct Curl {
  field_ : Vector
}

///|
pub struct Laplacian {
  field_ : ScalarOrVector
}

///|
pub struct Del {} derive(Default)

///|
pub struct Point {
  name_ : String
  raw_ : @rawvec.Point
}

///|
pub struct CoordSys3D {
  name_ : String
  eq_key_ : String
  root_key_ : String
  frame_ : @rawvec.ReferenceFrame
  origin_ : Point
  parent_ : CoordSys3D?
  vector_names_ : Array[String]
  variable_names_ : Array[String]
  transformation_ : CoordTransform
  lame_coefficients_ : Array[@symcore.Expr]
  parent_rotation_matrix_ : @symphysics.ExplicitMatrix
  location_ : Vector
  transformation_to_parent_ : Array[@symcore.Expr]
  transformation_from_parent_template_ : Array[@symcore.Expr]?
  transformation_matrix_to_parent_ : @symphysics.ExplicitMatrix
  is_cartesian_ : Bool
  is_curvilinear_ : Bool
}

///|
pub struct BaseScalar {
  axis_ : Int
  system_ : CoordSys3D
  name_ : String
  expr_ : @symcore.Expr
}

///|
pub struct BaseVector {
  axis_ : Int
  system_ : CoordSys3D
}

///|
pub struct BaseDyadic {
  left_ : BaseVector
  right_ : BaseVector
}

///|
pub struct Vector {
  raw_ : @rawvec.Vector
}

///|
pub struct Dyadic {
  raw_ : @rawvec.Dyadic
}

///|
pub struct VectorZero {
  value_ : Vector
}

///|
pub struct VectorMul {
  measure_number_ : @symcore.Expr
  base_vector_ : BaseVector
  value_ : Vector
}

///|
pub struct VectorAdd {
  terms_ : Array[Vector]
  value_ : Vector
}

///|
pub struct Cross {
  lhs_ : Vector
  rhs_ : Vector
  sign_ : Int
}

///|
pub struct Dot {
  lhs_ : Vector
  rhs_ : Vector
}

///|
pub struct DyadicZero {
  value_ : Dyadic
}

///|
pub struct DyadicMul {
  measure_number_ : @symcore.Expr
  base_dyadic_ : BaseDyadic
  value_ : Dyadic
}

///|
pub struct DyadicAdd {
  terms_ : Array[Dyadic]
  value_ : Dyadic
}

///|
pub struct AxisOrienter {
  angle_ : @symcore.Expr
  axis_ : Vector
}

///|
pub struct BodyOrienter {
  angle1_ : @symcore.Expr
  angle2_ : @symcore.Expr
  angle3_ : @symcore.Expr
  rotation_order_ : String
  parent_orient_ : @symphysics.ExplicitMatrix
}

///|
pub struct SpaceOrienter {
  angle1_ : @symcore.Expr
  angle2_ : @symcore.Expr
  angle3_ : @symcore.Expr
  rotation_order_ : String
  parent_orient_ : @symphysics.ExplicitMatrix
}

///|
pub struct QuaternionOrienter {
  q0_ : @symcore.Expr
  q1_ : @symcore.Expr
  q2_ : @symcore.Expr
  q3_ : @symcore.Expr
  parent_orient_ : @symphysics.ExplicitMatrix
}

///|
pub enum Orienter {
  Axis(AxisOrienter)
  Body(BodyOrienter)
  Space(SpaceOrienter)
  Quaternion(QuaternionOrienter)
}
