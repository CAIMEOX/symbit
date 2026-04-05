///|
pub fn vector_kind(element_kind? : String = "NumberKind") -> VectorKind {
  { element_kind_: element_kind }
}

///|
fn coord_scalars_exprs(system : CoordSys3D) -> Array[@symcore.Expr] {
  [system.x().expr(), system.y().expr(), system.z().expr()]
}

///|
fn coord_transform_lame_coeffs(system : CoordSys3D) -> Array[@symcore.Expr] {
  match system.transformation_ {
    CoordTransform::Cartesian =>
      [@symcore.int(1), @symcore.int(1), @symcore.int(1)]
    CoordTransform::Cylindrical =>
      [@symcore.int(1), system.x().expr(), @symcore.int(1)]
    CoordTransform::Spherical =>
      [
        @symcore.int(1),
        system.x().expr(),
        system.x().expr() * @symelem.sin(system.y().expr()),
      ]
  }
}

///|
fn location_components_in_parent(
  location : Vector,
  parent : CoordSys3D?,
) -> Array[@symcore.Expr] raise @rawvec.VectorError {
  match parent {
    None => [@symcore.int(0), @symcore.int(0), @symcore.int(0)]
    Some(value) => {
      let rows = (location.to_matrix(value) catch { err => raise err }).rows_copy()
      [rows[0][0], rows[1][0], rows[2][0]]
    }
  }
}

///|
fn cartesian_transform_to_parent(
  self_scalars : Array[@symcore.Expr],
  parent_rotation_matrix : @symphysics.ExplicitMatrix,
  location : Vector,
  parent : CoordSys3D?,
) -> Array[@symcore.Expr] raise @rawvec.VectorError {
  let rotated = parent_rotation_matrix
    .transpose()
    .mul(array_to_column(self_scalars)) catch {
      _ => abort("cartesian_transform_to_parent")
    }
  let location_terms = location_components_in_parent(location, parent) catch {
    err => raise err
  }
  let rows = rotated.rows_copy()
  [
    rows[0][0] + location_terms[0],
    rows[1][0] + location_terms[1],
    rows[2][0] + location_terms[2],
  ]
}

///|
fn cartesian_inverse_template(
  parent_rotation_matrix : @symphysics.ExplicitMatrix,
  location : Vector,
  parent : CoordSys3D?,
) -> Array[@symcore.Expr] raise @rawvec.VectorError {
  let shifted = [
    expr_placeholder_x(),
    expr_placeholder_y(),
    expr_placeholder_z(),
  ]
  let location_terms = location_components_in_parent(location, parent) catch {
    err => raise err
  }
  let shifted_column = array_to_column([
    shifted[0] - location_terms[0],
    shifted[1] - location_terms[1],
    shifted[2] - location_terms[2],
  ])
  column_to_array(
    parent_rotation_matrix.mul(shifted_column) catch {
      _ => abort("cartesian_inverse_template")
    },
  )
}

///|
fn coord_signature(
  transform : CoordTransform,
  parent_rotation_matrix : @symphysics.ExplicitMatrix,
  transformation_to_parent : Array[@symcore.Expr],
  transformation_matrix_to_parent : @symphysics.ExplicitMatrix,
  is_cartesian : Bool,
  is_curvilinear : Bool,
) -> String {
  coord_transform_name(transform) +
  "|" +
  matrix_summary(parent_rotation_matrix) +
  "|" +
  expr_array_key(transformation_to_parent) +
  "|" +
  matrix_summary(transformation_matrix_to_parent) +
  "|" +
  is_cartesian.to_string() +
  "|" +
  is_curvilinear.to_string()
}

