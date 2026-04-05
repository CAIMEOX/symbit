///|
pub fn vector_zero_expr() -> VectorZero {
  { value_: vector_zero() }
}

///|
pub fn vector_mul_expr(
  measure_number : @symcore.Expr,
  base_vector : BaseVector,
) -> VectorMul {
  {
    measure_number_: measure_number,
    base_vector_: base_vector,
    value_: base_vector.scale(measure_number),
  }
}

///|
pub fn vector_add_expr(terms : Array[Vector]) -> VectorAdd {
  let mut value = vector_zero()
  for term in terms {
    value = value + term
  }
  { terms_: terms, value_: value }
}

///|
pub fn cross_unevaluated(lhs : Vector, rhs : Vector) -> Cross {
  if lhs.to_string() <= rhs.to_string() {
    { lhs_: lhs, rhs_: rhs, sign_: 1 }
  } else {
    { lhs_: rhs, rhs_: lhs, sign_: -1 }
  }
}

///|
pub fn dot_unevaluated(lhs : Vector, rhs : Vector) -> Dot {
  if lhs.to_string() <= rhs.to_string() {
    { lhs_: lhs, rhs_: rhs }
  } else {
    { lhs_: rhs, rhs_: lhs }
  }
}

///|
pub fn dyadic_zero_expr() -> DyadicZero {
  { value_: dyadic_zero() }
}

///|
pub fn dyadic_mul_expr(
  measure_number : @symcore.Expr,
  base_dyadic : BaseDyadic,
) -> DyadicMul {
  {
    measure_number_: measure_number,
    base_dyadic_: base_dyadic,
    value_: base_dyadic.to_dyadic().scale(measure_number),
  }
}

///|
pub fn dyadic_add_expr(terms : Array[Dyadic]) -> DyadicAdd {
  let mut value = dyadic_zero()
  for term in terms {
    value = value + term
  }
  { terms_: terms, value_: value }
}

///|
pub fn VectorZero::doit(self : VectorZero) -> Vector {
  self.value_
}

///|
pub fn VectorMul::base_vector(self : VectorMul) -> BaseVector {
  self.base_vector_
}

///|
pub fn VectorMul::measure_number(self : VectorMul) -> @symcore.Expr {
  self.measure_number_
}

///|
pub fn VectorMul::doit(self : VectorMul) -> Vector {
  self.value_
}

///|
pub fn VectorAdd::doit(self : VectorAdd) -> Vector {
  self.value_
}

///|
pub fn DyadicZero::doit(self : DyadicZero) -> Dyadic {
  self.value_
}

///|
pub fn DyadicMul::base_dyadic(self : DyadicMul) -> BaseDyadic {
  self.base_dyadic_
}

///|
pub fn DyadicMul::measure_number(self : DyadicMul) -> @symcore.Expr {
  self.measure_number_
}

///|
pub fn DyadicMul::doit(self : DyadicMul) -> Dyadic {
  self.value_
}

///|
pub fn DyadicAdd::doit(self : DyadicAdd) -> Dyadic {
  self.value_
}

///|
pub fn Cross::doit(self : Cross) -> Vector raise @rawvec.VectorError {
  let value = cross(self.lhs_, self.rhs_) catch { err => raise err }
  if self.sign_ < 0 {
    value.neg()
  } else {
    value
  }
}

///|
pub fn Dot::doit(self : Dot) -> @symcore.Expr raise @rawvec.VectorError {
  dot(self.lhs_, self.rhs_) catch {
    err => raise err
  }
}
