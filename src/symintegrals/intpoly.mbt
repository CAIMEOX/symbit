///|
/// Exact polynomial integration over 2D polygonal regions and segments.
///
/// The public surface mirrors the high-value `sympy.integrals.intpoly` paths
/// that are already supported by the current Symbit geometry layer:
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
              expr_div(expr_pow(x, @symcore.int(power + 1)), @symcore.int(power + 1)),
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
  let lhs = if dx == 0 { @symcore.int(1) } else { expr_pow(x, @symcore.int(dx)) }
  let rhs = if dy == 0 { @symcore.int(1) } else { expr_pow(y, @symcore.int(dy)) }
  expr_mul(lhs, rhs)
}

///|
/// Integrate a polynomial exactly along a line segment in the plane.
///
/// The segment is parameterized affinely and the Jacobian factor is included,
/// so this is the line-integral analogue of SymPy's `intpoly` helpers.
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
  integrate(weighted, limits=[integral_limit([t, @symcore.int(0), @symcore.int(1)])])
}

///|
/// Integrate a planar polynomial exactly over a polygonal region.
///
/// This currently covers the 2D `Polygon` path using Green-style primitive
/// accumulation and orientation normalization.
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
/// Exact polygon integral for several polynomials at once.
pub fn polytope_integrate_many(
  poly : @symgeometry.Polygon,
  exprs : Array[Expr],
  vars? : Array[Expr] = intpoly_default_vars(),
) -> Map[Expr, Expr] raise IntegralError {
  let out : Map[Expr, Expr] = {}
  for expr in exprs {
    out[expr] = polytope_integrate(poly, expr, vars~)
  }
  out
}

///|
/// Compute all planar monomial moments up to total degree `max_degree`.
///
/// The returned map is keyed by monomials in the requested variables.
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
  let out : Map[Expr, Expr] = {}
  for degree in 0..<=max_degree {
    for dx in 0..<=degree {
      let dy = degree - dx
      let monomial = intpoly_monomial(x, y, dx, dy)
      out[monomial] = polytope_integrate(poly, monomial, vars~)
    }
  }
  out
}
