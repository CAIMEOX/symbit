///|
/// Multibody system container aligned with the high-value surface of
/// `sympy.physics.mechanics.system`.

///|
pub struct System {
  frame_ : @symvector.ReferenceFrame
  fixed_point_ : @symvector.Point
  mut q_ind_ : Array[Expr]
  mut q_dep_ : Array[Expr]
  mut u_ind_ : Array[Expr]
  mut u_dep_ : Array[Expr]
  mut u_aux_ : Array[Expr]
  kdes_ : Array[Expr]
  bodies_ : Array[BodyLike]
  joints_ : Array[JointLike]
  loads_ : Array[Load]
  actuators_ : Array[ActuatorLike]
  holonomic_constraints_ : Array[Expr]
  nonholonomic_constraints_ : Array[Expr]
  mut eom_method_ : MechanicsBackend?
} derive(Eq)

///|
fn system_contains_expr(
  items : Array[Expr],
  expr : Expr,
) -> Bool {
  items.any(fn(item) { @symcore.compare_expr(item, expr) == 0 })
}

///|
fn system_append_exprs_unique(
  target : Array[Expr],
  items : Array[Expr],
) -> Unit {
  for item in items {
    if !system_contains_expr(target, item) {
      target.push(item)
    }
  }
}

///|
fn system_load_key(load : Load) -> String {
  match load {
    Load::ForceLoad(value) => value.repr()
    Load::TorqueLoad(value) => value.repr()
  }
}

///|
fn system_append_loads_unique(
  target : Array[Load],
  loads : Array[Load],
) -> Unit {
  for load in loads {
    let key = system_load_key(load)
    if !target.any(fn(existing) { system_load_key(existing) == key }) {
      target.push(load)
    }
  }
}

///|
fn system_append_bodies_unique(
  target : Array[BodyLike],
  bodies : Array[BodyLike],
) -> Unit {
  for body in bodies {
    let key = mech_bodylike_name(body)
    if !target.any(fn(existing) { mech_bodylike_name(existing) == key }) {
      target.push(body)
    }
  }
}

///|
fn system_append_joints_unique(
  target : Array[JointLike],
  joints : Array[JointLike],
) -> Unit {
  for joint in joints {
    let key = joint.name()
    if !target.any(fn(existing) { existing.name() == key }) {
      target.push(joint)
    }
  }
}

///|
fn system_append_actuators_unique(
  target : Array[ActuatorLike],
  actuators : Array[ActuatorLike],
) -> Unit {
  for actuator in actuators {
    let key = actuator.repr()
    if !target.any(fn(existing) { existing.repr() == key }) {
      target.push(actuator)
    }
  }
}

///|
pub fn system(
  frame? : @symvector.ReferenceFrame? = None,
  fixed_point? : @symvector.Point? = None,
) -> System raise @symvector.VectorError {
  let inertial_frame = frame.unwrap_or(
    @symvector.reference_frame("inertial_frame"),
  )
  let inertial_point = fixed_point.unwrap_or(
    @symvector.point("inertial_point"),
  )
  inertial_point.set_vel(inertial_frame, @symvector.vector_zero())
  System::{
    frame_: inertial_frame,
    fixed_point_: inertial_point,
    q_ind_: [],
    q_dep_: [],
    u_ind_: [],
    u_dep_: [],
    u_aux_: [],
    kdes_: [],
    bodies_: [],
    joints_: [],
    loads_: [],
    actuators_: [],
    holonomic_constraints_: [],
    nonholonomic_constraints_: [],
    eom_method_: None,
  }
}

