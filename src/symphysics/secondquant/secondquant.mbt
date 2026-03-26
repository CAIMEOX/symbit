///|
/// Core helpers for the first `sympy.physics.secondquant` migration tranche.
///
/// This package starts with the bosonic Fock-space surface that other
/// second-quantized algorithms depend on: creation/annihilation operators,
/// bosonic Fock states, bosonic bases, operator application, matrix elements,
/// and commutator/normal-order wrappers. The implementation delegates the
/// low-level symbolic algebra to `symphysics/quantum` so Dagger, qapply,
/// InnerProduct, and ordering rules stay consistent across the physics port.

///|
pub struct BosonState {
  occupations : Array[Expr]
} derive(Eq)

///|
pub struct BosonicOperatorExpr {
  index : Expr
  is_annihilation : Bool
} derive(Eq)

///|
pub struct VarBosonicBasis {
  n_max : Int
  basis : Array[Expr]
} derive(Eq)

///|
pub struct FixedBosonicBasis {
  n_particles : Int
  n_levels : Int
  basis : Array[Expr]
} derive(Eq)

///|
pub enum BosonicBasisSet {
  Var(VarBosonicBasis)
  Fixed(FixedBosonicBasis)
} derive(Eq)

///|
///|
fn sq_tuple_string(items : Array[Expr]) -> String {
  let rendered = items.map(@symprint.to_string).join(", ")
  if items.length() == 1 {
    "(\{rendered},)"
  } else {
    "(\{rendered})"
  }
}

///|
fn sq_fock_state_repr(items : Array[Expr]) -> String {
  "FockState(\{sq_tuple_string(items)})"
}

///|
fn sq_boson_ket_expr(items : Array[Expr]) -> Expr {
  @symcore.raw_function("FockStateBosonKet", [Expr::Tuple(items)])
}

///|
fn sq_boson_bra_expr(items : Array[Expr]) -> Expr {
  @symcore.raw_function("FockStateBosonBra", [Expr::Tuple(items)])
}

///|
fn sq_boson_items_from_expr(expr : Expr) -> Array[Expr]? {
  if @symquant.quantum_expr_has_any_name(expr, [
      "FockStateBosonKet", "FockStateBosonBra", "FockState",
    ]) {
    match @symquant.quantum_expr_args(expr) {
      Some([arg]) => @symcore.tuple_items(arg)
      _ => None
    }
  } else {
    None
  }
}

///|
fn sq_boson_basis_list_string(states : Array[Expr]) -> String {
  let rendered = states
    .map(expr => {
      match sq_boson_items_from_expr(expr) {
        Some(items) => sq_fock_state_repr(items)
        None => @symprint.to_string(expr)
      }
    })
    .join(", ")
  "[\{rendered}]"
}

