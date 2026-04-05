///|
pub fn gradient_vector(field : Vector) -> Dyadic raise @rawvec.VectorError {
  match primary_coord_system_in_vector(field) {
    None => dyadic_zero()
    Some(system) => {
      let expressed = field.express(system, variables=true) catch {
        err => raise err
      }
      let comps = expressed.raw_.components_in(system.frame_) catch {
        err => raise err
      }
      let basis = system.base_vectors()
      let mut out = dyadic_zero()
      for axis in 0..<3 {
        out = out +
          (gradient(comps[axis]).outer(basis[axis].to_vector()) catch {
            err => raise err
          })
      }
      out
    }
  }
}

///|
pub fn gradient_unevaluated(field : ScalarOrVector) -> Gradient {
  { field_: field }
}

///|
pub fn divergence_unevaluated(field : Vector) -> Divergence {
  { field_: field }
}

///|
pub fn curl_unevaluated(field : Vector) -> Curl {
  { field_: field }
}

///|
pub fn Gradient::doit(
  self : Gradient,
) -> GradientValue raise @rawvec.VectorError {
  match self.field_ {
    ScalarOrVector::ScalarExpr(expr) =>
      GradientValue::VectorValue(gradient(expr))
    ScalarOrVector::VectorExpr(vect) =>
      GradientValue::DyadicValue(
        gradient_vector(vect) catch {
          err => raise err
        },
      )
  }
}

///|
pub fn Divergence::doit(
  self : Divergence,
) -> @symcore.Expr raise @rawvec.VectorError {
  divergence(self.field_)
}

///|
pub fn Curl::doit(self : Curl) -> Vector raise @rawvec.VectorError {
  curl(self.field_)
}
