///|
pub struct VectorKind {
  element_kind_ : String
}

///|
pub enum CoordTransform {
  Cartesian
  Cylindrical
  Spherical
}

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
  PointReference::PointObject(point)
}

///|
pub fn point_reference_coord_system(system : CoordSys3D) -> PointReference {
  PointReference::CoordSystem(system)
}

///|
pub fn scalar_or_vector_scalar(expr : @symcore.Expr) -> ScalarOrVector {
  ScalarOrVector::ScalarExpr(expr)
}

///|
pub fn scalar_or_vector_vector(vector : Vector) -> ScalarOrVector {
  ScalarOrVector::VectorExpr(vector)
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
pub struct Del {}

///|
pub struct Point {
  name_ : String
  raw_ : @rawvec.Point
}

///|
pub struct CoordSys3D {
  name_ : String
  eq_key_ : String
  frame_ : @rawvec.ReferenceFrame
  origin_ : Point
  parent_ : CoordSys3D?
  vector_names_ : Array[String]
  variable_names_ : Array[String]
  transformation_ : CoordTransform
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