///|
fn sq_integral_index(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn sq_state_at(
  items : Array[Expr],
  index : Int,
) -> Expr raise @symphysics.PhysicsError {
  if index < 0 || index >= items.length() {
    raise @symphysics.PhysicsError::IndexError("boson state index out of range")
  }
  items[index]
}

///|
fn sq_fixed_boson_states(
  remaining : Int,
  levels_left : Int,
) -> Array[Array[Expr]] {
  if levels_left == 1 {
    return [[int(remaining)]]
  }
  let out : Array[Array[Expr]] = []
  for occ in 0..<=remaining {
    let leading = remaining - occ
    for tail in sq_fixed_boson_states(occ, levels_left - 1) {
      let row : Array[Expr] = [int(leading)]
      for item in tail {
        row.push(item)
      }
      out.push(row)
    }
  }
  out
}

///|
pub fn boson_state(occupations : Array[Expr]) -> BosonState {
  BosonState::{ occupations: occupations.copy() }
}

///|
pub fn BosonState::len(self : BosonState) -> Int {
  self.occupations.length()
}

///|
pub fn BosonState::get(
  self : BosonState,
  index : Int,
) -> Expr raise @symphysics.PhysicsError {
  sq_state_at(self.occupations, index)
}

///|
pub fn BosonState::up(
  self : BosonState,
  index : Int,
) -> BosonState raise @symphysics.PhysicsError {
  ignore(sq_state_at(self.occupations, index))
  let updated = self.occupations.copy()
  updated[index] = updated[index] + int(1)
  boson_state(updated)
}

///|
pub fn BosonState::down(
  self : BosonState,
  index : Int,
) -> BosonState? raise @symphysics.PhysicsError {
  let current = sq_state_at(self.occupations, index)
  if current == int(0) {
    None
  } else {
    let updated = self.occupations.copy()
    updated[index] = current - int(1)
    Some(boson_state(updated))
  }
}

///|
pub fn BosonState::as_expr(self : BosonState) -> Expr {
  @symcore.raw_function("FockState", [Expr::Tuple(self.occupations)])
}

///|
pub fn BosonState::as_ket_expr(self : BosonState) -> Expr {
  sq_boson_ket_expr(self.occupations)
}

///|
pub fn BosonState::as_bra_expr(self : BosonState) -> Expr {
  sq_boson_bra_expr(self.occupations)
}

///|
pub impl Show for BosonState with to_string(self) {
  sq_tuple_string(self.occupations)
}

///|
pub impl Show for BosonState with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn BosonState::repr(self : BosonState) -> String {
  sq_fock_state_repr(self.occupations)
}

///|
pub fn boson_ket(occupations : Array[Expr]) -> Expr {
  sq_boson_ket_expr(occupations)
}

///|
pub fn boson_bra(occupations : Array[Expr]) -> Expr {
  sq_boson_bra_expr(occupations)
}

///|
pub fn boson_state_from_expr(expr : Expr) -> BosonState? {
  match sq_boson_items_from_expr(expr) {
    Some(items) => Some(boson_state(items))
    None => None
  }
}

///|
pub fn boson_annihilator(index : Expr) -> BosonicOperatorExpr {
  BosonicOperatorExpr::{ index, is_annihilation: true }
}

///|
pub fn boson_creator(index : Expr) -> BosonicOperatorExpr {
  BosonicOperatorExpr::{ index, is_annihilation: false }
}

///|
pub fn BosonicOperatorExpr::as_expr(self : BosonicOperatorExpr) -> Expr {
  @symcore.raw_function(
    if self.is_annihilation {
      "AnnihilateBoson"
    } else {
      "CreateBoson"
    },
    [self.index],
  )
}

///|
pub impl Show for BosonicOperatorExpr with to_string(self) {
  if self.is_annihilation {
    "b(\{@symprint.to_string(self.index)})"
  } else {
    "b+(\{@symprint.to_string(self.index)})"
  }
}

///|
pub impl Show for BosonicOperatorExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn BosonicOperatorExpr::repr(self : BosonicOperatorExpr) -> String {
  let class_name = if self.is_annihilation {
    "AnnihilateBoson"
  } else {
    "CreateBoson"
  }
  "\{class_name}(\{@symprint.to_string(self.index)})"
}

///|
pub fn BosonicOperatorExpr::dagger(
  self : BosonicOperatorExpr,
) -> BosonicOperatorExpr {
  BosonicOperatorExpr::{
    index: self.index,
    is_annihilation: !self.is_annihilation,
  }
}

///|
pub fn BosonicOperatorExpr::is_symbolic(self : BosonicOperatorExpr) -> Bool {
  sq_integral_index(self.index) is None
}

///|
pub fn BosonicOperatorExpr::state(self : BosonicOperatorExpr) -> Expr {
  self.index
}

///|
pub fn BosonicOperatorExpr::apply_operator(
  self : BosonicOperatorExpr,
  state : Expr,
) -> Expr {
  if self.is_symbolic() {
    @symcore.raw_mul([self.as_expr(), state])
  } else {
    @symquant.qapply(@symcore.raw_mul([self.as_expr(), state]))
  }
}

///|
pub fn variable_bosonic_basis(n_max : Int) -> VarBosonicBasis {
  let basis : Array[Expr] = []
  for i in 0..<n_max {
    basis.push(boson_ket([int(i)]))
  }
  VarBosonicBasis::{ n_max, basis }
}

///|
pub fn fixed_bosonic_basis(
  n_particles : Int,
  n_levels : Int,
) -> FixedBosonicBasis {
  let basis : Array[Expr] = []
  for state in sq_fixed_boson_states(n_particles, n_levels) {
    basis.push(boson_ket(state))
  }
  FixedBosonicBasis::{ n_particles, n_levels, basis }
}

///|
pub fn VarBosonicBasis::len(self : VarBosonicBasis) -> Int {
  self.basis.length()
}

///|
pub fn VarBosonicBasis::state(
  self : VarBosonicBasis,
  index : Int,
) -> Expr raise @symphysics.PhysicsError {
  if index < 0 || index >= self.basis.length() {
    raise @symphysics.PhysicsError::IndexError("basis index out of range")
  }
  self.basis[index]
}

///|
pub fn VarBosonicBasis::index(
  self : VarBosonicBasis,
  state : Expr,
) -> Int raise @symphysics.PhysicsError {
  for idx in 0..<self.basis.length() {
    if self.basis[idx] == state {
      return idx
    }
  }
  raise @symphysics.PhysicsError::ValueError(
    "state not present in bosonic basis",
  )
}

///|
pub impl Show for VarBosonicBasis with to_string(self) {
  sq_boson_basis_list_string(self.basis)
}

///|
pub impl Show for VarBosonicBasis with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn VarBosonicBasis::repr(self : VarBosonicBasis) -> String {
  self.to_string()
}

///|
pub fn VarBosonicBasis::as_basis(self : VarBosonicBasis) -> BosonicBasisSet {
  BosonicBasisSet::Var(self)
}

///|
pub fn FixedBosonicBasis::len(self : FixedBosonicBasis) -> Int {
  self.basis.length()
}

///|
pub fn FixedBosonicBasis::state(
  self : FixedBosonicBasis,
  index : Int,
) -> Expr raise @symphysics.PhysicsError {
  if index < 0 || index >= self.basis.length() {
    raise @symphysics.PhysicsError::IndexError("basis index out of range")
  }
  self.basis[index]
}

///|
pub fn FixedBosonicBasis::index(
  self : FixedBosonicBasis,
  state : Expr,
) -> Int raise @symphysics.PhysicsError {
  for idx in 0..<self.basis.length() {
    if self.basis[idx] == state {
      return idx
    }
  }
  raise @symphysics.PhysicsError::ValueError(
    "state not present in bosonic basis",
  )
}

///|
pub impl Show for FixedBosonicBasis with to_string(self) {
  sq_boson_basis_list_string(self.basis)
}

///|
pub impl Show for FixedBosonicBasis with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn FixedBosonicBasis::repr(self : FixedBosonicBasis) -> String {
  self.to_string()
}

///|
pub fn FixedBosonicBasis::as_basis(self : FixedBosonicBasis) -> BosonicBasisSet {
  BosonicBasisSet::Fixed(self)
}

///|
pub fn BosonicBasisSet::len(self : BosonicBasisSet) -> Int {
  match self {
    BosonicBasisSet::Var(basis) => basis.len()
    BosonicBasisSet::Fixed(basis) => basis.len()
  }
}

///|
pub fn BosonicBasisSet::state(
  self : BosonicBasisSet,
  index : Int,
) -> Expr raise @symphysics.PhysicsError {
  match self {
    BosonicBasisSet::Var(basis) => basis.state(index)
    BosonicBasisSet::Fixed(basis) => basis.state(index)
  }
}

///|
pub fn BosonicBasisSet::index(
  self : BosonicBasisSet,
  state : Expr,
) -> Int raise @symphysics.PhysicsError {
  match self {
    BosonicBasisSet::Var(basis) => basis.index(state)
    BosonicBasisSet::Fixed(basis) => basis.index(state)
  }
}

///|
pub impl Show for BosonicBasisSet with to_string(self) {
  match self {
    BosonicBasisSet::Var(basis) => basis.to_string()
    BosonicBasisSet::Fixed(basis) => basis.to_string()
  }
}

///|
pub impl Show for BosonicBasisSet with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn secondquant_dagger(expr : Expr) -> Expr {
  match sq_secondquant_dagger_local(expr) {
    Some(value) => value
    None => @symquant.dagger(expr)
  }
}

///|
pub fn secondquant_inner_product(bra : Expr, ket : Expr) -> Expr {
  match sq_secondquant_inner_product_local(bra, ket) {
    Some(value) => value
    None => @symquant.inner_product(bra, ket)
  }
}

///|
pub fn secondquant_apply_operators(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) =>
      @symcore.raw_add(args.map(term => secondquant_apply_operators(term)))
    Expr::Mul(args) =>
      match sq_apply_fermion_mul(args) {
        Some(value) => value
        None => @symquant.qapply(expr)
      }
    _ => @symquant.qapply(expr)
  }
}

