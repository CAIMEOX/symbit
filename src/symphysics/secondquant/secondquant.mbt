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
  occupations : Array[@symcore.Expr]
} derive(Eq)

///|
pub struct BosonicOperatorExpr {
  index : @symcore.Expr
  is_annihilation : Bool
} derive(Eq)

///|
pub struct VarBosonicBasis {
  n_max : Int
  basis : Array[@symcore.Expr]
} derive(Eq)

///|
pub struct FixedBosonicBasis {
  n_particles : Int
  n_levels : Int
  basis : Array[@symcore.Expr]
} derive(Eq)

///|
pub enum BosonicBasisSet {
  Var(VarBosonicBasis)
  Fixed(FixedBosonicBasis)
} derive(Eq)

///|
fn sq_tuple_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.raw_function("Tuple", items)
}

///|
fn sq_tuple_string(items : Array[@symcore.Expr]) -> String {
  let rendered = items.map(@symprint.to_string).join(", ")
  if items.length() == 1 {
    "(\{rendered},)"
  } else {
    "(\{rendered})"
  }
}

///|
fn sq_fock_state_repr(items : Array[@symcore.Expr]) -> String {
  "FockState(\{sq_tuple_string(items)})"
}

///|
fn sq_boson_ket_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.raw_function("FockStateBosonKet", [sq_tuple_expr(items)])
}

///|
fn sq_boson_bra_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.raw_function("FockStateBosonBra", [sq_tuple_expr(items)])
}

///|
fn sq_boson_items_from_expr(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function(name, args) if (
      name == "FockStateBosonKet" || name == "FockStateBosonBra" || name == "FockState"
    ) && args.length() == 1 =>
      match args[0] {
        @symcore.Expr::Function("Tuple", items) => Some(items)
        _ => None
      }
    _ => None
  }
}

///|
fn sq_boson_basis_list_string(states : Array[@symcore.Expr]) -> String {
  let rendered = states.map(expr =>
    match sq_boson_items_from_expr(expr) {
      Some(items) => sq_fock_state_repr(items)
      None => @symprint.to_string(expr)
    }
  ).join(", ")
  "[\{rendered}]"
}

