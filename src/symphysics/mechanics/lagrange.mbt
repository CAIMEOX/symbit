///|
/// Lagrange's equations for unconstrained and holonomically constrained
/// systems, aligned with the high-value surface of
/// `sympy.physics.mechanics.lagrange`.

///|
pub struct LagrangesMethod {
  lagrangian_ : @symcore.Expr
  coordinates_ : Array[@symcore.Expr]
  frame_ : @symvector.ReferenceFrame?
  bodies_ : Array[BodyLike]
  forcelist_ : Array[Load]
  hol_coneqs_ : Array[@symcore.Expr]
  lam_vec_ : Array[@symcore.Expr]
  mut eom_ : Array[@symcore.Expr]
  mut mass_matrix_ : @symphysics.ExplicitMatrix
  mut forcing_ : @symphysics.ExplicitMatrix
  mut full_mass_matrix_ : @symphysics.ExplicitMatrix
  mut full_forcing_ : @symphysics.ExplicitMatrix
} derive(Eq)

///|
fn lagrange_qdots(coords : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  coords.map(fn(q) { @symcalculus.diff(q, @symvector.dynamicsymbols_t) })
}

///|
fn lagrange_qddots(coords : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  coords.map(fn(q) {
    @symcalculus.diff(
      @symcalculus.diff(q, @symvector.dynamicsymbols_t),
      @symvector.dynamicsymbols_t,
    )
  })
}

///|
fn lagrange_lambda_symbols(count : Int) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for i in 0..<count {
    out.push(@symcore.symbol("lam" + (i + 1).to_string()))
  }
  out
}

///|
fn lagrange_default_frame(
  frame : @symvector.ReferenceFrame?,
  bodies : Array[BodyLike],
  loads : Array[Load],
) -> @symvector.ReferenceFrame raise @symphysics.PhysicsError {
  match frame {
    Some(value) => value
    None => {
      for body in bodies {
        match body.frame() {
          Some(found) => return found
          None => ()
        }
      }
      for load in loads {
        match load {
          Load::TorqueLoad(value) => return value.frame
          _ => ()
        }
      }
      raise @symphysics.PhysicsError::ValueError(
        "LagrangesMethod requires a reference frame when no body frame is available",
      )
    }
  }
}

///|
fn lagrange_generalized_forces(
  frame : @symvector.ReferenceFrame,
  coordinates : Array[@symcore.Expr],
  forcelist : Array[Load],
) -> Array[@symcore.Expr] raise @symvector.VectorError {
  let qdots = lagrange_qdots(coordinates)
  let out : Array[@symcore.Expr] = []
  for qd in qdots {
    let mut total = @symcore.int(0)
    for load in forcelist {
      match load {
        Load::ForceLoad(value) =>
          total = mech_simplify_expr(
            total +
            (try! value.point.partial_velocity(frame, qd).dot(value.force)),
          )
        Load::TorqueLoad(value) => {
          let partials = try! value.frame.partial_velocity(frame, [qd])
          total = mech_simplify_expr(
            total + (try! partials[0].dot(value.torque)),
          )
        }
      }
    }
    out.push(total)
  }
  out
}

///|
fn lagrange_dynamic_equations(
  lagrangian : @symcore.Expr,
  coordinates : Array[@symcore.Expr],
  loads : Array[@symcore.Expr],
  constraints : Array[@symcore.Expr],
  lambdas : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let qdots = lagrange_qdots(coordinates)
  let out : Array[@symcore.Expr] = []
  for i in 0..<coordinates.length() {
    let q = coordinates[i]
    let qd = qdots[i]
    let mut expr = mech_simplify_expr(
      @symcalculus.diff(
        @symcalculus.diff(lagrangian, qd),
        @symvector.dynamicsymbols_t,
      ) -
      @symcalculus.diff(lagrangian, q) -
      loads[i],
    )
    for j in 0..<constraints.length() {
      expr = mech_simplify_expr(
        expr + lambdas[j] * @symcalculus.diff(constraints[j], q),
      )
    }
    out.push(expr)
  }
  out
}

///|
fn lagrange_constraint_acceleration_equations(
  constraints : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  constraints.map(fn(expr) {
    mech_simplify_expr(
      @symcalculus.diff(
        @symcalculus.diff(expr, @symvector.dynamicsymbols_t),
        @symvector.dynamicsymbols_t,
      ),
    )
  })
}

///|
fn lagrange_constraint_velocity_equations(
  constraints : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  constraints.map(fn(expr) {
    mech_simplify_expr(@symcalculus.diff(expr, @symvector.dynamicsymbols_t))
  })
}

