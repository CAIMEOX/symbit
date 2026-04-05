///|
fn deriv_step(
  expr : @symcore.Expr,
  wrt : @symcore.Expr,
  doit : Bool,
) -> @symcore.Expr {
  if doit {
    @symcalculus.diff(expr, wrt)
  } else {
    @symcore.derivative(expr, wrt)
  }
}

///|
fn expr_div(num : @symcore.Expr, den : @symcore.Expr) -> @symcore.Expr {
  num * (den ^ @symcore.int(-1))
}

///|
fn scale_factors(system : CoordSys3D) -> Array[@symcore.Expr] {
  system.lame_coefficients()
}

///|
fn scalar_coords(system : CoordSys3D) -> Array[@symcore.Expr] {
  system.base_scalars().map(fn(item) { item.expr() })
}

///|
fn vector_components_in_system(
  field : Vector,
  system : CoordSys3D,
) -> Array[@symcore.Expr] raise @rawvec.VectorError {
  let expressed = field.express(system, variables=true) catch {
    err => raise err
  }
  expressed.raw_.components_in(system.frame_) catch {
    err => raise err
  }
}

///|
fn left_contract_matrix(
  direction : Vector,
  matrix : @symphysics.ExplicitMatrix,
  system : CoordSys3D,
) -> Vector raise @rawvec.VectorError {
  let direction_components = (direction.to_matrix(system) catch {
    err => raise err
  }).rows_copy()
  let rows = matrix.rows_copy()
  let components : Array[@symcore.Expr] = []
  for j in 0..<3 {
    let mut acc = @symcore.int(0)
    for i in 0..<3 {
      acc = acc + direction_components[i][0] * rows[i][j]
    }
    components.push(acc)
  }
  vector_from_terms([
    (components[0], system.i()),
    (components[1], system.j()),
    (components[2], system.k()),
  ])
}

///|
fn christoffel_symbol_2nd_kind(
  h : Array[@symcore.Expr],
  q : Array[@symcore.Expr],
  i : Int,
  j : Int,
  k : Int,
  doit : Bool,
) -> @symcore.Expr {
  if i == j && i == k {
    return expr_div(deriv_step(h[i], q[i], doit), h[i])
  }
  if i == k && i != j {
    return expr_div(deriv_step(h[i], q[j], doit), h[i])
  }
  if j == k && i != j {
    return expr_div(deriv_step(h[j], q[i], doit), h[j])
  }
  if i == j && i != k {
    return expr_div(
      @symcore.int(-1) * deriv_step(h[i], q[k], doit) * h[i],
      h[k] ^ @symcore.int(2),
    )
  }
  @symcore.int(0)
}

///|
pub fn gradient(field : @symcore.Expr, doit? : Bool = true) -> Vector {
  match coord_systems_in_scalar_expr(field) {
    [] => vector_zero()
    systems => {
      let system = systems[0]
      let h = scale_factors(system)
      let q = scalar_coords(system)
      vector_from_terms([
        (expr_div(deriv_step(field, q[0], doit), h[0]), system.i()),
        (expr_div(deriv_step(field, q[1], doit), h[1]), system.j()),
        (expr_div(deriv_step(field, q[2], doit), h[2]), system.k()),
      ])
    }
  }
}

///|
pub fn gradient_vector(
  field : Vector,
  doit? : Bool = true,
) -> Dyadic raise @rawvec.VectorError {
  match primary_coord_system_in_vector(field) {
    None => dyadic_zero()
    Some(system) => {
      let components = vector_components_in_system(field, system) catch {
        err => raise err
      }
      let q = scalar_coords(system)
      let h = scale_factors(system)
      let rows : Array[Array[@symcore.Expr]] = []
      for i in 0..<3 {
        let row : Array[@symcore.Expr] = []
        for j in 0..<3 {
          let mut component = expr_div(
              deriv_step(components[j], q[i], doit),
              h[i],
            ) -
            expr_div(components[j], h[i] * h[j]) * deriv_step(h[j], q[i], doit)
          for k in 0..<3 {
            let gamma = christoffel_symbol_2nd_kind(h, q, i, k, j, doit)
            component = component +
              expr_div(h[j], h[i] * h[k]) * components[k] * gamma
          }
          row.push(component)
        }
        rows.push(row)
      }
      matrix_to_dyadic(
        @symphysics.explicit_matrix_from_rows(rows) catch {
          _ => abort("gradient_vector")
        },
        system,
      )
    }
  }
}

///|
pub fn divergence(
  field : Vector,
  doit? : Bool = true,
) -> @symcore.Expr raise @rawvec.VectorError {
  match primary_coord_system_in_vector(field) {
    Some(system) => {
      let components = vector_components_in_system(field, system) catch {
        err => raise err
      }
      let h = scale_factors(system)
      let q = scalar_coords(system)
      let numer = deriv_step(components[0] * h[1] * h[2], q[0], doit) +
        deriv_step(components[1] * h[2] * h[0], q[1], doit) +
        deriv_step(components[2] * h[0] * h[1], q[2], doit)
      let result = expr_div(numer, h[0] * h[1] * h[2])
      if doit {
        @symsimplify.simplify(result)
      } else {
        result
      }
    }
    None => @symcore.int(0)
  }
}

///|
pub fn curl(
  field : Vector,
  doit? : Bool = true,
) -> Vector raise @rawvec.VectorError {
  match primary_coord_system_in_vector(field) {
    Some(system) => {
      let components = vector_components_in_system(field, system) catch {
        err => raise err
      }
      let h = scale_factors(system)
      let q = scalar_coords(system)
      vector_from_terms([
        (
          expr_div(
            deriv_step(components[2] * h[2], q[1], doit) -
            deriv_step(components[1] * h[1], q[2], doit),
            h[1] * h[2],
          ),
          system.i(),
        ),
        (
          expr_div(
            deriv_step(components[0] * h[0], q[2], doit) -
            deriv_step(components[2] * h[2], q[0], doit),
            h[0] * h[2],
          ),
          system.j(),
        ),
        (
          expr_div(
            deriv_step(components[1] * h[1], q[0], doit) -
            deriv_step(components[0] * h[0], q[1], doit),
            h[1] * h[0],
          ),
          system.k(),
        ),
      ])
    }
    None => vector_zero()
  }
}

///|
pub fn is_conservative(field : Vector) -> Bool raise @rawvec.VectorError {
  (curl(field) catch { err => raise err }).is_zero()
}

///|
pub fn is_solenoidal(field : Vector) -> Bool raise @rawvec.VectorError {
  @symcore.is_zero(divergence(field) catch { err => raise err })
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
          let grad = gradient_vector(vect) catch { err => raise err }
          let result = left_contract_matrix(
            direction,
            grad.to_matrix(system) catch {
              err => raise err
            },
            system,
          ) catch {
            err => raise err
          }
          ScalarOrVector::VectorExpr(result)
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