///|
pub fn system_from_newtonian(
  body : BodyLike,
) -> System raise @symphysics.PhysicsError {
  let frame = match mech_bodylike_frame(body) {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "System.from_newtonian requires a body with a reference frame",
      )
  }
  let fixed_point = mech_bodylike_masscenter(body)
  fixed_point.set_vel(frame, @symvector.vector_zero())
  let out = System::{
    frame_: frame,
    fixed_point_: fixed_point,
    q_ind_: [],
    q_dep_: [],
    u_ind_: [],
    u_dep_: [],
    u_aux_: [],
    kdes_: [],
    bodies_: [body],
    joints_: [],
    loads_: [],
    actuators_: [],
    holonomic_constraints_: [],
    nonholonomic_constraints_: [],
    eom_method_: None,
  }
  out
}

///|
pub fn System::frame(self : System) -> @symvector.ReferenceFrame {
  self.frame_
}

///|
pub fn System::fixed_point(self : System) -> @symvector.Point {
  self.fixed_point_
}

///|
pub fn System::x(self : System) -> @symvector.Vector {
  self.frame_.x()
}

///|
pub fn System::y(self : System) -> @symvector.Vector {
  self.frame_.y()
}

///|
pub fn System::z(self : System) -> @symvector.Vector {
  self.frame_.z()
}

///|
pub fn System::bodies(self : System) -> Array[BodyLike] {
  self.bodies_.copy()
}

///|
pub fn System::joints(self : System) -> Array[JointLike] {
  self.joints_.copy()
}

///|
pub fn System::loads(self : System) -> Array[Load] {
  self.loads_.copy()
}

///|
pub fn System::actuators(self : System) -> Array[ActuatorLike] {
  self.actuators_.copy()
}

///|
pub fn System::q_ind(self : System) -> Array[Expr] {
  self.q_ind_.copy()
}

///|
pub fn System::q_dep(self : System) -> Array[Expr] {
  self.q_dep_.copy()
}

///|
pub fn System::u_ind(self : System) -> Array[Expr] {
  self.u_ind_.copy()
}

///|
pub fn System::u_dep(self : System) -> Array[Expr] {
  self.u_dep_.copy()
}

///|
pub fn System::u_aux(self : System) -> Array[Expr] {
  self.u_aux_.copy()
}

///|
pub fn System::kdes(self : System) -> Array[Expr] {
  self.kdes_.copy()
}

///|
pub fn System::q(self : System) -> Array[Expr] {
  self.q_ind_.copy() + self.q_dep_.copy()
}

///|
pub fn System::u(self : System) -> Array[Expr] {
  self.u_ind_.copy() + self.u_dep_.copy()
}

///|
pub fn System::holonomic_constraints(self : System) -> Array[Expr] {
  self.holonomic_constraints_.copy()
}

///|
pub fn System::nonholonomic_constraints(self : System) -> Array[Expr] {
  self.nonholonomic_constraints_.copy()
}

///|
pub fn System::velocity_constraints(self : System) -> Array[Expr] {
  let out : Array[Expr] = []
  for expr in self.holonomic_constraints_ {
    out.push(
      mech_simplify_expr(@symcalculus.diff(expr, @symvector.dynamicsymbols_t)),
    )
  }
  for expr in self.nonholonomic_constraints_ {
    out.push(expr)
  }
  out
}

///|
pub fn System::eom_method(self : System) -> MechanicsBackend? {
  self.eom_method_
}

///|
pub fn System::set_q_ind(
  self : System,
  exprs : Array[Expr],
) -> Unit raise @symphysics.PhysicsError {
  validate_coordinates(
    coordinates=exprs,
    speeds=self.u(),
    u_auxiliary=self.u_aux_,
  )
  self.q_ind_ = exprs.copy()
}

///|
pub fn System::set_q_dep(
  self : System,
  exprs : Array[Expr],
) -> Unit raise @symphysics.PhysicsError {
  validate_coordinates(
    coordinates=self.q_ind_ + exprs,
    speeds=self.u(),
    u_auxiliary=self.u_aux_,
  )
  self.q_dep_ = exprs.copy()
}

