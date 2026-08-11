///|
/// Exact polynomial integration over 2D polygonal regions and segments.
///
/// The public surface focuses on the polygon and segment integration paths that
/// are already supported by the current geometry layer:
/// exact integration of polynomial expressions over planar polygons, exact
/// line integration over segments, and bulk moment generation up to a total
/// degree bound.

///|
fn intpoly_default_vars() -> Array[Expr] {
  [@symcore.Expr::Symbol("x"), @symcore.Expr::Symbol("y")]
}

///|
fn intpoly_var_names(
  vars : Array[Expr],
) -> (String, String) raise IntegralError {
  if vars.length() != 2 {
    raise IntegralError::ValueError(
      "expecting exactly two coordinate symbols for planar intpoly routines",
    )
  }
  let x_name = match vars[0] {
    @symcore.Expr::Symbol(name) => name
    _ =>
      raise IntegralError::ValueError(
        "expecting symbols as planar intpoly variables",
      )
  }
  let y_name = match vars[1] {
    @symcore.Expr::Symbol(name) => name
    _ =>
      raise IntegralError::ValueError(
        "expecting symbols as planar intpoly variables",
      )
  }
  (x_name, y_name)
}

///|
fn expr_depends_on_any(expr : Expr, names : Array[String]) -> Bool {
  names.any(fn(name) { expr_depends_on(expr, name) })
}

///|
fn intpoly_degree(expr : Expr, names : Array[String]) -> Int? {
  match expr_simplify(expr) {
    @symcore.Expr::Number(_) => Some(0)
    @symcore.Expr::Symbol(name) =>
      if names.any(fn(item) { item == name }) {
        Some(1)
      } else {
        Some(0)
      }
    @symcore.Expr::Add(args) => {
      let mut best = 0
      for arg in args {
        match intpoly_degree(arg, names) {
          Some(value) => if value > best { best = value }
          None => return None
        }
      }
      Some(best)
    }
    @symcore.Expr::Mul(args) => {
      let mut total = 0
      for arg in args {
        match intpoly_degree(arg, names) {
          Some(value) => total += value
          None => return None
        }
      }
      Some(total)
    }
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power >= 0 =>
          match intpoly_degree(base, names) {
            Some(value) => Some(value * power)
            None => None
          }
        _ => None
      }
    _ => if expr_depends_on_any(expr, names) { None } else { Some(0) }
  }
}

///|
fn intpoly_is_polynomial(expr : Expr, names : Array[String]) -> Bool {
  intpoly_degree(expr, names) is Some(_)
}

///|
fn intpoly_has_unevaluated_integral(expr : Expr) -> Bool {
  if @symcore.application_has_name(expr, "Integral") {
    true
  } else {
    @symcore.children(expr).any(fn(child) {
      intpoly_has_unevaluated_integral(child)
    })
  }
}

///|
fn intpoly_fresh_parameter(expr : Expr, vars : Array[String]) -> String {
  let mut idx = 0
  let mut name = "__intpoly_t"
  while vars.any(fn(item) { item == name }) || expr_depends_on(expr, name) {
    idx += 1
    name = "__intpoly_t" + idx.to_string()
  }
  name
}

///|
fn intpoly_segment_integrand(
  expr : Expr,
  seg : @symgeometry.Segment,
  x_name : String,
  y_name : String,
  t_name : String,
) -> Expr raise IntegralError {
  let p0 = seg.p1()
  let p1 = seg.p2()
  let x0 = p0.x() catch {
    _ => raise IntegralError::ValueError("segment must be planar")
  }
  let y0 = p0.y() catch {
    _ => raise IntegralError::ValueError("segment must be planar")
  }
  let x1 = p1.x() catch {
    _ => raise IntegralError::ValueError("segment must be planar")
  }
  let y1 = p1.y() catch {
    _ => raise IntegralError::ValueError("segment must be planar")
  }
  let t = @symcore.Expr::Symbol(t_name)
  let x_t = expr_add(x0, expr_mul(expr_sub(x1, x0), t))
  let y_t = expr_add(y0, expr_mul(expr_sub(y1, y0), t))
  subst_symbol(subst_symbol(expr, x_name, x_t), y_name, y_t)
}

///|
fn intpoly_segment_length(
  seg : @symgeometry.Segment,
) -> Expr raise IntegralError {
  seg.length() catch {
    _ => raise IntegralError::ValueError("failed to determine segment length")
  }
}

///|
fn intpoly_polygon_signed_integral(
  poly : @symgeometry.Polygon,
  primitive_x : Expr,
  x_name : String,
  y_name : String,
) -> Expr raise IntegralError {
  let vars = [x_name, y_name]
  let t_name = intpoly_fresh_parameter(primitive_x, vars)
  let t = @symcore.Expr::Symbol(t_name)
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let sides = poly.sides() catch {
    _ => raise IntegralError::ValueError("failed to derive polygon sides")
  }
  let mut total = @symcore.int(0)
  for side in sides {
    let p0 = side.p1()
    let p1 = side.p2()
    let y0 = p0.y() catch {
      _ => raise IntegralError::ValueError("polygon must be planar")
    }
    let y1 = p1.y() catch {
      _ => raise IntegralError::ValueError("polygon must be planar")
    }
    let dy = expr_sub(y1, y0)
    let edge_integrand = expr_mul(
      intpoly_segment_integrand(primitive_x, side, x_name, y_name, t_name),
      dy,
    )
    total = expr_add(
      total,
      integrate(edge_integrand, limits=[integral_limit([t, zero, one])]),
    )
  }
  total
}

///|
fn intpoly_normalize_orientation(
  poly : @symgeometry.Polygon,
  value : Expr,
) -> Expr {
  match expr_num_value(poly.area()) {
    Some(area) if area.compare(@symnum.BigRational::zero()) < 0 =>
      expr_mul(@symcore.int(-1), value)
    _ => value
  }
}

///|
fn intpoly_validate_planar_polynomial(
  expr : Expr,
  vars : Array[Expr],
) -> (String, String) raise IntegralError {
  let (x_name, y_name) = intpoly_var_names(vars)
  if !intpoly_is_polynomial(expr, [x_name, y_name]) {
    raise IntegralError::ValueError(
      "intpoly currently supports exact polynomial expressions in two variables",
    )
  }
  (x_name, y_name)
}