///|
fn build_root_coord_system(
  name : String,
  normalized_vector_names : Array[String],
  normalized_variable_names : Array[String],
  normalized_transform : CoordTransform,
) -> CoordSys3D raise @rawvec.VectorError {
  let raw_origin = @rawvec.point(name + ".origin")
  let raw_frame = @rawvec.reference_frame(
    name,
    indices=Some(normalized_vector_names),
    variables=Some(full_variable_names(name, normalized_variable_names)),
  )
  let skeleton : CoordSys3D = {
    name_: name,
    eq_key_: "",
    root_key_: "",
    frame_: raw_frame,
    origin_: point_wrapper(name + ".origin", raw_origin),
    parent_: None,
    vector_names_: normalized_vector_names,
    variable_names_: normalized_variable_names,
    transformation_: normalized_transform,
    parent_rotation_matrix_: @symphysics.explicit_matrix_eye(3),
    location_: vector_zero(),
    transformation_to_parent_: [],
    transformation_from_parent_template_: None,
    transformation_matrix_to_parent_: @symphysics.explicit_matrix_eye(3),
    is_cartesian_: normalized_transform == CoordTransform::Cartesian,
    is_curvilinear_: false,
  }
  let self_scalars = coord_scalars_exprs(skeleton)
  let transformation_to_parent = coord_transform_to_parent_exprs(
    normalized_transform, self_scalars,
  )
  let transformation_matrix_to_parent = coord_transform_basis_matrix(
    normalized_transform, self_scalars,
  )
  let eq_key = root_cache_key(
    name, normalized_vector_names, normalized_variable_names, normalized_transform,
  )
  let system : CoordSys3D = {
    name_: name,
    eq_key_: eq_key,
    root_key_: eq_key,
    frame_: raw_frame,
    origin_: point_wrapper(name + ".origin", raw_origin),
    parent_: None,
    vector_names_: normalized_vector_names,
    variable_names_: normalized_variable_names,
    transformation_: normalized_transform,
    parent_rotation_matrix_: @symphysics.explicit_matrix_eye(3),
    location_: vector_zero(),
    transformation_to_parent_: transformation_to_parent,
    transformation_from_parent_template_: Some(
      coord_transform_inverse_template(normalized_transform),
    ),
    transformation_matrix_to_parent_: transformation_matrix_to_parent,
    is_cartesian_: normalized_transform == CoordTransform::Cartesian,
    is_curvilinear_: normalized_transform != CoordTransform::Cartesian,
  }
  register_coord_system(system)
  system
}

///|
fn build_child_coord_system(
  parent : CoordSys3D,
  name : String,
  normalized_vector_names : Array[String],
  normalized_variable_names : Array[String],
  transform : CoordTransform,
  parent_rotation_matrix : @symphysics.ExplicitMatrix,
  location : Vector,
) -> CoordSys3D raise @rawvec.VectorError {
  let raw_child = parent.frame_.orientnew(
    name,
    @rawvec.orient_dcm(parent_rotation_matrix),
    indices=Some(normalized_vector_names),
    variables=Some(full_variable_names(name, normalized_variable_names)),
  )
  let raw_origin = parent.origin_.raw_.locatenew(
    name + ".origin",
    location.raw_,
  )
  let skeleton : CoordSys3D = {
    name_: name,
    eq_key_: "",
    root_key_: parent.root_key_,
    frame_: raw_child,
    origin_: point_wrapper(name + ".origin", raw_origin),
    parent_: Some(parent),
    vector_names_: normalized_vector_names,
    variable_names_: normalized_variable_names,
    transformation_: transform,
    parent_rotation_matrix_: parent_rotation_matrix,
    location_: location,
    transformation_to_parent_: [],
    transformation_from_parent_template_: None,
    transformation_matrix_to_parent_: @symphysics.explicit_matrix_eye(3),
    is_cartesian_: transform == CoordTransform::Cartesian,
    is_curvilinear_: false,
  }
  let self_scalars = coord_scalars_exprs(skeleton)
  let transformation_to_parent = if transform == CoordTransform::Cartesian {
    cartesian_transform_to_parent(
      self_scalars,
      parent_rotation_matrix,
      location,
      Some(parent),
    ) catch {
      err => raise err
    }
  } else {
    coord_transform_to_parent_exprs(transform, self_scalars)
  }
  let transformation_from_parent_template = if transform ==
    CoordTransform::Cartesian {
    Some(
      cartesian_inverse_template(parent_rotation_matrix, location, Some(parent)) catch {
        err => raise err
      },
    )
  } else {
    Some(coord_transform_inverse_template(transform))
  }
  let transformation_matrix_to_parent = if transform ==
    CoordTransform::Cartesian {
    parent_rotation_matrix.transpose()
  } else {
    coord_transform_basis_matrix(transform, self_scalars)
  }
  let is_cartesian = transform == CoordTransform::Cartesian
  let is_curvilinear = transform != CoordTransform::Cartesian
  let eq_key = child_cache_key(
    parent.eq_key_,
    coord_signature(
      transform, parent_rotation_matrix, transformation_to_parent, transformation_matrix_to_parent,
      is_cartesian, is_curvilinear,
    ),
    vector_matrix_key(location),
    normalized_vector_names,
    normalized_variable_names,
  )
  let system : CoordSys3D = {
    name_: name,
    eq_key_: eq_key,
    root_key_: parent.root_key_,
    frame_: raw_child,
    origin_: point_wrapper(name + ".origin", raw_origin),
    parent_: Some(parent),
    vector_names_: normalized_vector_names,
    variable_names_: normalized_variable_names,
    transformation_: transform,
    parent_rotation_matrix_: parent_rotation_matrix,
    location_: location,
    transformation_to_parent_: transformation_to_parent,
    transformation_from_parent_template_: transformation_from_parent_template,
    transformation_matrix_to_parent_: transformation_matrix_to_parent,
    is_cartesian_: is_cartesian,
    is_curvilinear_: is_curvilinear,
  }
  register_coord_system(system)
  system
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
      let system = build_root_coord_system(
        name, normalized_vector_names, normalized_variable_names, normalized_transform,
      ) catch {
        err => raise err
      }
      root_coord_system_cache[cache_key] = system
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
  if self.is_cartesian_ {
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)]
  } else {
    coord_transform_lame_coeffs(self)
  }
}

