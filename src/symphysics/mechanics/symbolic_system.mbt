///|
/// Symbolic equation container aligned with the high-value surface of
/// `sympy.physics.mechanics.system.SymbolicSystem`.

///|
pub type OutputEquation = (Expr, Expr)

///|
pub struct SymbolicSystem {
  states_ : @symphysics.ExplicitMatrix
  coordinates_ : @symphysics.ExplicitMatrix?
  speeds_ : @symphysics.ExplicitMatrix?
  alg_con_ : Array[Int]?
  dyn_implicit_mat_ : @symphysics.ExplicitMatrix?
  dyn_implicit_rhs_ : @symphysics.ExplicitMatrix?
  mut comb_implicit_mat_ : @symphysics.ExplicitMatrix?
  mut comb_implicit_rhs_ : @symphysics.ExplicitMatrix?
  mut comb_explicit_rhs_ : @symphysics.ExplicitMatrix?
  kin_explicit_rhs_ : @symphysics.ExplicitMatrix?
  output_eqns_ : Array[OutputEquation]
  bodies_ : Array[BodyLike]?
  loads_ : Array[Load]?
} derive(Eq)

///|
fn symbolic_system_column(exprs : Array[Expr]) -> @symphysics.ExplicitMatrix {
  mechanics_matrix_column(exprs)
}

///|
fn symbolic_system_join_rows(
  lhs : @symphysics.ExplicitMatrix,
  rhs : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  @symphysics.explicit_matrix_horizontal_concat(lhs, rhs)
}

///|
fn symbolic_system_join_cols(
  top : @symphysics.ExplicitMatrix,
  bottom : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  @symphysics.explicit_matrix_vertical_concat(top, bottom)
}

///|
fn symbolic_system_flatten(matrix : @symphysics.ExplicitMatrix) -> Array[Expr] {
  let out : Array[Expr] = []
  for row in mechanics_matrix_entries(matrix) {
    for value in row {
      out.push(value)
    }
  }
  out
}

///|
fn symbolic_system_copy_opt_matrix(
  matrix : @symphysics.ExplicitMatrix?,
) -> @symphysics.ExplicitMatrix? {
  match matrix {
    Some(value) => Some(value)
    None => None
  }
}

///|
fn symbolic_system_copy_opt_ints(values : Array[Int]?) -> Array[Int]? {
  match values {
    Some(items) => Some(items.copy())
    None => None
  }
}

///|
fn symbolic_system_copy_opt_bodies(
  values : Array[BodyLike]?,
) -> Array[BodyLike]? {
  match values {
    Some(items) => Some(items.copy())
    None => None
  }
}

///|
fn symbolic_system_copy_opt_loads(values : Array[Load]?) -> Array[Load]? {
  match values {
    Some(items) => Some(items.copy())
    None => None
  }
}

///|
fn symbolic_system_collect_free_symbols(
  expr : Expr,
  seen : Map[String, Expr],
) -> Unit {
  match expr {
    Expr::Symbol(_) => seen.set(mech_expr_key(expr), expr)
    Expr::Add(args) | Expr::Mul(args) =>
      for arg in args {
        symbolic_system_collect_free_symbols(arg, seen)
      }
    Expr::Pow(base, exp) => {
      symbolic_system_collect_free_symbols(base, seen)
      symbolic_system_collect_free_symbols(exp, seen)
    }
    _ =>
      for arg in @symcore.args(expr) {
        symbolic_system_collect_free_symbols(arg, seen)
      }
  }
}

