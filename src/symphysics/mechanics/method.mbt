///|
/// Shared mechanics method utilities aligned with the high-value surface of
/// `sympy.physics.mechanics.method` and the linearization helpers used by
/// Kane/Lagrange backends.

///|
pub struct Linearizer {
  states_ : Array[Expr]
  inputs_ : Array[Expr]
  rhs_ : Array[Expr]
  q_ : Array[Expr]
  u_ : Array[Expr]
  q_i_ : Array[Expr]
  q_d_ : Array[Expr]
  u_i_ : Array[Expr]
  u_d_ : Array[Expr]
  r_ : Array[Expr]
  lams_ : Array[Expr]
  f_0_ : @symphysics.ExplicitMatrix
  f_1_ : @symphysics.ExplicitMatrix
  f_2_ : @symphysics.ExplicitMatrix
  f_3_ : @symphysics.ExplicitMatrix
  f_4_ : @symphysics.ExplicitMatrix
  f_c_ : @symphysics.ExplicitMatrix
  f_v_ : @symphysics.ExplicitMatrix
  f_a_ : @symphysics.ExplicitMatrix
  implicit_mass_ : @symphysics.ExplicitMatrix?
  implicit_forcing_ : @symphysics.ExplicitMatrix?
  perm_mat_ : @symphysics.ExplicitMatrix
} derive(Eq)

///|
fn mechanics_expr_div(lhs : Expr, rhs : Expr) -> Expr {
  mech_simplify_expr(lhs * (rhs ^ int(-1)))
}

///|
fn mechanics_matrix_column(exprs : Array[Expr]) -> @symphysics.ExplicitMatrix {
  @symphysics.explicit_matrix_column(exprs)
}

///|
fn mechanics_matrix_entries(
  matrix : @symphysics.ExplicitMatrix,
) -> Array[Array[Expr]] {
  matrix.rows_copy()
}

