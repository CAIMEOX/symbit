///|
fn expr_placeholder_x() -> @symcore.Expr {
  Symbol("x")
}

///|
fn expr_placeholder_y() -> @symcore.Expr {
  Symbol("y")
}

///|
fn expr_placeholder_z() -> @symcore.Expr {
  Symbol("z")
}

///|
fn expr_array_key(items : Array[@symcore.Expr]) -> String {
  items.map(@symprint.pretty_string).join("|")
}

///|
fn matrix_expr_key(matrix : @symphysics.ExplicitMatrix) -> String {
  matrix
  .rows_copy()
  .map(row => row.map(@symprint.pretty_string).join(","))
  .join("|")
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
    Cartesian => "cartesian"
    Cylindrical => "cylindrical"
    Spherical => "spherical"
    LambdaTransform(_) => "lambda"
    TupleTransform(_, _) => "tuple"
  }
}

///|
fn coord_transform_key(transform : CoordTransform) -> String {
  match transform {
    Cartesian | Cylindrical | Spherical => coord_transform_name(transform)
    LambdaTransform(function) => "lambda|" + expr_array_key(function.equations_)
    TupleTransform(rotation_matrix, location) =>
      "tuple|" +
      matrix_expr_key(rotation_matrix) +
      "|" +
      vector_matrix_key(location)
  }
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
  let env : Map[String, @symcore.Expr] = Map([])
  env[scalars[0].name_] = values[0]
  env[scalars[1].name_] = values[1]
  env[scalars[2].name_] = values[2]
  env
}

///|
fn transform_template_env(
  x : @symcore.Expr,
  y : @symcore.Expr,
  z : @symcore.Expr,
) -> Map[String, @symcore.Expr] {
  let env : Map[String, @symcore.Expr] = Map([])
  env["x"] = x
  env["y"] = y
  env["z"] = z
  env
}

///|
fn expr_depends_on_placeholders(expr : @symcore.Expr) -> Bool {
  let names : Map[String, Bool] = Map([])
  for item in @symcore.free_symbols(expr) {
    names[@symprint.pretty_string(item)] = true
  }
  names.contains("x") || names.contains("y") || names.contains("z")
}

///|
fn matrix_depends_on_placeholders(matrix : @symphysics.ExplicitMatrix) -> Bool {
  for row in matrix.rows_copy() {
    for item in row {
      if expr_depends_on_placeholders(item) {
        return true
      }
    }
  }
  false
}

///|
fn coord_transform_to_parent_exprs(
  transform : CoordTransform,
  vars : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  match transform {
    Cartesian => [vars[0], vars[1], vars[2]]
    Cylindrical =>
      [
        vars[0] * @symelem.cos(vars[1]),
        vars[0] * @symelem.sin(vars[1]),
        vars[2],
      ]
    Spherical =>
      [
        vars[0] * @symelem.sin(vars[1]) * @symelem.cos(vars[2]),
        vars[0] * @symelem.sin(vars[1]) * @symelem.sin(vars[2]),
        vars[0] * @symelem.cos(vars[1]),
      ]
    LambdaTransform(function) =>
      TransformFunction::{ equations_: function.equations_ }.call(
        vars[0],
        vars[1],
        vars[2],
      )
    TupleTransform(_, _) => [vars[0], vars[1], vars[2]]
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
    Cartesian => [x, y, z]
    Cylindrical =>
      [
        @symelem.sqrt((x ^ @symcore.int(2)) + (y ^ @symcore.int(2))),
        @symelem.atan2(y, x),
        z,
      ]
    Spherical => {
      let radius = @symelem.sqrt(
        (x ^ @symcore.int(2)) + (y ^ @symcore.int(2)) + (z ^ @symcore.int(2)),
      )
      [
        radius,
        @symelem.acos(z * (radius ^ @symcore.int(-1))),
        @symelem.atan2(y, x),
      ]
    }
    LambdaTransform(_) | TupleTransform(_, _) => [x, y, z]
  }
}

///|
fn coord_transform_jacobian_template(
  function : TransformFunction,
) -> @symphysics.ExplicitMatrix {
  let x = expr_placeholder_x()
  let y = expr_placeholder_y()
  let z = expr_placeholder_z()
  let equations = function.equations_
  matrix_simplify_entries(
    @symphysics.explicit_matrix_from_rows([
      [
        @symcalculus.diff(equations[0], x),
        @symcalculus.diff(equations[0], y),
        @symcalculus.diff(equations[0], z),
      ],
      [
        @symcalculus.diff(equations[1], x),
        @symcalculus.diff(equations[1], y),
        @symcalculus.diff(equations[1], z),
      ],
      [
        @symcalculus.diff(equations[2], x),
        @symcalculus.diff(equations[2], y),
        @symcalculus.diff(equations[2], z),
      ],
    ]) catch {
      _ => abort("coord_transform_jacobian_template")
    },
  )
}

