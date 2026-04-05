///|
pub fn gradient(field : @symcore.Expr) -> Vector {
  match coord_systems_in_scalar_expr(field) {
    [] => vector_zero()
    systems => { raw_: @rawvec.gradient(field, systems[0].frame_) }
  }
}

///|
pub fn divergence(field : Vector) -> @symcore.Expr raise @rawvec.VectorError {
  match primary_coord_system_in_vector(field) {
    Some(system) => @rawvec.divergence(field.raw_, system.frame_)
    None => @symcore.int(0)
  }
}

///|
pub fn curl(field : Vector) -> Vector raise @rawvec.VectorError {
  match primary_coord_system_in_vector(field) {
    Some(system) => { raw_: @rawvec.curl(field.raw_, system.frame_) }
    None => vector_zero()
  }
}

///|
pub fn is_conservative(field : Vector) -> Bool raise @rawvec.VectorError {
  @rawvec.is_conservative(field.raw_)
}

///|
pub fn is_solenoidal(field : Vector) -> Bool raise @rawvec.VectorError {
  @rawvec.is_solenoidal(field.raw_)
}

///|
pub fn directional_derivative(
  field : ScalarOrVector,
  direction : Vector,
) -> ScalarOrVector raise @rawvec.VectorError {
  match field {
    ScalarOrVector::ScalarExpr(expr) =>
      if coord_systems_in_scalar_expr(expr).is_empty() {
        ScalarOrVector::ScalarExpr(@symcore.int(0))
      } else {
        ScalarOrVector::ScalarExpr(
          direction.dot(gradient(expr)) catch {
            err => raise err
          },
        )
      }
    ScalarOrVector::VectorExpr(vect) =>
      match primary_coord_system_in_vector(vect) {
        Some(system) => {
          let expressed = vect.express(system, variables=true) catch {
            err => raise err
          }
          let comps = expressed.raw_.components_in(system.frame_) catch {
            err => raise err
          }
          let dx = direction.dot({
            raw_: @rawvec.gradient(comps[0], system.frame_),
          }) catch {
            err => raise err
          }
          let dy = direction.dot({
            raw_: @rawvec.gradient(comps[1], system.frame_),
          }) catch {
            err => raise err
          }
          let dz = direction.dot({
            raw_: @rawvec.gradient(comps[2], system.frame_),
          }) catch {
            err => raise err
          }
          ScalarOrVector::VectorExpr(
            vector_from_terms([
              (dx, system.i()),
              (dy, system.j()),
              (dz, system.k()),
            ]),
          )
        }
        None => ScalarOrVector::VectorExpr(vector_zero())
      }
  }
}

///|
pub fn laplacian(
  field : ScalarOrVector,
) -> ScalarOrVector raise @rawvec.VectorError {
  match field {
    ScalarOrVector::ScalarExpr(expr) =>
      ScalarOrVector::ScalarExpr(
        divergence(gradient(expr)) catch {
          err => raise err
        },
      )
    ScalarOrVector::VectorExpr(vect) => {
      let cc = curl(vect) catch { err => raise err }
      ScalarOrVector::VectorExpr(
        gradient(divergence(vect) catch { err => raise err }) -
        (curl(cc) catch { err => raise err }),
      )
    }
  }
}

///|
pub fn scalar_potential(
  field : Vector,
  system : CoordSys3D,
) -> @symcore.Expr raise @rawvec.VectorError {
  @rawvec.scalar_potential(field.raw_, system.frame_)
}

///|
pub fn scalar_potential_difference(
  field : ScalarOrVector,
  system : CoordSys3D,
  point1 : Point,
  point2 : Point,
) -> @symcore.Expr raise @rawvec.VectorError {
  match field {
    ScalarOrVector::ScalarExpr(expr) =>
      @rawvec.scalar_potential_difference(
        expr,
        system.frame_,
        point1.raw_,
        point2.raw_,
        system.origin_.raw_,
      )
    ScalarOrVector::VectorExpr(vect) =>
      @rawvec.scalar_potential_difference_field(
        vect.raw_,
        system.frame_,
        point1.raw_,
        point2.raw_,
        system.origin_.raw_,
      )
  }
}
