///|
/// Mixed-state density operators aligned with the usable core of
/// `sympy.physics.quantum.density`.
///
/// A density operator stores pairs `(state, probability)` and supports:
/// - symbolic access to the stored states and probabilities;
/// - operator application to each state in the ensemble;
/// - expansion into weighted outer products via `doit()`;
/// - exact matrix representation for the currently supported concrete bases;
/// - entropy and fidelity on the diagonal/projector subset that SymBit can
///   represent exactly today.

///|
pub struct DensityTerm {
  state : Expr
  prob : Expr
} derive(Eq)

///|
pub struct DensityExpr {
  terms : Array[DensityTerm]
} derive(Eq)

///|
fn density_exact_rational(num : Int, den : Int) -> Expr {
  let exact : Result[Expr, @symnum.RationalError] = try? @symcore.rational_from_ints(
    num, den,
  )
  match exact {
    Ok(value) => value
    Err(_) => int(num) * @symcore.pow(int(den), int(-1))
  }
}

///|
fn density_tuple_expr(term : DensityTerm) -> Expr {
  @symcore.Expr::Tuple([term.state, term.prob])
}

///|
fn density_term_from_expr(expr : Expr) -> DensityTerm? {
  match @symcore.tuple_items(expr) {
    Some(args) if args.length() == 2 =>
      Some(DensityTerm::{ state: args[0], prob: args[1] })
    _ => None
  }
}

///|
pub fn density(values : Array[(Expr, Expr)]) -> DensityExpr {
  let terms : Array[DensityTerm] = []
  for value in values {
    terms.push(DensityTerm::{ state: value.0, prob: value.1 })
  }
  DensityExpr::{ terms, }
}

///|
pub fn DensityExpr::as_expr(self : DensityExpr) -> Expr {
  @symcore.raw_function("Density", self.terms.map(density_tuple_expr))
}

///|
pub fn DensityExpr::states(self : DensityExpr) -> Expr {
  @symcore.Expr::Tuple(self.terms.map(term => term.state))
}

///|
pub fn DensityExpr::probs(self : DensityExpr) -> Expr {
  @symcore.Expr::Tuple(self.terms.map(term => term.prob))
}

///|
pub fn DensityExpr::get_state(
  self : DensityExpr,
  index : Int,
) -> Expr raise @symphysics.PhysicsError {
  guard index >= 0 && index < self.terms.length() else {
    raise @symphysics.PhysicsError::IndexError(
      "density state index out of range",
    )
  }
  self.terms[index].state
}

///|
pub fn DensityExpr::get_prob(
  self : DensityExpr,
  index : Int,
) -> Expr raise @symphysics.PhysicsError {
  guard index >= 0 && index < self.terms.length() else {
    raise @symphysics.PhysicsError::IndexError(
      "density probability index out of range",
    )
  }
  self.terms[index].prob
}

///|
pub fn DensityExpr::apply_op(self : DensityExpr, op : Expr) -> DensityExpr {
  let terms : Array[DensityTerm] = []
  for term in self.terms {
    terms.push(DensityTerm::{
      state: quantum_mul_from_args_preserve([op, term.state]),
      prob: term.prob,
    })
  }
  DensityExpr::{ terms, }
}

///|
fn density_mul_flatten(lhs : Expr, rhs : Expr) -> Expr {
  let args : Array[Expr] = []
  match lhs {
    Expr::Mul(lhs_args) =>
      for arg in lhs_args {
        args.push(arg)
      }
    _ => args.push(lhs)
  }
  match rhs {
    Expr::Mul(rhs_args) =>
      for arg in rhs_args {
        args.push(arg)
      }
    _ => args.push(rhs)
  }
  quantum_mul_from_args_preserve(args)
}

///|
fn density_expand_terms(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Add(args) => {
      let out : Array[Expr] = []
      for arg in args {
        for term in density_expand_terms(arg) {
          out.push(term)
        }
      }
      out
    }
    Expr::Mul(args) => {
      let mut partials : Array[Expr] = [int(1)]
      for arg in args {
        let expanded = density_expand_terms(arg)
        let next : Array[Expr] = []
        for partial in partials {
          for term in expanded {
            next.push(density_mul_flatten(partial, term))
          }
        }
        partials = next
      }
      partials
    }
    _ => [expr]
  }
}