///|
fn intpoly_primitive_x(
  expr : Expr,
  x_name : String,
) -> Expr raise IntegralError {
  let x = @symcore.Expr::Symbol(x_name)

  fn split_polynomial_x_term(term : Expr) -> (Expr, Int)? {
    match expr_simplify(term) {
      @symcore.Expr::Symbol(name) =>
        if name == x_name {
          Some((@symcore.int(1), 1))
        } else {
          Some((term, 0))
        }
      @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) if name == x_name =>
        match expr_is_int_value(exp) {
          Some(power) if power >= 0 => Some((@symcore.int(1), power))
          _ => None
        }
      @symcore.Expr::Mul(args) => {
        let mut coeff = @symcore.int(1)
        let mut power = 0
        for arg in args {
          match expr_simplify(arg) {
            @symcore.Expr::Symbol(name) =>
              if name == x_name {
                power += 1
              } else if expr_depends_on(arg, x_name) {
                return None
              } else {
                coeff = expr_mul(coeff, arg)
              }
            @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) if name ==
              x_name =>
              match expr_is_int_value(exp) {
                Some(value) if value >= 0 => power += value
                _ => return None
              }
            simplified =>
              if expr_depends_on(simplified, x_name) {
                return None
              } else {
                coeff = expr_mul(coeff, simplified)
              }
          }
        }
        Some((coeff, power))
      }
      simplified =>
        if expr_depends_on(simplified, x_name) {
          None
        } else {
          Some((simplified, 0))
        }
    }
  }

  fn primitive_term(term : Expr) -> Expr? {
    match split_polynomial_x_term(term) {
      Some((coeff, power)) =>
        Some(
          expr_simplify(
            expr_mul(
              coeff,
              expr_div(
                expr_pow(x, @symcore.int(power + 1)),
                @symcore.int(power + 1),
              ),
            ),
          ),
        )
      None => None
    }
  }

  let expanded = @symsimplify.numer_expand(expr_simplify(expr))
  let primitive = match expanded {
    @symcore.Expr::Add(args) => {
      let out : Array[Expr] = []
      for arg in args {
        match primitive_term(arg) {
          Some(value) => out.push(value)
          None =>
            raise IntegralError::ValueError(
              "failed to construct an exact polynomial primitive for intpoly",
            )
        }
      }
      expr_simplify(@symcore.add(out))
    }
    _ =>
      match primitive_term(expanded) {
        Some(value) => value
        None =>
          raise IntegralError::ValueError(
            "failed to construct an exact polynomial primitive for intpoly",
          )
      }
  }
  if intpoly_has_unevaluated_integral(primitive) {
    raise IntegralError::ValueError(
      "failed to construct an exact polynomial primitive for intpoly",
    )
  }
  primitive
}

///|
fn intpoly_monomial(x : Expr, y : Expr, dx : Int, dy : Int) -> Expr {
  let lhs = if dx == 0 {
    @symcore.int(1)
  } else {
    expr_pow(x, @symcore.int(dx))
  }
  let rhs = if dy == 0 {
    @symcore.int(1)
  } else {
    expr_pow(y, @symcore.int(dy))
  }
  expr_mul(lhs, rhs)
}

///|
fn intpoly_coords_norm(coords : Array[Expr]) -> Expr raise IntegralError {
  if coords.is_empty() {
    raise IntegralError::ValueError("expected at least one coordinate")
  }
  let mut total = @symcore.int(0)
  for coord in coords {
    total = expr_add(total, expr_pow(coord, @symcore.int(2)))
  }
  @symelem.sqrt(expr_simplify(total))
}

///|
fn intpoly_point3_coords(
  point : @symgeometry.Point,
) -> Array[Expr] raise IntegralError {
  let coords = point.coords()
  if coords.length() != 3 {
    raise IntegralError::ValueError("expected a 3D point")
  }
  coords
}

///|
fn intpoly_cross_product_coords(
  v1 : Array[Expr],
  v2 : Array[Expr],
  v3 : Array[Expr],
) -> Array[Expr] raise IntegralError {
  if v1.length() != 3 || v2.length() != 3 || v3.length() != 3 {
    raise IntegralError::ValueError("cross_product expects three 3D points")
  }
  let a = [
    expr_sub(v2[0], v1[0]),
    expr_sub(v2[1], v1[1]),
    expr_sub(v2[2], v1[2]),
  ]
  let b = [
    expr_sub(v3[0], v1[0]),
    expr_sub(v3[1], v1[1]),
    expr_sub(v3[2], v1[2]),
  ]
  [
    expr_simplify(expr_sub(expr_mul(b[2], a[1]), expr_mul(b[1], a[2]))),
    expr_simplify(expr_sub(expr_mul(b[0], a[2]), expr_mul(b[2], a[0]))),
    expr_simplify(expr_sub(expr_mul(b[1], a[0]), expr_mul(b[0], a[1]))),
  ]
}

///|
fn intpoly_segment2d_coords(
  seg : @symgeometry.Segment,
) -> (Array[Expr], Array[Expr]) raise IntegralError {
  let p1 = seg.p1().coords()
  let p2 = seg.p2().coords()
  if p1.length() != 2 || p2.length() != 2 {
    raise IntegralError::ValueError("expected a 2D segment")
  }
  (p1, p2)
}

///|
fn intpoly_abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn intpoly_gcd_int(lhs : Int, rhs : Int) -> Int {
  let mut a = intpoly_abs_int(lhs)
  let mut b = intpoly_abs_int(rhs)
  while b != 0 {
    let next = a % b
    a = b
    b = next
  }
  a
}

///|
fn intpoly_expr_gcd(values : Array[Expr]) -> Expr {
  let mut acc = 0
  for value in values {
    match expr_exact_int(value) {
      Some(item) => acc = intpoly_gcd_int(acc, item)
      None => return @symcore.int(1)
    }
  }
  if acc == 0 {
    @symcore.int(1)
  } else {
    @symcore.int(acc)
  }
}

///|
fn intpoly_sorted_symbol_names(expr : Expr) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  collect_symbols(expr, seen)
  let names : Array[String] = []
  for name in seen.keys() {
    names.push(name)
  }
  names.sort()
  names
}

///|
fn intpoly_total_degree(expr : Expr) -> Int raise IntegralError {
  let names = intpoly_sorted_symbol_names(expr)
  match intpoly_degree(expr, names) {
    Some(value) => value
    None =>
      raise IntegralError::ValueError(
        "decompose expects a polynomial expression with non-negative powers",
      )
  }
}

///|
fn intpoly_point_coord(
  point : @symgeometry.Point,
  index : Int,
) -> Expr raise IntegralError {
  let coords = point.coords()
  if index < 0 || index >= coords.length() {
    raise IntegralError::ValueError("point coordinate index out of range")
  }
  coords[index]
}

///|
fn intpoly_average_coord(
  points : Array[@symgeometry.Point],
  index : Int,
) -> Expr raise IntegralError {
  let mut total = @symcore.int(0)
  for point in points {
    total = expr_add(total, intpoly_point_coord(point, index))
  }
  expr_simplify(expr_div(total, @symcore.int(points.length())))
}

///|
fn intpoly_expr_compare(lhs : Expr, rhs : Expr) -> Int raise IntegralError {
  match expr_num_value(expr_simplify(expr_sub(lhs, rhs))) {
    Some(delta) => delta.compare(@symnum.BigRational::zero())
    None =>
      raise IntegralError::ValueError(
        "point_sort requires numerically comparable coordinates",
      )
  }
}

///|
fn intpoly_expr_sign(expr : Expr) -> Int raise IntegralError {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) => value.compare(@symnum.BigRational::zero())
    None =>
      raise IntegralError::ValueError(
        "point_sort requires numerically comparable coordinates",
      )
  }
}

///|
fn intpoly_compare_points_2d(
  a : @symgeometry.Point,
  b : @symgeometry.Point,
  center : @symgeometry.Point,
  order : Int,
) -> Int raise IntegralError {
  let ax = intpoly_point_coord(a, 0)
  let ay = intpoly_point_coord(a, 1)
  let bx = intpoly_point_coord(b, 0)
  let by = intpoly_point_coord(b, 1)
  let cx = intpoly_point_coord(center, 0)
  let cy = intpoly_point_coord(center, 1)
  let ax_rel = expr_sub(ax, cx)
  let ay_rel = expr_sub(ay, cy)
  let bx_rel = expr_sub(bx, cx)
  let by_rel = expr_sub(by, cy)
  let ax_sign = intpoly_expr_sign(ax_rel)
  let bx_sign = intpoly_expr_sign(bx_rel)
  if ax_sign >= 0 && bx_sign < 0 {
    -order
  } else if ax_sign < 0 && bx_sign >= 0 {
    order
  } else if ax_sign == 0 && bx_sign == 0 {
    if intpoly_expr_sign(ay_rel) >= 0 || intpoly_expr_sign(by_rel) >= 0 {
      if intpoly_expr_compare(ay, by) > 0 {
        -order
      } else {
        order
      }
    } else if intpoly_expr_compare(by, ay) > 0 {
      -order
    } else {
      order
    }
  } else {
    let det = expr_sub(expr_mul(ax_rel, by_rel), expr_mul(bx_rel, ay_rel))
    let det_sign = intpoly_expr_sign(det)
    if det_sign < 0 {
      -order
    } else if det_sign > 0 {
      order
    } else {
      let first = expr_add(expr_mul(ax_rel, ax_rel), expr_mul(ay_rel, ay_rel))
      let second = expr_add(expr_mul(bx_rel, bx_rel), expr_mul(by_rel, by_rel))
      if intpoly_expr_compare(first, second) > 0 {
        -order
      } else {
        order
      }
    }
  }
}

