///|
/// Shared mechanics method utilities aligned with the high-value surface of
/// `sympy.physics.mechanics.method` and the linearization helpers used by
/// Kane/Lagrange backends.

///|
pub struct Linearizer {
  states_ : Array[@symcore.Expr]
  inputs_ : Array[@symcore.Expr]
  rhs_ : Array[@symcore.Expr]
} derive(Eq)

///|
fn mechanics_expr_div(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
  mech_simplify_expr(lhs * (rhs ^ @symcore.int(-1)))
}

///|
fn mechanics_matrix_column(
  exprs : Array[@symcore.Expr],
) -> @symphysics.ExplicitMatrix {
  let rows : Array[Array[@symcore.Expr]] = []
  for expr in exprs {
    rows.push([expr])
  }
  try! @symphysics.explicit_matrix_from_rows(rows)
}

///|
fn mechanics_matrix_entries(
  matrix : @symphysics.ExplicitMatrix,
) -> Array[Array[@symcore.Expr]] {
  let rows : Array[Array[@symcore.Expr]] = []
  for i in 0..<matrix.height() {
    let row : Array[@symcore.Expr] = []
    for j in 0..<matrix.width() {
      row.push(try! matrix.get(i, j))
    }
    rows.push(row)
  }
  rows
}

///|
fn mechanics_matrix_jacobian(
  exprs : Array[@symcore.Expr],
  vars : Array[@symcore.Expr],
) -> @symphysics.ExplicitMatrix {
  let rows : Array[Array[@symcore.Expr]] = []
  for expr in exprs {
    let row : Array[@symcore.Expr] = []
    for wrt in vars {
      row.push(mech_simplify_expr(@symcalculus.diff(expr, wrt)))
    }
    rows.push(row)
  }
  try! @symphysics.explicit_matrix_from_rows(rows)
}

///|
fn mechanics_matrix_subs(
  matrix : @symphysics.ExplicitMatrix,
  substitutions : Array[Substitution],
) -> @symphysics.ExplicitMatrix {
  msubs_matrix(matrix, substitutions)
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
  rhs : Array[@symcore.Expr],
) -> Array[@symcore.Expr] raise @symphysics.PhysicsError {
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

  let solution : Array[@symcore.Expr] = Array::make(ncols, @symcore.int(0))
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
fn mechanics_matrix_negative_residual(
  exprs : Array[@symcore.Expr],
  vars : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let zero_subs : Array[Substitution] = []
  for wrt in vars {
    zero_subs.push((wrt, @symcore.int(0)))
  }
  exprs.map(fn(expr) {
    mech_simplify_expr(@symcore.int(-1) * msubs_expr(expr, zero_subs))
  })
}

///|
pub fn linearizer(
  states : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
  inputs? : Array[@symcore.Expr] = [],
) -> Linearizer {
  Linearizer::{
    states_: states.copy(),
    inputs_: inputs.copy(),
    rhs_: rhs.copy(),
  }
}

///|
pub fn Linearizer::permutation_matrix(
  self : Linearizer,
) -> @symphysics.ExplicitMatrix {
  mechanics_identity(self.states_.length())
}

///|
pub fn Linearizer::states(self : Linearizer) -> Array[@symcore.Expr] {
  self.states_.copy()
}

///|
pub fn Linearizer::inputs(self : Linearizer) -> Array[@symcore.Expr] {
  self.inputs_.copy()
}

///|
pub fn Linearizer::rhs(self : Linearizer) -> Array[@symcore.Expr] {
  self.rhs_.copy()
}

///|
pub fn Linearizer::linearize(
  self : Linearizer,
  op_point? : Array[Substitution] = [],
  a_and_b? : Bool = false,
) -> (@symphysics.ExplicitMatrix, @symphysics.ExplicitMatrix) {
  let a = mechanics_matrix_subs(
    mechanics_matrix_jacobian(self.rhs_, self.states_),
    op_point,
  )
  let b = mechanics_matrix_subs(
    mechanics_matrix_jacobian(self.rhs_, self.inputs_),
    op_point,
  )
  if a_and_b {
    (a, b)
  } else {
    (a, b)
  }
}