///|
pub fn System::set_u_ind(
  self : System,
  exprs : Array[Expr],
) -> Unit raise @symphysics.PhysicsError {
  validate_coordinates(
    coordinates=self.q(),
    speeds=exprs + self.u_dep_,
    u_auxiliary=self.u_aux_,
  )
  self.u_ind_ = exprs.copy()
}

///|
pub fn System::set_u_dep(
  self : System,
  exprs : Array[Expr],
) -> Unit raise @symphysics.PhysicsError {
  validate_coordinates(
    coordinates=self.q(),
    speeds=self.u_ind_ + exprs,
    u_auxiliary=self.u_aux_,
  )
  self.u_dep_ = exprs.copy()
}

///|
pub fn System::set_u_aux(
  self : System,
  exprs : Array[Expr],
) -> Unit raise @symphysics.PhysicsError {
  validate_coordinates(
    coordinates=self.q(),
    speeds=self.u(),
    u_auxiliary=exprs,
  )
  self.u_aux_ = exprs.copy()
}

///|
pub fn System::add_coordinates(
  self : System,
  coordinates : Array[Expr],
  independent? : Bool = true,
) -> Unit raise @symphysics.PhysicsError {
  let next_ind = if independent {
    self.q_ind_.copy() + coordinates.copy()
  } else {
    self.q_ind_.copy()
  }
  let next_dep = if independent {
    self.q_dep_.copy()
  } else {
    self.q_dep_.copy() + coordinates.copy()
  }
  validate_coordinates(
    coordinates=next_ind + next_dep,
    speeds=self.u(),
    u_auxiliary=self.u_aux_,
  )
  if independent {
    system_append_exprs_unique(self.q_ind_, coordinates)
  } else {
    system_append_exprs_unique(self.q_dep_, coordinates)
  }
  self.eom_method_ = None
}

///|
pub fn System::add_speeds(
  self : System,
  speeds : Array[Expr],
  independent? : Bool = true,
) -> Unit raise @symphysics.PhysicsError {
  let next_ind = if independent {
    self.u_ind_.copy() + speeds.copy()
  } else {
    self.u_ind_.copy()
  }
  let next_dep = if independent {
    self.u_dep_.copy()
  } else {
    self.u_dep_.copy() + speeds.copy()
  }
  validate_coordinates(
    coordinates=self.q(),
    speeds=next_ind + next_dep,
    u_auxiliary=self.u_aux_,
  )
  if independent {
    system_append_exprs_unique(self.u_ind_, speeds)
  } else {
    system_append_exprs_unique(self.u_dep_, speeds)
  }
  self.eom_method_ = None
}

///|
pub fn System::add_auxiliary_speeds(
  self : System,
  speeds : Array[Expr],
) -> Unit raise @symphysics.PhysicsError {
  validate_coordinates(
    coordinates=self.q(),
    speeds=self.u(),
    u_auxiliary=self.u_aux_ + speeds.copy(),
  )
  system_append_exprs_unique(self.u_aux_, speeds)
  self.eom_method_ = None
}

///|
pub fn System::add_kdes(
  self : System,
  equations : Array[Expr],
) -> Unit {
  system_append_exprs_unique(self.kdes_, equations)
  self.eom_method_ = None
}

///|
pub fn System::add_holonomic_constraints(
  self : System,
  equations : Array[Expr],
) -> Unit {
  system_append_exprs_unique(self.holonomic_constraints_, equations)
  self.eom_method_ = None
}

///|
pub fn System::add_nonholonomic_constraints(
  self : System,
  equations : Array[Expr],
) -> Unit {
  system_append_exprs_unique(self.nonholonomic_constraints_, equations)
  self.eom_method_ = None
}

///|
pub fn System::add_bodies(self : System, bodies : Array[BodyLike]) -> Unit {
  system_append_bodies_unique(self.bodies_, bodies)
  self.eom_method_ = None
}