///|
fn intpoly_compare_points_3d(
  a : @symgeometry.Point,
  b : @symgeometry.Point,
  center : @symgeometry.Point,
  normal : @symgeometry.Point,
  order : Int,
) -> Int raise IntegralError {
  let det = intpoly_cross_product_coords(
    center.coords(),
    a.coords(),
    b.coords(),
  )
  let normal_coords = intpoly_point3_coords(normal)
  let mut dot = @symcore.int(0)
  for i in 0..<3 {
    dot = expr_add(dot, expr_mul(det[i], normal_coords[i]))
  }
  let sign = intpoly_expr_sign(dot)
  if sign < 0 {
    -order
  } else if sign > 0 {
    order
  } else {
    0
  }
}

///|
fn intpoly_sort_points(
  points : Array[@symgeometry.Point],
  center : @symgeometry.Point,
  normal : @symgeometry.Point?,
  clockwise : Bool,
) -> Array[@symgeometry.Point] raise IntegralError {
  let out = points.copy()
  let order = if clockwise { 1 } else { -1 }
  for i in 1..<out.length() {
    let item = out[i]
    let mut j = i
    while j > 0 {
      let cmp = match normal {
        Some(normal_point) =>
          intpoly_compare_points_3d(
            item,
            out[j - 1],
            center,
            normal_point,
            order,
          )
        None => intpoly_compare_points_2d(item, out[j - 1], center, order)
      }
      if cmp >= 0 {
        break
      }
      out[j] = out[j - 1]
      j -= 1
    }
    out[j] = item
  }
  out
}

///|
fn intpoly_symbol_name(symbol_expr : Expr) -> String raise IntegralError {
  match symbol_expr {
    @symcore.Expr::Symbol(name) => name
    _ => raise IntegralError::ValueError("expected coordinate symbols")
  }
}

///|
fn intpoly_substitute_point(
  expr : Expr,
  gens : Array[Expr],
  point : @symgeometry.Point,
) -> Expr raise IntegralError {
  let coords = point.coords()
  if gens.length() > coords.length() {
    raise IntegralError::ValueError("point does not have enough coordinates")
  }
  let mut out = expr
  for i in 0..<gens.length() {
    out = subst_symbol(out, intpoly_symbol_name(gens[i]), coords[i])
  }
  expr_simplify(out)
}

///|
fn intpoly_point_distance(
  lhs : @symgeometry.Point,
  rhs : @symgeometry.Point,
) -> Expr raise IntegralError {
  let lhs_coords = lhs.coords()
  let rhs_coords = rhs.coords()
  if lhs_coords.length() != rhs_coords.length() {
    raise IntegralError::ValueError("distance expects same-dimensional points")
  }
  let delta : Array[Expr] = []
  for i in 0..<lhs_coords.length() {
    delta.push(expr_sub(lhs_coords[i], rhs_coords[i]))
  }
  intpoly_coords_norm(delta)
}

///|
fn intpoly_point3_from_coords(
  coords : Array[Expr],
) -> @symgeometry.Point raise IntegralError {
  if coords.length() != 3 {
    raise IntegralError::ValueError("expected three coordinates")
  }
  @symgeometry.point3d(coords[0], coords[1], coords[2]) catch {
    _ => raise IntegralError::ValueError("failed to construct 3D point")
  }
}

///|
fn intpoly_directional_derivative_at_origin(
  expr : Expr,
  point : @symgeometry.Point,
  dims : Array[Expr],
) -> Expr raise IntegralError {
  let coords = point.coords()
  if dims.length() != coords.length() {
    raise IntegralError::ValueError("directional derivative dimension mismatch")
  }
  let mut out = @symcore.int(0)
  for i in 0..<dims.length() {
    out = expr_add(out, expr_mul(@symcalculus.diff(expr, dims[i]), coords[i]))
  }
  expr_simplify(out)
}

///|
fn intpoly_axis_cut_x(
  seg : @symgeometry.Segment,
) -> @symgeometry.Point? raise IntegralError {
  let p = seg.p1()
  let q = seg.p2()
  let px = intpoly_point_coord(p, 0)
  let py = intpoly_point_coord(p, 1)
  let qx = intpoly_point_coord(q, 0)
  let qy = intpoly_point_coord(q, 1)
  if expr_is_zero(py) {
    Some(p)
  } else if expr_is_zero(qy) {
    Some(q)
  } else if expr_is_negative(expr_div(py, qy)) {
    Some(
      @symgeometry.point2d(
        expr_simplify(
          expr_add(
            expr_div(expr_mul(py, expr_sub(px, qx)), expr_sub(qy, py)),
            px,
          ),
        ),
        @symcore.int(0),
      ) catch {
        _ => raise IntegralError::ValueError("failed to construct x-axis cut")
      },
    )
  } else {
    None
  }
}

///|
fn intpoly_axis_cut_y(
  seg : @symgeometry.Segment,
) -> @symgeometry.Point? raise IntegralError {
  let p = seg.p1()
  let q = seg.p2()
  let px = intpoly_point_coord(p, 0)
  let py = intpoly_point_coord(p, 1)
  let qx = intpoly_point_coord(q, 0)
  let qy = intpoly_point_coord(q, 1)
  if expr_is_zero(px) {
    Some(p)
  } else if expr_is_zero(qx) {
    Some(q)
  } else if expr_is_negative(expr_div(px, qx)) {
    Some(
      @symgeometry.point2d(
        @symcore.int(0),
        expr_simplify(
          expr_add(
            expr_div(expr_mul(px, expr_sub(py, qy)), expr_sub(qx, px)),
            py,
          ),
        ),
      ) catch {
        _ => raise IntegralError::ValueError("failed to construct y-axis cut")
      },
    )
  } else {
    None
  }
}

///|
fn intpoly_symbol_power_sum(expr : Expr, symbol_name : String) -> Int {
  match expr_simplify(expr) {
    @symcore.Expr::Symbol(name) => if name == symbol_name { 1 } else { 0 }
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) if name == symbol_name =>
      match expr_is_int_value(exp) {
        Some(power) if power > 0 => power
        _ => 0
      }
    @symcore.Expr::Mul(args) => {
      let mut total = 0
      for arg in args {
        total += intpoly_symbol_power_sum(arg, symbol_name)
      }
      total
    }
    @symcore.Expr::Add(args) => {
      let mut total = 0
      for arg in args {
        total += intpoly_symbol_power_sum(arg, symbol_name)
      }
      total
    }
    _ => 0
  }
}

