///|
pub fn vector_kind(element_kind? : String = "NumberKind") -> VectorKind {
  { element_kind_: element_kind }
}

///|
pub fn coord_sys3d(
  name : String,
  vector_names? : Array[String]? = None,
  variable_names? : Array[String]? = None,
  transformation? : String? = None,
) -> CoordSys3D raise @rawvec.VectorError {
  let normalized_transform = normalize_transformation(transformation)
  let normalized_vector_names = normalize_names(
    "vector_names", vector_names, normalized_transform,
  )
  let normalized_variable_names = normalize_names(
    "variable_names", variable_names, normalized_transform,
  )
  let cache_key = root_cache_key(
    name, normalized_vector_names, normalized_variable_names, normalized_transform,
  )
  match root_coord_system_cache.get(cache_key) {
    Some(existing) => existing
    None => {
      let raw_origin = @rawvec.point(name + ".origin")
      let raw_frame = @rawvec.reference_frame(
        name,
        indices=Some(normalized_vector_names),
        variables=Some(full_variable_names(name, normalized_variable_names)),
      )
      let system : CoordSys3D = {
        name_: name,
        eq_key_: cache_key,
        frame_: raw_frame,
        origin_: point_wrapper(name + ".origin", raw_origin),
        parent_: None,
        vector_names_: normalized_vector_names,
        variable_names_: normalized_variable_names,
        transformation_: normalized_transform,
      }
      root_coord_system_cache[cache_key] = system
      register_coord_system(system)
      system
    }
  }
}

///|
pub fn CoordSys3D::name(self : CoordSys3D) -> String {
  self.name_
}

///|
pub fn CoordSys3D::origin(self : CoordSys3D) -> Point {
  self.origin_
}

///|
pub fn CoordSys3D::parent(self : CoordSys3D) -> CoordSys3D? {
  self.parent_
}

///|
pub fn CoordSys3D::scalar(
  self : CoordSys3D,
  axis : Int,
) -> BaseScalar raise @rawvec.VectorError {
  if axis < 0 || axis > 2 {
    abort("coordinate axis must be 0, 1, or 2")
  }
  let name = self.name_ + "." + self.variable_names_[axis]
  {
    axis_: axis,
    system_: self,
    name_: name,
    expr_: @symcore.Expr::Symbol(name),
  }
}

///|
pub fn CoordSys3D::vector(
  self : CoordSys3D,
  axis : Int,
) -> BaseVector raise @rawvec.VectorError {
  if axis < 0 || axis > 2 {
    abort("basis axis must be 0, 1, or 2")
  }
  { axis_: axis, system_: self }
}

///|
pub fn CoordSys3D::x(self : CoordSys3D) -> BaseScalar {
  self.scalar(0) catch {
    _ => abort("CoordSys3D::x")
  }
}

///|
pub fn CoordSys3D::y(self : CoordSys3D) -> BaseScalar {
  self.scalar(1) catch {
    _ => abort("CoordSys3D::y")
  }
}

///|
pub fn CoordSys3D::z(self : CoordSys3D) -> BaseScalar {
  self.scalar(2) catch {
    _ => abort("CoordSys3D::z")
  }
}

///|
pub fn CoordSys3D::i(self : CoordSys3D) -> BaseVector {
  self.vector(0) catch {
    _ => abort("CoordSys3D::i")
  }
}

///|
pub fn CoordSys3D::j(self : CoordSys3D) -> BaseVector {
  self.vector(1) catch {
    _ => abort("CoordSys3D::j")
  }
}

///|
pub fn CoordSys3D::k(self : CoordSys3D) -> BaseVector {
  self.vector(2) catch {
    _ => abort("CoordSys3D::k")
  }
}

///|
pub fn CoordSys3D::base_scalars(self : CoordSys3D) -> Array[BaseScalar] {
  [self.x(), self.y(), self.z()]
}

///|
pub fn CoordSys3D::base_vectors(self : CoordSys3D) -> Array[BaseVector] {
  [self.i(), self.j(), self.k()]
}

