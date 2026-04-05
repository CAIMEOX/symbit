///|
fn expr_placeholder_x() -> @symcore.Expr {
  @symcore.Expr::Symbol("x")
}

///|
fn expr_placeholder_y() -> @symcore.Expr {
  @symcore.Expr::Symbol("y")
}

///|
fn expr_placeholder_z() -> @symcore.Expr {
  @symcore.Expr::Symbol("z")
}

///|
fn expr_array_key(items : Array[@symcore.Expr]) -> String {
  items.map(@symprint.to_string).join("|")
}

///|
fn matrix_simplify_entries(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix {
  matrix.map(fn(expr) {
    @symsimplify.ratsimp(@symsimplify.trigsimp(@symsimplify.simplify(expr)))
  })
}

///|
fn coord_transform_name(transform : CoordTransform) -> String {
  match transform {
    CoordTransform::Cartesian => "cartesian"
    CoordTransform::Cylindrical => "cylindrical"
    CoordTransform::Spherical => "spherical"
  }
}

///|
fn coord_transform_to_parent_exprs(
  transform : CoordTransform,
  vars : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  match transform {
    CoordTransform::Cartesian => [vars[0], vars[1], vars[2]]
    CoordTransform::Cylindrical =>
      [
        vars[0] * @symelem.cos(vars[1]),
        vars[0] * @symelem.sin(vars[1]),
        vars[2],
      ]
    CoordTransform::Spherical =>
      [
        vars[0] * @symelem.sin(vars[1]) * @symelem.cos(vars[2]),
        vars[0] * @symelem.sin(vars[1]) * @symelem.sin(vars[2]),
        vars[0] * @symelem.cos(vars[1]),
      ]
  }
}

///|
fn coord_transform_inverse_template(
  transform : CoordTransform,
) -> Array[@symcore.Expr] {
  let x = expr_placeholder_x()
  let y = expr_placeholder_y()
  let z = expr_placeholder_z()
  match transform {
    CoordTransform::Cartesian => [x, y, z]
    CoordTransform::Cylindrical =>
      [
        @symelem.sqrt((x ^ @symcore.int(2)) + (y ^ @symcore.int(2))),
        @symelem.atan2(y, x),
        z,
      ]
    CoordTransform::Spherical => {
      let radius = @symelem.sqrt(
        (x ^ @symcore.int(2)) + (y ^ @symcore.int(2)) + (z ^ @symcore.int(2)),
      )
      [
        radius,
        @symelem.acos(z * (radius ^ @symcore.int(-1))),
        @symelem.atan2(y, x),
      ]
    }
  }
}

///|
fn coord_transform_basis_matrix(
  transform : CoordTransform,
  vars : Array[@symcore.Expr],
) -> @symphysics.ExplicitMatrix {
  let rows = match transform {
    CoordTransform::Cartesian =>
      [
        [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
        [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
        [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
      ]
    CoordTransform::Cylindrical =>
      [
        [
          @symelem.cos(vars[1]),
          @symcore.int(-1) * @symelem.sin(vars[1]),
          @symcore.int(0),
        ],
        [@symelem.sin(vars[1]), @symelem.cos(vars[1]), @symcore.int(0)],
        [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
      ]
    CoordTransform::Spherical =>
      [
        [
          @symelem.sin(vars[1]) * @symelem.cos(vars[2]),
          @symelem.cos(vars[1]) * @symelem.cos(vars[2]),
          @symcore.int(-1) * @symelem.sin(vars[2]),
        ],
        [
          @symelem.sin(vars[1]) * @symelem.sin(vars[2]),
          @symelem.cos(vars[1]) * @symelem.sin(vars[2]),
          @symelem.cos(vars[2]),
        ],
        [
          @symelem.cos(vars[1]),
          @symcore.int(-1) * @symelem.sin(vars[1]),
          @symcore.int(0),
        ],
      ]
  }
  matrix_simplify_entries(
    @symphysics.explicit_matrix_from_rows(rows) catch {
      _ => abort("coord_transform_basis_matrix")
    },
  )
}

///|
fn subst_expr_array(
  items : Array[@symcore.Expr],
  env : Map[String, @symcore.Expr],
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for item in items {
    out.push(@symcore.subst(item, env))
  }
  out
}

///|
fn scalar_env(
  scalars : Array[BaseScalar],
  values : Array[@symcore.Expr],
) -> Map[String, @symcore.Expr] {
  let env : Map[String, @symcore.Expr] = {}
  env[scalars[0].name_] = values[0]
  env[scalars[1].name_] = values[1]
  env[scalars[2].name_] = values[2]
  env
}

///|
fn array_to_column(items : Array[@symcore.Expr]) -> @symphysics.ExplicitMatrix {
  @symphysics.explicit_matrix_column(items)
}

///|
fn column_to_array(matrix : @symphysics.ExplicitMatrix) -> Array[@symcore.Expr] {
  let rows = matrix.rows_copy()
  [rows[0][0], rows[1][0], rows[2][0]]
}

///|
fn vector_matrix_key(vector : Vector) -> String {
  vector.to_string()
}

///|
fn coord_path(
  from_object : CoordSys3D,
  to_object : CoordSys3D,
) -> (Int, Array[CoordSys3D]) raise @rawvec.VectorError {
  if from_object.root_key_ != to_object.root_key_ {
    @rawvec.raise_value_error(
      "No connecting path found between " +
      from_object.to_string() +
      " and " +
      to_object.to_string(),
    )
  }
  let other_path : Array[CoordSys3D] = []
  let mut other = to_object
  while true {
    other_path.push(other)
    match other.parent_ {
      Some(parent) => other = parent
      None => break
    }
  }
  let other_index : Map[String, Int] = {}
  for i in 0..<other_path.length() {
    other_index[other_path[i].eq_key_] = i
  }
  let from_path : Array[CoordSys3D] = []
  let mut current = from_object
  while true {
    if other_index.contains(current.eq_key_) {
      let join_index = other_index[current.eq_key_]
      let split_index = from_path.length()
      let mut idx = join_index
      while true {
        from_path.push(other_path[idx])
        if idx == 0 {
          break
        }
        idx -= 1
      }
      return (split_index, from_path)
    }
    from_path.push(current)
    match current.parent_ {
      Some(parent) => current = parent
      None =>
        @rawvec.raise_value_error(
          "No connecting path found between " +
          from_object.to_string() +
          " and " +
          to_object.to_string(),
        )
    }
  }
  abort("coord_path")
}