///|
pub fn CoordSys3D::transformation_to_parent(
  self : CoordSys3D,
) -> Array[@symcore.Expr] {
  self.transformation_to_parent_
}

///|
pub fn CoordSys3D::transformation_from_parent(
  self : CoordSys3D,
) -> Array[@symcore.Expr] raise @rawvec.VectorError {
  if self.parent_ is None {
    @rawvec.raise_value_error(
      "no parent coordinate system, use `transformation_from_parent_function()`",
    )
    abort("CoordSys3D::transformation_from_parent")
  }
  match self.transformation_from_parent_template_ {
    Some(template) => {
      let parent = self.parent_.unwrap()
      TransformFunction::{ equations_: template }.call(
        parent.x().expr(),
        parent.y().expr(),
        parent.z().expr(),
      )
    }
    None => {
      @rawvec.raise_value_error("inverse transformation is not available")
      abort("CoordSys3D::transformation_from_parent-none")
    }
  }
}

///|
pub fn CoordSys3D::transformation_from_parent_function(
  self : CoordSys3D,
) -> TransformFunction raise @rawvec.VectorError {
  match self.transformation_from_parent_template_ {
    Some(template) => { equations_: template }
    None => {
      @rawvec.raise_value_error("inverse transformation is not available")
      abort("CoordSys3D::transformation_from_parent_function-none")
    }
  }
}

///|
pub fn TransformFunction::call(
  self : TransformFunction,
  x : @symcore.Expr,
  y : @symcore.Expr,
  z : @symcore.Expr,
) -> Array[@symcore.Expr] {
  let env : Map[String, @symcore.Expr] = {}
  env["x"] = x
  env["y"] = y
  env["z"] = z
  subst_expr_array(self.equations_, env)
}