///|
pub fn CoordSys3D::lame_coefficients(self : CoordSys3D) -> Array[@symcore.Expr] {
  match self.transformation_ {
    CoordTransform::Cartesian =>
      [@symcore.int(1), @symcore.int(1), @symcore.int(1)]
    CoordTransform::Cylindrical =>
      [@symcore.int(1), self.x().expr(), @symcore.int(1)]
    CoordTransform::Spherical =>
      [
        @symcore.int(1),
        self.x().expr(),
        self.x().expr() * @symcore.function("sin", [self.y().expr()]),
      ]
  }
}

///|
pub fn CoordSys3D::rotation_matrix(
  self : CoordSys3D,
  other : CoordSys3D,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  self.frame_.dcm(other.frame_)
}

///|
pub fn CoordSys3D::scalar_map(
  self : CoordSys3D,
  other : CoordSys3D,
) -> Map[BaseScalar, @symcore.Expr] raise @rawvec.VectorError {
  let raw_mapping = self.frame_.variable_map(other.frame_)
  let out : Map[BaseScalar, @symcore.Expr] = {}
  for scalar in self.base_scalars() {
    out[scalar] = raw_mapping[scalar.name_]
  }
  out
}

///|
pub fn CoordSys3D::orient_new_axis(
  self : CoordSys3D,
  name : String,
  angle : @symcore.Expr,
  axis : Vector,
  location? : Vector? = None,
  vector_names? : Array[String]? = None,
  variable_names? : Array[String]? = None,
) -> CoordSys3D raise @rawvec.VectorError {
  let normalized_vector_names = normalize_names(
    "vector_names",
    match vector_names {
      Some(values) => Some(values)
      None => Some(self.vector_names_)
    },
    self.transformation_,
  )
  let normalized_variable_names = normalize_names(
    "variable_names",
    match variable_names {
      Some(values) => Some(values)
      None => Some(self.variable_names_)
    },
    self.transformation_,
  )
  let raw_child = self.frame_.orientnew(
    name,
    @rawvec.orient_axis(angle, axis.raw_),
    indices=Some(normalized_vector_names),
    variables=Some(full_variable_names(name, normalized_variable_names)),
  )
  let raw_location = match location {
    Some(value) => value.raw_
    None => @rawvec.vector_zero()
  }
  let raw_origin = self.origin_.raw_.locatenew(name + ".origin", raw_location)
  let eq_key = child_cache_key(
    self.eq_key_,
    matrix_summary(self.frame_.dcm(raw_child)),
    Vector::{ raw_: raw_location }.to_string(),
    normalized_vector_names,
    normalized_variable_names,
  )
  let system : CoordSys3D = {
    name_: name,
    eq_key_: eq_key,
    frame_: raw_child,
    origin_: point_wrapper(name + ".origin", raw_origin),
    parent_: Some(self),
    vector_names_: normalized_vector_names,
    variable_names_: normalized_variable_names,
    transformation_: self.transformation_,
  }
  register_coord_system(system)
  system
}

///|
pub fn BaseScalar::expr(self : BaseScalar) -> @symcore.Expr {
  self.expr_
}

///|
pub fn BaseScalar::system(self : BaseScalar) -> CoordSys3D {
  self.system_
}

///|
pub fn BaseScalar::kind(self : BaseScalar) -> String {
  "NumberKind"
}

///|
pub fn BaseVector::system(self : BaseVector) -> CoordSys3D {
  self.system_
}

///|
pub fn BaseVector::to_vector(self : BaseVector) -> Vector {
  { raw_: raw_basis(self.system_.frame_, self.axis_) }
}

///|
pub fn BaseVector::scale(self : BaseVector, scalar : @symcore.Expr) -> Vector {
  { raw_: raw_basis(self.system_.frame_, self.axis_).scale(scalar) }
}

///|
pub fn BaseVector::outer(
  self : BaseVector,
  other : BaseVector,
) -> Dyadic raise @rawvec.VectorError {
  self.to_vector().outer(other.to_vector())
}

///|
pub fn BaseVector::kind(self : BaseVector) -> VectorKind {
  vector_kind()
}