///|
fn sq_integral_index(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn sq_state_at(
  items : Array[@symcore.Expr],
  index : Int,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  if index < 0 || index >= items.length() {
    raise @symphysics.PhysicsError::IndexError("boson state index out of range")
  }
  items[index]
}

///|
fn sq_fixed_boson_states(
  remaining : Int,
  levels_left : Int,
) -> Array[Array[@symcore.Expr]] {
  if levels_left == 1 {
    return [[@symcore.int(remaining)]]
  }
  let out : Array[Array[@symcore.Expr]] = []
  for occ in 0..=remaining {
    let leading = remaining - occ
    for tail in sq_fixed_boson_states(occ, levels_left - 1) {
      let row : Array[@symcore.Expr] = [@symcore.int(leading)]
      for item in tail {
        row.push(item)
      }
      out.push(row)
    }
  }
  out
}

///|
pub fn boson_state(occupations : Array[@symcore.Expr]) -> BosonState {
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
) -> @symcore.Expr raise @symphysics.PhysicsError {
  sq_state_at(self.occupations, index)
}

///|
pub fn BosonState::up(
  self : BosonState,
  index : Int,
) -> BosonState raise @symphysics.PhysicsError {
  ignore(sq_state_at(self.occupations, index))
  let updated = self.occupations.copy()
  updated[index] = updated[index] + @symcore.int(1)
  boson_state(updated)
}

///|
pub fn BosonState::down(
  self : BosonState,
  index : Int,
) -> BosonState? raise @symphysics.PhysicsError {
  let current = sq_state_at(self.occupations, index)
  if current == @symcore.int(0) {
    None
  } else {
    let updated = self.occupations.copy()
    updated[index] = current - @symcore.int(1)
    Some(boson_state(updated))
  }
}

///|
pub fn BosonState::as_expr(self : BosonState) -> @symcore.Expr {
  @symcore.raw_function("FockState", [sq_tuple_expr(self.occupations)])
}

///|
pub fn BosonState::as_ket_expr(self : BosonState) -> @symcore.Expr {
  sq_boson_ket_expr(self.occupations)
}

///|
pub fn BosonState::as_bra_expr(self : BosonState) -> @symcore.Expr {
  sq_boson_bra_expr(self.occupations)
}

///|
pub fn BosonState::to_string(self : BosonState) -> String {
  sq_tuple_string(self.occupations)
}

///|
pub fn BosonState::repr(self : BosonState) -> String {
  sq_fock_state_repr(self.occupations)
}

///|
pub fn boson_ket(occupations : Array[@symcore.Expr]) -> @symcore.Expr {
  sq_boson_ket_expr(occupations)
}

///|
pub fn boson_bra(occupations : Array[@symcore.Expr]) -> @symcore.Expr {
  sq_boson_bra_expr(occupations)
}

///|
pub fn boson_state_from_expr(expr : @symcore.Expr) -> BosonState? {
  match sq_boson_items_from_expr(expr) {
    Some(items) => Some(boson_state(items))
    None => None
  }
}

///|
pub fn boson_annihilator(index : @symcore.Expr) -> BosonicOperatorExpr {
  BosonicOperatorExpr::{ index, is_annihilation: true }
}

///|
pub fn boson_creator(index : @symcore.Expr) -> BosonicOperatorExpr {
  BosonicOperatorExpr::{ index, is_annihilation: false }
}

///|
pub fn BosonicOperatorExpr::as_expr(self : BosonicOperatorExpr) -> @symcore.Expr {
  @symcore.raw_function(
    if self.is_annihilation { "AnnihilateBoson" } else { "CreateBoson" },
    [self.index],
  )
}

///|
pub fn BosonicOperatorExpr::to_string(self : BosonicOperatorExpr) -> String {
  if self.is_annihilation {
    "b(\{@symprint.to_string(self.index)})"
  } else {
    "b+(\{@symprint.to_string(self.index)})"
  }
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
pub fn BosonicOperatorExpr::dagger(self : BosonicOperatorExpr) -> BosonicOperatorExpr {
  BosonicOperatorExpr::{ index: self.index, is_annihilation: !self.is_annihilation }
}

///|
pub fn BosonicOperatorExpr::is_symbolic(self : BosonicOperatorExpr) -> Bool {
  sq_integral_index(self.index) is None
}

///|
pub fn BosonicOperatorExpr::state(self : BosonicOperatorExpr) -> @symcore.Expr {
  self.index
}

///|
pub fn BosonicOperatorExpr::apply_operator(
  self : BosonicOperatorExpr,
  state : @symcore.Expr,
) -> @symcore.Expr {
  if self.is_symbolic() {
    @symcore.raw_mul([self.as_expr(), state])
  } else {
    @symquant.qapply(@symcore.raw_mul([self.as_expr(), state]))
  }
}

///|
pub fn variable_bosonic_basis(n_max : Int) -> VarBosonicBasis {
  let basis : Array[@symcore.Expr] = []
  for i in 0..<n_max {
    basis.push(boson_ket([@symcore.int(i)]))
  }
  VarBosonicBasis::{ n_max, basis }
}

///|
pub fn fixed_bosonic_basis(
  n_particles : Int,
  n_levels : Int,
) -> FixedBosonicBasis {
  let basis : Array[@symcore.Expr] = []
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
) -> @symcore.Expr raise @symphysics.PhysicsError {
  if index < 0 || index >= self.basis.length() {
    raise @symphysics.PhysicsError::IndexError("basis index out of range")
  }
  self.basis[index]
}

///|
pub fn VarBosonicBasis::index(
  self : VarBosonicBasis,
  state : @symcore.Expr,
) -> Int raise @symphysics.PhysicsError {
  for idx in 0..<self.basis.length() {
    if self.basis[idx] == state {
      return idx
    }
  }
  raise @symphysics.PhysicsError::ValueError("state not present in bosonic basis")
}

///|
pub fn VarBosonicBasis::to_string(self : VarBosonicBasis) -> String {
  sq_boson_basis_list_string(self.basis)
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
) -> @symcore.Expr raise @symphysics.PhysicsError {
  if index < 0 || index >= self.basis.length() {
    raise @symphysics.PhysicsError::IndexError("basis index out of range")
  }
  self.basis[index]
}

///|
pub fn FixedBosonicBasis::index(
  self : FixedBosonicBasis,
  state : @symcore.Expr,
) -> Int raise @symphysics.PhysicsError {
  for idx in 0..<self.basis.length() {
    if self.basis[idx] == state {
      return idx
    }
  }
  raise @symphysics.PhysicsError::ValueError("state not present in bosonic basis")
}

///|
pub fn FixedBosonicBasis::to_string(self : FixedBosonicBasis) -> String {
  sq_boson_basis_list_string(self.basis)
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
) -> @symcore.Expr raise @symphysics.PhysicsError {
  match self {
    BosonicBasisSet::Var(basis) => basis.state(index)
    BosonicBasisSet::Fixed(basis) => basis.state(index)
  }
}

///|
pub fn BosonicBasisSet::index(
  self : BosonicBasisSet,
  state : @symcore.Expr,
) -> Int raise @symphysics.PhysicsError {
  match self {
    BosonicBasisSet::Var(basis) => basis.index(state)
    BosonicBasisSet::Fixed(basis) => basis.index(state)
  }
}

///|
pub fn BosonicBasisSet::to_string(self : BosonicBasisSet) -> String {
  match self {
    BosonicBasisSet::Var(basis) => basis.to_string()
    BosonicBasisSet::Fixed(basis) => basis.to_string()
  }
}

///|
pub fn secondquant_dagger(expr : @symcore.Expr) -> @symcore.Expr {
  @symquant.dagger(expr)
}

///|
pub fn secondquant_inner_product(
  bra : @symcore.Expr,
  ket : @symcore.Expr,
) -> @symcore.Expr {
  @symquant.inner_product(bra, ket)
}

///|
pub fn secondquant_apply_operators(expr : @symcore.Expr) -> @symcore.Expr {
  @symquant.qapply(expr)
}

///|
pub fn secondquant_commutator(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
  @symquant.commutator(lhs, rhs)
}

///|
fn sq_is_boson_annihilator(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function("AnnihilateBoson", args) if args.length() == 1 =>
      Some(args[0])
    _ => None
  }
}

///|
fn sq_is_boson_creator(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function("CreateBoson", args) if args.length() == 1 =>
      Some(args[0])
    _ => None
  }
}