///|
fn density_generate_outer_prod(
  left : Expr,
  right : Expr,
) -> Expr raise @symphysics.PhysicsError {
  let (left_scalar, left_body) = quantum_split_scalar_factors(left)
  let (right_scalar, right_body) = quantum_split_scalar_factors(right)
  let left_core = left_body.unwrap_or_else(() => {
    raise @symphysics.PhysicsError::ValueError(
      "Density.doit() expects each term to contain a noncommutative state factor",
    )
  })
  let right_core = right_body.unwrap_or_else(() => {
    raise @symphysics.PhysicsError::ValueError(
      "Density.doit() expects each term to contain a noncommutative state factor",
    )
  })
  let op : Result[Expr, @symphysics.PhysicsError] = try? quantum_canonical_mul(
    @symcore.raw_mul([left_core, dagger(right_core)]),
  )
  let core = match op {
    Ok(expr) => expr
    Err(_) => @symcore.raw_mul([left_core, dagger(right_core)])
  }
  quantum_mul_from_args_preserve([left_scalar, right_scalar, core])
}

///|
pub fn DensityExpr::doit(self : DensityExpr) -> Expr {
  let terms : Array[Expr] = []
  for entry in self.terms {
    let expanded = density_expand_terms(entry.state)
    for left in expanded {
      for right in expanded {
        let outer = try density_generate_outer_prod(left, right) catch {
          _ => quantum_mul_from_args_preserve([left, dagger(right)])
        } noraise {
          value => value
        }
        terms.push(entry.prob * outer)
      }
    }
  }
  quantum_add_from_args_preserve(terms)
}

///|
pub fn DensityExpr::trace(
  self : DensityExpr,
  indices? : Array[Int] = [],
) -> Expr {
  tr_doit(tr(self.doit(), indices~))
}

///|
pub fn density_from_expr(expr : Expr) -> DensityExpr? {
  match @symcore.application_args(expr) {
    Some(args) if @symcore.application_has_name(expr, "Density") => {
      let terms : Array[DensityTerm] = []
      for arg in args {
        match density_term_from_expr(arg) {
          Some(term) => terms.push(term)
          None => return None
        }
      }
      Some(DensityExpr::{ terms, })
    }
    _ => None
  }
}

///|
fn density_infer_nqubits_expr(expr : Expr) -> Int {
  match qubit_from_expr(expr) {
    Some(q) => q.nqubits()
    None =>
      match expr {
        Expr::Add(args) | Expr::Mul(args) => {
          let mut inferred = 0
          for arg in args {
            let next = density_infer_nqubits_expr(arg)
            if next > inferred {
              inferred = next
            }
          }
          inferred
        }
        _ if @symcore.application_parts(expr) is Some(_) => {
          let mut inferred = 0
          for arg in @symcore.application_args(expr).unwrap_or([]) {
            let next = density_infer_nqubits_expr(arg)
            if next > inferred {
              inferred = next
            }
          }
          inferred
        }
        Expr::Pow(base, exp) => {
          let left = density_infer_nqubits_expr(base)
          let right = density_infer_nqubits_expr(exp)
          if left > right {
            left
          } else {
            right
          }
        }
        _ => 0
      }
  }
}

///|
fn density_infer_spin_j_expr(expr : Expr) -> Expr? {
  match jz_state_from_expr(expr) {
    Some(state) => Some(state.j)
    None =>
      match expr {
        Expr::Add(args) | Expr::Mul(args) => {
          for arg in args {
            match density_infer_spin_j_expr(arg) {
              Some(value) => return Some(value)
              None => ()
            }
          }
          None
        }
        _ if @symcore.application_parts(expr) is Some(_) => {
          for arg in @symcore.application_args(expr).unwrap_or([]) {
            match density_infer_spin_j_expr(arg) {
              Some(value) => return Some(value)
              None => ()
            }
          }
          None
        }
        Expr::Pow(base, exp) =>
          match density_infer_spin_j_expr(base) {
            Some(value) => Some(value)
            None => density_infer_spin_j_expr(exp)
          }
        _ => None
      }
  }
}

///|
fn density_infer_spin_j(density_expr : DensityExpr, fallback : Expr) -> Expr {
  for term in density_expr.terms {
    match density_infer_spin_j_expr(term.state) {
      Some(value) => return value
      None => ()
    }
  }
  fallback
}