///|
fn intpoly_polynomial_integrate(
  pieces : Array[(Int, Expr)],
  facets : Array[@symgeometry.Segment],
  hp_params : Array[(Array[Expr], Expr)],
) -> Expr raise IntegralError {
  if facets.length() != hp_params.length() {
    raise IntegralError::ValueError(
      "facets and hyperplane parameters must have the same length",
    )
  }
  let dims = [@symcore.Expr::Symbol("x"), @symcore.Expr::Symbol("y")]
  let dim_length = @symcore.int(dims.length())
  let mut integral_value = @symcore.int(0)
  for piece in pieces {
    let degree = piece.0
    let polynomial = piece.1
    let mut poly_contribute = @symcore.int(0)
    for facet_count in 0..<hp_params.length() {
      let hp = hp_params[facet_count]
      let value_over_boundary = integration_reduction(
        facets,
        facet_count,
        hp.0,
        hp.1,
        polynomial,
        dims,
        degree,
      )
      poly_contribute = expr_add(
        poly_contribute,
        expr_mul(value_over_boundary, expr_div(hp.1, intpoly_coords_norm(hp.0))),
      )
    }
    poly_contribute = expr_div(
      poly_contribute,
      expr_add(dim_length, @symcore.int(degree)),
    )
    integral_value = expr_add(integral_value, poly_contribute)
  }
  expr_simplify(integral_value)
}

///|
/// Split one monomial into numeric coefficient and remaining monomial.
///
/// - Does: Mirrors SymPy `integrals.intpoly.strip` for numeric constants and multiplicative monomials.
/// - Input: One monomial expression.
/// - Returns: `(coefficient, monomial_without_coefficient)`.
/// - Limits: General sums are treated as one symbolic monomial with coefficient `1`.
pub fn strip(monom : Expr) -> (Expr, Expr) {
  let simplified = expr_simplify(monom)
  if expr_is_zero(simplified) {
    return (@symcore.int(0), @symcore.int(0))
  }
  match expr_num_value(simplified) {
    Some(_) => return (simplified, @symcore.int(1))
    None => ()
  }
  match simplified {
    @symcore.Expr::Mul(args) => {
      let mut coeff = @symcore.int(1)
      let rest : Array[Expr] = []
      for arg in args {
        match expr_num_value(arg) {
          Some(_) => coeff = expr_mul(coeff, arg)
          None => rest.push(arg)
        }
      }
      if rest.is_empty() {
        (coeff, @symcore.int(1))
      } else {
        (expr_simplify(coeff), expr_simplify(@symcore.mul(rest)))
      }
    }
    _ => (@symcore.int(1), simplified)
  }
}

///|
/// Decompose a polynomial into homogeneous pieces.
///
/// - Does: Splits an expression by total degree, matching the information carried by SymPy `intpoly.decompose`.
/// - Input: One polynomial expression and an optional `separate` flag.
/// - Returns: Sorted `(degree, expression)` rows. With `separate=true`, each original monomial is returned separately.
/// - Limits: Raises for non-polynomial terms or non-integer powers.
pub fn decompose(
  expr : Expr,
  separate? : Bool = false,
) -> Array[(Int, Expr)] raise IntegralError {
  let simplified = expr_simplify(expr)
  let terms = match simplified {
    @symcore.Expr::Add(args) => args
    _ => [simplified]
  }
  if separate {
    let out : Array[(Int, Expr)] = []
    for term in terms {
      out.push((intpoly_total_degree(term), term))
    }
    out.sort_by(fn(lhs, rhs) {
      let cmp = lhs.0.compare(rhs.0)
      if cmp != 0 {
        cmp
      } else {
        @symcore.compare_expr(lhs.1, rhs.1)
      }
    })
    return out
  }

  let grouped : Map[Int, Expr] = Map([])
  let degrees : Array[Int] = []
  for term in terms {
    let degree = intpoly_total_degree(term)
    match grouped.get(degree) {
      Some(current) => grouped[degree] = expr_simplify(expr_add(current, term))
      None => {
        grouped[degree] = term
        degrees.push(degree)
      }
    }
  }
  degrees.sort()
  let out : Array[(Int, Expr)] = []
  for degree in degrees {
    match grouped.get(degree) {
      Some(value) => out.push((degree, value))
      None => ()
    }
  }
  out
}

///|
/// Return the Euclidean norm of a point.
///
/// - Does: Computes `sqrt(sum(coord**2))`.
/// - Input: One geometry `Point`.
/// - Returns: The symbolic Euclidean norm from the origin.
/// - Limits: Raises on empty points, which the geometry layer should not create.
pub fn norm(point : @symgeometry.Point) -> Expr raise IntegralError {
  intpoly_coords_norm(point.coords())
}

///|
/// Return whether an entity is a vertex-like point.
///
/// - Does: Accepts 2D and 3D geometry points as vertices, matching the point cases of SymPy intpoly.
/// - Input: One geometry `Point`.
/// - Returns: `true` for 2D or 3D points.
/// - Limits: Non-point tuple detection is represented by the typed `Point` input.
pub fn is_vertex(point : @symgeometry.Point) -> Bool {
  let len = point.length()
  len == 2 || len == 3
}

///|
/// Return `(v2 - v1) x (v3 - v1)` for three 3D points.
///
/// - Does: Computes the same oriented cross product helper used by SymPy intpoly.
/// - Input: Three 3D geometry points.
/// - Returns: Three symbolic coordinates of the cross product.
/// - Limits: Raises unless all inputs are 3D points.
pub fn cross_product(
  v1 : @symgeometry.Point,
  v2 : @symgeometry.Point,
  v3 : @symgeometry.Point,
) -> Array[Expr] raise IntegralError {
  intpoly_cross_product_coords(v1.coords(), v2.coords(), v3.coords())
}

///|
/// Generate monomial gradient bookkeeping rows up to a total degree.
///
/// - Does: Produces the 2D rows `[x**i*y**j, i, j, 0]` used by SymPy intpoly's polynomial reduction helpers.
/// - Input: A non-negative degree bound and generator count.
/// - Returns: Rows ordered like SymPy's 2D `gradient_terms`.
/// - Limits: The current typed front door supports the 2D case.
pub fn gradient_terms(
  binomial_power? : Int = 0,
  no_of_gens? : Int = 2,
) -> Array[Array[Expr]] raise IntegralError {
  if binomial_power < 0 {
    raise IntegralError::ValueError("binomial_power must be non-negative")
  }
  if no_of_gens != 2 {
    raise IntegralError::ValueError("gradient_terms currently supports 2D")
  }
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let terms : Array[Array[Expr]] = []
  for x_count in 0..<=binomial_power {
    for y_count in 0..<=(binomial_power - x_count) {
      terms.push([
        intpoly_monomial(x, y, x_count, y_count),
        @symcore.int(x_count),
        @symcore.int(y_count),
        @symcore.int(0),
      ])
    }
  }
  terms
}