///|
pub fn lagranges_method(
  lagrangian : @symcore.Expr,
  coordinates : Array[@symcore.Expr],
  bodies? : Array[BodyLike] = [],
  forcelist? : Array[Load] = [],
  frame? : @symvector.ReferenceFrame? = None,
  hol_coneqs? : Array[@symcore.Expr] = [],
) -> LagrangesMethod raise @symphysics.PhysicsError {
  try! validate_coordinates(coordinates~, is_dynamicsymbols=true)
  let chosen_frame = match
    (try? lagrange_default_frame(frame, bodies, forcelist)) {
    Ok(value) => Some(value)
    Err(_) => None
  }
  let lambda_syms = lagrange_lambda_symbols(hol_coneqs.length())
  LagrangesMethod::{
    lagrangian_: lagrangian,
    coordinates_: coordinates.copy(),
    frame_: chosen_frame,
    bodies_: bodies.copy(),
    forcelist_: forcelist.copy(),
    hol_coneqs_: hol_coneqs.copy(),
    lam_vec_: lambda_syms,
    eom_: [],
    mass_matrix_: mechanics_zero_column(0),
    forcing_: mechanics_zero_column(0),
    full_mass_matrix_: mechanics_zero_column(0),
    full_forcing_: mechanics_zero_column(0),
  }
}

///|
pub fn LagrangesMethod::coordinates(
  self : LagrangesMethod,
) -> Array[@symcore.Expr] {
  self.coordinates_.copy()
}

///|
pub fn LagrangesMethod::q(self : LagrangesMethod) -> Array[@symcore.Expr] {
  self.coordinates()
}

///|
pub fn LagrangesMethod::u(self : LagrangesMethod) -> Array[@symcore.Expr] {
  lagrange_qdots(self.coordinates_)
}

///|
pub fn LagrangesMethod::bodies(self : LagrangesMethod) -> Array[BodyLike] {
  self.bodies_.copy()
}

///|
pub fn LagrangesMethod::forcelist(self : LagrangesMethod) -> Array[Load] {
  self.forcelist_.copy()
}

