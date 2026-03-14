///|
fn geo_zero() -> @symcore.Expr {
  @symcore.int(0)
}

///|
fn geo_one() -> @symcore.Expr {
  @symcore.int(1)
}

///|
fn geo_neg_one() -> @symcore.Expr {
  @symcore.int(-1)
}

///|
fn geo_int(value : Int) -> @symcore.Expr {
  @symcore.int(value)
}

///|
fn geo_simplify(expr : @symcore.Expr) -> @symcore.Expr {
  @symsimplify.ratsimp(
    @symsimplify.trigsimp(
      @symsimplify.simplify(expr, max_passes=6),
      max_passes=8,
    ),
    max_passes=4,
  )
}

///|
fn geo_clone_exprs(items : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for item in items {
    out.push(item)
  }
  out
}

///|
fn geo_expr_text(expr : @symcore.Expr) -> String {
  @symprint.to_string(geo_simplify(expr))
}

///|
fn geo_expr_eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  match geo_simplify(lhs - rhs) {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn geo_div(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  geo_simplify(lhs * (rhs ^ geo_neg_one()))
}

///|
fn geo_expr_is_zero(expr : @symcore.Expr) -> Bool {
  geo_expr_eq(expr, geo_zero())
}

///|
fn geo_expr_sign(expr : @symcore.Expr) -> Int? {
  match geo_simplify(expr) {
    @symcore.Expr::Number(n) =>
      if n.is_zero() {
        Some(0)
      } else if n.compare(@symnum.BigRational::zero()) < 0 {
        Some(-1)
      } else {
        Some(1)
      }
    _ => None
  }
}

///|
fn geo_collect_symbols(expr : @symcore.Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => seen.set(name, true)
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      for arg in args {
        geo_collect_symbols(arg, seen)
      }
    @symcore.Expr::Pow(base, exp) => {
      geo_collect_symbols(base, seen)
      geo_collect_symbols(exp, seen)
    }
    _ => ()
  }
}

///|
fn geo_point_name(dim : Int) -> String {
  match dim {
    2 => "Point2D"
    3 => "Point3D"
    _ => "Point"
  }
}

///|
fn geo_linear_name(kind : LinearKind, dim : Int) -> String {
  match (kind, dim) {
    (LinearKind::Line, 2) => "Line2D"
    (LinearKind::Line, 3) => "Line3D"
    (LinearKind::Line, _) => "Line"
    (LinearKind::Ray, 2) => "Ray2D"
    (LinearKind::Ray, 3) => "Ray3D"
    (LinearKind::Ray, _) => "Ray"
    (LinearKind::Segment, 2) => "Segment2D"
    (LinearKind::Segment, 3) => "Segment3D"
    (LinearKind::Segment, _) => "Segment"
  }
}

///|
fn geo_render_exprs(items : Array[@symcore.Expr]) -> String {
  items.map(geo_expr_text).join(", ")
}

///|
fn geo_render_tuple(items : Array[@symcore.Expr]) -> String {
  "(" + geo_render_exprs(items) + ")"
}

///|
fn geo_zero_coords(dim : Int) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for _ in 0..<dim {
    out.push(geo_zero())
  }
  out
}

///|
fn geo_add_coords(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for i in 0..<lhs.length() {
    out.push(geo_simplify(lhs[i] + rhs[i]))
  }
  out
}

///|
fn geo_sub_coords(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for i in 0..<lhs.length() {
    out.push(geo_simplify(lhs[i] - rhs[i]))
  }
  out
}

///|
fn geo_scale_coords(
  coords : Array[@symcore.Expr],
  factor : @symcore.Expr,
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for item in coords {
    out.push(geo_simplify(item * factor))
  }
  out
}

///|
fn geo_scale_coords_axis(
  coords : Array[@symcore.Expr],
  factors : Array[@symcore.Expr],
) -> Array[@symcore.Expr] raise GeometryError {
  if coords.length() != factors.length() {
    raise GeometryError::ValueError(
      "scale factors must match coordinate dimension",
    )
  }
  let out : Array[@symcore.Expr] = []
  for i in 0..<coords.length() {
    out.push(geo_simplify(coords[i] * factors[i]))
  }
  out
}

///|
fn geo_dot(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> @symcore.Expr {
  let mut acc = geo_zero()
  for i in 0..<lhs.length() {
    acc = geo_simplify(acc + lhs[i] * rhs[i])
  }
  acc
}

///|
fn geo_cross2(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> @symcore.Expr {
  geo_simplify(lhs[0] * rhs[1] - lhs[1] * rhs[0])
}

///|
fn geo_cross3(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  [
    geo_simplify(lhs[1] * rhs[2] - lhs[2] * rhs[1]),
    geo_simplify(lhs[2] * rhs[0] - lhs[0] * rhs[2]),
    geo_simplify(lhs[0] * rhs[1] - lhs[1] * rhs[0]),
  ]
}

///|
fn geo_norm_sq(coords : Array[@symcore.Expr]) -> @symcore.Expr {
  geo_dot(coords, coords)
}

///|
fn geo_norm(coords : Array[@symcore.Expr]) -> @symcore.Expr {
  @symelem.sqrt(geo_norm_sq(coords))
}

///|
fn geo_all_zero(coords : Array[@symcore.Expr]) -> Bool {
  for item in coords {
    if !geo_expr_is_zero(item) {
      return false
    }
  }
  true
}

///|
fn geo_dominant_index(coords : Array[@symcore.Expr]) -> Int? {
  for i in 0..<coords.length() {
    if !geo_expr_is_zero(coords[i]) {
      return Some(i)
    }
  }
  None
}

///|
fn geo_pair_determinant(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
  i : Int,
  j : Int,
) -> @symcore.Expr {
  geo_simplify(lhs[i] * rhs[j] - lhs[j] * rhs[i])
}

///|
fn geo_rotate_coords_2d(
  coords : Array[@symcore.Expr],
  angle : @symcore.Expr,
  pivot : Array[@symcore.Expr],
) -> Array[@symcore.Expr] raise GeometryError {
  if coords.length() != 2 || pivot.length() != 2 {
    raise GeometryError::ValueError(
      "rotation is only defined for 2D coordinates",
    )
  }
  let x = coords[0] - pivot[0]
  let y = coords[1] - pivot[1]
  let c = @symelem.cos(angle)
  let s = @symelem.sin(angle)
  [
    geo_simplify(pivot[0] + x * c - y * s),
    geo_simplify(pivot[1] + x * s + y * c),
  ]
}

///|
fn geo_midpoint_coords(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let two = geo_int(2)
  let out : Array[@symcore.Expr] = []
  for i in 0..<lhs.length() {
    out.push(geo_div(lhs[i] + rhs[i], two))
  }
  out
}

///|
fn geo_point_from_coords(coords : Array[@symcore.Expr]) -> Point {
  Point::{ coords_: coords.map(geo_simplify) }
}

///|
fn geo_normalize_dim(points : Array[Point]) -> Array[Point] raise GeometryError {
  if points.is_empty() {
    return []
  }
  let mut dim = points[0].ambient_dimension()
  for item in points {
    if item.ambient_dimension() > dim {
      dim = item.ambient_dimension()
    }
  }
  let out : Array[Point] = []
  for item in points {
    out.push(item.with_dim(dim))
  }
  out
}
