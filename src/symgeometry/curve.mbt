///|
/// Parametric curve given by coordinate functions and a parameter interval.
pub struct Curve {
  functions_ : Array[@symcore.Expr]
  parameter_ : @symcore.Expr
  start_ : @symcore.Expr
  end_ : @symcore.Expr
} derive(Eq)

///|
pub fn curve(
  functions : Array[@symcore.Expr],
  parameter : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
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
pub fn Curve::functions(self : Curve) -> Array[@symcore.Expr] {
  self.functions_[:].to_array()
}

///|
pub fn Curve::parameter(self : Curve) -> @symcore.Expr {
  self.parameter_
}

///|
pub fn Curve::limits(
  self : Curve,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) {
  (self.parameter_, self.start_, self.end_)
}

///|
pub fn Curve::arbitrary_point(
  self : Curve,
  parameter? : @symcore.Expr = @symcore.symbol("t"),
) -> Point raise GeometryError {
  let env : Map[String, @symcore.Expr] = {}
  let actual = if @symcore.compare_expr(parameter, @symcore.symbol("t")) == 0 {
    self.parameter_
  } else {
    parameter
  }
  match self.parameter_ {
    @symcore.Expr::Symbol(name) => env.set(name, actual)
    _ => ()
  }
  point(
    self.functions_.map(fn(expr) { @symcore.subst(expr, env) }),
    dim=self.functions_.length(),
  )
}

///|
pub fn Curve::translate(
  self : Curve,
  offsets : Array[@symcore.Expr],
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
  factors : Array[@symcore.Expr],
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
  let out : Array[@symcore.Expr] = []
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
  angle : @symcore.Expr,
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
  let coords = try! geo_rotate_coords_2d(self.functions_, angle, pivot.coords_)
  curve(coords, self.parameter_, self.start_, self.end_)
}

///|
pub fn Curve::length(self : Curve) -> @symcore.Expr {
  let integrand_terms : Array[@symcore.Expr] = []
  for expr in self.functions_ {
    integrand_terms.push(@symcalculus.diff(expr, self.parameter_) ^ geo_int(2))
  }
  @symcore.function("Integral", [
    @symelem.sqrt(
      integrand_terms.fold(init=geo_zero(), fn(acc, item) {
        geo_simplify(acc + item)
      }),
    ),
    self.parameter_,
    self.start_,
    self.end_,
  ])
}
