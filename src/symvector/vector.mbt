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
fn vector_equals_zero(expr : @symcore.Expr) -> Bool? {
  let simplified = @symsimplify.ratsimp(
    @symsimplify.futrig(
      @symsimplify.trigsimp(@symsimplify.simplify(expr), max_passes=4),
      max_passes=4,
    ),
    max_passes=4,
  )
  if @symcore.is_zero(simplified) {
    return Some(true)
  }
  if @symcore.free_symbols(simplified).is_empty() {
    let approx = @symcore.evalf(simplified, prec=80)
    if @symcore.is_zero(approx) {
      return Some(true)
    }
  }
  match simplified {
    @symcore.Expr::Number(n) => Some(n.is_zero())
    _ => Some(false)
  }
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
pub fn Vector::outer(
  self : Vector,
  other : Vector,
) -> Dyadic raise @rawvec.VectorError {
  { raw_: self.raw_.outer(other.raw_) }
}

///|
pub fn Vector::projection(
  self : Vector,
  other : Vector,
  scalar? : Bool = false,
) -> ScalarOrVector raise @rawvec.VectorError {
  let zero_self = self.equals(vector_zero())
  match zero_self {
    Some(true) => {
      if scalar {
        return scalar_or_vector_scalar(@symcore.int(0))
      }
      return scalar_or_vector_vector(vector_zero())
    }
    Some(false) => ()
    None => ()
  }
  let coeff = self.dot(other) * (self.dot(self) ^ @symcore.int(-1))
  if scalar {
    scalar_or_vector_scalar(coeff)
  } else {
    scalar_or_vector_vector(self.scale(coeff))
  }
}

///|
pub fn Vector::equals(
  self : Vector,
  other : Vector,
) -> Bool? raise @rawvec.VectorError {
  let diff = self - other
  match vector_equals_zero(diff.dot(diff)) {
    Some(true) => Some(true)
    Some(false) => {
      if diff.is_zero() {
        return Some(true)
      }
      let bases = diff.components().keys().to_array()
      if bases.is_empty() {
        return Some(true)
      }
      bases.sort()
      let anchor = bases[0].system_
      let rows = diff
        .express(anchor, variables=true)
        .to_matrix(anchor)
        .rows_copy()
      let mut saw_unknown = false
      for row in rows {
        match vector_equals_zero(row[0]) {
          Some(true) => ()
          Some(false) => return Some(false)
          None => saw_unknown = true
        }
      }
      if saw_unknown {
        None
      } else {
        Some(true)
      }
    }
    None => {
      if diff.is_zero() {
        return Some(true)
      }
      let bases = diff.components().keys().to_array()
      if bases.is_empty() {
        return Some(true)
      }
      bases.sort()
      let anchor = bases[0].system_
      let rows = diff
        .express(anchor, variables=true)
        .to_matrix(anchor)
        .rows_copy()
      let mut saw_unknown = false
      for row in rows {
        match vector_equals_zero(row[0]) {
          Some(true) => ()
          Some(false) => return Some(false)
          None => saw_unknown = true
        }
      }
      if saw_unknown {
        None
      } else {
        Some(true)
      }
    }
  }
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
pub fn Vector::separate(self : Vector) -> Map[CoordSys3D, Vector] {
  let components = self.components()
  let parts : Map[CoordSys3D, Vector] = {}
  for basis in components.keys() {
    let system = basis.system_
    let term = basis.scale(components[basis])
    match parts.get(system) {
      Some(prev) => parts[system] = prev + term
      None => parts[system] = term
    }
  }
  parts
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
