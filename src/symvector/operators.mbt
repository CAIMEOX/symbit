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
pub fn laplacian_unevaluated(field : ScalarOrVector) -> Laplacian {
  { field_: field }
}

///|
pub fn Gradient::doit(
  self : Gradient,
) -> GradientValue raise @rawvec.VectorError {
  match self.field_ {
    ScalarExpr(expr) => VectorValue(gradient(expr))
    VectorExpr(vect) =>
      DyadicValue(gradient_vector(vect) catch { err => raise err })
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

///|
pub fn Laplacian::doit(
  self : Laplacian,
) -> ScalarOrVector raise @rawvec.VectorError {
  laplacian(self.field_)
}