///|
fn mechanics_matrix_jacobian(
  exprs : Array[Expr],
  vars : Array[Expr],
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let rows : Array[Array[Expr]] = []
  for expr in exprs {
    let row : Array[Expr] = []
    for wrt in vars {
      row.push(mech_simplify_expr(@symcalculus.diff(expr, wrt)))
    }
    rows.push(row)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
fn mechanics_matrix_subs(
  matrix : @symphysics.ExplicitMatrix,
  substitutions : Array[Substitution],
) -> @symphysics.ExplicitMatrix {
  msubs_matrix(matrix, substitutions)
}

///|
fn mechanics_matrix_simplify(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix {
  matrix.map(mech_simplify_expr)
}

///|
fn mechanics_zero_column(n : Int) -> @symphysics.ExplicitMatrix {
  @symphysics.explicit_matrix_zeros(n, 1)
}

///|
fn mechanics_identity(n : Int) -> @symphysics.ExplicitMatrix {
  @symphysics.explicit_matrix_eye(n)
}

///|
fn mechanics_linear_solve(
  coeff : @symphysics.ExplicitMatrix,
  rhs : Array[Expr],
) -> Array[Expr] raise @symphysics.PhysicsError {
  let nrows = coeff.height()
  let ncols = coeff.width()
  guard nrows == rhs.length() && nrows == ncols else {
    raise @symphysics.PhysicsError::ShapeError(
      "mechanics linear system must be square",
    )
  }
  let aug = mechanics_matrix_entries(coeff)
  for i in 0..<nrows {
    aug[i].push(rhs[i])
  }

  for pivot in 0..<ncols {
    let mut pivot_row = pivot
    while pivot_row < nrows && mech_expr_is_zero(aug[pivot_row][pivot]) {
      pivot_row += 1
    }
    guard pivot_row < nrows else {
      raise @symphysics.PhysicsError::ValueError(
        "mechanics linear system is singular",
      )
    }
    if pivot_row != pivot {
      let tmp = aug[pivot]
      aug[pivot] = aug[pivot_row]
      aug[pivot_row] = tmp
    }
    let pivot_value = aug[pivot][pivot]
    for row in (pivot + 1)..<nrows {
      if mech_expr_is_zero(aug[row][pivot]) {
        continue
      }
      let factor = mechanics_expr_div(aug[row][pivot], pivot_value)
      for col in pivot..<=ncols {
        aug[row][col] = mech_simplify_expr(
          aug[row][col] - factor * aug[pivot][col],
        )
      }
    }
  }

  let solution : Array[Expr] = Array::make(ncols, int(0))
  let mut row = nrows - 1
  while row >= 0 {
    let mut value = aug[row][ncols]
    let mut col = row + 1
    while col < ncols {
      value = mech_simplify_expr(value - aug[row][col] * solution[col])
      col += 1
    }
    guard !mech_expr_is_zero(aug[row][row]) else {
      raise @symphysics.PhysicsError::ValueError(
        "mechanics linear system is singular",
      )
    }
    solution[row] = mechanics_expr_div(value, aug[row][row])
    row -= 1
  }
  solution
}

///|
fn mechanics_matrix_linear_solve(
  coeff : @symphysics.ExplicitMatrix,
  rhs : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  guard coeff.height() == rhs.height() else {
    raise @symphysics.PhysicsError::ShapeError(
      "mechanics linear systems require equal row counts",
    )
  }
  let solved_columns : Array[Array[Expr]] = []
  let rhs_rows = rhs.rows_copy()
  for j in 0..<rhs.width() {
    let column : Array[Expr] = []
    for i in 0..<rhs.height() {
      column.push(rhs_rows[i][j])
    }
    solved_columns.push(mechanics_linear_solve(coeff, column))
  }
  let rows : Array[Array[Expr]] = []
  for i in 0..<coeff.width() {
    let row : Array[Expr] = []
    for j in 0..<solved_columns.length() {
      row.push(solved_columns[j][i])
    }
    rows.push(row)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
fn mechanics_matrix_negative_residual(
  exprs : Array[Expr],
  vars : Array[Expr],
) -> Array[Expr] {
  let zero_subs : Array[Substitution] = []
  for wrt in vars {
    zero_subs.push((wrt, int(0)))
  }
  exprs.map(fn(expr) {
    mech_simplify_expr(int(-1) * msubs_expr(expr, zero_subs))
  })
}

///|
fn mechanics_dynamic_inputs(
  exprs : Array[Expr],
  exclude : Array[Expr],
) -> Array[Expr] {
  let seen : Map[String, Expr] = {}
  for expr in exprs {
    mech_find_dynamicsymbols_go(expr, seen)
  }
  for expr in exclude {
    seen.remove(mech_expr_key(expr))
  }
  let keys : Array[String] = []
  for entry in seen {
    keys.push(entry.0)
  }
  keys.sort()
  keys.map(fn(key) { seen[key] })
}

///|
fn linearizer_with_metadata(
  states : Array[Expr],
  rhs : Array[Expr],
  inputs? : Array[Expr] = [],
  q? : Array[Expr] = [],
  u? : Array[Expr] = [],
  q_i? : Array[Expr] = [],
  q_d? : Array[Expr] = [],
  u_i? : Array[Expr] = [],
  u_d? : Array[Expr] = [],
  r? : Array[Expr] = [],
  lams? : Array[Expr] = [],
  f_0? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  f_1? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  f_2? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  f_3? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  f_4? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  f_c? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  f_v? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  f_a? : @symphysics.ExplicitMatrix = mechanics_zero_column(0),
  implicit_mass? : @symphysics.ExplicitMatrix? = None,
  implicit_forcing? : @symphysics.ExplicitMatrix? = None,
  perm_mat? : @symphysics.ExplicitMatrix? = None,
) -> Linearizer {
  let actual_mass = match implicit_mass {
    Some(value) => Some(value)
    None => Some(mechanics_identity(states.length()))
  }
  let actual_forcing = match implicit_forcing {
    Some(value) => Some(value)
    None => Some(mechanics_matrix_column(rhs))
  }
  let actual_perm = match perm_mat {
    Some(value) => value
    None => mechanics_identity(states.length())
  }
  Linearizer::{
    states_: states.copy(),
    inputs_: inputs.copy(),
    rhs_: rhs.copy(),
    q_: q.copy(),
    u_: u.copy(),
    q_i_: q_i.copy(),
    q_d_: q_d.copy(),
    u_i_: u_i.copy(),
    u_d_: u_d.copy(),
    r_: r.copy(),
    lams_: lams.copy(),
    f_0_: f_0,
    f_1_: f_1,
    f_2_: f_2,
    f_3_: f_3,
    f_4_: f_4,
    f_c_: f_c,
    f_v_: f_v,
    f_a_: f_a,
    implicit_mass_: actual_mass,
    implicit_forcing_: actual_forcing,
    perm_mat_: actual_perm,
  }
}

///|
pub fn linearizer(
  states : Array[Expr],
  rhs : Array[Expr],
  inputs? : Array[Expr] = [],
) -> Linearizer {
  linearizer_with_metadata(states, rhs, inputs~)
}

///|
pub fn Linearizer::permutation_matrix(
  self : Linearizer,
) -> @symphysics.ExplicitMatrix {
  self.perm_mat_
}

///|
pub fn Linearizer::states(self : Linearizer) -> Array[Expr] {
  self.states_.copy()
}

///|
pub fn Linearizer::inputs(self : Linearizer) -> Array[Expr] {
  self.inputs_.copy()
}

///|
pub fn Linearizer::q(self : Linearizer) -> Array[Expr] {
  if self.q_.is_empty() {
    self.states_.copy()
  } else {
    self.q_.copy()
  }
}

///|
pub fn Linearizer::u(self : Linearizer) -> Array[Expr] {
  self.u_.copy()
}

///|
pub fn Linearizer::q_i(self : Linearizer) -> Array[Expr] {
  if self.q_i_.is_empty() && self.q_d_.is_empty() {
    self.q()
  } else {
    self.q_i_.copy()
  }
}

///|
pub fn Linearizer::q_d(self : Linearizer) -> Array[Expr] {
  self.q_d_.copy()
}

///|
pub fn Linearizer::u_i(self : Linearizer) -> Array[Expr] {
  if self.u_i_.is_empty() && self.u_d_.is_empty() {
    self.u()
  } else {
    self.u_i_.copy()
  }
}

///|
pub fn Linearizer::u_d(self : Linearizer) -> Array[Expr] {
  self.u_d_.copy()
}

///|
pub fn Linearizer::r(self : Linearizer) -> Array[Expr] {
  if self.r_.is_empty() {
    self.inputs()
  } else {
    self.r_.copy()
  }
}

///|
pub fn Linearizer::lams(self : Linearizer) -> Array[Expr] {
  self.lams_.copy()
}

///|
pub fn Linearizer::f_0(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_0_
}

///|
pub fn Linearizer::f_1(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_1_
}

///|
pub fn Linearizer::f_2(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_2_
}

///|
pub fn Linearizer::f_3(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_3_
}

///|
pub fn Linearizer::f_4(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_4_
}

///|
pub fn Linearizer::f_c(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_c_
}

///|
pub fn Linearizer::f_v(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_v_
}

///|
pub fn Linearizer::f_a(self : Linearizer) -> @symphysics.ExplicitMatrix {
  self.f_a_
}

///|
pub fn Linearizer::rhs(self : Linearizer) -> Array[Expr] {
  self.rhs_.copy()
}

///|
pub fn Linearizer::linearize_mab(
  self : Linearizer,
  op_point? : Array[Substitution] = [],
  simplify? : Bool = false,
) -> (
  @symphysics.ExplicitMatrix,
  @symphysics.ExplicitMatrix,
  @symphysics.ExplicitMatrix,
) raise @symphysics.PhysicsError {
  let mass = match self.implicit_mass_ {
    Some(value) => value
    None => mechanics_identity(self.states_.length())
  }
  let forcing = match self.implicit_forcing_ {
    Some(value) => value
    None => mechanics_matrix_column(self.rhs_)
  }
  let m_eq = mechanics_matrix_subs(mass, op_point)
  let a_eq = mechanics_matrix_subs(
    mechanics_matrix_jacobian(
      mechanics_matrix_entries(forcing).map(fn(row) { row[0] }),
      self.states_,
    ),
    op_point,
  )
  let b_eq = if self.inputs_.is_empty() {
    @symphysics.explicit_matrix_zeros(0, 0)
  } else {
    mechanics_matrix_subs(
      mechanics_matrix_jacobian(
        mechanics_matrix_entries(forcing).map(fn(row) { row[0] }),
        self.inputs_,
      ),
      op_point,
    )
  }
  if simplify {
    (
      mechanics_matrix_simplify(m_eq),
      mechanics_matrix_simplify(a_eq),
      mechanics_matrix_simplify(b_eq),
    )
  } else {
    (m_eq, a_eq, b_eq)
  }
}

///|
pub fn Linearizer::linearize(
  self : Linearizer,
  op_point? : Array[Substitution] = [],
  a_and_b? : Bool = false,
  simplify? : Bool = false,
) -> (@symphysics.ExplicitMatrix, @symphysics.ExplicitMatrix) raise @symphysics.PhysicsError {
  let (m, a, b) = self.linearize_mab(op_point~, simplify~)
  if a_and_b {
    let a_solved = if a.height() == 0 || a.width() == 0 {
      @symphysics.explicit_matrix_zeros(self.states_.length(), a.width())
    } else {
      self.perm_mat_.transpose().mul(mechanics_matrix_linear_solve(m, a))
    }
    let b_solved = if b.height() == 0 {
      b
    } else {
      self.perm_mat_.transpose().mul(mechanics_matrix_linear_solve(m, b))
    }
    let a_final = mechanics_matrix_simplify(a_solved)
    let b_final = mechanics_matrix_simplify(b_solved)
    if simplify {
      (a_final, b_final)
    } else {
      (a_final, b_final)
    }
  } else {
    let m_final = mechanics_matrix_simplify(m)
    let a_final = mechanics_matrix_simplify(a)
    if simplify {
      (m_final, a_final)
    } else {
      (m_final, a_final)
    }
  }
}
