///|
pub fn dyadic_zero() -> Dyadic {
  { raw_: @rawvec.dyadic_zero() }
}

///|
pub fn base_dyadic(left : BaseVector, right : BaseVector) -> BaseDyadic {
  { left_: left, right_: right }
}

///|
pub fn BaseDyadic::left(self : BaseDyadic) -> BaseVector {
  self.left_
}

///|
pub fn BaseDyadic::right(self : BaseDyadic) -> BaseVector {
  self.right_
}

///|
pub fn BaseDyadic::to_dyadic(self : BaseDyadic) -> Dyadic {
  {
    raw_: @rawvec.dyadic_basis(
      self.left_.system_.frame_,
      self.left_.axis_,
      self.right_.system_.frame_,
      self.right_.axis_,
    ),
  }
}

///|
pub impl Add for Dyadic with add(self, other : Dyadic) -> Dyadic {
  { raw_: self.raw_ + other.raw_ }
}

///|
pub impl Sub for Dyadic with sub(self, other : Dyadic) -> Dyadic {
  { raw_: self.raw_ - other.raw_ }
}

///|
pub fn Dyadic::is_zero(self : Dyadic) -> Bool {
  self.raw_.args.is_empty()
}

///|
pub fn Dyadic::components(self : Dyadic) -> Map[BaseDyadic, @symcore.Expr] {
  let out : Map[BaseDyadic, @symcore.Expr] = {}
  for item in self.raw_.args {
    let basis = base_dyadic(
      { axis_: item.2, system_: coord_system_from_frame(item.1) },
      { axis_: item.4, system_: coord_system_from_frame(item.3) },
    )
    match out.get(basis) {
      Some(prev) => out[basis] = prev + item.0
      None => out[basis] = item.0
    }
  }
  out
}

///|
pub fn Dyadic::scale(self : Dyadic, scalar : @symcore.Expr) -> Dyadic {
  { raw_: self.raw_.scale(scalar) }
}

///|
pub fn Dyadic::neg(self : Dyadic) -> Dyadic {
  self.scale(@symcore.int(-1))
}

///|
pub fn Dyadic::dot_vector(
  self : Dyadic,
  other : Vector,
) -> Vector raise @rawvec.VectorError {
  { raw_: self.raw_.dot_vector(other.raw_) }
}

///|
pub fn Dyadic::dot_dyadic(
  self : Dyadic,
  other : Dyadic,
) -> Dyadic raise @rawvec.VectorError {
  { raw_: self.raw_.dot_dyadic(other.raw_) }
}

///|
pub fn Dyadic::cross(
  self : Dyadic,
  other : Vector,
) -> Dyadic raise @rawvec.VectorError {
  { raw_: self.raw_.cross_vector(other.raw_) }
}

///|
pub fn Dyadic::express(
  self : Dyadic,
  system : CoordSys3D,
  system2? : CoordSys3D? = None,
  variables? : Bool = false,
) -> Dyadic raise @rawvec.VectorError {
  let right_system = system2.unwrap_or(system)
  {
    raw_: self.raw_.express(
      system.frame_,
      frame2=Some(right_system.frame_),
      variables~,
    ),
  }
}

///|
pub fn Dyadic::to_matrix(
  self : Dyadic,
  system : CoordSys3D,
  system2? : CoordSys3D? = None,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  let right_system = system2.unwrap_or(system)
  self.raw_.to_matrix(system.frame_, frame2=Some(right_system.frame_))
}

///|
pub fn Dyadic::truediv(
  self : Dyadic,
  scalar : @symcore.Expr,
) -> Dyadic raise @rawvec.VectorError {
  { raw_: self.raw_.truediv(scalar) }
}

///|
pub fn Dyadic::simplify(self : Dyadic) -> Dyadic {
  { raw_: self.raw_.simplify() }
}

///|
pub fn Dyadic::doit(self : Dyadic) -> Dyadic {
  { raw_: self.raw_.doit() }
}
