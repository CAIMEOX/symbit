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
  state : @symcore.Expr
  prob : @symcore.Expr
} derive(Eq)

///|
pub struct DensityExpr {
  terms : Array[DensityTerm]
} derive(Eq)

///|
fn density_tuple_expr(term : DensityTerm) -> @symcore.Expr {
  @symcore.raw_function("Tuple", [term.state, term.prob])
}

///|
fn density_term_from_expr(expr : @symcore.Expr) -> DensityTerm? {
  match expr {
    @symcore.Expr::Function("Tuple", args) if args.length() == 2 =>
      Some(DensityTerm::{ state: args[0], prob: args[1] })
    _ => None
  }
}

///|
pub fn density(values : Array[(@symcore.Expr, @symcore.Expr)]) -> DensityExpr {
  let terms : Array[DensityTerm] = []
  for value in values {
    terms.push(DensityTerm::{ state: value.0, prob: value.1 })
  }
  DensityExpr::{ terms, }
}

///|
pub fn DensityExpr::as_expr(self : DensityExpr) -> @symcore.Expr {
  @symcore.raw_function("Density", self.terms.map(density_tuple_expr))
}

///|
pub fn DensityExpr::states(self : DensityExpr) -> @symcore.Expr {
  @symcore.raw_function("Tuple", self.terms.map(term => term.state))
}

///|
pub fn DensityExpr::probs(self : DensityExpr) -> @symcore.Expr {
  @symcore.raw_function("Tuple", self.terms.map(term => term.prob))
}

///|
pub fn DensityExpr::get_state(
  self : DensityExpr,
  index : Int,
) -> @symcore.Expr raise @symphysics.PhysicsError {
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
) -> @symcore.Expr raise @symphysics.PhysicsError {
  guard index >= 0 && index < self.terms.length() else {
    raise @symphysics.PhysicsError::IndexError(
      "density probability index out of range",
    )
  }
  self.terms[index].prob
}