///|
pub fn secondquant_commutator(lhs : Expr, rhs : Expr) -> Expr {
  @symquant.commutator(lhs, rhs)
}

///|
pub fn secondquant_no(expr : Expr) -> Expr {
  no(expr)
}

///|
pub fn secondquant_contraction(lhs : Expr, rhs : Expr) -> Expr {
  contraction(lhs, rhs)
}

///|
pub fn secondquant_evaluate_deltas(expr : Expr) -> Expr {
  evaluate_deltas(expr)
}

///|
pub fn secondquant_substitute_dummies(
  expr : Expr,
  new_indices? : Bool = false,
  pretty_indices? : Map[String, String] = {},
) -> Expr {
  substitute_dummies(expr, new_indices~, pretty_indices~)
}

///|
pub fn secondquant_wicks(
  expr : Expr,
  simplify_kronecker_deltas? : Bool = false,
  expand? : Bool = true,
  simplify_dummies? : Bool = false,
  keep_only_fully_contracted? : Bool = false,
) -> Expr {
  wicks(
    expr,
    simplify_kronecker_deltas~,
    expand~,
    simplify_dummies~,
    keep_only_fully_contracted~,
  )
}

///|
pub fn secondquant_permutation_operator(lhs : Expr, rhs : Expr) -> Expr {
  permutation_operator(lhs, rhs)
}

