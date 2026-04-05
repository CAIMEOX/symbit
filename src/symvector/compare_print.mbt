///|
pub impl Eq for VectorKind with equal(self, other : VectorKind) -> Bool {
  self.element_kind_ == other.element_kind_
}

///|
pub impl Eq for VectorKind with not_equal(self, other : VectorKind) -> Bool {
  self.element_kind_ != other.element_kind_
}

///|
pub impl Show for VectorKind with to_string(self) -> String {
  "VectorKind(" + self.element_kind_ + ")"
}

///|
pub impl Show for VectorKind with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for Point with equal(self, other : Point) -> Bool {
  self.raw_ == other.raw_
}

///|
pub impl Eq for Point with not_equal(self, other : Point) -> Bool {
  self.raw_ != other.raw_
}

///|
pub impl Hash for Point with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for Point with hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_string(self.name_)
}

///|
pub impl Show for Point with to_string(self) -> String {
  self.name_
}

///|
pub impl Show for Point with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for CoordSys3D with equal(self, other : CoordSys3D) -> Bool {
  self.eq_key_ == other.eq_key_
}

///|
pub impl Eq for CoordSys3D with not_equal(self, other : CoordSys3D) -> Bool {
  self.eq_key_ != other.eq_key_
}

///|
pub impl Hash for CoordSys3D with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for CoordSys3D with hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_string(self.eq_key_)
}

///|
pub impl Compare for CoordSys3D with compare(self, other : CoordSys3D) -> Int {
  compare_coord_sys(self, other)
}

///|
pub impl Show for CoordSys3D with to_string(self) -> String {
  self.name_
}

///|
pub impl Show for CoordSys3D with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for BaseScalar with equal(self, other : BaseScalar) -> Bool {
  self.axis_ == other.axis_ && self.system_ == other.system_
}

///|
pub impl Eq for BaseScalar with not_equal(self, other : BaseScalar) -> Bool {
  self.axis_ != other.axis_ || self.system_ != other.system_
}

///|
pub impl Hash for BaseScalar with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for BaseScalar with hash_combine(self, hasher : Hasher) -> Unit {
  self.system_.hash_combine(hasher)
  hasher.combine_int(self.axis_)
}

///|
pub impl Compare for BaseScalar with compare(self, other : BaseScalar) -> Int {
  let sys_cmp = compare_coord_sys(self.system_, other.system_)
  if sys_cmp != 0 {
    return sys_cmp
  }
  self.axis_ - other.axis_
}

///|
pub impl Show for BaseScalar with to_string(self) -> String {
  self.name_
}

///|
pub impl Show for BaseScalar with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for BaseVector with equal(self, other : BaseVector) -> Bool {
  self.axis_ == other.axis_ && self.system_ == other.system_
}

///|
pub impl Eq for BaseVector with not_equal(self, other : BaseVector) -> Bool {
  self.axis_ != other.axis_ || self.system_ != other.system_
}

///|
pub impl Hash for BaseVector with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for BaseVector with hash_combine(self, hasher : Hasher) -> Unit {
  self.system_.hash_combine(hasher)
  hasher.combine_int(self.axis_)
}

///|
pub impl Compare for BaseVector with compare(self, other : BaseVector) -> Int {
  compare_base_vector(self, other)
}

///|
pub impl Show for BaseVector with to_string(self) -> String {
  self.system_.name_ + "." + self.system_.vector_names_[self.axis_]
}

///|
pub impl Show for BaseVector with output(self, logger : &Logger) -> Unit {
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
    if lhs_components[basis] != rhs_components[basis] {
      return false
    }
  }
  true
}

///|
pub impl Eq for Vector with equal(self, other : Vector) -> Bool {
  vector_components_equal(self, other)
}

///|
pub impl Eq for Vector with not_equal(self, other : Vector) -> Bool {
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
pub impl Show for Vector with to_string(self) -> String {
  vector_string(self)
}

///|
pub impl Show for Vector with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