///|
fn density_matrix(
  density_expr : DensityExpr,
  basis : Expr?,
  nqubits : Int,
  spin_j : Expr,
  ndim : Int,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  let effective_nqubits = if nqubits > 0 {
    nqubits
  } else {
    let mut inferred = 0
    for term in density_expr.terms {
      let next = density_infer_nqubits_expr(term.state)
      if next > inferred {
        inferred = next
      }
    }
    inferred
  }
  let mut acc : @symphysics.ExplicitMatrix? = None
  for term in density_expr.terms {
    let represented = represent(
      term.state,
      basis~,
      nqubits=effective_nqubits,
      spin_j~,
      ndim~,
    )
    let state_matrix = match represented {
      MatrixScalarValue::Matrix(matrix) => matrix
      MatrixScalarValue::Scalar(_) =>
        raise @symphysics.PhysicsError::ValueError(
          "Density representation expects states with matrix representations",
        )
    }
    guard state_matrix.width() == 1 else {
      raise @symphysics.PhysicsError::ShapeError(
        "Density representation currently expects ket-like column states",
      )
    }
    let contrib = state_matrix.mul(matrix_dagger(state_matrix)).scale(term.prob)
    acc = Some(
      match acc {
        Some(current) => current.add(contrib)
        None => contrib
      },
    )
  }
  match acc {
    Some(matrix) => MatrixScalarValue::Matrix(matrix)
    None => MatrixScalarValue::Matrix(@symphysics.explicit_matrix_from_rows([]))
  }
}

///|
pub fn DensityExpr::represent(
  self : DensityExpr,
  basis? : Expr? = None,
  nqubits? : Int = 0,
  spin_j? : Expr = density_exact_rational(1, 2),
  ndim? : Int = 4,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  density_matrix(self, basis, nqubits, spin_j, ndim)
}

///|
fn matrix_is_square(matrix : @symphysics.ExplicitMatrix) -> Bool {
  matrix.height() == matrix.width()
}

///|
fn matrix_is_diagonal(
  matrix : @symphysics.ExplicitMatrix,
) -> Bool raise @symphysics.PhysicsError {
  guard matrix_is_square(matrix) else { return false }
  for i in 0..<matrix.height() {
    for j in 0..<matrix.width() {
      if i != j && matrix.get(i, j) != int(0) {
        return false
      }
    }
  }
  true
}

///|
fn matrix_diagonal_entries(
  matrix : @symphysics.ExplicitMatrix,
) -> Array[Expr] raise @symphysics.PhysicsError {
  let out : Array[Expr] = []
  for idx in 0..<matrix.height() {
    out.push(matrix.get(idx, idx))
  }
  out
}

///|
fn expr_log(expr : Expr) -> Expr {
  @symcore.raw_function("log", [expr])
}

///|
fn expr_sqrt(expr : Expr) -> Expr {
  @symcore.raw_function("sqrt", [expr])
}