///|
/// Return normalized 2D hyperplane parameters for each polygon side.
///
/// - Does: Computes `((y1-y2, x2-x1), x2*y1-y2*x1)` for every edge and normalizes exact integer factors.
/// - Input: One planar polygon.
/// - Returns: One `(normal, offset)` pair per polygon side.
/// - Limits: The current typed front door supports planar polygons.
pub fn hyperplane_parameters(
  poly : @symgeometry.Polygon,
) -> Array[(Array[Expr], Expr)] raise IntegralError {
  let vertices = poly.vertices()
  let params : Array[(Array[Expr], Expr)] = []
  for i in 0..<vertices.length() {
    let v1 = vertices[i].coords()
    let v2 = vertices[(i + 1) % vertices.length()].coords()
    if v1.length() != 2 || v2.length() != 2 {
      raise IntegralError::ValueError(
        "hyperplane_parameters currently supports 2D polygons",
      )
    }
    let a1 = expr_sub(v1[1], v2[1])
    let a2 = expr_sub(v2[0], v1[0])
    let b = expr_sub(expr_mul(v2[0], v1[1]), expr_mul(v2[1], v1[0]))
    let factor = intpoly_expr_gcd([a1, a2, b])
    params.push(
      (
        [
          expr_simplify(expr_div(a1, factor)),
          expr_simplify(expr_div(a2, factor)),
        ],
        expr_simplify(expr_div(b, factor)),
      ),
    )
  }
  params
}

///|
/// Sort polygon vertices clockwise or counter-clockwise around their center.
///
/// - Does: Recreates SymPy `intpoly.point_sort` for numeric 2D points, and for 3D points when a normal is supplied.
/// - Input: An array of points, an optional 3D normal, and an orientation flag.
/// - Returns: A new sorted array; the input array is not mutated.
/// - Limits: Coordinates must be numerically comparable.
pub fn point_sort(
  points : Array[@symgeometry.Point],
  normal? : @symgeometry.Point? = None,
  clockwise? : Bool = true,
) -> Array[@symgeometry.Point] raise IntegralError {
  if points.length() < 2 {
    return points.copy()
  }
  let dim = points[0].length()
  if dim != 2 && dim != 3 {
    raise IntegralError::ValueError("point_sort supports 2D and 3D points")
  }
  for point in points {
    if point.length() != dim {
      raise IntegralError::ValueError(
        "point_sort expects points of one dimension",
      )
    }
  }
  let center = if dim == 2 {
    @symgeometry.point2d(
      intpoly_average_coord(points, 0),
      intpoly_average_coord(points, 1),
    ) catch {
      _ => raise IntegralError::ValueError("failed to construct 2D center")
    }
  } else {
    @symgeometry.point3d(
      intpoly_average_coord(points, 0),
      intpoly_average_coord(points, 1),
      intpoly_average_coord(points, 2),
    ) catch {
      _ => raise IntegralError::ValueError("failed to construct 3D center")
    }
  }
  if dim == 3 && normal is None {
    raise IntegralError::ValueError(
      "point_sort requires a normal for 3D points",
    )
  }
  intpoly_sort_points(points, center, normal, clockwise)
}

///|
/// Pick a low-degree origin point on a 2D line segment.
///
/// - Does: Mirrors SymPy `intpoly.best_origin`, preferring axis intersections that reduce the dominant polynomial variable.
/// - Input: Hyperplane normal `a`, offset `b`, one 2D segment, and a polynomial expression.
/// - Returns: A point on the segment to use as the reduction origin.
/// - Limits: Supports the 2D case used by SymPy's current helper.
pub fn best_origin(
  a : Array[Expr],
  b : Expr,
  lineseg : @symgeometry.Segment,
  expr : Expr,
) -> @symgeometry.Point raise IntegralError {
  if a.length() != 2 {
    raise IntegralError::ValueError("best_origin currently supports 2D")
  }
  let first = lineseg.p1()
  if expr_is_zero(a[0]) {
    match intpoly_axis_cut_y(lineseg) {
      Some(_) =>
        return @symgeometry.point2d(@symcore.int(0), expr_div(b, a[1])) catch {
          _ =>
            raise IntegralError::ValueError("failed to construct best origin")
        }
      None => return first
    }
  }
  if expr_is_zero(a[1]) {
    match intpoly_axis_cut_x(lineseg) {
      Some(_) =>
        return @symgeometry.point2d(expr_div(b, a[0]), @symcore.int(0)) catch {
          _ =>
            raise IntegralError::ValueError("failed to construct best origin")
        }
      None => return first
    }
  }
  if expr_num_value(expr) is Some(_) {
    return first
  }
  let x_power = intpoly_symbol_power_sum(expr, "x")
  let y_power = intpoly_symbol_power_sum(expr, "y")
  if x_power >= y_power {
    match intpoly_axis_cut_y(lineseg) {
      Some(_) =>
        @symgeometry.point2d(@symcore.int(0), expr_div(b, a[1])) catch {
          _ =>
            raise IntegralError::ValueError("failed to construct best origin")
        }
      None =>
        match intpoly_axis_cut_x(lineseg) {
          Some(_) =>
            @symgeometry.point2d(expr_div(b, a[0]), @symcore.int(0)) catch {
              _ =>
                raise IntegralError::ValueError(
                  "failed to construct best origin",
                )
            }
          None => first
        }
    }
  } else {
    match intpoly_axis_cut_x(lineseg) {
      Some(_) =>
        @symgeometry.point2d(expr_div(b, a[0]), @symcore.int(0)) catch {
          _ =>
            raise IntegralError::ValueError("failed to construct best origin")
        }
      None =>
        match intpoly_axis_cut_y(lineseg) {
          Some(_) =>
            @symgeometry.point2d(@symcore.int(0), expr_div(b, a[1])) catch {
              _ =>
                raise IntegralError::ValueError(
                  "failed to construct best origin",
                )
            }
          None => first
        }
    }
  }
}

///|
/// Compute the signed distance helper from a 3D point to a side.
///
/// - Does: Recreates SymPy intpoly's side-distance formula from a point, a segment, and a facet normal.
/// - Input: One 3D point, one 3D segment, and one 3D normal encoded as a `Point`.
/// - Returns: A symbolic signed distance.
/// - Limits: Raises unless every geometric input is 3D.
pub fn distance_to_side(
  point : @symgeometry.Point,
  line_seg : @symgeometry.Segment,
  normal : @symgeometry.Point,
) -> Expr raise IntegralError {
  let p = intpoly_point3_coords(point)
  let p1 = intpoly_point3_coords(line_seg.p1())
  let p2 = intpoly_point3_coords(line_seg.p2())
  let normal_coords = intpoly_point3_coords(normal)
  let normal_norm = intpoly_coords_norm(normal_coords)
  let rev_normal = normal_coords.map(coord => {
    expr_div(expr_mul(@symcore.int(-1), coord), normal_norm)
  })
  let direction = [
    expr_sub(p2[0], p1[0]),
    expr_sub(p2[1], p1[1]),
    expr_sub(p2[2], p1[2]),
  ]
  let direction_norm = intpoly_coords_norm(direction)
  let unit_direction = direction.map(coord => expr_div(coord, direction_norm))
  let side_normal = intpoly_cross_product_coords(
    [@symcore.int(0), @symcore.int(0), @symcore.int(0)],
    rev_normal,
    unit_direction,
  )
  let offset = [
    expr_sub(p1[0], p[0]),
    expr_sub(p1[1], p[1]),
    expr_sub(p1[2], p[2]),
  ]
  let mut dot = @symcore.int(0)
  for i in 0..<3 {
    dot = expr_add(dot, expr_mul(offset[i], side_normal[i]))
  }
  expr_simplify(dot)
}

