///|
pub impl Eq for VectorKind with fn equal(self, other : VectorKind) -> Bool {
  self.element_kind_ == other.element_kind_
}

///|
pub impl Eq for VectorKind with fn not_equal(self, other : VectorKind) -> Bool {
  self.element_kind_ != other.element_kind_
}

///|
pub impl Show for VectorKind with fn to_string(self) -> String {
  "VectorKind(" + self.element_kind_ + ")"
}

///|
pub impl Show for VectorKind with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for CoordTransform with fn to_string(self) -> String {
  match self {
    CoordTransform::Cartesian => "Cartesian"
    CoordTransform::Cylindrical => "Cylindrical"
    CoordTransform::Spherical => "Spherical"
    CoordTransform::LambdaTransform(function) =>
      "LambdaTransform(" + function.to_string() + ")"
    CoordTransform::TupleTransform(rotation_matrix, location) =>
      "TupleTransform(" +
      matrix_expr_key(rotation_matrix) +
      ", " +
      location.to_string() +
      ")"
  }
}

///|
pub impl Show for CoordTransform with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for Point with fn equal(self, other : Point) -> Bool {
  self.raw_ == other.raw_
}

///|
pub impl Eq for Point with fn not_equal(self, other : Point) -> Bool {
  self.raw_ != other.raw_
}

///|
pub impl Hash for Point with fn hash(self) -> Int {
  let hasher = Hasher()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for Point with fn hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_string(self.name_)
}

///|
pub impl Show for Point with fn to_string(self) -> String {
  self.name_
}

///|
pub impl Show for Point with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for CoordSys3D with fn equal(self, other : CoordSys3D) -> Bool {
  self.eq_key_ == other.eq_key_
}

///|
pub impl Eq for CoordSys3D with fn not_equal(self, other : CoordSys3D) -> Bool {
  self.eq_key_ != other.eq_key_
}

///|
pub impl Hash for CoordSys3D with fn hash(self) -> Int {
  let hasher = Hasher()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for CoordSys3D with fn hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_string(self.eq_key_)
}

///|
pub impl Compare for CoordSys3D with fn compare(self, other : CoordSys3D) -> Int {
  compare_coord_sys(self, other)
}

///|
pub impl Show for CoordSys3D with fn to_string(self) -> String {
  self.name_
}

///|
pub impl Show for CoordSys3D with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for BaseScalar with fn equal(self, other : BaseScalar) -> Bool {
  self.axis_ == other.axis_ && self.system_ == other.system_
}

///|
pub impl Eq for BaseScalar with fn not_equal(self, other : BaseScalar) -> Bool {
  self.axis_ != other.axis_ || self.system_ != other.system_
}