///|
pub fn symbolic_system(
  coord_states : Array[Expr],
  right_hand_side : @symphysics.ExplicitMatrix,
  speeds? : Array[Expr]? = None,
  mass_matrix? : @symphysics.ExplicitMatrix? = None,
  coordinate_derivatives? : @symphysics.ExplicitMatrix? = None,
  alg_con? : Array[Int]? = None,
  output_eqns? : Array[OutputEquation] = [],
  coord_idxs? : Array[Int]? = None,
  speed_idxs? : Array[Int]? = None,
  bodies? : Array[BodyLike]? = None,
  loads? : Array[Load]? = None,
) -> SymbolicSystem raise @symphysics.PhysicsError {
  let (states, coordinates, speed_matrix) = match speeds {
    Some(speed_values) => {
      let coord_matrix = symbolic_system_column(coord_states)
      let speed_value_matrix = symbolic_system_column(speed_values)
      (
        symbolic_system_join_cols(coord_matrix, speed_value_matrix),
        Some(coord_matrix),
        Some(speed_value_matrix),
      )
    }
    None =>
      (
        symbolic_system_column(coord_states),
        match coord_idxs {
          Some(idxs) =>
            Some(
              symbolic_system_column(
                idxs.map(fn(index) { coord_states[index] }),
              ),
            )
          None => None
        },
        match speed_idxs {
          Some(idxs) =>
            Some(
              symbolic_system_column(
                idxs.map(fn(index) { coord_states[index] }),
              ),
            )
          None => None
        },
      )
  }

  let (kin_rhs, dyn_rhs, dyn_mat, comb_rhs, comb_mat, comb_explicit) = match
    coordinate_derivatives {
    Some(kinematics) =>
      (Some(kinematics), Some(right_hand_side), mass_matrix, None, None, None)
    None =>
      match mass_matrix {
        Some(matrix) =>
          (None, None, None, Some(right_hand_side), Some(matrix), None)
        None => (None, None, None, None, None, Some(right_hand_side))
      }
  }

  let adjusted_alg_con = match (alg_con, coordinate_derivatives) {
    (Some(items), Some(kinematics)) =>
      Some(items.map(fn(index) { index + kinematics.height() }))
    _ => symbolic_system_copy_opt_ints(alg_con)
  }
  SymbolicSystem::{
    states_: states,
    coordinates_: coordinates,
    speeds_: speed_matrix,
    alg_con_: adjusted_alg_con,
    dyn_implicit_mat_: symbolic_system_copy_opt_matrix(dyn_mat),
    dyn_implicit_rhs_: symbolic_system_copy_opt_matrix(dyn_rhs),
    comb_implicit_mat_: symbolic_system_copy_opt_matrix(comb_mat),
    comb_implicit_rhs_: symbolic_system_copy_opt_matrix(comb_rhs),
    comb_explicit_rhs_: symbolic_system_copy_opt_matrix(comb_explicit),
    kin_explicit_rhs_: symbolic_system_copy_opt_matrix(kin_rhs),
    output_eqns_: output_eqns.copy(),
    bodies_: symbolic_system_copy_opt_bodies(bodies),
    loads_: symbolic_system_copy_opt_loads(loads),
  }
}

///|
pub fn SymbolicSystem::coordinates(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.coordinates_ {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "coordinates were not specified",
      )
  }
}

///|
pub fn SymbolicSystem::speeds(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.speeds_ {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError("speeds were not specified")
  }
}

///|
pub fn SymbolicSystem::states(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix {
  self.states_
}

///|
pub fn SymbolicSystem::alg_con(self : SymbolicSystem) -> Array[Int]? {
  symbolic_system_copy_opt_ints(self.alg_con_)
}

///|
pub fn SymbolicSystem::dyn_implicit_mat(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.dyn_implicit_mat_ {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "dyn_implicit_mat is not specified for this equations-of-motion form",
      )
  }
}

///|
pub fn SymbolicSystem::dyn_implicit_rhs(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.dyn_implicit_rhs_ {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "dyn_implicit_rhs is not specified for this equations-of-motion form",
      )
  }
}

///|
pub fn SymbolicSystem::comb_implicit_mat(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.comb_implicit_mat_ {
    Some(value) => value
    None =>
      match
        (self.kin_explicit_rhs_, self.dyn_implicit_mat_, self.dyn_implicit_rhs_) {
        (Some(kin_rhs), Some(dyn_mat), Some(dyn_rhs)) => {
          let zeros1 = @symphysics.explicit_matrix_zeros(
            kin_rhs.height(),
            dyn_rhs.height(),
          )
          let zeros2 = @symphysics.explicit_matrix_zeros(
            dyn_rhs.height(),
            kin_rhs.height(),
          )
          let inter1 = symbolic_system_join_rows(
            @symphysics.explicit_matrix_eye(kin_rhs.height()),
            zeros1,
          )
          let inter2 = symbolic_system_join_rows(zeros2, dyn_mat)
          let value = symbolic_system_join_cols(inter1, inter2)
          self.comb_implicit_mat_ = Some(value)
          value
        }
        _ =>
          raise @symphysics.PhysicsError::ValueError(
            "comb_implicit_mat is not specified for explicit equations of motion",
          )
      }
  }
}

///|
pub fn SymbolicSystem::comb_implicit_rhs(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.comb_implicit_rhs_ {
    Some(value) => value
    None =>
      match (self.kin_explicit_rhs_, self.dyn_implicit_rhs_) {
        (Some(kin_rhs), Some(dyn_rhs)) => {
          let value = symbolic_system_join_cols(kin_rhs, dyn_rhs)
          self.comb_implicit_rhs_ = Some(value)
          value
        }
        _ =>
          raise @symphysics.PhysicsError::ValueError(
            "comb_implicit_rhs is not specified for explicit equations of motion",
          )
      }
  }
}