///|
/// Return the intersection point of two known-intersecting 2D segments.
///
/// - Does: Implements SymPy intpoly's `intersection(..., "segment2D")` line formula.
/// - Input: Two 2D segments and the intersection kind string.
/// - Returns: `Some(Point)` for a unique intersection, or `None` for parallel/coincident lines.
/// - Limits: Currently supports `intersection_type="segment2D"`.
pub fn intersection(
  geom_1 : @symgeometry.Segment,
  geom_2 : @symgeometry.Segment,
  intersection_type : String,
) -> @symgeometry.Point? raise IntegralError {
  if intersection_type != "segment2D" {
    raise IntegralError::ValueError(
      "intersection currently supports only segment2D",
    )
  }
  let (p1, p2) = intpoly_segment2d_coords(geom_1)
  let (p3, p4) = intpoly_segment2d_coords(geom_2)
  let x1 = p1[0]
  let y1 = p1[1]
  let x2 = p2[0]
  let y2 = p2[1]
  let x3 = p3[0]
  let y3 = p3[1]
  let x4 = p4[0]
  let y4 = p4[1]
  let denom = expr_sub(
    expr_mul(expr_sub(x1, x2), expr_sub(y3, y4)),
    expr_mul(expr_sub(y1, y2), expr_sub(x3, x4)),
  )
  if expr_is_zero(denom) {
    return None
  }
  let t1 = expr_sub(expr_mul(x1, y2), expr_mul(y1, x2))
  let t2 = expr_sub(expr_mul(x3, y4), expr_mul(x4, y3))
  let x = expr_div(
    expr_sub(expr_mul(t1, expr_sub(x3, x4)), expr_mul(t2, expr_sub(x1, x2))),
    denom,
  )
  let y = expr_div(
    expr_sub(expr_mul(t1, expr_sub(y3, y4)), expr_mul(t2, expr_sub(y1, y2))),
    denom,
  )
  Some(
    @symgeometry.point2d(expr_simplify(x), expr_simplify(y)) catch {
      _ => raise IntegralError::ValueError("failed to construct intersection")
    },
  )
}

///|
/// Compute the 2D boundary contribution from neighboring facets.
///
/// - Does: Implements SymPy `intpoly.left_integral2D` for planar segment facets.
/// - Input: The facet count, current facet index, facets, origin point, polynomial, and coordinate symbols.
/// - Returns: The left-integral contribution used by the reduction recurrence.
/// - Limits: Supports 2D segment facets with 2D or 3D point substitutions according to `gens`.
pub fn left_integral2D(
  m : Int,
  index : Int,
  facets : Array[@symgeometry.Segment],
  x0 : @symgeometry.Point,
  expr : Expr,
  gens : Array[Expr],
) -> Expr raise IntegralError {
  if index < 0 || index >= facets.length() || m != facets.length() {
    raise IntegralError::ValueError("invalid facet index for left_integral2D")
  }
  let mut value = @symcore.int(0)
  for j in 0..<m {
    if j == (index + m - 1) % m || j == (index + 1) % m {
      match intersection(facets[index], facets[j], "segment2D") {
        Some(intersect) =>
          if is_vertex(intersect) {
            let distance_origin = intpoly_point_distance(intersect, x0)
            let evaluated = match expr_num_value(expr) {
              Some(_) => expr
              None => intpoly_substitute_point(expr, gens, intersect)
            }
            value = expr_add(value, expr_mul(distance_origin, evaluated))
          }
        None => ()
      }
    }
  }
  expr_simplify(value)
}

///|
/// Reduce a homogeneous 2D polynomial integral to boundary values.
///
/// - Does: Mirrors SymPy `intpoly.integration_reduction` for planar facets.
/// - Input: Planar facets, one facet index, hyperplane data, expression, dimensions, and degree.
/// - Returns: The reduced boundary integral value for that facet.
/// - Limits: Supports the 2D branch of the SymPy routine.
pub fn integration_reduction(
  facets : Array[@symgeometry.Segment],
  index : Int,
  _a : Array[Expr],
  _b : Expr,
  expr : Expr,
  dims : Array[Expr],
  degree : Int,
) -> Expr raise IntegralError {
  if dims.length() != 2 {
    raise IntegralError::ValueError(
      "integration_reduction currently supports 2D",
    )
  }
  let simplified = expr_simplify(expr)
  if expr_is_zero(simplified) {
    return simplified
  }
  if index < 0 || index >= facets.length() {
    raise IntegralError::ValueError("invalid facet index")
  }
  let x0 = facets[index].p1()
  let x_coord = intpoly_point_coord(x0, 0)
  let y_coord = intpoly_point_coord(x0, 1)
  let x_diff = @symcalculus.diff(simplified, dims[0])
  let y_diff = @symcalculus.diff(simplified, dims[1])
  let inner_product = expr_add(
    expr_mul(x_diff, x_coord),
    expr_mul(y_diff, y_coord),
  )
  let mut value = @symcore.int(0)
  if !expr_is_zero(expr_simplify(inner_product)) {
    value = expr_add(
      value,
      integration_reduction(
        facets,
        index,
        _a,
        _b,
        inner_product,
        dims,
        degree - 1,
      ),
    )
  }
  value = expr_add(
    value,
    left_integral2D(facets.length(), index, facets, x0, simplified, dims),
  )
  expr_simplify(expr_div(value, @symcore.int(dims.length() + degree - 1)))
}

///|
/// Dynamic-programming variant of 2D integration reduction.
///
/// - Does: Reuses previously computed monomial boundary values, following SymPy `intpoly.integration_reduction_dynamic` for the 2D case.
/// - Input: Facets, hyperplane data, a monomial, degree/index metadata, origin, prior monomial rows, and row index.
/// - Returns: The reduced boundary value for that monomial.
/// - Limits: Supports the 2D monomial table layout `[expr, x_degree, y_degree, value]`.
pub fn integration_reduction_dynamic(
  facets : Array[@symgeometry.Segment],
  index : Int,
  _a : Array[Expr],
  _b : Expr,
  expr : Expr,
  degree : Int,
  dims : Array[Expr],
  x_index : Int,
  _y_index : Int,
  max_index : Int,
  x0 : @symgeometry.Point,
  monomial_values : Array[Array[Expr]],
  monom_index : Int,
) -> Expr raise IntegralError {
  let simplified = expr_simplify(expr)
  if expr_is_zero(simplified) {
    return simplified
  }
  if dims.length() != 2 {
    raise IntegralError::ValueError(
      "integration_reduction_dynamic currently supports 2D",
    )
  }
  if monom_index < 0 || monom_index >= monomial_values.length() {
    raise IntegralError::ValueError("monomial index out of range")
  }
  let mut value = @symcore.int(0)
  if expr_num_value(simplified) is None {
    let row = monomial_values[monom_index]
    if row.length() < 4 {
      raise IntegralError::ValueError("monomial rows need four fields")
    }
    let x_degree = expr_exact_int(row[1]).unwrap_or(0)
    let y_degree = expr_exact_int(row[2]).unwrap_or(0)
    if x_degree > 0 {
      let lookup = monom_index - max_index + x_index - 2
      if lookup < 0 || lookup >= monomial_values.length() {
        raise IntegralError::ValueError("x monomial lookup out of range")
      }
      value = expr_add(
        value,
        expr_mul(
          expr_mul(@symcore.int(x_degree), monomial_values[lookup][3]),
          intpoly_point_coord(x0, 0),
        ),
      )
    }
    if y_degree > 0 {
      let lookup = monom_index - 1
      if lookup < 0 || lookup >= monomial_values.length() {
        raise IntegralError::ValueError("y monomial lookup out of range")
      }
      value = expr_add(
        value,
        expr_mul(
          expr_mul(@symcore.int(y_degree), monomial_values[lookup][3]),
          intpoly_point_coord(x0, 1),
        ),
      )
    }
  }
  value = expr_add(
    value,
    left_integral2D(facets.length(), index, facets, x0, simplified, dims),
  )
  expr_simplify(expr_div(value, @symcore.int(dims.length() + degree - 1)))
}