///|
fn entropy_from_diagonal_entries(entries : Array[Expr]) -> Expr {
  let unique : Array[Expr] = []
  for entry in entries {
    if entry != int(0) && !unique.contains(entry) {
      unique.push(entry)
    }
  }
  let terms : Array[Expr] = []
  for entry in unique {
    terms.push(int(-1) * entry * expr_log(entry))
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn entropy_term(entry : Expr) -> Expr {
  if entry == int(0) {
    int(0)
  } else {
    int(-1) * entry * expr_log(entry)
  }
}

///|
fn matrix_is_2x2(matrix : @symphysics.ExplicitMatrix) -> Bool {
  matrix.height() == 2 && matrix.width() == 2
}

///|
fn matrix_det_2x2(
  matrix : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  guard matrix_is_2x2(matrix) else {
    raise @symphysics.PhysicsError::ShapeError(
      "2x2 determinant expects a 2x2 matrix",
    )
  }
  matrix.get(0, 0) * matrix.get(1, 1) - matrix.get(0, 1) * matrix.get(1, 0)
}

///|
fn density_matrix_eigenvalues_2x2(
  matrix : @symphysics.ExplicitMatrix,
) -> Array[Expr] raise @symphysics.PhysicsError {
  let trace_value = matrix_trace(matrix)
  let det_value = matrix_det_2x2(matrix)
  let discr = expr_sqrt(trace_value * trace_value - int(4) * det_value)
  let half = density_exact_rational(1, 2)
  [half * (trace_value + discr), half * (trace_value - discr)]
}

///|
fn entropy_from_eigenvalues(eigenvalues : Array[Expr]) -> Expr {
  quantum_add_from_args_preserve(eigenvalues.map(entry => entropy_term(entry)))
}

///|
fn matrix_is_rank_one_projector(
  matrix : @symphysics.ExplicitMatrix,
) -> Bool raise @symphysics.PhysicsError {
  guard matrix_is_square(matrix) else { return false }
  let trace_value = matrix_trace(matrix)
  if trace_value != int(1) {
    return false
  }
  let product = matrix.mul(matrix)
  product == matrix
}

///|
fn density_matrix_from_expr(
  expr : Expr,
  basis : Expr?,
  nqubits : Int,
  spin_j : Expr,
  ndim : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match density_from_expr(expr) {
    Some(density_expr) => {
      let effective_spin_j = density_infer_spin_j(density_expr, spin_j)
      match
        density_matrix(density_expr, basis, nqubits, effective_spin_j, ndim) {
        MatrixScalarValue::Matrix(matrix) => matrix
        MatrixScalarValue::Scalar(_) =>
          raise @symphysics.PhysicsError::ValueError(
            "density should represent as a matrix",
          )
      }
    }
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "Expected a Density expression",
      )
  }
}

///|
pub fn entropy(
  expr : Expr,
  basis? : Expr? = None,
  nqubits? : Int = 0,
  spin_j? : Expr = density_exact_rational(1, 2),
  ndim? : Int = 4,
) -> Expr raise @symphysics.PhysicsError {
  let matrix = density_matrix_from_expr(expr, basis, nqubits, spin_j, ndim)
  if matrix_is_diagonal(matrix) {
    entropy_from_diagonal_entries(matrix_diagonal_entries(matrix))
  } else if matrix_is_rank_one_projector(matrix) {
    int(0)
  } else if matrix_is_2x2(matrix) {
    entropy_from_eigenvalues(density_matrix_eigenvalues_2x2(matrix))
  } else {
    raise @symphysics.PhysicsError::ValueError(
      "entropy currently expects a diagonal density matrix, a rank-one projector, or a 2x2 density matrix",
    )
  }
}

///|
pub fn DensityExpr::entropy(
  self : DensityExpr,
  basis? : Expr? = None,
  nqubits? : Int = 0,
  spin_j? : Expr = density_exact_rational(1, 2),
  ndim? : Int = 4,
) -> Expr raise @symphysics.PhysicsError {
  entropy(self.as_expr(), basis~, nqubits~, spin_j~, ndim~)
}

///|
fn fidelity_from_diagonal(
  left : @symphysics.ExplicitMatrix,
  right : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  let left_diag = matrix_diagonal_entries(left)
  let right_diag = matrix_diagonal_entries(right)
  let terms : Array[Expr] = []
  for idx in 0..<left_diag.length() {
    terms.push(expr_sqrt(left_diag[idx] * right_diag[idx]))
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn projector_overlap(
  left : @symphysics.ExplicitMatrix,
  right : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  let product = left.mul(right)
  expr_sqrt(matrix_trace(product))
}

///|
fn fidelity_2x2(
  left : @symphysics.ExplicitMatrix,
  right : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  let product = left.mul(right)
  expr_sqrt(
    matrix_trace(product) +
    int(2) * expr_sqrt(matrix_det_2x2(left) * matrix_det_2x2(right)),
  )
}

///|
pub fn fidelity(
  lhs : Expr,
  rhs : Expr,
  basis? : Expr? = None,
  nqubits? : Int = 0,
  spin_j? : Expr = density_exact_rational(1, 2),
  ndim? : Int = 4,
) -> Expr raise @symphysics.PhysicsError {
  let left = density_matrix_from_expr(lhs, basis, nqubits, spin_j, ndim)
  let right = density_matrix_from_expr(rhs, basis, nqubits, spin_j, ndim)
  guard left.height() == right.height() &&
    left.width() == right.width() &&
    matrix_is_square(left) else {
    raise @symphysics.PhysicsError::ShapeError(
      "fidelity expects equal square density matrices",
    )
  }
  if matrix_is_diagonal(left) && matrix_is_diagonal(right) {
    fidelity_from_diagonal(left, right)
  } else if matrix_is_rank_one_projector(left) &&
    matrix_is_rank_one_projector(right) {
    projector_overlap(left, right)
  } else if matrix_is_rank_one_projector(left) ||
    matrix_is_rank_one_projector(right) {
    projector_overlap(left, right)
  } else if matrix_is_2x2(left) && matrix_is_2x2(right) {
    fidelity_2x2(left, right)
  } else {
    raise @symphysics.PhysicsError::ValueError(
      "fidelity currently expects diagonal density matrices, at least one rank-one projector, or 2x2 density matrices",
    )
  }
}

///|
pub fn DensityExpr::fidelity(
  self : DensityExpr,
  other : DensityExpr,
  basis? : Expr? = None,
  nqubits? : Int = 0,
  spin_j? : Expr = density_exact_rational(1, 2),
  ndim? : Int = 4,
) -> Expr raise @symphysics.PhysicsError {
  fidelity(self.as_expr(), other.as_expr(), basis~, nqubits~, spin_j~, ndim~)
}