///|
pub fn DensityExpr::apply_op(
  self : DensityExpr,
  op : @symcore.Expr,
) -> DensityExpr {
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
fn density_mul_flatten(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = []
  match lhs {
    @symcore.Expr::Mul(lhs_args) =>
      for arg in lhs_args {
        args.push(arg)
      }
    _ => args.push(lhs)
  }
  match rhs {
    @symcore.Expr::Mul(rhs_args) =>
      for arg in rhs_args {
        args.push(arg)
      }
    _ => args.push(rhs)
  }
  quantum_mul_from_args_preserve(args)
}

///|
fn density_expand_terms(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    @symcore.Expr::Add(args) => {
      let out : Array[@symcore.Expr] = []
      for arg in args {
        for term in density_expand_terms(arg) {
          out.push(term)
        }
      }
      out
    }
    @symcore.Expr::Mul(args) => {
      let mut partials : Array[@symcore.Expr] = [@symcore.int(1)]
      for arg in args {
        let expanded = density_expand_terms(arg)
        let next : Array[@symcore.Expr] = []
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
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise @symphysics.PhysicsError {
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
  let op : Result[@symcore.Expr, @symphysics.PhysicsError] = try? quantum_canonical_mul(
    @symcore.raw_mul([left_core, dagger(right_core)]),
  )
  let core = match op {
    Ok(expr) => expr
    Err(_) => @symcore.raw_mul([left_core, dagger(right_core)])
  }
  quantum_mul_from_args_preserve([left_scalar, right_scalar, core])
}

///|
pub fn DensityExpr::doit(self : DensityExpr) -> @symcore.Expr {
  let terms : Array[@symcore.Expr] = []
  for entry in self.terms {
    let expanded = density_expand_terms(entry.state)
    for left in expanded {
      for right in expanded {
        terms.push(entry.prob * (try! density_generate_outer_prod(left, right)))
      }
    }
  }
  quantum_add_from_args_preserve(terms)
}

///|
pub fn DensityExpr::trace(
  self : DensityExpr,
  indices? : Array[Int] = [],
) -> @symcore.Expr {
  tr_doit(tr(self.doit(), indices~))
}

///|
pub fn density_from_expr(expr : @symcore.Expr) -> DensityExpr? {
  match expr {
    @symcore.Expr::Function("Density", args) => {
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
fn density_infer_nqubits_expr(expr : @symcore.Expr) -> Int {
  match qubit_from_expr(expr) {
    Some(q) => q.nqubits()
    None =>
      match expr {
        @symcore.Expr::Add(args)
        | @symcore.Expr::Mul(args)
        | @symcore.Expr::Function(_, args) => {
          let mut inferred = 0
          for arg in args {
            let next = density_infer_nqubits_expr(arg)
            if next > inferred {
              inferred = next
            }
          }
          inferred
        }
        @symcore.Expr::Pow(base, exp) => {
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
fn density_infer_spin_j_expr(expr : @symcore.Expr) -> @symcore.Expr? {
  match jz_state_from_expr(expr) {
    Some(state) => Some(state.j)
    None =>
      match expr {
        @symcore.Expr::Add(args)
        | @symcore.Expr::Mul(args)
        | @symcore.Expr::Function(_, args) => {
          for arg in args {
            match density_infer_spin_j_expr(arg) {
              Some(value) => return Some(value)
              None => ()
            }
          }
          None
        }
        @symcore.Expr::Pow(base, exp) =>
          match density_infer_spin_j_expr(base) {
            Some(value) => Some(value)
            None => density_infer_spin_j_expr(exp)
          }
        _ => None
      }
  }
}

///|
fn density_infer_spin_j(
  density_expr : DensityExpr,
  fallback : @symcore.Expr,
) -> @symcore.Expr {
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
  basis : @symcore.Expr?,
  nqubits : Int,
  spin_j : @symcore.Expr,
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
    let contrib = (try! state_matrix.mul(matrix_dagger(state_matrix))).scale(
      term.prob,
    )
    acc = Some(
      match acc {
        Some(current) => try! current.add(contrib)
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
  basis? : @symcore.Expr? = None,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = try! @symcore.rational_from_ints(1, 2),
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
      if i != j && matrix.get(i, j) != @symcore.int(0) {
        return false
      }
    }
  }
  true
}

///|
fn matrix_diagonal_entries(
  matrix : @symphysics.ExplicitMatrix,
) -> Array[@symcore.Expr] raise @symphysics.PhysicsError {
  let out : Array[@symcore.Expr] = []
  for idx in 0..<matrix.height() {
    out.push(matrix.get(idx, idx))
  }
  out
}

///|
fn expr_log(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("log", [expr])
}

///|
fn expr_sqrt(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("sqrt", [expr])
}

///|
fn entropy_from_diagonal_entries(
  entries : Array[@symcore.Expr],
) -> @symcore.Expr {
  let unique : Array[@symcore.Expr] = []
  for entry in entries {
    if entry != @symcore.int(0) && !unique.contains(entry) {
      unique.push(entry)
    }
  }
  let terms : Array[@symcore.Expr] = []
  for entry in unique {
    terms.push(@symcore.int(-1) * entry * expr_log(entry))
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn matrix_is_rank_one_projector(matrix : @symphysics.ExplicitMatrix) -> Bool {
  guard matrix_is_square(matrix) else { return false }
  let trace_value = try! matrix_trace(matrix)
  if trace_value != @symcore.int(1) {
    return false
  }
  let product = try! matrix.mul(matrix)
  product == matrix
}

///|
fn density_matrix_from_expr(
  expr : @symcore.Expr,
  basis : @symcore.Expr?,
  nqubits : Int,
  spin_j : @symcore.Expr,
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
  expr : @symcore.Expr,
  basis? : @symcore.Expr? = None,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = try! @symcore.rational_from_ints(1, 2),
  ndim? : Int = 4,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  let matrix = try! density_matrix_from_expr(expr, basis, nqubits, spin_j, ndim)
  if (try! matrix_is_diagonal(matrix)) {
    entropy_from_diagonal_entries(try! matrix_diagonal_entries(matrix))
  } else if matrix_is_rank_one_projector(matrix) {
    @symcore.int(0)
  } else {
    raise @symphysics.PhysicsError::ValueError(
      "entropy currently expects a diagonal density matrix or a rank-one projector",
    )
  }
}

///|
pub fn DensityExpr::entropy(
  self : DensityExpr,
  basis? : @symcore.Expr? = None,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = try! @symcore.rational_from_ints(1, 2),
  ndim? : Int = 4,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  entropy(self.as_expr(), basis~, nqubits~, spin_j~, ndim~)
}

///|
fn fidelity_from_diagonal(
  left : @symphysics.ExplicitMatrix,
  right : @symphysics.ExplicitMatrix,
) -> @symcore.Expr {
  let left_diag = try! matrix_diagonal_entries(left)
  let right_diag = try! matrix_diagonal_entries(right)
  let terms : Array[@symcore.Expr] = []
  for idx in 0..<left_diag.length() {
    terms.push(expr_sqrt(left_diag[idx] * right_diag[idx]))
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn projector_overlap(
  left : @symphysics.ExplicitMatrix,
  right : @symphysics.ExplicitMatrix,
) -> @symcore.Expr {
  let product = try! left.mul(right)
  expr_sqrt(try! matrix_trace(product))
}

///|
pub fn fidelity(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
  basis? : @symcore.Expr? = None,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = try! @symcore.rational_from_ints(1, 2),
  ndim? : Int = 4,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  let left = try! density_matrix_from_expr(lhs, basis, nqubits, spin_j, ndim)
  let right = try! density_matrix_from_expr(rhs, basis, nqubits, spin_j, ndim)
  guard left.height() == right.height() &&
    left.width() == right.width() &&
    matrix_is_square(left) else {
    raise @symphysics.PhysicsError::ShapeError(
      "fidelity expects equal square density matrices",
    )
  }
  if (try! matrix_is_diagonal(left)) && (try! matrix_is_diagonal(right)) {
    fidelity_from_diagonal(left, right)
  } else if matrix_is_rank_one_projector(left) &&
    matrix_is_rank_one_projector(right) {
    projector_overlap(left, right)
  } else if matrix_is_rank_one_projector(left) ||
    matrix_is_rank_one_projector(right) {
    projector_overlap(left, right)
  } else {
    raise @symphysics.PhysicsError::ValueError(
      "fidelity currently expects diagonal density matrices or at least one rank-one projector",
    )
  }
}

///|
pub fn DensityExpr::fidelity(
  self : DensityExpr,
  other : DensityExpr,
  basis? : @symcore.Expr? = None,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = try! @symcore.rational_from_ints(1, 2),
  ndim? : Int = 4,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  fidelity(self.as_expr(), other.as_expr(), basis~, nqubits~, spin_j~, ndim~)
}