///|
pub fn SymbolicSystem::compute_explicit_form(
  self : SymbolicSystem,
) -> Unit raise @symphysics.PhysicsError {
  guard self.comb_explicit_rhs_ is None else {
    raise @symphysics.PhysicsError::ValueError(
      "comb_explicit_rhs is already formed",
    )
  }
  let out = match
    (self.kin_explicit_rhs_, self.dyn_implicit_mat_, self.dyn_implicit_rhs_) {
    (Some(kin_rhs), Some(dyn_mat), Some(dyn_rhs)) => {
      let dyn_solution = mechanics_linear_solve(
        dyn_mat,
        symbolic_system_flatten(dyn_rhs),
      )
      symbolic_system_join_cols(kin_rhs, symbolic_system_column(dyn_solution))
    }
    _ => {
      let comb_mat = self.comb_implicit_mat()
      let comb_rhs = self.comb_implicit_rhs()
      symbolic_system_column(
        mechanics_linear_solve(comb_mat, symbolic_system_flatten(comb_rhs)),
      )
    }
  }
  self.comb_explicit_rhs_ = Some(out)
}

///|
pub fn SymbolicSystem::comb_explicit_rhs(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.comb_explicit_rhs_ {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "compute_explicit_form must be called before comb_explicit_rhs",
      )
  }
}

///|
pub fn SymbolicSystem::kin_explicit_rhs(
  self : SymbolicSystem,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.kin_explicit_rhs_ {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "kin_explicit_rhs is not specified for this equations-of-motion form",
      )
  }
}

///|
pub fn SymbolicSystem::dynamic_symbols(self : SymbolicSystem) -> Array[Expr] {
  let seen : Map[String, Expr] = {}
  let eom_exprs = match self.comb_explicit_rhs_ {
    Some(value) => symbolic_system_flatten(value)
    None => {
      let out : Array[Expr] = []
      try self.comb_implicit_mat() catch {
        _ => ()
      } noraise {
        matrix =>
          for item in symbolic_system_flatten(matrix) {
            out.push(item)
          }
      }
      try self.comb_implicit_rhs() catch {
        _ => ()
      } noraise {
        matrix =>
          for item in symbolic_system_flatten(matrix) {
            out.push(item)
          }
      }
      out
    }
  }
  for expr in eom_exprs {
    mech_find_dynamicsymbols_go(expr, seen)
  }
  for expr in symbolic_system_flatten(self.states_) {
    seen.set(mech_expr_key(expr), expr)
  }
  let keys : Array[String] = []
  for entry in seen {
    keys.push(entry.0)
  }
  keys.sort_by((a, b) => a.compare(b))
  keys.map(fn(key) { seen[key] })
}

///|
pub fn SymbolicSystem::constant_symbols(self : SymbolicSystem) -> Array[Expr] {
  let seen : Map[String, Expr] = {}
  let eom_exprs = match self.comb_explicit_rhs_ {
    Some(value) => symbolic_system_flatten(value)
    None => {
      let out : Array[Expr] = []
      try self.comb_implicit_mat() catch {
        _ => ()
      } noraise {
        matrix =>
          for item in symbolic_system_flatten(matrix) {
            out.push(item)
          }
      }
      try self.comb_implicit_rhs() catch {
        _ => ()
      } noraise {
        matrix =>
          for item in symbolic_system_flatten(matrix) {
            out.push(item)
          }
      }
      out
    }
  }
  for expr in eom_exprs {
    symbolic_system_collect_free_symbols(expr, seen)
  }
  seen.remove(mech_expr_key(@symvector.dynamicsymbols_t))
  let keys : Array[String] = []
  for entry in seen {
    keys.push(entry.0)
  }
  keys.sort_by((a, b) => a.compare(b))
  keys.map(fn(key) { seen[key] })
}

///|
pub fn SymbolicSystem::output_eqns(
  self : SymbolicSystem,
) -> Array[OutputEquation] {
  self.output_eqns_.copy()
}

///|
pub fn SymbolicSystem::bodies(
  self : SymbolicSystem,
) -> Array[BodyLike] raise @symphysics.PhysicsError {
  match self.bodies_ {
    Some(value) => value.copy()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "bodies were not specified for the system",
      )
  }
}

///|
pub fn SymbolicSystem::loads(
  self : SymbolicSystem,
) -> Array[Load] raise @symphysics.PhysicsError {
  match self.loads_ {
    Some(value) => value.copy()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "loads were not specified for the system",
      )
  }
}