///|
pub fn CoordSys3D::rotation_matrix(
  self : CoordSys3D,
  other : CoordSys3D,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  if self == other {
    return @symphysics.explicit_matrix_eye(3)
  }
  match self.parent_ {
    Some(parent) if parent == other => return self.parent_rotation_matrix_
    _ => ()
  }
  match other.parent_ {
    Some(parent) if parent == self =>
      return other.parent_rotation_matrix_.transpose()
    _ => ()
  }
  let (root_index, path) = coord_path(self, other) catch { err => raise err }
  let mut result = @symphysics.explicit_matrix_eye(3)
  for i in 0..<root_index {
    result = result.mul(path[i].parent_rotation_matrix_) catch {
      _ => abort("CoordSys3D::rotation_matrix-parent")
    }
  }
  for i in (root_index + 1)..<path.length() {
    result = result.mul(path[i].parent_rotation_matrix_.transpose()) catch {
      _ => abort("CoordSys3D::rotation_matrix-child")
    }
  }
  matrix_simplify_entries(result)
}

///|
pub fn CoordSys3D::change_of_basis_matrix_from(
  self : CoordSys3D,
  other : CoordSys3D,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  if self == other {
    return @symphysics.explicit_matrix_eye(3)
  }
  let (root_index, path) = coord_path(self, other) catch { err => raise err }
  let mut result = @symphysics.explicit_matrix_eye(3)
  for i in 0..<root_index {
    result = result.mul(path[i].transformation_matrix_to_parent_.transpose()) catch {
      _ => abort("CoordSys3D::change_of_basis_matrix_from-up")
    }
  }
  for i in (root_index + 1)..<path.length() {
    result = result.mul(path[i].transformation_matrix_to_parent_) catch {
      _ => abort("CoordSys3D::change_of_basis_matrix_from-down")
    }
  }
  matrix_simplify_entries(result)
}

///|
fn scalar_map_post_process(expr : @symcore.Expr) -> @symcore.Expr {
  @symsimplify.ratsimp(@symsimplify.trigsimp(@symsimplify.simplify(expr)))
}

///|
pub fn CoordSys3D::scalar_map(
  self : CoordSys3D,
  other : CoordSys3D,
) -> Map[BaseScalar, @symcore.Expr] raise @rawvec.VectorError {
  let (root_index, systems) = coord_path(other, self) catch { err => raise err }
  let scalars = self.base_scalars()
  let mut current = scalar_env(scalars, coord_scalars_exprs(self))
  for system in systems[:root_index] {
    let parent = match system.parent_ {
      Some(value) => value
      None => abort("CoordSys3D::scalar_map-parent")
    }
    let next_values = subst_expr_array(
      system.transformation_to_parent(),
      current,
    )
    current = scalar_env(parent.base_scalars(), next_values)
  }
  for system in systems[root_index + 1:] {
    let next_values = subst_expr_array(
      system.transformation_from_parent() catch {
        err => raise err
      },
      current,
    )
    current = scalar_env(system.base_scalars(), next_values)
  }
  let out : Map[BaseScalar, @symcore.Expr] = {}
  for scalar in self.base_scalars() {
    out[scalar] = scalar_map_post_process(current[scalar.name_])
  }
  out
}

///|
pub fn CoordSys3D::position_wrt(
  self : CoordSys3D,
  other : PointReference,
) -> Vector raise @rawvec.VectorError {
  self.origin_.position_wrt(other) catch {
    err => raise err
  }
}

///|
pub fn CoordSys3D::locate_new(
  self : CoordSys3D,
  name : String,
  position : Vector,
  vector_names? : Array[String]? = None,
  variable_names? : Array[String]? = None,
) -> CoordSys3D raise @rawvec.VectorError {
  let normalized_vector_names = normalize_names(
    "vector_names",
    match vector_names {
      Some(values) => Some(values)
      None => Some(self.vector_names_)
    },
    CoordTransform::Cartesian,
  )
  let normalized_variable_names = normalize_names(
    "variable_names",
    match variable_names {
      Some(values) => Some(values)
      None => Some(self.variable_names_)
    },
    CoordTransform::Cartesian,
  )
  build_child_coord_system(
    self,
    name,
    normalized_vector_names,
    normalized_variable_names,
    CoordTransform::Cartesian,
    @symphysics.explicit_matrix_eye(3),
    position,
  ) catch {
    err => raise err
  }
}

