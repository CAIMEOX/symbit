///|
/// Core symbolic body/load types aligned with the high-value surface of
/// `sympy.physics.mechanics`.

///|
pub type Substitution = (Expr, Expr)

///|
pub struct Inertia {
  dyadic : @symvector.Dyadic
  point : @symvector.Point
} derive(Eq)

///|
pub struct Particle {
  name_ : String
  mut point_ : @symvector.Point
  mut mass_ : Expr
  mut potential_energy_ : Expr
} derive(Eq)

///|
pub struct RigidBody {
  name_ : String
  mut masscenter_ : @symvector.Point
  mut frame_ : @symvector.ReferenceFrame
  mut mass_ : Expr
  mut inertia_ : Inertia
  mut central_inertia_ : @symvector.Dyadic
  mut potential_energy_ : Expr
} derive(Eq)

///|
pub struct Force {
  point : @symvector.Point
  force : @symvector.Vector
} derive(Eq)

///|
pub struct Torque {
  frame : @symvector.ReferenceFrame
  torque : @symvector.Vector
} derive(Eq)

///|
pub enum Load {
  ForceLoad(Force)
  TorqueLoad(Torque)
} derive(Eq)

///|
pub struct Body {
  name_ : String
  masscenter_ : @symvector.Point
  frame_ : @symvector.ReferenceFrame
  mass_ : Expr
  mut inertia_ : Inertia
  mut central_inertia_ : @symvector.Dyadic
  mut potential_energy_ : Expr
  mut loads_ : Array[Load]
  mut is_rigidbody_ : Bool
} derive(Eq)

///|
pub enum BodyLike {
  ParticleLike(Particle)
  RigidBodyLike(RigidBody)
  BodyLikeLegacy(Body)
} derive(Eq)

///|
fn mech_half_expr() -> Expr {
  mech_simplify_expr(int(1) * (int(2) ^ int(-1)))
}

///|
fn mech_simplify_expr(expr : Expr) -> Expr {
  @symsimplify.ratsimp(@symsimplify.simplify(expr, max_passes=6), max_passes=4)
}

///|
fn mech_expr_is_zero(expr : Expr) -> Bool {
  mech_simplify_expr(expr) == int(0)
}

///|
fn mech_expr_equal(lhs : Expr, rhs : Expr) -> Bool {
  mech_expr_is_zero(lhs - rhs)
}

///|
fn mech_expr_depends_on(expr : Expr, wrt : Expr) -> Bool {
  if @symcore.compare_expr(expr, wrt) == 0 {
    return true
  }
  match expr {
    Expr::Add(args) | Expr::Mul(args) =>
      args.any(fn(arg) { mech_expr_depends_on(arg, wrt) })
    _ if @symcore.application_parts(expr) is Some(_) =>
      @symcore.application_args(expr)
      .unwrap_or([])
      .any(fn(arg) { mech_expr_depends_on(arg, wrt) })
    Expr::Pow(base, exp) =>
      mech_expr_depends_on(base, wrt) || mech_expr_depends_on(exp, wrt)
    _ => false
  }
}

///|
fn mech_builtin_function(name : String) -> Bool {
  [
    "sin", "cos", "tan", "sqrt", "exp", "log", "Integral", "Tuple", "Abs", "asin",
    "acos", "atan", "sinh", "cosh", "tanh", "Derivative",
  ].contains(name)
}

///|
fn mech_is_dynamicsymbol(expr : Expr) -> Bool {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some(args)) if args.length() == 1 &&
      @symcore.compare_expr(args[0], @symvector.dynamicsymbols_t) == 0 =>
      !mech_builtin_function(name)
    _ =>
      match @symcore.derivative_parts(expr) {
        Some((head, deriv_args)) if deriv_args.length() >= 1 => {
          let only_t = deriv_args.all(fn(arg) {
            @symcore.compare_expr(arg, @symvector.dynamicsymbols_t) == 0
          })
          only_t && mech_expr_depends_on(head, @symvector.dynamicsymbols_t)
        }
        _ => false
      }
  }
}

///|
fn mech_expr_key(expr : Expr) -> String {
  @symprint.pretty_string(expr)
}

///|
fn mech_rewrite_tan(expr : Expr) -> Expr {
  match expr {
    _ if @symcore.application_has_name(expr, "tan", arity=1) => {
      let arg = @symcore.application_args(expr).unwrap_or([])[0]
      @symelem.sin(mech_rewrite_tan(arg)) *
      (@symelem.cos(mech_rewrite_tan(arg)) ^ int(-1))
    }
    Expr::Add(args) => @symcore.add(args.map(mech_rewrite_tan))
    Expr::Mul(args) => @symcore.mul(args.map(mech_rewrite_tan))
    Expr::Pow(base, exp) =>
      @symcore.pow(mech_rewrite_tan(base), mech_rewrite_tan(exp))
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.raw_apply(head, args.map(mech_rewrite_tan)) {
            Some(value) => value
            None => expr
          }
        None => expr
      }
  }
}

