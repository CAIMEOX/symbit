///|
/// Parametric curve given by coordinate functions and a parameter interval.
pub struct Curve {
  functions_ : Array[Expr]
  parameter_ : Expr
  start_ : Expr
  end_ : Expr
} derive(Eq)

///|
pub fn curve(
  functions : Array[Expr],
  parameter : Expr,
  start : Expr,
  end : Expr,
) -> Curve raise GeometryError {
  if functions.length() < 2 {
    raise GeometryError::ValueError(
      "curve requires at least two coordinate functions",
    )
  }
  Curve::{
    functions_: functions.map(geo_simplify),
    parameter_: parameter,
    start_: start,
    end_: end,
  }
}

///|
pub fn Curve::repr(self : Curve) -> String {
  "Curve((" +
  self.functions_.map(geo_expr_text).join(", ") +
  "), (" +
  geo_expr_text(self.parameter_) +
  ", " +
  geo_expr_text(self.start_) +
  ", " +
  geo_expr_text(self.end_) +
  "))"
}

///|
pub fn Curve::ambient_dimension(self : Curve) -> Int {
  self.functions_.length()
}

///|
pub fn Curve::functions(self : Curve) -> Array[Expr] {
  self.functions_[:].to_array()
}

///|
pub fn Curve::parameter(self : Curve) -> Expr {
  self.parameter_
}

///|
pub fn Curve::limits(self : Curve) -> (Expr, Expr, Expr) {
  (self.parameter_, self.start_, self.end_)
}

///|
pub fn Curve::free_symbols(self : Curve) -> Array[Expr] {
  let seen : Map[String, Bool] = {}
  for expr in self.functions_ {
    geo_collect_symbols(expr, seen)
  }
  geo_collect_symbols(self.start_, seen)
  geo_collect_symbols(self.end_, seen)
  let out : Array[Expr] = []
  let parameter_name = match self.parameter_ {
    Expr::Symbol(name) => Some(name)
    _ => None
  }
  for item in seen {
    if parameter_name != Some(item.0) {
      out.push(Expr::Symbol(item.0))
    }
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if @symprint.pretty_string(out[i]).compare(
          @symprint.pretty_string(out[j]),
        ) >
        0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
pub fn Curve::plot_interval(
  self : Curve,
  parameter? : Expr = Expr::Symbol("t"),
) -> Array[Expr] {
  [parameter, self.start_, self.end_]
}

///|
pub fn Curve::arbitrary_point(
  self : Curve,
  parameter? : Expr = Expr::Symbol("t"),
) -> Point raise GeometryError {
  let env : Map[String, Expr] = {}
  let actual = if @symcore.compare_expr(parameter, Expr::Symbol("t")) == 0 {
    self.parameter_
  } else {
    parameter
  }
  match self.parameter_ {
    Expr::Symbol(name) => env.set(name, actual)
    _ => ()
  }
  point(
    self.functions_.map(fn(expr) { @symcore.subst(expr, env) }),
    dim=self.functions_.length(),
  )
}

///|
pub fn Curve::parameter_value(
  self : Curve,
  other : Point,
  t : Expr,
) -> Map[Expr, Expr] raise GeometryError {
  let point_obj = other.with_dim(self.functions_.length())
  let mut candidates : Array[Expr]? = None
  for i in 0..<self.functions_.length() {
    let diff = geo_simplify(self.functions_[i] - point_obj.coords_[i])
    if geo_expr_is_zero(diff) {
      continue
    }
    let roots = match geo_solve_univar_deg2(diff, self.parameter_) {
      Some(items) if !items.is_empty() => items
      _ => raise GeometryError::ValueError("point is not on curve")
    }
    let unique_roots : Array[Expr] = []
    for root in roots {
      let normalized_root = geo_simplify(root)
      if !unique_roots.any(fn(prev) { geo_expr_eq(prev, normalized_root) }) {
        unique_roots.push(normalized_root)
      }
    }
    match candidates {
      None => candidates = Some(unique_roots)
      Some(prev) => {
        let next : Array[Expr] = []
        for candidate in prev {
          if unique_roots.any(fn(root) { geo_expr_eq(root, candidate) }) {
            next.push(candidate)
          }
        }
        candidates = Some(next)
      }
    }
  }
  let matches = match candidates {
    Some(items) if !items.is_empty() => items
    _ => raise GeometryError::ValueError("point is not on curve")
  }
  for candidate in matches {
    let candidate = geo_simplify(candidate)
    let env : Map[String, Expr] = {}
    match self.parameter_ {
      Expr::Symbol(name) => env.set(name, candidate)
      _ => ()
    }
    let mut ok = true
    for i in 0..<self.functions_.length() {
      let value = geo_simplify(@symcore.subst(self.functions_[i], env))
      if !geo_expr_eq(value, point_obj.coords_[i]) {
        ok = false
      }
    }
    if ok {
      let out : Map[Expr, Expr] = {}
      out.set(t, geo_simplify(candidate))
      return out
    }
  }
  raise GeometryError::ValueError("point is not on curve")
}

///|
pub fn Curve::translate(
  self : Curve,
  offsets : Array[Expr],
) -> Curve raise GeometryError {
  if offsets.length() != self.functions_.length() {
    raise GeometryError::ValueError(
      "curve translation offsets must match ambient dimension",
    )
  }
  curve(
    self.functions_.mapi(fn(i, expr) { geo_simplify(expr + offsets[i]) }),
    self.parameter_,
    self.start_,
    self.end_,
  )
}

///|
pub fn Curve::scale(
  self : Curve,
  factors : Array[Expr],
  pt? : Point? = None,
) -> Curve raise GeometryError {
  if factors.length() != self.functions_.length() {
    raise GeometryError::ValueError(
      "curve scale factors must match ambient dimension",
    )
  }
  let origin = match pt {
    Some(value) => value.with_dim(self.functions_.length())
    None => point_origin(self.functions_.length())
  }
  let out : Array[Expr] = []
  for i in 0..<self.functions_.length() {
    out.push(
      geo_simplify(
        origin.coords_[i] +
        (self.functions_[i] - origin.coords_[i]) * factors[i],
      ),
    )
  }
  curve(out, self.parameter_, self.start_, self.end_)
}

///|
pub fn Curve::rotate(
  self : Curve,
  angle : Expr,
  pt? : Point? = None,
) -> Curve raise GeometryError {
  if self.functions_.length() != 2 {
    raise GeometryError::ValueError(
      "curve rotation is only implemented for planar curves",
    )
  }
  let pivot = match pt {
    Some(value) => value.with_dim(2)
    None => point_origin(2)
  }
  let coords = geo_rotate_coords_2d(self.functions_, angle, pivot.coords_)
  curve(coords, self.parameter_, self.start_, self.end_)
}

///|
pub fn Curve::length(self : Curve) -> Expr {
  let integrand_terms : Array[Expr] = []
  for expr in self.functions_ {
    integrand_terms.push(@symcalculus.diff(expr, self.parameter_) ^ geo_int(2))
  }
  @symcore.function("Integral", [
    @symelem.sqrt(
      integrand_terms.fold(init=int(0), fn(acc, item) {
        geo_simplify(acc + item)
      }),
    ),
    self.parameter_,
    self.start_,
    self.end_,
  ])
}