///|
fn coord_transform_lame_template(
  function : TransformFunction,
) -> Array[@symcore.Expr] {
  let x = expr_placeholder_x()
  let y = expr_placeholder_y()
  let z = expr_placeholder_z()
  let equations = function.equations_
  let sums = [
    (@symcalculus.diff(equations[0], x) ^ @symcore.int(2)) +
    (@symcalculus.diff(equations[1], x) ^ @symcore.int(2)) +
    (@symcalculus.diff(equations[2], x) ^ @symcore.int(2)),
    (@symcalculus.diff(equations[0], y) ^ @symcore.int(2)) +
    (@symcalculus.diff(equations[1], y) ^ @symcore.int(2)) +
    (@symcalculus.diff(equations[2], y) ^ @symcore.int(2)),
    (@symcalculus.diff(equations[0], z) ^ @symcore.int(2)) +
    (@symcalculus.diff(equations[1], z) ^ @symcore.int(2)) +
    (@symcalculus.diff(equations[2], z) ^ @symcore.int(2)),
  ]
  [
    @symsimplify.ratsimp(@symsimplify.trigsimp(@symelem.sqrt(sums[0]))),
    @symsimplify.ratsimp(@symsimplify.trigsimp(@symelem.sqrt(sums[1]))),
    @symsimplify.ratsimp(@symsimplify.trigsimp(@symelem.sqrt(sums[2]))),
  ]
}

///|
fn coord_transform_check_orthogonality(function : TransformFunction) -> Bool {
  let x = expr_placeholder_x()
  let y = expr_placeholder_y()
  let z = expr_placeholder_z()
  let equations = function.equations_
  let v1 = [
    @symcalculus.diff(equations[0], x),
    @symcalculus.diff(equations[1], x),
    @symcalculus.diff(equations[2], x),
  ]
  let v2 = [
    @symcalculus.diff(equations[0], y),
    @symcalculus.diff(equations[1], y),
    @symcalculus.diff(equations[2], y),
  ]
  let v3 = [
    @symcalculus.diff(equations[0], z),
    @symcalculus.diff(equations[1], z),
    @symcalculus.diff(equations[2], z),
  ]
  if @symcore.is_zero(@symsimplify.simplify(v1[0] + v1[1] + v1[2])) ||
    @symcore.is_zero(@symsimplify.simplify(v2[0] + v2[1] + v2[2])) ||
    @symcore.is_zero(@symsimplify.simplify(v3[0] + v3[1] + v3[2])) {
    return false
  }
  let dot12 = @symsimplify.simplify(
    v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2],
  )
  let dot23 = @symsimplify.simplify(
    v2[0] * v3[0] + v2[1] * v3[1] + v2[2] * v3[2],
  )
  let dot31 = @symsimplify.simplify(
    v3[0] * v1[0] + v3[1] * v1[1] + v3[2] * v1[2],
  )
  @symcore.is_zero(dot12) && @symcore.is_zero(dot23) && @symcore.is_zero(dot31)
}

///|
fn coord_transform_lame_coefficients(
  transform : CoordTransform,
  vars : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  match transform {
    Cartesian | TupleTransform(_, _) =>
      [@symcore.int(1), @symcore.int(1), @symcore.int(1)]
    Cylindrical => [@symcore.int(1), vars[0], @symcore.int(1)]
    Spherical => [@symcore.int(1), vars[0], vars[0] * @symelem.sin(vars[1])]
    LambdaTransform(function) =>
      subst_expr_array(
        coord_transform_lame_template(function),
        transform_template_env(vars[0], vars[1], vars[2]),
      )
  }
}

///|
fn coord_transform_is_cartesian(
  lame_coefficients : Array[@symcore.Expr],
) -> Bool {
  @symcore.compare_expr(lame_coefficients[0], @symcore.int(1)) == 0 &&
  @symcore.compare_expr(lame_coefficients[1], @symcore.int(1)) == 0 &&
  @symcore.compare_expr(lame_coefficients[2], @symcore.int(1)) == 0
}

///|
fn coord_transform_basis_matrix_from_function(
  function : TransformFunction,
  lame_coefficients : Array[@symcore.Expr],
) -> (@symphysics.ExplicitMatrix, Bool) {
  let jacobian = coord_transform_jacobian_template(function)
  let is_curvilinear = matrix_depends_on_placeholders(jacobian)
  if !is_curvilinear {
    return (jacobian, false)
  }
  let rows = jacobian.rows_copy()
  let inverse_h = [
    lame_coefficients[0] ^ @symcore.int(-1),
    lame_coefficients[1] ^ @symcore.int(-1),
    lame_coefficients[2] ^ @symcore.int(-1),
  ]
  (
    matrix_simplify_entries(
      @symphysics.explicit_matrix_from_rows([
        [
          rows[0][0] * inverse_h[0],
          rows[0][1] * inverse_h[1],
          rows[0][2] * inverse_h[2],
        ],
        [
          rows[1][0] * inverse_h[0],
          rows[1][1] * inverse_h[1],
          rows[1][2] * inverse_h[2],
        ],
        [
          rows[2][0] * inverse_h[0],
          rows[2][1] * inverse_h[1],
          rows[2][2] * inverse_h[2],
        ],
      ]) catch {
        _ => abort("coord_transform_basis_matrix_from_function")
      },
    ),
    true,
  )
}