///|
/// Integrate a planar polynomial from its facets and hyperplane parameters.
///
/// - Does: Implements the non-dynamic 2D branch of SymPy `intpoly.main_integrate`.
/// - Input: One polynomial, polygon sides, and `hyperplane_parameters` output.
/// - Returns: The exact area integral.
/// - Limits: Dynamic moment-table mode (`max_degree`) is exposed through `polytope_integrate_upto`.
pub fn main_integrate(
  expr : Expr,
  facets : Array[@symgeometry.Segment],
  hp_params : Array[(Array[Expr], Expr)],
  max_degree? : Int = -1,
) -> Expr raise IntegralError {
  if max_degree >= 0 {
    raise IntegralError::ValueError(
      "main_integrate dynamic max_degree mode is available as polytope_integrate_upto",
    )
  }
  intpoly_polynomial_integrate(decompose(expr), facets, hp_params)
}

///|
/// Compute a 3D line-segment contribution for polytope integration.
///
/// - Does: Implements SymPy `intpoly.lineseg_integrate` using recursive Euler reduction along one 3D segment.
/// - Input: The containing polygon vertices, side index, 3D segment, expression, and homogeneous degree.
/// - Returns: The exact segment contribution.
/// - Limits: Coordinates are assumed to be 3D and `expr` polynomial in `x, y, z`.
pub fn lineseg_integrate(
  _polygon : Array[@symgeometry.Point],
  _index : Int,
  line_seg : @symgeometry.Segment,
  expr : Expr,
  degree : Int,
) -> Expr raise IntegralError {
  let simplified = expr_simplify(expr)
  if expr_is_zero(simplified) || degree < 0 {
    return @symcore.int(0)
  }
  let p0 = line_seg.p1()
  let p1 = line_seg.p2()
  let distance = intpoly_point_distance(p0, p1)
  let dims = [
    @symcore.Expr::Symbol("x"),
    @symcore.Expr::Symbol("y"),
    @symcore.Expr::Symbol("z"),
  ]
  let evaluated = match expr_num_value(simplified) {
    Some(_) => simplified
    None => intpoly_substitute_point(simplified, dims, p1)
  }
  let mut result = expr_mul(distance, evaluated)
  let reduced = intpoly_directional_derivative_at_origin(simplified, p0, dims)
  result = expr_add(
    result,
    lineseg_integrate(_polygon, _index, line_seg, reduced, degree - 1),
  )
  expr_simplify(expr_div(result, @symcore.int(degree + 1)))
}

///|
/// Compute the 3D left-integral contribution over one face boundary.
///
/// - Does: Sums line-segment contributions weighted by signed side distance, matching SymPy `left_integral3D`.
/// - Input: Face index lists, current face index, polynomial, vertices, one face hyperplane, and degree.
/// - Returns: The boundary contribution for the selected face.
/// - Limits: Supports 3D vertex-index facets.
pub fn left_integral3D(
  facets : Array[Array[Int]],
  index : Int,
  expr : Expr,
  vertices : Array[@symgeometry.Point],
  hp_param : (Array[Expr], Expr),
  degree : Int,
) -> Expr raise IntegralError {
  if index < 0 || index >= facets.length() {
    raise IntegralError::ValueError("invalid facet index for left_integral3D")
  }
  let facet = facets[index]
  if facet.is_empty() {
    raise IntegralError::ValueError("empty facet")
  }
  let x0 = vertices[facet[0]]
  let normal = intpoly_point3_from_coords(hp_param.0)
  let facet_points : Array[@symgeometry.Point] = []
  for vertex_index in facet {
    facet_points.push(vertices[vertex_index])
  }
  let mut value = @symcore.int(0)
  for i in 0..<facet.length() {
    let side = @symgeometry.segment(
      vertices[facet[i]],
      vertices[facet[(i + 1) % facet.length()]],
    ) catch {
      _ => raise IntegralError::ValueError("failed to construct facet side")
    }
    value = expr_add(
      value,
      expr_mul(
        distance_to_side(x0, side, normal),
        lineseg_integrate(facet_points, i, side, expr, degree),
      ),
    )
  }
  expr_simplify(value)
}

///|
/// Integrate one homogeneous polynomial over a 3D face.
///
/// - Does: Implements SymPy `intpoly.polygon_integrate` for one indexed polyhedron face.
/// - Input: One face, hyperplane parameters, all faces, vertices, expression, and degree.
/// - Returns: The exact face integral contribution.
/// - Limits: Supports 3D faces described by vertex indices.
pub fn polygon_integrate(
  facet : Array[Int],
  hp_param : (Array[Expr], Expr),
  index : Int,
  facets : Array[Array[Int]],
  vertices : Array[@symgeometry.Point],
  expr : Expr,
  degree : Int,
) -> Expr raise IntegralError {
  let simplified = expr_simplify(expr)
  if expr_is_zero(simplified) {
    return @symcore.int(0)
  }
  if facet.is_empty() {
    raise IntegralError::ValueError("empty facet")
  }
  let x0 = vertices[facet[0]]
  let normal = intpoly_point3_from_coords(hp_param.0)
  let facet_points : Array[@symgeometry.Point] = []
  for vertex_index in facet {
    facet_points.push(vertices[vertex_index])
  }
  let mut result = @symcore.int(0)
  for i in 0..<facet.length() {
    let side = @symgeometry.segment(
      vertices[facet[i]],
      vertices[facet[(i + 1) % facet.length()]],
    ) catch {
      _ => raise IntegralError::ValueError("failed to construct facet side")
    }
    result = expr_add(
      result,
      expr_mul(
        distance_to_side(x0, side, normal),
        lineseg_integrate(facet_points, i, side, simplified, degree),
      ),
    )
  }
  if expr_num_value(simplified) is None {
    let dims = [
      @symcore.Expr::Symbol("x"),
      @symcore.Expr::Symbol("y"),
      @symcore.Expr::Symbol("z"),
    ]
    let reduced = intpoly_directional_derivative_at_origin(simplified, x0, dims)
    result = expr_add(
      result,
      polygon_integrate(
        facet,
        hp_param,
        index,
        facets,
        vertices,
        reduced,
        degree - 1,
      ),
    )
  }
  expr_simplify(expr_div(result, @symcore.int(degree + 2)))
}

///|
/// Integrate a polynomial over a 3D polytope from face data.
///
/// - Does: Implements the non-dynamic branch of SymPy `intpoly.main_integrate3d`.
/// - Input: One polynomial, face index lists, vertices, and hyperplane parameters.
/// - Returns: The exact signed volume integral.
/// - Limits: Dynamic moment-table mode (`max_degree`) is not part of this typed front door.
pub fn main_integrate3d(
  expr : Expr,
  facets : Array[Array[Int]],
  vertices : Array[@symgeometry.Point],
  hp_params : Array[(Array[Expr], Expr)],
  max_degree? : Int = -1,
) -> Expr raise IntegralError {
  if max_degree >= 0 {
    raise IntegralError::ValueError(
      "main_integrate3d dynamic max_degree mode is not implemented",
    )
  }
  if facets.length() != hp_params.length() {
    raise IntegralError::ValueError("facets and hyperplane parameters mismatch")
  }
  let mut integral_value = @symcore.int(0)
  for piece in decompose(expr) {
    let degree = piece.0
    let polynomial = piece.1
    let mut poly_contribute = @symcore.int(0)
    for i in 0..<facets.length() {
      let hp = hp_params[i]
      if !expr_is_zero(hp.1) {
        let face_value = polygon_integrate(
          facets[i],
          hp,
          i,
          facets,
          vertices,
          polynomial,
          degree,
        )
        poly_contribute = expr_add(
          poly_contribute,
          expr_mul(face_value, expr_div(hp.1, intpoly_coords_norm(hp.0))),
        )
      }
    }
    poly_contribute = expr_div(poly_contribute, @symcore.int(3 + degree))
    integral_value = expr_add(integral_value, poly_contribute)
  }
  expr_simplify(integral_value)
}