///|
fn mech_pi_half() -> Expr {
  mech_half_expr() * @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
}

///|
fn mech_eval_special_trig(expr : Expr) -> Expr {
  match expr {
    _ if @symcore.application_has_name(expr, "sin", arity=1) => {
      let arg = mech_eval_special_trig(
        @symcore.application_args(expr).unwrap_or([])[0],
      )
      if @symcore.compare_expr(arg, int(0)) == 0 {
        int(0)
      } else if @symcore.compare_expr(arg, mech_pi_half()) == 0 {
        int(1)
      } else {
        @symcore.raw_function("sin", [arg])
      }
    }
    _ if @symcore.application_has_name(expr, "cos", arity=1) => {
      let arg = mech_eval_special_trig(
        @symcore.application_args(expr).unwrap_or([])[0],
      )
      if @symcore.compare_expr(arg, int(0)) == 0 {
        int(1)
      } else if @symcore.compare_expr(arg, mech_pi_half()) == 0 {
        int(0)
      } else {
        @symcore.raw_function("cos", [arg])
      }
    }
    Expr::Add(args) => @symcore.add(args.map(mech_eval_special_trig))
    Expr::Mul(args) => @symcore.mul(args.map(mech_eval_special_trig))
    Expr::Pow(base, exp) =>
      @symcore.pow(mech_eval_special_trig(base), mech_eval_special_trig(exp))
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.raw_apply(head, args.map(mech_eval_special_trig)) {
            Some(value) => value
            None => expr
          }
        None => expr
      }
  }
}

///|
fn mech_apply_subs_exact(
  expr : Expr,
  subs : Array[Substitution],
  ignore_derivative_children? : Bool = true,
) -> Expr {
  for pair in subs {
    if @symcore.compare_expr(expr, pair.0) == 0 {
      return pair.1
    }
  }
  match expr {
    Expr::Add(args) =>
      @symcore.add(
        args.map(arg => {
          mech_apply_subs_exact(arg, subs, ignore_derivative_children~)
        }),
      )
    Expr::Mul(args) =>
      @symcore.mul(
        args.map(arg => {
          mech_apply_subs_exact(arg, subs, ignore_derivative_children~)
        }),
      )
    Expr::Pow(base, exp) =>
      @symcore.pow(
        mech_apply_subs_exact(base, subs, ignore_derivative_children~),
        mech_apply_subs_exact(exp, subs, ignore_derivative_children~),
      )
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          if ignore_derivative_children &&
            @symcore.application_has_name(expr, "Derivative") {
            expr
          } else {
            match
              @symcore.raw_apply(
                head,
                args.map(arg => {
                  mech_apply_subs_exact(arg, subs, ignore_derivative_children~)
                }),
              ) {
              Some(value) => value
              None => expr
            }
          }
        None => expr
      }
  }
}

///|
fn mech_find_dynamicsymbols_go(expr : Expr, seen : Map[String, Expr]) -> Unit {
  if mech_is_dynamicsymbol(expr) {
    seen.set(mech_expr_key(expr), expr)
  }
  match expr {
    Expr::Add(args) | Expr::Mul(args) =>
      for arg in args {
        mech_find_dynamicsymbols_go(arg, seen)
      }
    _ if @symcore.application_parts(expr) is Some(_) =>
      for arg in @symcore.application_args(expr).unwrap_or([]) {
        mech_find_dynamicsymbols_go(arg, seen)
      }
    Expr::Pow(base, exp) => {
      mech_find_dynamicsymbols_go(base, seen)
      mech_find_dynamicsymbols_go(exp, seen)
    }
    _ => ()
  }
}

///|
pub fn inertia_tuple(
  dyadic : @symvector.Dyadic,
  point : @symvector.Point,
) -> Inertia {
  Inertia::{ dyadic, point }
}

///|
pub fn Inertia::from_inertia_scalars(
  point : @symvector.Point,
  frame : @symvector.ReferenceFrame,
  ixx : Expr,
  iyy : Expr,
  izz : Expr,
  ixy? : Expr = int(0),
  iyz? : Expr = int(0),
  izx? : Expr = int(0),
) -> Inertia raise @symvector.VectorError {
  inertia_tuple(inertia(frame, ixx, iyy, izz, ixy~, iyz~, izx~), point)
}

///|
pub fn Inertia::repr(self : Inertia) -> String {
  "Inertia(dyadic=" +
  @symvector.vsprint_dyadic(self.dyadic) +
  ", point=" +
  self.point.name() +
  ")"
}

///|
pub fn force(point : @symvector.Point, force : @symvector.Vector) -> Force {
  Force::{ point, force }
}

