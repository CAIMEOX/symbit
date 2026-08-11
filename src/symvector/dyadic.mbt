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
pub impl Add for Dyadic with fn add(self, other : Dyadic) -> Dyadic {
  { raw_: self.raw_ + other.raw_ }
}

///|
pub impl Sub for Dyadic with fn sub(self, other : Dyadic) -> Dyadic {
  { raw_: self.raw_ - other.raw_ }
}

///|
pub fn Dyadic::is_zero(self : Dyadic) -> Bool {
  self.raw_.args.is_empty()
}

///|
pub fn Dyadic::components(self : Dyadic) -> Map[BaseDyadic, @symcore.Expr] {
  let out : Map[BaseDyadic, @symcore.Expr] = Map([])
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
fn dyadic_map_components(
  dyadic : Dyadic,
  f : (@symcore.Expr) -> @symcore.Expr,
) -> Dyadic {
  let components = dyadic.components()
  if components.is_empty() {
    return dyadic_zero()
  }
  let basis = components.keys().to_array()
  basis.sort_by(compare_base_dyadic)
  let mut out = dyadic_zero()
  for item in basis {
    let coeff = f(components[item])
    if !@symcore.is_zero(coeff) {
      out = out + item.to_dyadic().scale(coeff)
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
fn dyadic_matrix_in_systems(
  dyadic : Dyadic,
  system : CoordSys3D,
  right_system : CoordSys3D,
  variables : Bool,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  let accum = [
    [@symcore.int(0), @symcore.int(0), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(0)],
  ]
  let components = dyadic.components()
  let basis = components.keys().to_array()
  basis.sort()
  for item in basis {
    let left_rows = (vector_matrix_in_system(
      item.left_.to_vector(),
      system,
      variables,
    ) catch {
      err => raise err
    }).rows_copy()
    let right_rows = (vector_matrix_in_system(
      item.right_.to_vector(),
      right_system,
      variables,
    ) catch {
      err => raise err
    }).rows_copy()
    let coeff = components[item]
    for i in 0..<3 {
      for j in 0..<3 {
        accum[i][j] = accum[i][j] + coeff * left_rows[i][0] * right_rows[j][0]
      }
    }
  }
  matrix_simplify_entries(
    @symphysics.explicit_matrix_from_rows(accum) catch {
      _ => abort("dyadic_matrix_in_systems")
    },
  )
}

///|
fn dyadic_from_matrix_in_systems(
  matrix : @symphysics.ExplicitMatrix,
  system : CoordSys3D,
  right_system : CoordSys3D,
) -> Dyadic raise @rawvec.VectorError {
  let rows = matrix.rows_copy()
  let left_basis = system.base_vectors()
  let right_basis = right_system.base_vectors()
  let mut out = dyadic_zero()
  for i in 0..<3 {
    for j in 0..<3 {
      let coeff = rows[i][j]
      if !@symcore.is_zero(coeff) {
        out = out +
          (left_basis[i].outer(right_basis[j]) catch { err => raise err }).scale(
            coeff,
          )
      }
    }
  }
  out
}

///|
pub fn Dyadic::express(
  self : Dyadic,
  system : CoordSys3D,
  system2? : CoordSys3D? = None,
  variables? : Bool = false,
) -> Dyadic raise @rawvec.VectorError {
  let right_system = system2.unwrap_or(system)
  dyadic_from_matrix_in_systems(
    dyadic_matrix_in_systems(self, system, right_system, variables) catch {
      err => raise err
    },
    system,
    right_system,
  ) catch {
    err => raise err
  }
}

///|
pub fn Dyadic::to_matrix(
  self : Dyadic,
  system : CoordSys3D,
  system2? : CoordSys3D? = None,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  let right_system = system2.unwrap_or(system)
  dyadic_matrix_in_systems(self, system, right_system, false) catch {
    err => raise err
  }
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
  dyadic_map_components(self, coeff => @symsimplify.simplify(coeff))
}

///|
pub fn Dyadic::trigsimp(self : Dyadic) -> Dyadic {
  dyadic_map_components(self, coeff => {
    @symsimplify.factor_terms(@symsimplify.trigsimp(coeff))
  })
}

///|
pub fn Dyadic::factor(self : Dyadic) -> Dyadic {
  dyadic_map_components(self, coeff => @symsimplify.factor_terms(coeff))
}

///|
pub fn Dyadic::evalf(self : Dyadic, prec? : Int = 53) -> Dyadic {
  dyadic_map_components(self, coeff => @symcore.evalf(coeff, prec~))
}

///|
pub fn Dyadic::doit(self : Dyadic) -> Dyadic {
  { raw_: self.raw_.doit() }
}
