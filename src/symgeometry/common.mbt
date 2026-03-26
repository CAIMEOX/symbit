///|
fn geo_pi() -> Expr {
  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
}

///|
fn geo_two_pi() -> Expr {
  geo_int(2) * geo_pi()
}

///|
fn geo_half_pi() -> Expr {
  geo_div(geo_pi(), geo_int(2))
}

///|
fn geo_int(value : Int) -> Expr {
  int(value)
}

///|
fn geo_simplify(expr : Expr) -> Expr {
  @symsimplify.ratsimp(
    @symsimplify.trigsimp(
      @symsimplify.simplify(expr, max_passes=6),
      max_passes=8,
    ),
    max_passes=4,
  )
}

///|
fn geo_radsimp(expr : Expr) -> Expr {
  geo_simplify(@symsimplify.radsimp(geo_simplify(expr), max_passes=6))
}

///|
fn geo_clone_exprs(items : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for item in items {
    out.push(item)
  }
  out
}

///|
fn geo_expr_text(expr : Expr) -> String {
  @symprint.to_string(geo_simplify(expr))
}

///|
fn geo_exact_value(expr : Expr) -> @symnum.BigRational? {
  match geo_simplify(expr) {
    Expr::Number(n) => Some(n)
    Expr::Float(f) =>
      if !f.is_finite() {
        None
      } else {
        let pair : Result[(BigInt, BigInt), @symnum.MpfError] = try? f.to_rational()
        match pair {
          Ok((num, den)) =>
            match
              (
                try? @symnum.BigRational::new(num, den) :
                Result[@symnum.BigRational, @symnum.RationalError]) {
              Ok(value) => Some(value)
              Err(_) => None
            }
          Err(_) => None
        }
      }
    _ => None
  }
}

///|
fn geo_expr_eq(lhs : Expr, rhs : Expr) -> Bool {
  match geo_exact_value(lhs - rhs) {
    Some(value) => value.is_zero()
    None => false
  }
}

///|
fn geo_div(lhs : Expr, rhs : Expr) -> Expr {
  geo_simplify(lhs * (rhs ^ int(-1)))
}

///|
fn geo_expr_is_zero(expr : Expr) -> Bool {
  geo_expr_eq(expr, int(0))
}

///|
fn geo_expr_sign(expr : Expr) -> Int? {
  match geo_exact_value(expr) {
    Some(n) =>
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
fn geo_collect_symbols(expr : Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    Expr::Symbol(name) => seen.set(name, true)
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) =>
      for arg in args {
        geo_collect_symbols(arg, seen)
      }
    Expr::Pow(base, exp) => {
      geo_collect_symbols(base, seen)
      geo_collect_symbols(exp, seen)
    }
    _ => ()
  }
}

///|
fn geo_expr_depends_on(expr : Expr, wrt : Expr) -> Bool {
  if @symcore.compare_expr(expr, wrt) == 0 {
    return true
  }
  match expr {
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) =>
      args.any(fn(arg) { geo_expr_depends_on(arg, wrt) })
    Expr::Pow(base, exp) =>
      geo_expr_depends_on(base, wrt) || geo_expr_depends_on(exp, wrt)
    _ => false
  }
}

