///|
pub let delop : Del = Default::default()

///|
pub fn Del::gradient(
  self : Del,
  scalar_field : @symcore.Expr,
  doit? : Bool = false,
) -> Vector {
  ignore(self)
  gradient(scalar_field, doit~)
}

///|
pub fn Del::call(
  self : Del,
  scalar_field : @symcore.Expr,
  doit? : Bool = false,
) -> Vector {
  self.gradient(scalar_field, doit~)
}

///|
pub fn Del::dot(
  self : Del,
  vect : Vector,
  doit? : Bool = false,
) -> @symcore.Expr raise @rawvec.VectorError {
  ignore(self)
  divergence(vect, doit~)
}

///|
pub fn Del::cross(
  self : Del,
  vect : Vector,
  doit? : Bool = false,
) -> Vector raise @rawvec.VectorError {
  ignore(self)
  curl(vect, doit~)
}