///|
pub fn CoordSys3D::orient_new(
  self : CoordSys3D,
  name : String,
  orienters : Array[Orienter],
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
    CoordTransform::Cartesian,
  )
  let normalized_variable_names = normalize_names(
    "variable_names",
    match variable_names {
      Some(values) => Some(values)
      None => Some(self.variable_names_)
    },
    CoordTransform::Cartesian,
  )
  let mut final_matrix = @symphysics.explicit_matrix_eye(3)
  for orienter in orienters {
    final_matrix = final_matrix.mul(
      orienter_rotation_matrix(orienter, self) catch {
        err => raise err
      },
    ) catch {
      _ => abort("CoordSys3D::orient_new")
    }
  }
  build_child_coord_system(
    self,
    name,
    normalized_vector_names,
    normalized_variable_names,
    CoordTransform::Cartesian,
    matrix_simplify_entries(final_matrix),
    location.unwrap_or(vector_zero()),
  ) catch {
    err => raise err
  }
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
  self.orient_new(
    name,
    [orienter_axis(axis_orienter(angle, axis))],
    location~,
    vector_names~,
    variable_names~,
  ) catch {
    err => raise err
  }
}

///|
pub fn CoordSys3D::orient_new_body(
  self : CoordSys3D,
  name : String,
  angle1 : @symcore.Expr,
  angle2 : @symcore.Expr,
  angle3 : @symcore.Expr,
  rotation_order : String,
  location? : Vector? = None,
  vector_names? : Array[String]? = None,
  variable_names? : Array[String]? = None,
) -> CoordSys3D raise @rawvec.VectorError {
  self.orient_new(
    name,
    [
      orienter_body(
        body_orienter(angle1, angle2, angle3, rotation_order) catch {
          err => raise err
        },
      ),
    ],
    location~,
    vector_names~,
    variable_names~,
  ) catch {
    err => raise err
  }
}

///|
pub fn CoordSys3D::orient_new_space(
  self : CoordSys3D,
  name : String,
  angle1 : @symcore.Expr,
  angle2 : @symcore.Expr,
  angle3 : @symcore.Expr,
  rotation_order : String,
  location? : Vector? = None,
  vector_names? : Array[String]? = None,
  variable_names? : Array[String]? = None,
) -> CoordSys3D raise @rawvec.VectorError {
  self.orient_new(
    name,
    [
      orienter_space(
        space_orienter(angle1, angle2, angle3, rotation_order) catch {
          err => raise err
        },
      ),
    ],
    location~,
    vector_names~,
    variable_names~,
  ) catch {
    err => raise err
  }
}

///|
pub fn CoordSys3D::orient_new_quaternion(
  self : CoordSys3D,
  name : String,
  q0 : @symcore.Expr,
  q1 : @symcore.Expr,
  q2 : @symcore.Expr,
  q3 : @symcore.Expr,
  location? : Vector? = None,
  vector_names? : Array[String]? = None,
  variable_names? : Array[String]? = None,
) -> CoordSys3D raise @rawvec.VectorError {
  self.orient_new(
    name,
    [orienter_quaternion(quaternion_orienter(q0, q1, q2, q3))],
    location~,
    vector_names~,
    variable_names~,
  ) catch {
    err => raise err
  }
}

///|
pub fn CoordSys3D::create_new(
  self : CoordSys3D,
  name : String,
  transformation : String,
  variable_names? : Array[String]? = None,
  vector_names? : Array[String]? = None,
) -> CoordSys3D raise @rawvec.VectorError {
  let normalized_transform = normalize_transformation(Some(transformation))
  let normalized_vector_names = normalize_names(
    "vector_names", vector_names, normalized_transform,
  )
  let normalized_variable_names = normalize_names(
    "variable_names", variable_names, normalized_transform,
  )
  build_child_coord_system(
    self,
    name,
    normalized_vector_names,
    normalized_variable_names,
    normalized_transform,
    @symphysics.explicit_matrix_eye(3),
    vector_zero(),
  ) catch {
    err => raise err
  }
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
  ignore(self)
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
  ignore(self)
  vector_kind()
}