///|
fn geo_expr_int_value(expr : Expr) -> Int? {
  match geo_exact_value(expr) {
    Some(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn geo_poly_deg2_add(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  [
    geo_simplify(lhs[0] + rhs[0]),
    geo_simplify(lhs[1] + rhs[1]),
    geo_simplify(lhs[2] + rhs[2]),
  ]
}

///|
fn geo_poly_deg2_mul(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr]? {
  let out = [int(0), int(0), int(0)]
  for i in 0..<3 {
    for j in 0..<3 {
      if i + j > 2 {
        if !geo_expr_is_zero(lhs[i]) && !geo_expr_is_zero(rhs[j]) {
          return None
        }
        continue
      }
      out[i + j] = geo_simplify(out[i + j] + lhs[i] * rhs[j])
    }
  }
  Some(out)
}

///|
fn geo_poly_deg2_pow(coeffs : Array[Expr], exp : Int) -> Array[Expr]? {
  let mut out = [int(1), int(0), int(0)]
  for _ in 0..<exp {
    match geo_poly_deg2_mul(out, coeffs) {
      Some(next) => out = next
      None => return None
    }
  }
  Some(out)
}

///|
fn geo_poly_deg2_coeffs(expr : Expr, wrt : Expr) -> Array[Expr]? {
  match geo_simplify(expr) {
    Expr::Number(_)
    | Expr::Float(_)
    | Expr::ComplexFloat(_)
    | Expr::NumberSymbol(_) => Some([expr, int(0), int(0)])
    Expr::Symbol(_)
    | Expr::Dummy(_, _)
    | Expr::Wild(_)
    | Expr::FunctionHead(_)
    | Expr::UndefinedFunction(_) =>
      if @symcore.compare_expr(expr, wrt) == 0 {
        Some([int(0), int(1), int(0)])
      } else {
        Some([expr, int(0), int(0)])
      }
    Expr::AppliedUndef(_, _) => None
    Expr::Dict(_) => None
    Expr::Add(args) => {
      let mut out = [int(0), int(0), int(0)]
      for arg in args {
        match geo_poly_deg2_coeffs(arg, wrt) {
          Some(coeffs) => out = geo_poly_deg2_add(out, coeffs)
          None => return None
        }
      }
      Some(out)
    }
    Expr::Mod(_, _) => None
    Expr::Mul(args) => {
      let mut out = [int(1), int(0), int(0)]
      for arg in args {
        match geo_poly_deg2_coeffs(arg, wrt) {
          Some(coeffs) =>
            match geo_poly_deg2_mul(out, coeffs) {
              Some(next) => out = next
              None => return None
            }
          None => return None
        }
      }
      Some(out)
    }
    Expr::Pow(base, exp) =>
      if !geo_expr_depends_on(expr, wrt) {
        Some([expr, int(0), int(0)])
      } else {
        match geo_expr_int_value(exp) {
          Some(k) if k >= 0 && k <= 2 =>
            match geo_poly_deg2_coeffs(base, wrt) {
              Some(coeffs) => geo_poly_deg2_pow(coeffs, k)
              None => None
            }
          _ => None
        }
      }
    Expr::Function(_, _) | Expr::Derivative(_, _) | Expr::Subs(_, _, _) =>
      if geo_expr_depends_on(expr, wrt) {
        None
      } else {
        Some([expr, int(0), int(0)])
      }
    Expr::Boolean(_)
    | Expr::Tuple(_)
    | Expr::Relational(_, _, _)
    | Expr::Lambda(_, _) => None
  }
}

///|
fn geo_solve_univar_deg2(expr : Expr, wrt : Expr) -> Array[Expr]? {
  match geo_poly_deg2_coeffs(expr, wrt) {
    Some(coeffs) => Some(quadratic_roots(coeffs[2], coeffs[1], coeffs[0]))
    None => None
  }
}

///|
fn geo_normalized_atan2(y : Expr, x : Expr) -> Expr {
  if geo_expr_is_zero(y) && geo_expr_eq(x, int(1)) {
    return int(0)
  }
  if geo_expr_eq(y, int(1)) && geo_expr_is_zero(x) {
    return geo_half_pi()
  }
  if geo_expr_is_zero(y) && geo_expr_eq(x, int(-1)) {
    return geo_pi()
  }
  if geo_expr_eq(y, int(-1)) && geo_expr_is_zero(x) {
    return int(0) - geo_half_pi()
  }
  geo_simplify(@symelem.atan2(y, x))
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
fn geo_render_exprs(items : Array[Expr]) -> String {
  items.map(geo_expr_text).join(", ")
}

///|
fn geo_render_tuple(items : Array[Expr]) -> String {
  "(" + geo_render_exprs(items) + ")"
}

///|
fn geo_zero_coords(dim : Int) -> Array[Expr] {
  let out : Array[Expr] = []
  for _ in 0..<dim {
    out.push(int(0))
  }
  out
}

///|
fn geo_add_coords(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for i in 0..<lhs.length() {
    out.push(geo_simplify(lhs[i] + rhs[i]))
  }
  out
}

///|
fn geo_sub_coords(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for i in 0..<lhs.length() {
    out.push(geo_simplify(lhs[i] - rhs[i]))
  }
  out
}

///|
fn geo_scale_coords(coords : Array[Expr], factor : Expr) -> Array[Expr] {
  let out : Array[Expr] = []
  for item in coords {
    out.push(geo_simplify(item * factor))
  }
  out
}

///|
fn geo_scale_coords_axis(
  coords : Array[Expr],
  factors : Array[Expr],
) -> Array[Expr] raise GeometryError {
  if coords.length() != factors.length() {
    raise GeometryError::ValueError(
      "scale factors must match coordinate dimension",
    )
  }
  let out : Array[Expr] = []
  for i in 0..<coords.length() {
    out.push(geo_simplify(coords[i] * factors[i]))
  }
  out
}

///|
fn geo_dot(lhs : Array[Expr], rhs : Array[Expr]) -> Expr {
  let mut acc = int(0)
  for i in 0..<lhs.length() {
    acc = geo_simplify(acc + lhs[i] * rhs[i])
  }
  acc
}

///|
fn geo_cross2(lhs : Array[Expr], rhs : Array[Expr]) -> Expr {
  geo_simplify(lhs[0] * rhs[1] - lhs[1] * rhs[0])
}

///|
fn geo_perp2(coords : Array[Expr]) -> Array[Expr] raise GeometryError {
  if coords.length() != 2 {
    raise GeometryError::ValueError("perp2 is only defined for planar vectors")
  }
  [geo_simplify(int(0) - coords[1]), coords[0]]
}

///|
fn geo_cross3(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  [
    geo_simplify(lhs[1] * rhs[2] - lhs[2] * rhs[1]),
    geo_simplify(lhs[2] * rhs[0] - lhs[0] * rhs[2]),
    geo_simplify(lhs[0] * rhs[1] - lhs[1] * rhs[0]),
  ]
}

///|
fn geo_norm_sq(coords : Array[Expr]) -> Expr {
  geo_dot(coords, coords)
}

///|
fn geo_norm(coords : Array[Expr]) -> Expr {
  @symelem.sqrt(geo_norm_sq(coords))
}

///|
fn geo_all_zero(coords : Array[Expr]) -> Bool {
  for item in coords {
    if !geo_expr_is_zero(item) {
      return false
    }
  }
  true
}

///|
fn geo_dominant_index(coords : Array[Expr]) -> Int? {
  for i in 0..<coords.length() {
    if !geo_expr_is_zero(coords[i]) {
      return Some(i)
    }
  }
  None
}

///|
fn geo_pair_determinant(
  lhs : Array[Expr],
  rhs : Array[Expr],
  i : Int,
  j : Int,
) -> Expr {
  geo_simplify(lhs[i] * rhs[j] - lhs[j] * rhs[i])
}

///|
fn geo_rotate_coords_2d(
  coords : Array[Expr],
  angle : Expr,
  pivot : Array[Expr],
) -> Array[Expr] raise GeometryError {
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
fn geo_midpoint_coords(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  let two = geo_int(2)
  let out : Array[Expr] = []
  for i in 0..<lhs.length() {
    out.push(geo_div(lhs[i] + rhs[i], two))
  }
  out
}

///|
fn geo_point_from_coords(coords : Array[Expr]) -> Point {
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