///|
pub fn secondquant_simplify_index_permutations(
  expr : Expr,
  permutation_operators : Array[Expr],
) -> Expr {
  simplify_index_permutations(expr, permutation_operators)
}

///|
fn sq_is_boson_annihilator(expr : Expr) -> Expr? {
  match @symquant.quantum_expr_args(expr) {
    Some([arg]) if @symquant.quantum_expr_has_name(expr, "AnnihilateBoson") =>
      Some(arg)
    _ => None
  }
}

///|
fn sq_is_boson_creator(expr : Expr) -> Expr? {
  match @symquant.quantum_expr_args(expr) {
    Some([arg]) if @symquant.quantum_expr_has_name(expr, "CreateBoson") =>
      Some(arg)
    _ => None
  }
}

///|
fn sq_normal_order_product(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) if args.length() >= 2 => {
      for idx in 0..<(args.length() - 1) {
        match
          (
            sq_is_boson_annihilator(args[idx]),
            sq_is_boson_creator(args[idx + 1]),
          ) {
          (Some(left_idx), Some(right_idx)) => {
            let prefix = args[0:idx]
            let suffix = args[idx + 2:args.length()]
            let swapped = Array::new()
            for item in prefix {
              swapped.push(item)
            }
            swapped.push(args[idx + 1])
            swapped.push(args[idx])
            for item in suffix {
              swapped.push(item)
            }
            let comm_term = if left_idx == right_idx {
              int(1)
            } else {
              @symcore.raw_function("KroneckerDelta", [left_idx, right_idx])
            }
            let ordered = sq_normal_order_product(@symcore.raw_mul(swapped))
            let leading : Array[Expr] = []
            for item in prefix {
              leading.push(item)
            }
            if comm_term != int(1) || prefix.length() + suffix.length() > 0 {
              if comm_term != int(1) {
                leading.push(comm_term)
              }
              for item in suffix {
                leading.push(item)
              }
            }
            let correction = if leading.is_empty() {
              int(1)
            } else {
              sq_normal_order_product(@symcore.raw_mul(leading))
            }
            return ordered + correction
          }
          _ => ()
        }
      }
      expr
    }
    _ => expr
  }
}

///|
pub fn secondquant_normal_ordered_form(
  expr : Expr,
  independent? : Bool = false,
  recursive_limit? : Int = 10,
) -> Expr {
  ignore(independent)
  ignore(recursive_limit)
  match expr {
    Expr::Add(args) =>
      @symcore.raw_add(args.map(term => secondquant_normal_ordered_form(term)))
    _ => sq_normal_order_product(expr)
  }
}

///|
fn sq_scale_inner_product(bra : Expr, expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) =>
      @symcore.raw_add(args.map(term => sq_scale_inner_product(bra, term)))
    Expr::Mul(args) => {
      let scalar_factors : Array[Expr] = []
      let ket_factors : Array[Expr] = []
      for arg in args {
        if @symquant.quantum_is_ket_expr(arg) {
          ket_factors.push(arg)
        } else {
          scalar_factors.push(arg)
        }
      }
      if ket_factors.length() == 1 {
        let scalar = if scalar_factors.is_empty() {
          int(1)
        } else {
          @symcore.raw_mul(scalar_factors)
        }
        scalar * secondquant_inner_product(bra, ket_factors[0])
      } else {
        bra * expr
      }
    }
    _ if @symquant.quantum_is_ket_expr(expr) =>
      secondquant_inner_product(bra, expr)
    _ => bra * expr
  }
}

///|
pub fn secondquant_matrix_rep(
  op : Expr,
  basis : BosonicBasisSet,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let rows : Array[Array[Expr]] = []
  for i in 0..<basis.len() {
    let row : Array[Expr] = []
    let bra = secondquant_dagger(basis.state(i))
    for j in 0..<basis.len() {
      let acted = secondquant_apply_operators(
        @symcore.raw_mul([op, basis.state(j)]),
      )
      row.push(sq_scale_inner_product(bra, acted))
    }
    rows.push(row)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}
