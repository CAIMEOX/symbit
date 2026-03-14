///|
/// Kane-style first-order equations for the high-value unconstrained surface of
/// `sympy.physics.mechanics.kane`.

///|
pub struct KanesMethod {
  frame_ : @symvector.ReferenceFrame
  q_ind_ : Array[@symcore.Expr]
  u_ind_ : Array[@symcore.Expr]
  kd_eqs_ : Array[@symcore.Expr]
  mut bodies_ : Array[BodyLike]
  mut loads_ : Array[Load]
  mut mass_matrix_ : @symphysics.ExplicitMatrix
  mut forcing_ : @symphysics.ExplicitMatrix
  mut full_mass_matrix_ : @symphysics.ExplicitMatrix
  mut full_forcing_ : @symphysics.ExplicitMatrix
  mut explicit_kinematics_ : Bool
} derive(Eq)

///|
fn kane_qdots(coords : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  coords.map(fn(q) { @symcalculus.diff(q, @symvector.dynamicsymbols_t) })
}

///|
fn kane_udots(speeds : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  speeds.map(fn(u) { @symcalculus.diff(u, @symvector.dynamicsymbols_t) })
}

///|
fn kane_identity_kdes(
  coords : Array[@symcore.Expr],
  speeds : Array[@symcore.Expr],
  kd_eqs : Array[@symcore.Expr],
) -> Array[Substitution] raise @symphysics.PhysicsError {
  guard coords.length() == speeds.length() && kd_eqs.length() == coords.length() else {
    raise @symphysics.PhysicsError::ValueError(
      "KanesMethod currently requires one kinematic equation per coordinate",
    )
  }
  let out : Array[Substitution] = []
  for i in 0..<coords.length() {
    let qd = @symcalculus.diff(coords[i], @symvector.dynamicsymbols_t)
    let simplified = mech_simplify_expr(kd_eqs[i])
    let merged = mech_simplify_expr(msubs_expr(simplified, [(qd, speeds[i])]))
    if !mech_expr_is_zero(merged) {
      raise @symphysics.PhysicsError::ValueError(
        "KanesMethod currently supports identity-style kinematic differential equations only",
      )
    }
    out.push((qd, speeds[i]))
  }
  out
}