///|
pub fn System::add_loads(self : System, loads : Array[Load]) -> Unit {
  system_append_loads_unique(self.loads_, loads)
  self.eom_method_ = None
}

///|
pub fn System::apply_uniform_gravity(
  self : System,
  acceleration : @symvector.Vector,
) -> Unit {
  let grav = gravity(acceleration, self.bodies_)
  let loads : Array[Load] = []
  for item in grav {
    loads.push(Load::ForceLoad(item))
  }
  self.add_loads(loads)
}

///|
pub fn System::add_actuators(
  self : System,
  actuators : Array[ActuatorLike],
) -> Unit {
  system_append_actuators_unique(self.actuators_, actuators)
  self.eom_method_ = None
}

///|
pub fn System::add_joints(
  self : System,
  joints : Array[JointLike],
) -> Unit raise @symphysics.PhysicsError {
  for joint in joints {
    system_append_joints_unique(self.joints_, [joint])
    self.add_bodies([joint.parent(), joint.child()])
    self.add_coordinates(joint.coordinates())
    self.add_speeds(joint.speeds())
    self.add_kdes(joint.kdes())
  }
  self.eom_method_ = None
}

///|
pub fn System::get_body(self : System, name : String) -> BodyLike? {
  for body in self.bodies_ {
    if mech_bodylike_name(body) == name {
      return Some(body)
    }
  }
  None
}

///|
pub fn System::get_joint(self : System, name : String) -> JointLike? {
  for joint in self.joints_ {
    if joint.name() == name {
      return Some(joint)
    }
  }
  None
}

