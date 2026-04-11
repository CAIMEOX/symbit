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
fn vector_components_for_system(
  vector : Vector,
  system : CoordSys3D,
) -> Array[@symcore.Expr] {
  let components = vector.components()
  [
    components.get(system.i()).unwrap_or(@symcore.int(0)),
    components.get(system.j()).unwrap_or(@symcore.int(0)),
    components.get(system.k()).unwrap_or(@symcore.int(0)),
  ]
}

///|
fn vector_matrix_in_system(
  vector : Vector,
  system : CoordSys3D,
  variables : Bool,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  if vector.is_zero() {
    return array_to_column([@symcore.int(0), @symcore.int(0), @symcore.int(0)])
  }
  let separated = vector.separate()
  let accum = [@symcore.int(0), @symcore.int(0), @symcore.int(0)]
  let sources = separated.keys().to_array()
  sources.sort()
  for source in sources {
    let source_vector = separated[source]
    let source_components = vector_components_for_system(source_vector, source)
    let target_components = if source == system {
      source_components
    } else {
      let basis_result : Result[
        @symphysics.ExplicitMatrix,
        @rawvec.VectorError,
      ] = try? system.change_of_basis_matrix_from(source)
      let basis_matrix = match basis_result {
        Ok(value) => value
        Err(err) => raise err
      }
      column_to_array(
        basis_matrix.mul(
          array_to_column(source_components),
        ) catch {
          _ => abort("vector_matrix_in_system")
        },
      )
    }
    for axis in 0..<3 {
      let value = if variables {
        express_scalar(target_components[axis], system, variables=true)
      } else {
        target_components[axis]
      }
      accum[axis] = accum[axis] + value
    }
  }
  array_to_column([
    @symsimplify.ratsimp(@symsimplify.trigsimp(@symsimplify.simplify(accum[0]))),
    @symsimplify.ratsimp(@symsimplify.trigsimp(@symsimplify.simplify(accum[1]))),
    @symsimplify.ratsimp(@symsimplify.trigsimp(@symsimplify.simplify(accum[2]))),
  ])
}

///|
fn vector_anchor_system(lhs : Vector, rhs : Vector) -> CoordSys3D? {
  match primary_coord_system_in_vector(lhs) {
    Some(system) => Some(system)
    None => primary_coord_system_in_vector(rhs)
  }
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
  ignore(self)
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
fn vector_map_components(
  vector : Vector,
  f : (@symcore.Expr) -> @symcore.Expr,
) -> Vector {
  let components = vector.components()
  if components.is_empty() {
    return vector_zero()
  }
  let basis = components.keys().to_array()
  basis.sort_by(compare_base_vector)
  let mut out = vector_zero()
  for item in basis {
    let coeff = f(components[item])
    if !@symcore.is_zero(coeff) {
      out = out + item.scale(coeff)
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
  match vector_anchor_system(self, other) {
    None => @symcore.int(0)
    Some(system) => {
      let lhs_rows = (vector_matrix_in_system(self, system, true) catch {
        err => raise err
      }).rows_copy()
      let rhs_rows = (vector_matrix_in_system(other, system, true) catch {
        err => raise err
      }).rows_copy()
      let value = lhs_rows[0][0] * rhs_rows[0][0] +
        lhs_rows[1][0] * rhs_rows[1][0] +
        lhs_rows[2][0] * rhs_rows[2][0]
      @symsimplify.ratsimp(@symsimplify.trigsimp(@symsimplify.simplify(value)))
    }
  }
}

///|
pub fn Vector::cross(
  self : Vector,
  other : Vector,
) -> Vector raise @rawvec.VectorError {
  match vector_anchor_system(self, other) {
    None => vector_zero()
    Some(system) => {
      let lhs_rows = (vector_matrix_in_system(self, system, true) catch {
        err => raise err
      }).rows_copy()
      let rhs_rows = (vector_matrix_in_system(other, system, true) catch {
        err => raise err
      }).rows_copy()
      matrix_to_vector(
        @symphysics.explicit_matrix_column([
          lhs_rows[1][0] * rhs_rows[2][0] - lhs_rows[2][0] * rhs_rows[1][0],
          lhs_rows[2][0] * rhs_rows[0][0] - lhs_rows[0][0] * rhs_rows[2][0],
          lhs_rows[0][0] * rhs_rows[1][0] - lhs_rows[1][0] * rhs_rows[0][0],
        ]),
        system,
      )
    }
  }
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
      let expressed = diff.express(anchor, variables=true) catch {
        err => raise err
      }
      let rows = (expressed.to_matrix(anchor) catch { err => raise err }).rows_copy()
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
      let expressed = diff.express(anchor, variables=true) catch {
        err => raise err
      }
      let rows = (expressed.to_matrix(anchor) catch { err => raise err }).rows_copy()
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
  matrix_to_vector(vector_matrix_in_system(self, system, variables) catch {
    err => raise err
  }, system)
}

///|
pub fn Vector::to_matrix(
  self : Vector,
  system : CoordSys3D,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  vector_matrix_in_system(self, system, false) catch {
    err => raise err
  }
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
  if self.is_zero() {
    return @symcore.int(0)
  }
  @symelem.sqrt(self.dot(self) catch { err => raise err })
}

///|
pub fn Vector::normalize(self : Vector) -> Vector raise @rawvec.VectorError {
  if self.is_zero() {
    return vector_zero()
  }
  self.scale((self.magnitude() catch { err => raise err }) ^ @symcore.int(-1))
}

///|
pub fn Vector::subs(self : Vector, env : Map[String, @symcore.Expr]) -> Vector {
  { raw_: self.raw_.subs(env) }
}

///|
pub fn Vector::simplify(self : Vector) -> Vector {
  vector_map_components(self, coeff => @symsimplify.simplify(coeff))
}

///|
pub fn Vector::trigsimp(self : Vector) -> Vector {
  vector_map_components(self, coeff => {
    @symsimplify.factor_terms(@symsimplify.trigsimp(coeff))
  })
}

///|
pub fn Vector::factor(self : Vector) -> Vector {
  vector_map_components(self, coeff => @symsimplify.factor_terms(coeff))
}

///|
pub fn Vector::evalf(self : Vector, prec? : Int = 53) -> Vector {
  vector_map_components(self, coeff => @symcore.evalf(coeff, prec~))
}

///|
pub fn Vector::diff(
  self : Vector,
  wrt : @symcore.Expr,
  system : CoordSys3D,
  var_in_dcm? : Bool = true,
) -> Vector raise @rawvec.VectorError {
  {
    raw_: self.raw_.diff(wrt, system.frame_, var_in_dcm~) catch {
      err => raise err
    },
  }
}

///|
pub fn Vector::doit(self : Vector) -> Vector {
  { raw_: self.raw_.doit() }
}