///|
pub fn LagrangesMethod::lam_vec(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix {
  mechanics_matrix_column(self.lam_vec_)
}

///|
pub fn LagrangesMethod::eom(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix {
  mechanics_matrix_column(self.eom_)
}

///|
pub fn LagrangesMethod::mass_matrix(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix {
  self.mass_matrix_
}

///|
pub fn LagrangesMethod::forcing(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix {
  self.forcing_
}

///|
pub fn LagrangesMethod::mass_matrix_full(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix {
  self.full_mass_matrix_
}

///|
pub fn LagrangesMethod::forcing_full(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix {
  self.full_forcing_
}

///|
pub fn LagrangesMethod::form_lagranges_equations(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix raise {
  let frame = lagrange_default_frame(self.frame_, self.bodies_, self.forcelist_)
  let generalized = try! lagrange_generalized_forces(
    frame,
    self.coordinates_,
    self.forcelist_,
  )
  let dynamics = lagrange_dynamic_equations(
    self.lagrangian_,
    self.coordinates_,
    generalized,
    self.hol_coneqs_,
    self.lam_vec_,
  )
  let qddots = lagrange_qddots(self.coordinates_)
  let unknowns = qddots + self.lam_vec_
  self.eom_ = dynamics
  self.mass_matrix_ = mechanics_matrix_jacobian(dynamics, unknowns)
  self.forcing_ = mechanics_matrix_column(
    mechanics_matrix_negative_residual(dynamics, unknowns),
  )

  let full_eqs = dynamics +
    lagrange_constraint_acceleration_equations(self.hol_coneqs_)
  let full_mass = mechanics_matrix_jacobian(full_eqs, unknowns)
  let full_forcing = mechanics_matrix_column(
    mechanics_matrix_negative_residual(full_eqs, unknowns),
  )
  self.full_mass_matrix_ = full_mass
  self.full_forcing_ = full_forcing
  self.eom()
}

///|
pub fn LagrangesMethod::rhs(
  self : LagrangesMethod,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  if self.eom_.is_empty() {
    ignore(try! self.form_lagranges_equations())
  }
  let qdots = lagrange_qdots(self.coordinates_)
  let rhs_terms = mechanics_linear_solve(
    self.full_mass_matrix_,
    mechanics_matrix_entries(self.full_forcing_).map(fn(row) { row[0] }),
  )
  let qdd_rhs : Array[@symcore.Expr] = []
  for expr in rhs_terms[:self.coordinates_.length()] {
    qdd_rhs.push(expr)
  }
  mechanics_matrix_column(qdots + qdd_rhs)
}

///|
pub fn LagrangesMethod::solve_multipliers(
  self : LagrangesMethod,
  op_point? : Array[Substitution] = [],
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  if self.eom_.is_empty() {
    ignore(try! self.form_lagranges_equations())
  }
  if self.lam_vec_.is_empty() {
    return mechanics_zero_column(0)
  }
  let solved = mechanics_linear_solve(
    self.full_mass_matrix_,
    mechanics_matrix_entries(self.full_forcing_).map(fn(row) { row[0] }),
  )
  let start = self.coordinates_.length()
  let out : Array[@symcore.Expr] = []
  for expr in solved[start:] {
    out.push(msubs_expr(expr, op_point))
  }
  mechanics_matrix_column(out)
}

///|
pub fn LagrangesMethod::linearizer(
  self : LagrangesMethod,
) -> Linearizer raise @symphysics.PhysicsError {
  let rhs = try! self.rhs()
  let rhs_terms = mechanics_matrix_entries(rhs).map(fn(row) { row[0] })
  let qdots = lagrange_qdots(self.coordinates_)
  let qddots = lagrange_qddots(self.coordinates_)
  let velocity_constraints = lagrange_constraint_velocity_equations(
    self.hol_coneqs_,
  )
  let inputs = mechanics_dynamic_inputs(
    rhs_terms,
    self.coordinates_ + qdots + qddots + self.lam_vec_,
  )
  let mut implicit_mass : @symphysics.ExplicitMatrix? = None
  let mut implicit_forcing : @symphysics.ExplicitMatrix? = None
  if self.hol_coneqs_.is_empty() && self.lam_vec_.is_empty() {
    let top_rows : Array[Array[@symcore.Expr]] = []
    for i in 0..<self.coordinates_.length() {
      let row = Array::make(self.coordinates_.length() * 2, @symcore.int(0))
      row[i] = @symcore.int(1)
      top_rows.push(row)
    }
    let lower_rows = mechanics_matrix_entries(self.mass_matrix_).map(fn(row) {
      Array::make(self.coordinates_.length(), @symcore.int(0)) + row
    })
    implicit_mass = Some(
      try! @symphysics.explicit_matrix_from_rows(top_rows + lower_rows),
    )
    implicit_forcing = Some(
      mechanics_matrix_column(
        qdots + mechanics_matrix_entries(self.forcing_).map(fn(row) { row[0] }),
      ),
    )
  }
  linearizer_with_metadata(
    self.coordinates_ + qdots,
    rhs_terms,
    inputs~,
    q=self.coordinates_,
    u=qdots,
    q_i=self.coordinates_,
    u_i=qdots,
    r=inputs,
    lams=self.lam_vec_,
    f_0=mechanics_matrix_column(qdots),
    f_1=mechanics_matrix_column(
      qdots.map(fn(qd) { mech_simplify_expr(@symcore.int(-1) * qd) }),
    ),
    f_2=try! self.mass_matrix_.mul(
      mechanics_matrix_column(qddots + self.lam_vec_),
    ),
    f_3=self.forcing_.neg(),
    f_c=mechanics_matrix_column(self.hol_coneqs_),
    f_v=mechanics_matrix_column(velocity_constraints),
    f_a=mechanics_matrix_column(
      lagrange_constraint_acceleration_equations(self.hol_coneqs_),
    ),
    implicit_mass~,
    implicit_forcing~,
    perm_mat=Some(mechanics_identity(self.coordinates_.length() * 2)),
  )
}

///|
pub fn LagrangesMethod::to_linearizer(
  self : LagrangesMethod,
) -> Linearizer raise @symphysics.PhysicsError {
  self.linearizer()
}

///|
pub fn LagrangesMethod::loads(self : LagrangesMethod) -> Array[Load] {
  self.forcelist()
}

///|
pub fn LagrangesMethod::linearize(
  self : LagrangesMethod,
  op_point? : Array[Substitution] = [],
  a_and_b? : Bool = false,
  simplify? : Bool = false,
) -> (@symphysics.ExplicitMatrix, @symphysics.ExplicitMatrix) raise @symphysics.PhysicsError {
  (try! self.linearizer()).linearize(op_point~, a_and_b~, simplify~)
}