///|
pub fn System::validate_system(
  self : System,
  use_lagrange? : Bool = false,
  check_duplicates? : Bool = false,
) -> Unit raise @symphysics.PhysicsError {
  validate_coordinates(
    coordinates=self.q(),
    speeds=self.u(),
    u_auxiliary=self.u_aux_,
    check_duplicates~,
  )
  let msgs : Array[String] = []
  let q_all = self.q()
  let u_all = self.u()
  let n_hc = self.holonomic_constraints_.length()
  let n_vc = self.velocity_constraints().length()
  let n_q_dep = self.q_dep_.length()
  let n_u_dep = self.u_dep_.length()
  let q_keys = q_all.map(mech_expr_key)
  let u_keys = u_all.map(mech_expr_key)
  let n_q = Set::from_array(q_keys).length()
  let n_u = Set::from_array(u_keys).length()
  if n_q_dep != n_hc {
    msgs.push(
      "The number of dependent generalized coordinates " +
      n_q_dep.to_string() +
      " should be equal to the number of holonomic constraints " +
      n_hc.to_string() +
      ".",
    )
  }
  let missing_q : Map[String, Expr] = {}
  for joint in self.joints_ {
    let parent_name = mech_bodylike_name(joint.parent())
    let child_name = mech_bodylike_name(joint.child())
    if self.get_body(parent_name) is None || self.get_body(child_name) is None {
      msgs.push(
        "Joint " +
        joint.name() +
        " references a body not present in the system.",
      )
    }
    for coord in joint.coordinates() {
      if !q_keys.contains(mech_expr_key(coord)) {
        missing_q.set(mech_expr_key(coord), coord)
      }
    }
  }
  if !missing_q.is_empty() {
    let names : Array[String] = []
    for item in missing_q {
      names.push(@symprint.to_string(item.1))
    }
    names.sort()
    msgs.push(
      "The generalized coordinates {" +
      names.join(", ") +
      "} used in joints are not added to the system.",
    )
  }
  if use_lagrange {
    let qdots = q_all.map(fn(q) {
      @symcalculus.diff(q, @symvector.dynamicsymbols_t)
    })
    let qdot_keys = qdots.map(mech_expr_key)
    let not_qdots : Map[String, Expr] = {}
    for speed in u_all {
      if !qdot_keys.contains(mech_expr_key(speed)) {
        not_qdots.set(mech_expr_key(speed), speed)
      }
    }
    for joint in self.joints_ {
      for speed in joint.speeds() {
        if !qdot_keys.contains(mech_expr_key(speed)) {
          not_qdots.set(mech_expr_key(speed), speed)
        }
      }
    }
    if !not_qdots.is_empty() {
      let names : Array[String] = []
      for item in not_qdots {
        names.push(@symprint.to_string(item.1))
      }
      names.sort()
      msgs.push(
        "The generalized speeds {" +
        names.join(", ") +
        "} are not supported by this method. Only derivatives of the generalized coordinates are supported.",
      )
    }
    if !self.u_aux_.is_empty() {
      msgs.push(
        "This method does not support auxiliary speeds. The auxiliary speeds are {" +
        self.u_aux_.map(@symprint.to_string).join(", ") +
        "}.",
      )
    }
  } else {
    let n_kdes = self.kdes_.length()
    let missing_u : Map[String, Expr] = {}
    let missing_kdes : Map[String, Expr] = {}
    for joint in self.joints_ {
      for speed in joint.speeds() {
        if !u_keys.contains(mech_expr_key(speed)) {
          missing_u.set(mech_expr_key(speed), speed)
        }
      }
      for kde in joint.kdes() {
        if !self.kdes_.any(fn(existing) {
            @symcore.compare_expr(existing, kde) == 0 ||
            @symcore.compare_expr(existing, int(-1) * kde) == 0 ||
            @symcore.compare_expr(int(-1) * existing, kde) == 0 ||
            mech_expr_equal(existing, kde) ||
            mech_expr_equal(existing, int(-1) * kde)
          }) {
          missing_kdes.set(mech_expr_key(kde), kde)
        }
      }
    }
    if !missing_u.is_empty() {
      let names : Array[String] = []
      for item in missing_u {
        names.push(@symprint.to_string(item.1))
      }
      names.sort()
      msgs.push(
        "The generalized speeds {" +
        names.join(", ") +
        "} used in joints are not added to the system.",
      )
    }
    if !missing_kdes.is_empty() {
      let names : Array[String] = []
      for item in missing_kdes {
        names.push(@symprint.to_string(item.1))
      }
      names.sort()
      msgs.push(
        "The kinematic differential equations {" +
        names.join(", ") +
        "} used in joints are not added to the system.",
      )
    }
    if n_u_dep != n_vc {
      msgs.push(
        "The number of dependent generalized speeds " +
        n_u_dep.to_string() +
        " should be equal to the number of velocity constraints " +
        n_vc.to_string() +
        ".",
      )
    }
    if n_q > n_u {
      msgs.push(
        "The number of generalized coordinates " +
        n_q.to_string() +
        " should be less than or equal to the number of generalized speeds " +
        n_u.to_string() +
        ".",
      )
    }
    if n_u != n_kdes {
      msgs.push(
        "The number of generalized speeds " +
        n_u.to_string() +
        " should be equal to the number of kinematic differential equations " +
        n_kdes.to_string() +
        ".",
      )
    }
  }
  if check_duplicates {
    let body_names = self.bodies_.map(mech_bodylike_name)
    if Set::from_array(body_names).length() != body_names.length() {
      msgs.push("The bodies exist multiple times within the system.")
    }
    let joint_names = self.joints_.map(fn(joint) { joint.name() })
    if Set::from_array(joint_names).length() != joint_names.length() {
      msgs.push("The joints exist multiple times within the system.")
    }
  }
  if !msgs.is_empty() {
    raise @symphysics.PhysicsError::ValueError(msgs.join("\n"))
  }
}

///|
fn System::system_effective_loads(
  self : System,
) -> Array[Load] raise {
  let out = self.loads_.copy()
  for actuator in self.actuators_ {
    system_append_loads_unique(out, actuator.to_loads())
  }
  out
}