///|
fn coord_transform_basis_matrix(
  transform : CoordTransform,
  vars : Array[@symcore.Expr],
) -> @symphysics.ExplicitMatrix {
  match transform {
    Cartesian =>
      matrix_simplify_entries(
        @symphysics.explicit_matrix_from_rows([
          [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
          [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
          [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
        ]) catch {
          _ => abort("coord_transform_basis_matrix-cartesian")
        },
      )
    Cylindrical =>
      matrix_simplify_entries(
        @symphysics.explicit_matrix_from_rows([
          [
            @symelem.cos(vars[1]),
            @symcore.int(-1) * @symelem.sin(vars[1]),
            @symcore.int(0),
          ],
          [@symelem.sin(vars[1]), @symelem.cos(vars[1]), @symcore.int(0)],
          [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
        ]) catch {
          _ => abort("coord_transform_basis_matrix-cylindrical")
        },
      )
    Spherical =>
      matrix_simplify_entries(
        @symphysics.explicit_matrix_from_rows([
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
        ]) catch {
          _ => abort("coord_transform_basis_matrix-spherical")
        },
      )
    LambdaTransform(function) =>
      coord_transform_basis_matrix_from_function(
        function,
        coord_transform_lame_coefficients(transform, vars),
      ).0
    TupleTransform(_, _) => @symphysics.explicit_matrix_eye(3)
  }
}

///|
fn matrix_inverse_3x3(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  let rows = matrix.rows_copy()
  if rows.length() != 3 {
    @rawvec.raise_value_error("matrix_inverse_3x3 expects a 3x3 matrix")
    abort("matrix_inverse_3x3")
  }
  if rows[0].length() != 3 || rows[1].length() != 3 || rows[2].length() != 3 {
    @rawvec.raise_value_error("matrix_inverse_3x3 expects a 3x3 matrix")
    abort("matrix_inverse_3x3")
  }
  let a = rows[0][0]
  let b = rows[0][1]
  let c = rows[0][2]
  let d = rows[1][0]
  let e = rows[1][1]
  let f = rows[1][2]
  let g = rows[2][0]
  let h = rows[2][1]
  let i = rows[2][2]
  let det = @symsimplify.ratsimp(
    @symsimplify.simplify(
      a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g),
    ),
  )
  let inv_det = det ^ @symcore.int(-1)
  matrix_simplify_entries(
    @symphysics.explicit_matrix_from_rows([
      [
        (e * i - f * h) * inv_det,
        @symcore.int(-1) * (b * i - c * h) * inv_det,
        (b * f - c * e) * inv_det,
      ],
      [
        @symcore.int(-1) * (d * i - f * g) * inv_det,
        (a * i - c * g) * inv_det,
        @symcore.int(-1) * (a * f - c * d) * inv_det,
      ],
      [
        (d * h - e * g) * inv_det,
        @symcore.int(-1) * (a * h - b * g) * inv_det,
        (a * e - b * d) * inv_det,
      ],
    ]) catch {
      _ => abort("matrix_inverse_3x3")
    },
  )
}

///|
fn solve_inverse_template(
  function : TransformFunction,
) -> Array[@symcore.Expr]? {
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  let w = @symcore.Expr::Symbol("w")
  let x = expr_placeholder_x()
  let y = expr_placeholder_y()
  let z = expr_placeholder_z()
  let equations = function.call(u, v, w)
  let system = [equations[0] - x, equations[1] - y, equations[2] - z]
  try
    @symsolvers.solve(@symsolvers.solve_exprs_input(system), symbols=[u, v, w])
  catch {
    _ => None
  } noraise {
    Dict(values) =>
      Some([
        values.get("u").unwrap_or(u),
        values.get("v").unwrap_or(v),
        values.get("w").unwrap_or(w),
      ])
    Dicts(items) =>
      if items.is_empty() {
        None
      } else {
        let values = items[0]
        Some([
          values.get("u").unwrap_or(u),
          values.get("v").unwrap_or(v),
          values.get("w").unwrap_or(w),
        ])
      }
    List(_) => None
  }
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
  Show::to_string(vector)
}

///|
fn coord_path(
  from_object : CoordSys3D,
  to_object : CoordSys3D,
) -> (Int, Array[CoordSys3D]) raise @rawvec.VectorError {
  if from_object.root_key_ != to_object.root_key_ {
    @rawvec.raise_value_error(
      "No connecting path found between " +
      Show::to_string(from_object) +
      " and " +
      Show::to_string(to_object),
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
  let other_index : Map[String, Int] = Map([])
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
          Show::to_string(from_object) +
          " and " +
          Show::to_string(to_object),
        )
    }
  }
  abort("coord_path")
}