///|
/// Build a plot object for a planar polygonal polytope.
///
/// - Does: Represents each polygon edge as a parametric 2D line series using `symplotting`.
/// - Input: One planar polygon.
/// - Returns: A `symplotting.Plot` object; it is not shown automatically.
/// - Limits: Supports 2D polygons.
pub fn plot_polytope(
  poly : @symgeometry.Polygon,
) -> @symplotting.Plot raise IntegralError {
  let t = @symcore.Expr::Symbol("t")
  let inputs : Array[@symplotting.ParametricPlotInput] = []
  let sides = poly.sides() catch {
    _ => raise IntegralError::ValueError("failed to derive polygon sides")
  }
  for side in sides {
    let p0 = side.p1()
    let p1 = side.p2()
    let x0 = intpoly_point_coord(p0, 0)
    let y0 = intpoly_point_coord(p0, 1)
    let x1 = intpoly_point_coord(p1, 0)
    let y1 = intpoly_point_coord(p1, 1)
    let x_t = expr_add(x0, expr_mul(expr_sub(x1, x0), t))
    let y_t = expr_add(y0, expr_mul(expr_sub(y1, y0), t))
    inputs.push(
      @symplotting.plot_parametric_group([
        @symplotting.plot_parametric_expr(x_t, y_t),
        @symplotting.plot_parametric_range(t, @symcore.int(0), @symcore.int(1)),
      ]),
    )
  }
  @symplotting.plot_parametric(inputs, show=false) catch {
    @symplotting.PlottingError::ValueError(message) =>
      raise IntegralError::ValueError(message)
    @symplotting.PlottingError::TypeError(message) =>
      raise IntegralError::ValueError(message)
  }
}

///|
/// Build a plot object for a univariate or bivariate polynomial.
///
/// - Does: Uses `symplotting.plot` for at most one free symbol and `symplotting.plot3d` for two free symbols.
/// - Input: One polynomial expression.
/// - Returns: A `symplotting.Plot` object; it is not shown automatically.
/// - Limits: Raises when more than two free symbols are present.
pub fn plot_polynomial(expr : Expr) -> @symplotting.Plot raise IntegralError {
  let symbols = @symcore.free_symbols(expr)
  if symbols.length() <= 1 {
    @symplotting.plot([@symplotting.plot_expr(expr)], show=false) catch {
      @symplotting.PlottingError::ValueError(message) =>
        raise IntegralError::ValueError(message)
      @symplotting.PlottingError::TypeError(message) =>
        raise IntegralError::ValueError(message)
    }
  } else if symbols.length() == 2 {
    @symplotting.plot3d([@symplotting.plot_expr(expr)], show=false) catch {
      @symplotting.PlottingError::ValueError(message) =>
        raise IntegralError::ValueError(message)
      @symplotting.PlottingError::TypeError(message) =>
        raise IntegralError::ValueError(message)
    }
  } else {
    raise IntegralError::ValueError(
      "plot_polynomial supports at most two free symbols",
    )
  }
}

///|
/// Integrate a polynomial exactly along one planar segment.
///
/// - Does: Pulls the polynomial back to an affine segment parameterization, multiplies by the Jacobian factor, and integrates over the parameter.
/// - Input: One `Segment`, one polynomial `Expr`, and an optional variable array.
/// - Returns: One exact integral `Expr`.
/// - Limits: Raises `IntegralError` when the polynomial or variables do not match the expected planar setup.
pub fn segment_integrate(
  seg : @symgeometry.Segment,
  expr : Expr,
  vars? : Array[Expr] = intpoly_default_vars(),
) -> Expr raise IntegralError {
  let (x_name, y_name) = intpoly_validate_planar_polynomial(expr, vars)
  let t_name = intpoly_fresh_parameter(expr, [x_name, y_name])
  let t = @symcore.Expr::Symbol(t_name)
  let transformed = intpoly_segment_integrand(expr, seg, x_name, y_name, t_name)
  let weighted = expr_mul(transformed, intpoly_segment_length(seg))
  integrate(weighted, limits=[
    integral_limit([t, @symcore.int(0), @symcore.int(1)]),
  ])
}

///|
/// Integrate a planar polynomial exactly over one polygon.
///
/// - Does: Uses the local polygon integration pipeline to compute the exact area integral of a polynomial over a planar polygon.
/// - Input: One `Polygon`, one polynomial `Expr`, and an optional variable array.
/// - Returns: One exact integral `Expr`.
/// - Limits: Raises `IntegralError` when the polygon or polynomial does not match the supported planar setup.
pub fn polytope_integrate(
  poly : @symgeometry.Polygon,
  expr : Expr,
  vars? : Array[Expr] = intpoly_default_vars(),
) -> Expr raise IntegralError {
  let (x_name, y_name) = intpoly_validate_planar_polynomial(expr, vars)
  let primitive = intpoly_primitive_x(expr, x_name)
  let signed = intpoly_polygon_signed_integral(poly, primitive, x_name, y_name)
  intpoly_normalize_orientation(poly, expr_simplify(signed))
}

///|
/// Integrate several planar polynomials over one polygon.
///
/// - Does: Reuses `polytope_integrate` for each input polynomial and collects the results in a map.
/// - Input: One `Polygon`, an `Array[Expr]` of polynomials, and an optional variable array.
/// - Returns: A `Map[Expr, Expr]` from each polynomial to its exact integral.
/// - Limits: Raises `IntegralError` under the same conditions as `polytope_integrate`.
pub fn polytope_integrate_many(
  poly : @symgeometry.Polygon,
  exprs : Array[Expr],
  vars? : Array[Expr] = intpoly_default_vars(),
) -> Map[Expr, Expr] raise IntegralError {
  let out : Map[Expr, Expr] = Map([])
  for expr in exprs {
    out[expr] = polytope_integrate(poly, expr, vars~)
  }
  out
}

///|
/// Compute planar monomial moments up to one total degree.
///
/// - Does: Integrates every monomial up to total degree `max_degree` over the polygon.
/// - Input: One `Polygon`, one non-negative maximum degree, and an optional variable array.
/// - Returns: A `Map[Expr, Expr]` keyed by monomials.
/// - Limits: Raises `IntegralError` if `max_degree` is negative or if polygon integration fails.
pub fn polytope_integrate_upto(
  poly : @symgeometry.Polygon,
  max_degree : Int,
  vars? : Array[Expr] = intpoly_default_vars(),
) -> Map[Expr, Expr] raise IntegralError {
  if max_degree < 0 {
    raise IntegralError::ValueError("max_degree must be non-negative")
  }
  let (x_name, y_name) = intpoly_var_names(vars)
  let x = @symcore.Expr::Symbol(x_name)
  let y = @symcore.Expr::Symbol(y_name)
  let out : Map[Expr, Expr] = Map([])
  for degree in 0..<=max_degree {
    for dx in 0..<=degree {
      let dy = degree - dx
      let monomial = intpoly_monomial(x, y, dx, dy)
      out[monomial] = polytope_integrate(poly, monomial, vars~)
    }
  }
  out
}
