///|
pub fn vector_zero() -> Vector {
  { raw_: @rawvec.vector_zero() }
}

///|
pub fn vector_term(coeff : @symcore.Expr, basis : BaseVector) -> Vector {
  basis.scale(coeff)
}

///|
pub fn vector_from_terms(terms : Array[(@symcore.Expr, BaseVector)]) -> Vector {
  let mut raw = @rawvec.vector_zero()
  for term in terms {
    raw = raw + raw_basis(term.1.system_.frame_, term.1.axis_).scale(term.0)
  }
  { raw_: raw }
}

///|
pub fn Vector::kind(self : Vector) -> VectorKind {
  vector_kind()
}

///|
pub fn Vector::is_zero(self : Vector) -> Bool {
  self.raw_.is_zero()
}

///|
pub fn Vector::components(self : Vector) -> Map[BaseVector, @symcore.Expr] {
  let out : Map[BaseVector, @symcore.Expr] = {}
  for item in self.raw_.args {
    let system = coord_system_from_frame(item.0)
    let coeffs = item.1
    for axis in 0..<3 {
      if !@symcore.is_zero(coeffs[axis]) {
        let basis = BaseVector::{ axis_: axis, system_: system }
        match out.get(basis) {
          Some(prev) => out[basis] = prev + coeffs[axis]
          None => out[basis] = coeffs[axis]
        }
      }
    }
  }
  out
}

///|
pub impl Add for Vector with add(self, other : Vector) -> Vector {
  { raw_: self.raw_ + other.raw_ }
}

///|
pub impl Sub for Vector with sub(self, other : Vector) -> Vector {
  { raw_: self.raw_ - other.raw_ }
}

///|
pub fn Vector::scale(self : Vector, scalar : @symcore.Expr) -> Vector {
  { raw_: self.raw_.scale(scalar) }
}

///|
pub fn Vector::neg(self : Vector) -> Vector {
  self.scale(@symcore.int(-1))
}

///|
pub fn Vector::dot(
  self : Vector,
  other : Vector,
) -> @symcore.Expr raise @rawvec.VectorError {
  self.raw_.dot(other.raw_)
}

///|
pub fn Vector::cross(
  self : Vector,
  other : Vector,
) -> Vector raise @rawvec.VectorError {
  { raw_: self.raw_.cross(other.raw_) }
}

///|
pub fn Vector::express(
  self : Vector,
  system : CoordSys3D,
  variables? : Bool = false,
) -> Vector raise @rawvec.VectorError {
  { raw_: self.raw_.express(system.frame_, variables~) }
}

///|
pub fn Vector::to_matrix(
  self : Vector,
  system : CoordSys3D,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  self.raw_.to_matrix(system.frame_)
}

///|
pub fn Vector::magnitude(
  self : Vector,
) -> @symcore.Expr raise @rawvec.VectorError {
  self.raw_.magnitude()
}

///|
pub fn Vector::normalize(self : Vector) -> Vector raise @rawvec.VectorError {
  { raw_: self.raw_.normalize() }
}