///|
pub impl Hash for BaseScalar with fn hash(self) -> Int {
  let hasher = Hasher()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for BaseScalar with fn hash_combine(self, hasher : Hasher) -> Unit {
  self.system_.hash_combine(hasher)
  hasher.combine_int(self.axis_)
}

///|
pub impl Compare for BaseScalar with fn compare(self, other : BaseScalar) -> Int {
  let sys_cmp = compare_coord_sys(self.system_, other.system_)
  if sys_cmp != 0 {
    return sys_cmp
  }
  self.axis_ - other.axis_
}

///|
pub impl Show for BaseScalar with fn to_string(self) -> String {
  self.name_
}

///|
pub impl Show for BaseScalar with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for BaseVector with fn equal(self, other : BaseVector) -> Bool {
  self.axis_ == other.axis_ && self.system_ == other.system_
}

///|
pub impl Eq for BaseVector with fn not_equal(self, other : BaseVector) -> Bool {
  self.axis_ != other.axis_ || self.system_ != other.system_
}

///|
pub impl Hash for BaseVector with fn hash(self) -> Int {
  let hasher = Hasher()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for BaseVector with fn hash_combine(self, hasher : Hasher) -> Unit {
  self.system_.hash_combine(hasher)
  hasher.combine_int(self.axis_)
}

///|
pub impl Compare for BaseVector with fn compare(self, other : BaseVector) -> Int {
  compare_base_vector(self, other)
}

///|
pub impl Show for BaseVector with fn to_string(self) -> String {
  self.system_.name_ + "." + self.system_.vector_names_[self.axis_]
}

///|
pub impl Show for BaseVector with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for BaseDyadic with fn equal(self, other : BaseDyadic) -> Bool {
  self.left_ == other.left_ && self.right_ == other.right_
}

///|
pub impl Eq for BaseDyadic with fn not_equal(self, other : BaseDyadic) -> Bool {
  self.left_ != other.left_ || self.right_ != other.right_
}

///|
pub impl Hash for BaseDyadic with fn hash(self) -> Int {
  let hasher = Hasher()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for BaseDyadic with fn hash_combine(self, hasher : Hasher) -> Unit {
  self.left_.hash_combine(hasher)
  self.right_.hash_combine(hasher)
}

///|
pub impl Compare for BaseDyadic with fn compare(self, other : BaseDyadic) -> Int {
  compare_base_dyadic(self, other)
}

///|
pub impl Show for BaseDyadic with fn to_string(self) -> String {
  "(" + self.left_.to_string() + "|" + self.right_.to_string() + ")"
}

///|
pub impl Show for BaseDyadic with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn vector_components_equal(lhs : Vector, rhs : Vector) -> Bool {
  let lhs_components = lhs.components()
  let rhs_components = rhs.components()
  if lhs_components.length() != rhs_components.length() {
    return false
  }
  for basis in lhs_components.keys() {
    if !rhs_components.contains(basis) {
      return false
    }
    if @symcore.compare_expr(lhs_components[basis], rhs_components[basis]) != 0 {
      return false
    }
  }
  true
}

///|
pub impl Eq for Vector with fn equal(self, other : Vector) -> Bool {
  vector_components_equal(self, other)
}

///|
pub impl Eq for Vector with fn not_equal(self, other : Vector) -> Bool {
  !vector_components_equal(self, other)
}

///|
fn vector_string(vector : Vector) -> String {
  let components = vector.components()
  if components.is_empty() {
    return "0"
  }
  let bases = components.keys().to_array()
  bases.sort_by(compare_base_vector)
  let parts : Array[String] = []
  for basis in bases {
    parts.push(scalar_with_basis(components[basis], basis.to_string()))
  }
  join_signed(parts)
}

///|
pub impl Show for Vector with fn to_string(self) -> String {
  vector_string(self)
}

///|
pub impl Show for Vector with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn dyadic_components_equal(lhs : Dyadic, rhs : Dyadic) -> Bool {
  let lhs_components = lhs.components()
  let rhs_components = rhs.components()
  if lhs_components.length() != rhs_components.length() {
    return false
  }
  for basis in lhs_components.keys() {
    if !rhs_components.contains(basis) {
      return false
    }
    if @symcore.compare_expr(lhs_components[basis], rhs_components[basis]) != 0 {
      return false
    }
  }
  true
}

///|
pub impl Eq for Dyadic with fn equal(self, other : Dyadic) -> Bool {
  dyadic_components_equal(self, other)
}

///|
pub impl Eq for Dyadic with fn not_equal(self, other : Dyadic) -> Bool {
  !dyadic_components_equal(self, other)
}

///|
fn dyadic_string(dyadic : Dyadic) -> String {
  let components = dyadic.components()
  if components.is_empty() {
    return "0"
  }
  let basis = components.keys().to_array()
  basis.sort_by(compare_base_dyadic)
  let parts : Array[String] = []
  for item in basis {
    parts.push(scalar_with_basis(components[item], item.to_string()))
  }
  join_signed(parts)
}

///|
pub impl Show for Dyadic with fn to_string(self) -> String {
  dyadic_string(self)
}

///|
pub impl Show for Dyadic with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for Gradient with fn to_string(self) -> String {
  match self.field_ {
    ScalarOrVector::ScalarExpr(expr) =>
      "Gradient(" + @symprint.pretty_string(expr) + ")"
    ScalarOrVector::VectorExpr(vect) => "Gradient(" + vect.to_string() + ")"
  }
}

///|
pub impl Show for Gradient with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for Divergence with fn to_string(self) -> String {
  "Divergence(" + self.field_.to_string() + ")"
}

///|
pub impl Show for Divergence with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for Curl with fn to_string(self) -> String {
  "Curl(" + self.field_.to_string() + ")"
}

///|
pub impl Show for Curl with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for Laplacian with fn to_string(self) -> String {
  match self.field_ {
    ScalarOrVector::ScalarExpr(expr) =>
      "Laplacian(" + @symprint.pretty_string(expr) + ")"
    ScalarOrVector::VectorExpr(vect) => "Laplacian(" + vect.to_string() + ")"
  }
}

///|
pub impl Show for Laplacian with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for Del with fn to_string(self) -> String {
  ignore(self)
  "delop"
}

///|
pub impl Show for Del with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for VectorZero with fn equal(self, other : VectorZero) -> Bool {
  self.value_ == other.value_
}

///|
pub impl Show for VectorZero with fn to_string(self) -> String {
  self.value_.to_string()
}

///|
pub impl Show for VectorZero with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for VectorMul with fn equal(self, other : VectorMul) -> Bool {
  self.base_vector_ == other.base_vector_ &&
  @symcore.compare_expr(self.measure_number_, other.measure_number_) == 0
}

///|
pub impl Show for VectorMul with fn to_string(self) -> String {
  self.value_.to_string()
}

///|
pub impl Show for VectorMul with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for VectorAdd with fn equal(self, other : VectorAdd) -> Bool {
  self.value_ == other.value_
}

///|
pub impl Show for VectorAdd with fn to_string(self) -> String {
  self.value_.to_string()
}

///|
pub impl Show for VectorAdd with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for Cross with fn equal(self, other : Cross) -> Bool {
  self.sign_ == other.sign_ &&
  self.lhs_ == other.lhs_ &&
  self.rhs_ == other.rhs_
}

///|
pub impl Show for Cross with fn to_string(self) -> String {
  let body = "Cross(" +
    self.lhs_.to_string() +
    ", " +
    self.rhs_.to_string() +
    ")"
  if self.sign_ < 0 {
    "-" + body
  } else {
    body
  }
}

///|
pub impl Show for Cross with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for Dot with fn equal(self, other : Dot) -> Bool {
  self.lhs_ == other.lhs_ && self.rhs_ == other.rhs_
}

///|
pub impl Show for Dot with fn to_string(self) -> String {
  "Dot(" + self.lhs_.to_string() + ", " + self.rhs_.to_string() + ")"
}

///|
pub impl Show for Dot with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for DyadicZero with fn equal(self, other : DyadicZero) -> Bool {
  self.value_ == other.value_
}

///|
pub impl Show for DyadicZero with fn to_string(self) -> String {
  self.value_.to_string()
}

///|
pub impl Show for DyadicZero with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for DyadicMul with fn equal(self, other : DyadicMul) -> Bool {
  self.base_dyadic_ == other.base_dyadic_ &&
  @symcore.compare_expr(self.measure_number_, other.measure_number_) == 0
}

///|
pub impl Show for DyadicMul with fn to_string(self) -> String {
  self.value_.to_string()
}

///|
pub impl Show for DyadicMul with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for DyadicAdd with fn equal(self, other : DyadicAdd) -> Bool {
  self.value_ == other.value_
}

///|
pub impl Show for DyadicAdd with fn to_string(self) -> String {
  self.value_.to_string()
}

///|
pub impl Show for DyadicAdd with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for AxisOrienter with fn to_string(self) -> String {
  "AxisOrienter(" +
  @symprint.pretty_string(self.angle_) +
  ", " +
  self.axis_.to_string() +
  ")"
}

///|
pub impl Show for AxisOrienter with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for BodyOrienter with fn to_string(self) -> String {
  "BodyOrienter(" +
  @symprint.pretty_string(self.angle1_) +
  ", " +
  @symprint.pretty_string(self.angle2_) +
  ", " +
  @symprint.pretty_string(self.angle3_) +
  ", " +
  self.rotation_order_ +
  ")"
}

///|
pub impl Show for BodyOrienter with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for SpaceOrienter with fn to_string(self) -> String {
  "SpaceOrienter(" +
  @symprint.pretty_string(self.angle1_) +
  ", " +
  @symprint.pretty_string(self.angle2_) +
  ", " +
  @symprint.pretty_string(self.angle3_) +
  ", " +
  self.rotation_order_ +
  ")"
}

///|
pub impl Show for SpaceOrienter with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for QuaternionOrienter with fn to_string(self) -> String {
  "QuaternionOrienter(" +
  @symprint.pretty_string(self.q0_) +
  ", " +
  @symprint.pretty_string(self.q1_) +
  ", " +
  @symprint.pretty_string(self.q2_) +
  ", " +
  @symprint.pretty_string(self.q3_) +
  ")"
}

///|
pub impl Show for QuaternionOrienter with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for TransformFunction with fn to_string(self) -> String {
  "TransformFunction(" +
  self.equations_.map(@symprint.pretty_string).join(", ") +
  ")"
}

///|
pub impl Show for TransformFunction with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