///|
fn sq_normal_order_product(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Mul(args) if args.length() >= 2 => {
      for idx in 0..<(args.length() - 1) {
        match (sq_is_boson_annihilator(args[idx]), sq_is_boson_creator(args[idx + 1])) {
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
              @symcore.int(1)
            } else {
              @symcore.raw_function("KroneckerDelta", [left_idx, right_idx])
            }
            let ordered = sq_normal_order_product(@symcore.raw_mul(swapped))
            let leading : Array[@symcore.Expr] = []
            for item in prefix {
              leading.push(item)
            }
            if comm_term != @symcore.int(1) || (prefix.length() + suffix.length()) > 0 {
              if comm_term != @symcore.int(1) {
                leading.push(comm_term)
              }
              for item in suffix {
                leading.push(item)
              }
            }
            let correction = if leading.is_empty() {
              @symcore.int(1)
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
  expr : @symcore.Expr,
  independent? : Bool = false,
  recursive_limit? : Int = 10,
) -> @symcore.Expr {
  ignore(independent)
  ignore(recursive_limit)
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.raw_add(args.map(term => secondquant_normal_ordered_form(term)))
    _ => sq_normal_order_product(expr)
  }
}

///|
fn sq_scale_inner_product(
  bra : @symcore.Expr,
  expr : @symcore.Expr,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.raw_add(args.map(term => sq_scale_inner_product(bra, term)))
    @symcore.Expr::Mul(args) => {
      let scalar_factors : Array[@symcore.Expr] = []
      let ket_factors : Array[@symcore.Expr] = []
      for arg in args {
        if @symquant.quantum_is_ket_expr(arg) {
          ket_factors.push(arg)
        } else {
          scalar_factors.push(arg)
        }
      }
      if ket_factors.length() == 1 {
        let scalar = if scalar_factors.is_empty() {
          @symcore.int(1)
        } else {
          @symcore.raw_mul(scalar_factors)
        }
        scalar * secondquant_inner_product(bra, ket_factors[0])
      } else {
        bra * expr
      }
    }
    _ if @symquant.quantum_is_ket_expr(expr) => secondquant_inner_product(bra, expr)
    _ => bra * expr
  }
}

///|
pub fn secondquant_matrix_rep(
  op : @symcore.Expr,
  basis : BosonicBasisSet,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let rows : Array[Array[@symcore.Expr]] = []
  for i in 0..<basis.len() {
    let row : Array[@symcore.Expr] = []
    let bra = secondquant_dagger(basis.state(i))
    for j in 0..<basis.len() {
      let acted = secondquant_apply_operators(@symcore.raw_mul([op, basis.state(j)]))
      row.push(sq_scale_inner_product(bra, acted))
    }
    rows.push(row)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}