///|
pub fn torque(
  frame : @symvector.ReferenceFrame,
  torque : @symvector.Vector,
) -> Torque {
  Torque::{ frame, torque }
}

///|
pub fn Force::repr(self : Force) -> String {
  "Force(point=" +
  self.point.name() +
  ", force=" +
  @symvector.vsprint(self.force) +
  ")"
}

///|
pub fn Torque::repr(self : Torque) -> String {
  "Torque(frame=" +
  self.frame.name() +
  ", torque=" +
  @symvector.vsprint(self.torque) +
  ")"
}

///|
fn mech_load_at_point(load : Load, point : @symvector.Point) -> Bool {
  match load {
    Load::ForceLoad(value) => value.point == point
    _ => false
  }
}

///|
fn mech_load_at_frame(load : Load, frame : @symvector.ReferenceFrame) -> Bool {
  match load {
    Load::TorqueLoad(value) => value.frame == frame
    _ => false
  }
}

///|
pub fn Particle::as_bodylike(self : Particle) -> BodyLike {
  BodyLike::ParticleLike(self)
}

///|
pub fn RigidBody::as_bodylike(self : RigidBody) -> BodyLike {
  BodyLike::RigidBodyLike(self)
}

///|
pub fn Body::as_bodylike(self : Body) -> BodyLike {
  BodyLike::BodyLikeLegacy(self)
}

///|
pub fn BodyLike::name(self : BodyLike) -> String {
  match self {
    BodyLike::ParticleLike(value) => value.name()
    BodyLike::RigidBodyLike(value) => value.name()
    BodyLike::BodyLikeLegacy(value) => value.name()
  }
}

///|
pub fn BodyLike::frame(self : BodyLike) -> @symvector.ReferenceFrame? {
  match self {
    BodyLike::ParticleLike(_) => None
    BodyLike::RigidBodyLike(value) => Some(value.frame())
    BodyLike::BodyLikeLegacy(value) => Some(value.frame())
  }
}

///|
pub fn BodyLike::masscenter(self : BodyLike) -> @symvector.Point {
  match self {
    BodyLike::ParticleLike(value) => value.point()
    BodyLike::RigidBodyLike(value) => value.masscenter()
    BodyLike::BodyLikeLegacy(value) => value.masscenter()
  }
}

///|
fn mech_bodylike_mass(body : BodyLike) -> Expr {
  match body {
    BodyLike::ParticleLike(value) => value.mass()
    BodyLike::RigidBodyLike(value) => value.mass()
    BodyLike::BodyLikeLegacy(value) => value.mass()
  }
}

///|
fn mech_bodylike_name(body : BodyLike) -> String {
  body.name()
}

///|
fn mech_bodylike_frame(body : BodyLike) -> @symvector.ReferenceFrame? {
  body.frame()
}

///|
fn mech_bodylike_masscenter(body : BodyLike) -> @symvector.Point {
  body.masscenter()
}

///|
fn mech_bodylike_potential_energy(body : BodyLike) -> Expr {
  match body {
    BodyLike::ParticleLike(value) => value.potential_energy()
    BodyLike::RigidBodyLike(value) => value.potential_energy()
    BodyLike::BodyLikeLegacy(value) => value.potential_energy()
  }
}

///|
fn mech_bodylike_linear_momentum(
  body : BodyLike,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  match body {
    BodyLike::ParticleLike(value) => value.linear_momentum(frame)
    BodyLike::RigidBodyLike(value) => value.linear_momentum(frame)
    BodyLike::BodyLikeLegacy(value) => value.linear_momentum(frame)
  }
}

///|
fn mech_bodylike_angular_momentum(
  body : BodyLike,
  point : @symvector.Point,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  match body {
    BodyLike::ParticleLike(value) => value.angular_momentum(point, frame)
    BodyLike::RigidBodyLike(value) => value.angular_momentum(point, frame)
    BodyLike::BodyLikeLegacy(value) => value.angular_momentum(point, frame)
  }
}

///|
fn mech_bodylike_kinetic_energy(
  body : BodyLike,
  frame : @symvector.ReferenceFrame,
) -> Expr raise @symvector.VectorError {
  match body {
    BodyLike::ParticleLike(value) => value.kinetic_energy(frame)
    BodyLike::RigidBodyLike(value) => value.kinetic_energy(frame)
    BodyLike::BodyLikeLegacy(value) => value.kinetic_energy(frame)
  }
}

///|
pub fn mechanics_printing() -> Unit {
  ()
}

///|
pub fn msprint_expr(expr : Expr) -> String {
  @symprint.pretty_string(expr)
}

///|
pub fn msprint_vector(expr : @symvector.Vector) -> String {
  @symvector.vsprint(expr)
}

///|
pub fn msprint_dyadic(expr : @symvector.Dyadic) -> String {
  @symvector.vsprint_dyadic(expr)
}