///|
fn kane_generalized_forces(
  frame : @symvector.ReferenceFrame,
  speeds : Array[@symcore.Expr],
  loads : Array[Load],
) -> Array[@symcore.Expr] raise @symvector.VectorError {
  let out : Array[@symcore.Expr] = []
  for speed in speeds {
    let mut total = @symcore.int(0)
    for load in loads {
      match load {
        Load::ForceLoad(value) =>
          total = mech_simplify_expr(
            total +
            (try! value.point.partial_velocity(frame, speed).dot(value.force)),
          )
        Load::TorqueLoad(value) => {
          let partials = try! value.frame.partial_velocity(frame, [speed])
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
fn kane_kinetic_lagrangian(
  frame : @symvector.ReferenceFrame,
  q_ind : Array[@symcore.Expr],
  u_ind : Array[@symcore.Expr],
  bodies : Array[BodyLike],
) -> @symcore.Expr raise @symvector.VectorError {
  let qdots = kane_qdots(q_ind)
  let to_qdots : Array[Substitution] = []
  for i in 0..<u_ind.length() {
    to_qdots.push((u_ind[i], qdots[i]))
  }
  let kinetic = try! kinetic_energy(frame, bodies)
  msubs_expr(kinetic, to_qdots)
}

///|
pub fn kanes_method(
  frame : @symvector.ReferenceFrame,
  q_ind : Array[@symcore.Expr],
  u_ind : Array[@symcore.Expr],
  kd_eqs : Array[@symcore.Expr],
  bodies? : Array[BodyLike] = [],
  forcelist? : Array[Load] = [],
  explicit_kinematics? : Bool = true,
) -> KanesMethod raise @symphysics.PhysicsError {
  try! validate_coordinates(coordinates=q_ind, speeds=u_ind)
  ignore(try! kane_identity_kdes(q_ind, u_ind, kd_eqs))
  KanesMethod::{
    frame_: frame,
    q_ind_: q_ind.copy(),
    u_ind_: u_ind.copy(),
    kd_eqs_: kd_eqs.copy(),
    bodies_: bodies.copy(),
    loads_: forcelist.copy(),
    mass_matrix_: mechanics_zero_column(0),
    forcing_: mechanics_zero_column(0),
    full_mass_matrix_: mechanics_zero_column(0),
    full_forcing_: mechanics_zero_column(0),
    explicit_kinematics_: explicit_kinematics,
  }
}

///|
pub fn KanesMethod::q(self : KanesMethod) -> Array[@symcore.Expr] {
  self.q_ind_.copy()
}

///|
pub fn KanesMethod::u(self : KanesMethod) -> Array[@symcore.Expr] {
  self.u_ind_.copy()
}

///|
pub fn KanesMethod::bodies(self : KanesMethod) -> Array[BodyLike] {
  self.bodies_.copy()
}

///|
pub fn KanesMethod::loads(self : KanesMethod) -> Array[Load] {
  self.loads_.copy()
}

///|
pub fn KanesMethod::bodylist(self : KanesMethod) -> Array[BodyLike] {
  self.bodies()
}

///|
pub fn KanesMethod::forcelist(self : KanesMethod) -> Array[Load] {
  self.loads()
}

///|
pub fn KanesMethod::kd_eqs(self : KanesMethod) -> Array[@symcore.Expr] {
  self.kd_eqs_.copy()
}

///|
pub fn KanesMethod::explicit_kinematics(self : KanesMethod) -> Bool {
  self.explicit_kinematics_
}

///|
pub fn KanesMethod::set_explicit_kinematics(
  self : KanesMethod,
  value : Bool,
) -> Unit {
  self.explicit_kinematics_ = value
}

///|
pub fn KanesMethod::kindiffdict(
  self : KanesMethod,
) -> Array[Substitution] raise @symphysics.PhysicsError {
  kane_identity_kdes(self.q_ind_, self.u_ind_, self.kd_eqs_)
}

///|
pub fn KanesMethod::mass_matrix(
  self : KanesMethod,
) -> @symphysics.ExplicitMatrix {
  self.mass_matrix_
}

///|
pub fn KanesMethod::forcing(self : KanesMethod) -> @symphysics.ExplicitMatrix {
  self.forcing_
}

///|
pub fn KanesMethod::mass_matrix_kin(
  self : KanesMethod,
) -> @symphysics.ExplicitMatrix {
  mechanics_identity(self.q_ind_.length())
}

///|
pub fn KanesMethod::forcing_kin(
  self : KanesMethod,
) -> @symphysics.ExplicitMatrix {
  mechanics_matrix_column(self.u_ind_)
}

///|
pub fn KanesMethod::mass_matrix_full(
  self : KanesMethod,
) -> @symphysics.ExplicitMatrix {
  self.full_mass_matrix_
}

///|
pub fn KanesMethod::forcing_full(
  self : KanesMethod,
) -> @symphysics.ExplicitMatrix {
  self.full_forcing_
}

///|
pub fn KanesMethod::kanes_equations(
  self : KanesMethod,
  bodies : Array[BodyLike],
  loads : Array[Load],
) -> (@symphysics.ExplicitMatrix, @symphysics.ExplicitMatrix) raise {
  let kd_subs = try! self.kindiffdict()
  self.bodies_ = bodies.copy()
  self.loads_ = loads.copy()

  let lagrangian_expr = msubs_expr(
    try! lagrangian(self.frame_, bodies),
    kd_subs,
  )
  let generalized = try! kane_generalized_forces(
    self.frame_,
    self.u_ind_,
    loads,
  )
  let udots = kane_udots(self.u_ind_)
  let dynamic_eqs : Array[@symcore.Expr] = []
  for i in 0..<self.u_ind_.length() {
    let u = self.u_ind_[i]
    let q = self.q_ind_[i]
    dynamic_eqs.push(
      mech_simplify_expr(
        @symcalculus.diff(
          @symcalculus.diff(lagrangian_expr, u),
          @symvector.dynamicsymbols_t,
        ) -
        @symcalculus.diff(lagrangian_expr, q) -
        generalized[i],
      ),
    )
  }
  self.mass_matrix_ = mechanics_matrix_jacobian(dynamic_eqs, udots)
  self.forcing_ = mechanics_matrix_column(
    mechanics_matrix_negative_residual(dynamic_eqs, udots),
  )

  let top_rows : Array[Array[@symcore.Expr]] = []
  for i in 0..<self.q_ind_.length() {
    let row = Array::make(
      self.q_ind_.length() + self.u_ind_.length(),
      @symcore.int(0),
    )
    row[i] = @symcore.int(1)
    top_rows.push(row)
  }
  let lower = mechanics_matrix_entries(self.mass_matrix_)
  let full_rows = top_rows +
    lower.map(fn(row) {
      Array::make(self.q_ind_.length(), @symcore.int(0)) + row
    })
  self.full_mass_matrix_ = try! @symphysics.explicit_matrix_from_rows(full_rows)
  self.full_forcing_ = mechanics_matrix_column(
    self.u_ind_ +
    mechanics_matrix_entries(self.forcing_).map(fn(row) { row[0] }),
  )
  (self.mass_matrix_, self.forcing_)
}

///|
pub fn KanesMethod::rhs(
  self : KanesMethod,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let solved = mechanics_linear_solve(
    self.mass_matrix_,
    mechanics_matrix_entries(self.forcing_).map(fn(row) { row[0] }),
  )
  mechanics_matrix_column(self.u_ind_ + solved)
}

///|
pub fn KanesMethod::linearizer(
  self : KanesMethod,
) -> Linearizer raise @symphysics.PhysicsError {
  let rhs = try! self.rhs()
  let rhs_terms = mechanics_matrix_entries(rhs).map(fn(row) { row[0] })
  let qdots = kane_qdots(self.q_ind_)
  let udots = kane_udots(self.u_ind_)
  let inputs = mechanics_dynamic_inputs(
    rhs_terms,
    self.q_ind_ + self.u_ind_ + qdots + udots,
  )
  let f_2 = try! self.mass_matrix_.mul(mechanics_matrix_column(udots))
  let top_rows : Array[Array[@symcore.Expr]] = []
  for i in 0..<self.q_ind_.length() {
    let row = Array::make(
      self.q_ind_.length() + self.u_ind_.length(),
      @symcore.int(0),
    )
    row[i] = @symcore.int(1)
    top_rows.push(row)
  }
  let lower_rows = mechanics_matrix_entries(self.mass_matrix_).map(fn(row) {
    Array::make(self.q_ind_.length(), @symcore.int(0)) +
    row.map(fn(item) { mech_simplify_expr(@symcore.int(-1) * item) })
  })
  let implicit_mass = try! @symphysics.explicit_matrix_from_rows(
    top_rows + lower_rows,
  )
  let implicit_forcing = mechanics_matrix_column(
    self.u_ind_ +
    mechanics_matrix_entries(self.forcing_).map(fn(row) {
      mech_simplify_expr(@symcore.int(-1) * row[0])
    }),
  )
  linearizer_with_metadata(
    self.q_ind_ + self.u_ind_,
    rhs_terms,
    inputs~,
    q=self.q_ind_,
    u=self.u_ind_,
    q_i=self.q_ind_,
    u_i=self.u_ind_,
    r=inputs,
    f_0=mechanics_matrix_column(qdots),
    f_1=mechanics_matrix_column(
      self.u_ind_.map(fn(u) { mech_simplify_expr(@symcore.int(-1) * u) }),
    ),
    f_2~,
    f_3=self.forcing_.neg(),
    implicit_mass=Some(implicit_mass),
    implicit_forcing=Some(implicit_forcing),
    perm_mat=Some(
      mechanics_identity(self.q_ind_.length() + self.u_ind_.length()),
    ),
  )
}

///|
pub fn KanesMethod::to_linearizer(
  self : KanesMethod,
) -> Linearizer raise @symphysics.PhysicsError {
  self.linearizer()
}

///|
pub fn KanesMethod::auxiliary_eqs(
  self : KanesMethod,
) -> @symphysics.ExplicitMatrix {
  mechanics_zero_column(0)
}

///|
pub fn KanesMethod::linearize(
  self : KanesMethod,
  op_point? : Array[Substitution] = [],
  a_and_b? : Bool = false,
  simplify? : Bool = false,
) -> (@symphysics.ExplicitMatrix, @symphysics.ExplicitMatrix) raise @symphysics.PhysicsError {
  (try! self.linearizer()).linearize(op_point~, a_and_b~, simplify~)
}