///|
pub fn System::form_eoms(
  self : System,
  use_lagrange? : Bool = false,
) -> @symphysics.ExplicitMatrix raise {
  self.validate_system(use_lagrange~)
  let loads = self.system_effective_loads()
  if use_lagrange {
    let q_all = self.q()
    let qdots = q_all.map(fn(q) {
      @symcalculus.diff(q, @symvector.dynamicsymbols_t)
    })
    let u_all = self.u()
    if u_all.length() != qdots.length() {
      raise @symphysics.PhysicsError::ValueError(
        "System.form_eoms(Lagrange) requires generalized speeds to match coordinate derivatives",
      )
    }
    let subs : Array[Substitution] = []
    for i in 0..<q_all.length() {
      subs.push((u_all[i], qdots[i]))
    }
    let lagr = msubs_expr(lagrangian(self.frame_, self.bodies_), subs)
    let lagrange_loads : Array[Load] = []
    for load in loads {
      match load {
        Load::ForceLoad(value) =>
          lagrange_loads.push(
            Load::ForceLoad(force(value.point, msubs_vector(value.force, subs))),
          )
        Load::TorqueLoad(value) =>
          lagrange_loads.push(
            Load::TorqueLoad(
              torque(value.frame, msubs_vector(value.torque, subs)),
            ),
          )
      }
    }
    let backend = lagranges_method(
      lagr,
      q_all,
      bodies=self.bodies_,
      forcelist=lagrange_loads,
      frame=Some(self.frame_),
      hol_coneqs=self.holonomic_constraints_,
    )
    let eom = backend.form_lagranges_equations()
    self.eom_method_ = Some(MechanicsBackend::Lagrange(backend))
    eom
  } else {
    let backend = kanes_method(
      self.frame_,
      self.q_ind_,
      self.u_ind_,
      self.kdes_,
      bodies=self.bodies_,
      forcelist=loads,
    )
    let (_, fr) = backend.kanes_equations(self.bodies_, loads)
    self.eom_method_ = Some(MechanicsBackend::Kane(backend))
    fr
  }
}

///|
pub fn System::rhs(
  self : System,
) -> @symphysics.ExplicitMatrix raise {
  match self.eom_method_ {
    Some(MechanicsBackend::Kane(value)) => value.rhs()
    Some(MechanicsBackend::Lagrange(value)) => value.rhs()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "form_eoms must be called before rhs",
      )
  }
}

///|
pub fn System::mass_matrix(
  self : System,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.eom_method_ {
    Some(MechanicsBackend::Kane(value)) => value.mass_matrix()
    Some(MechanicsBackend::Lagrange(value)) => value.mass_matrix()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "form_eoms must be called before mass_matrix",
      )
  }
}

///|
pub fn System::mass_matrix_full(
  self : System,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.eom_method_ {
    Some(MechanicsBackend::Kane(value)) => value.mass_matrix_full()
    Some(MechanicsBackend::Lagrange(value)) => value.mass_matrix_full()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "form_eoms must be called before mass_matrix_full",
      )
  }
}

///|
pub fn System::forcing(
  self : System,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.eom_method_ {
    Some(MechanicsBackend::Kane(value)) => value.forcing()
    Some(MechanicsBackend::Lagrange(value)) => value.forcing()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "form_eoms must be called before forcing",
      )
  }
}

///|
pub fn System::forcing_full(
  self : System,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.eom_method_ {
    Some(MechanicsBackend::Kane(value)) => value.forcing_full()
    Some(MechanicsBackend::Lagrange(value)) => value.forcing_full()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "form_eoms must be called before forcing_full",
      )
  }
}

///|
pub fn System::repr(self : System) -> String {
  "System(frame=" +
  self.frame_.name() +
  ", fixed_point=" +
  self.fixed_point_.name() +
  ", bodies=" +
  self.bodies_.length().to_string() +
  ", joints=" +
  self.joints_.length().to_string() +
  ")"
}
