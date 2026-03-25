///|
/// Fermionic operator/state families and shorthand constructors for
/// `sympy.physics.secondquant`.
///
/// This covers the many-body fermionic Fock-state layer that the initial
/// bosonic-only tranche did not implement. The representation is intentionally
/// explicit: operators are `AnnihilateFermion/CreateFermion` expressions and
/// states are `FockStateFermionKet/Bra(Tuple(...))`.

///|
pub struct FermionState {
  orbitals : Array[Expr]
  fermi_level : Int
} derive(Eq)

///|
pub struct FermionicOperatorExpr {
  index : Expr
  is_annihilation : Bool
} derive(Eq)

///|
fn sq_raw_mul(args : Array[Expr]) -> Expr {
  match args.length() {
    0 => int(1)
    1 => args[0]
    _ => @symcore.raw_mul(args)
  }
}

///|
fn sq_raw_add(args : Array[Expr]) -> Expr {
  match args.length() {
    0 => int(0)
    1 => args[0]
    _ => @symcore.raw_add(args)
  }
}

///|
fn sq_sign_expr(sign : Int, expr : Expr) -> Expr {
  if sign % 2 == 0 {
    expr
  } else {
    int(-1) * expr
  }
}

///|
fn sq_fermion_tuple_expr(items : Array[Expr]) -> Expr {
  @symcore.raw_function("Tuple", items)
}

///|
fn sq_fermion_ket_expr(items : Array[Expr]) -> Expr {
  @symcore.raw_function("FockStateFermionKet", [sq_fermion_tuple_expr(items)])
}

///|
fn sq_fermion_bra_expr(items : Array[Expr]) -> Expr {
  @symcore.raw_function("FockStateFermionBra", [sq_fermion_tuple_expr(items)])
}

///|
fn sq_fermion_items_from_expr(expr : Expr) -> Array[Expr]? {
  if @symquant.quantum_expr_has_any_name(expr, [
      "FockStateFermionKet", "FockStateFermionBra", "FockStateKet", "FockStateBra",
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
fn sq_expr_text(expr : Expr) -> String {
  @symprint.to_string(expr)
}

///|
fn sq_tuple_inner_product(lhs : Array[Expr], rhs : Array[Expr]) -> Expr {
  if lhs.length() != rhs.length() {
    return int(0)
  }
  let mut out = int(1)
  for idx in 0..<lhs.length() {
    if lhs[idx] == rhs[idx] {
      ()
    } else if lhs[idx] is Expr::Number(_) && rhs[idx] is Expr::Number(_) {
      return int(0)
    } else {
      out = out * @symcore.raw_function("KroneckerDelta", [lhs[idx], rhs[idx]])
    }
  }
  out
}

///|
fn sq_symbol_prefix(name : String) -> String {
  if name.length() >= 2 {
    name[:2].to_string()
  } else if name.length() == 1 {
    name[:1].to_string()
  } else {
    ""
  }
}

///|
fn sq_symbol_head(name : String) -> String {
  if name.length() >= 1 {
    name[:1].to_string()
  } else {
    ""
  }
}

///|
fn sq_index_group(expr : Expr, fermi_level : Int) -> Int {
  match expr {
    Expr::Number(n) if n.is_integral() =>
      if n.numerator().to_int() > fermi_level {
        0
      } else {
        1
      }
    Expr::Symbol(name) =>
      if sq_symbol_prefix(name) == "_a" ||
        ["a", "b", "c", "d"].contains(sq_symbol_head(name)) {
        0
      } else if sq_symbol_prefix(name) == "_i" ||
        ["i", "j", "k", "l", "m", "n"].contains(sq_symbol_head(name)) {
        1
      } else {
        2
      }
    _ => 2
  }
}

///|
fn sq_compare_fermion_indices(lhs : Expr, rhs : Expr, fermi_level : Int) -> Int {
  let group_l = sq_index_group(lhs, fermi_level)
  let group_r = sq_index_group(rhs, fermi_level)
  if group_l != group_r {
    return if group_l < group_r { -1 } else { 1 }
  }
  match (lhs, rhs) {
    (Expr::Number(ln), Expr::Number(rn)) => ln.compare(rn)
    _ => sq_expr_text(rhs).compare(sq_expr_text(lhs))
  }
}

///|
fn sq_sort_fermion_indices(
  values : Array[Expr],
  fermi_level : Int,
) -> (Array[Expr], Int, Bool) {
  let out = values.copy()
  let mut sign = 0
  if out.length() <= 1 {
    return (out, 0, false)
  }
  for i in 0..<out.length() {
    let mut j = 0
    while j + 1 < out.length() - i {
      if out[j] == out[j + 1] {
        return ([], 0, true)
      }
      if sq_compare_fermion_indices(out[j], out[j + 1], fermi_level) > 0 {
        let tmp = out[j]
        out[j] = out[j + 1]
        out[j + 1] = tmp
        sign += 1
      }
      j += 1
    }
  }
  (out, sign, false)
}

///|
fn sq_fermion_hole_count(orbitals : Array[Expr], fermi_level : Int) -> Int {
  let mut total = 0
  for orbital in orbitals {
    if sq_index_group(orbital, fermi_level) == 1 {
      total += 1
    }
  }
  total
}

///|
fn sq_fermion_state_expr(
  orbitals : Array[Expr],
  ket : Bool,
  fermi_level : Int,
) -> Expr {
  let (sorted, sign, invalid) = sq_sort_fermion_indices(orbitals, fermi_level)
  if invalid || sq_fermion_hole_count(sorted, fermi_level) > fermi_level {
    return int(0)
  }
  let base = if ket {
    sq_fermion_ket_expr(sorted)
  } else {
    sq_fermion_bra_expr(sorted)
  }
  sq_sign_expr(sign, base)
}

///|
fn sq_fermion_state_from_items(
  orbitals : Array[Expr],
  fermi_level : Int,
) -> FermionState {
  let (sorted, _, _) = sq_sort_fermion_indices(orbitals, fermi_level)
  FermionState::{ orbitals: sorted, fermi_level }
}

///|
fn sq_fermion_operator_parts(expr : Expr) -> (Expr, Bool)? {
  match @symquant.quantum_expr_args(expr) {
    Some([arg]) if @symquant.quantum_expr_has_name(expr, "AnnihilateFermion") =>
      Some((arg, true))
    Some([arg]) if @symquant.quantum_expr_has_name(expr, "CreateFermion") =>
      Some((arg, false))
    Some([arg, dagger_flag]) if @symquant.quantum_expr_has_name(
        expr, "FermionOp",
      ) => Some((arg, dagger_flag != int(0)))
    _ => None
  }
}

///|
fn sq_fermion_remove_orbital(
  orbitals : Array[Expr],
  target : Expr,
  fermi_level : Int,
  ket : Bool,
) -> Expr {
  let mut idx = -1
  for i in 0..<orbitals.length() {
    if orbitals[i] == target {
      idx = i
      break
    }
  }
  if idx < 0 {
    return int(0)
  }
  let updated : Array[Expr] = []
  for i in 0..<orbitals.length() {
    if i != idx {
      updated.push(orbitals[i])
    }
  }
  sq_sign_expr(idx, sq_fermion_state_expr(updated, ket, fermi_level))
}

///|
fn sq_fermion_add_orbital(
  orbitals : Array[Expr],
  target : Expr,
  fermi_level : Int,
  ket : Bool,
) -> Expr {
  for orbital in orbitals {
    if orbital == target {
      return int(0)
    }
  }
  let updated : Array[Expr] = [target]
  for orbital in orbitals {
    updated.push(orbital)
  }
  sq_fermion_state_expr(updated, ket, fermi_level)
}

///|
fn sq_apply_fermion_op_to_items(
  index : Expr,
  is_annihilation : Bool,
  orbitals : Array[Expr],
  fermi_level : Int,
  ket : Bool,
) -> Expr {
  let group = sq_index_group(index, fermi_level)
  if is_annihilation {
    if group == 0 {
      sq_fermion_remove_orbital(orbitals, index, fermi_level, ket)
    } else if group == 1 {
      let current_holes = sq_fermion_hole_count(orbitals, fermi_level)
      if current_holes >= fermi_level {
        int(0)
      } else {
        sq_fermion_add_orbital(orbitals, index, fermi_level, ket)
      }
    } else {
      sq_fermion_remove_orbital(orbitals, index, fermi_level, ket)
    }
  } else if group == 1 {
    sq_fermion_remove_orbital(orbitals, index, fermi_level, ket)
  } else {
    sq_fermion_add_orbital(orbitals, index, fermi_level, ket)
  }
}

///|
fn sq_apply_fermion_operator_to_state(
  op_expr : Expr,
  state_expr : Expr,
  ket : Bool,
) -> Expr? {
  let (index, is_annihilation) = match sq_fermion_operator_parts(op_expr) {
    Some(parts) => parts
    None => return None
  }
  match state_expr {
    Expr::Function(name, args) if (ket && name == "FockStateFermionKet") ||
      (!ket && name == "FockStateFermionBra") => {
      guard args.length() == 1 else { return None }
      match @symcore.tuple_items(args[0]) {
        Some(items) =>
          match index {
            Expr::Number(_) =>
              Some(
                sq_apply_fermion_op_to_items(
                  index, is_annihilation, items, 0, ket,
                ),
              )
            _ =>
              if sq_index_group(index, 0) == 1 && items.contains(index) {
                Some(int(0))
              } else {
                None
              }
          }
        None => None
      }
    }
    _ => None
  }
}

///|
pub fn fermion_state(
  orbitals : Array[Expr],
  fermi_level? : Int = 0,
) -> FermionState {
  sq_fermion_state_from_items(orbitals, fermi_level)
}

///|
pub fn FermionState::len(self : FermionState) -> Int {
  self.orbitals.length()
}

///|
pub fn FermionState::as_expr(self : FermionState) -> Expr {
  @symcore.raw_function("FockState", [sq_fermion_tuple_expr(self.orbitals)])
}

///|
pub fn FermionState::as_ket_expr(self : FermionState) -> Expr {
  sq_fermion_state_expr(self.orbitals, true, self.fermi_level)
}

///|
pub fn FermionState::as_bra_expr(self : FermionState) -> Expr {
  sq_fermion_state_expr(self.orbitals, false, self.fermi_level)
}

///|
pub fn FermionState::up(self : FermionState, orbital : Expr) -> Expr {
  sq_apply_fermion_op_to_items(
    orbital,
    false,
    self.orbitals,
    self.fermi_level,
    true,
  )
}

///|
pub fn FermionState::down(self : FermionState, orbital : Expr) -> Expr {
  sq_apply_fermion_op_to_items(
    orbital,
    true,
    self.orbitals,
    self.fermi_level,
    true,
  )
}

///|
pub fn FermionState::repr(self : FermionState) -> String {
  "FockStateKet(\{sq_tuple_string(self.orbitals)})"
}

///|
pub impl Show for FermionState with to_string(self) {
  sq_tuple_string(self.orbitals)
}

///|
pub impl Show for FermionState with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn fermion_state_from_expr(expr : Expr) -> FermionState? {
  match sq_fermion_items_from_expr(expr) {
    Some(items) => Some(fermion_state(items))
    None => None
  }
}

///|
pub fn fermion_ket(orbitals : Array[Expr], fermi_level? : Int = 0) -> Expr {
  sq_fermion_state_expr(orbitals, true, fermi_level)
}

///|
pub fn fermion_bra(orbitals : Array[Expr], fermi_level? : Int = 0) -> Expr {
  sq_fermion_state_expr(orbitals, false, fermi_level)
}

///|
pub fn fermion_annihilator(index : Expr) -> FermionicOperatorExpr {
  FermionicOperatorExpr::{ index, is_annihilation: true }
}

///|
pub fn fermion_creator(index : Expr) -> FermionicOperatorExpr {
  FermionicOperatorExpr::{ index, is_annihilation: false }
}

///|
pub fn FermionicOperatorExpr::as_expr(self : FermionicOperatorExpr) -> Expr {
  @symcore.raw_function(
    if self.is_annihilation {
      "AnnihilateFermion"
    } else {
      "CreateFermion"
    },
    [self.index],
  )
}

///|
pub fn FermionicOperatorExpr::dagger(
  self : FermionicOperatorExpr,
) -> FermionicOperatorExpr {
  FermionicOperatorExpr::{
    index: self.index,
    is_annihilation: !self.is_annihilation,
  }
}

///|
pub impl Show for FermionicOperatorExpr with to_string(self) {
  if self.is_annihilation {
    "f(\{@symprint.to_string(self.index)})"
  } else {
    "f+(\{@symprint.to_string(self.index)})"
  }
}

///|
pub impl Show for FermionicOperatorExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn FermionicOperatorExpr::repr(self : FermionicOperatorExpr) -> String {
  let name = if self.is_annihilation {
    "AnnihilateFermion"
  } else {
    "CreateFermion"
  }
  "\{name}(\{@symprint.to_string(self.index)})"
}

///|
pub fn FermionicOperatorExpr::apply_operator(
  self : FermionicOperatorExpr,
  state : Expr,
) -> Expr {
  match sq_apply_fermion_operator_to_state(self.as_expr(), state, true) {
    Some(value) => value
    None => @symcore.raw_mul([self.as_expr(), state])
  }
}

///|
pub fn b(index : Expr) -> Expr {
  boson_annihilator(index).as_expr()
}

///|
pub fn bd(index : Expr) -> Expr {
  boson_creator(index).as_expr()
}

///|
pub fn f(index : Expr) -> Expr {
  fermion_annihilator(index).as_expr()
}

///|
pub fn fd(index : Expr) -> Expr {
  fermion_creator(index).as_expr()
}

///|
pub fn bket(items : Array[Expr]) -> Expr {
  boson_ket(items)
}

///|
pub fn bbra(items : Array[Expr]) -> Expr {
  boson_bra(items)
}

///|
pub fn fket(items : Array[Expr]) -> Expr {
  fermion_ket(items)
}

///|
pub fn fbra(items : Array[Expr]) -> Expr {
  fermion_bra(items)
}

///|
fn sq_secondquant_dagger_local(expr : Expr) -> Expr? {
  match @symquant.quantum_expr_args(expr) {
    Some(args) if args.length() == 1 &&
      @symquant.quantum_expr_has_name(expr, "AnnihilateFermion") =>
      Some(@symcore.raw_function("CreateFermion", args))
    Some(args) if args.length() == 1 &&
      @symquant.quantum_expr_has_name(expr, "CreateFermion") =>
      Some(@symcore.raw_function("AnnihilateFermion", args))
    Some(args) if args.length() == 1 &&
      @symquant.quantum_expr_has_name(expr, "FockStateFermionKet") =>
      Some(@symcore.raw_function("FockStateFermionBra", args))
    Some(args) if args.length() == 1 &&
      @symquant.quantum_expr_has_name(expr, "FockStateFermionBra") =>
      Some(@symcore.raw_function("FockStateFermionKet", args))
    _ => None
  }
}

///|
fn sq_secondquant_inner_product_local(bra : Expr, ket : Expr) -> Expr? {
  match (sq_fermion_items_from_expr(bra), sq_fermion_items_from_expr(ket)) {
    (Some(bitems), Some(kitems)) => Some(sq_tuple_inner_product(bitems, kitems))
    _ => None
  }
}

///|
fn sq_apply_fermion_mul(args : Array[Expr]) -> Expr? {
  guard args.length() >= 2 else { return None }
  let factors = args.copy()
  let scalar_terms : Array[Expr] = []
  let mut current : Expr? = None
  let mut idx = factors.length()
  while idx > 0 {
    idx -= 1
    let factor = factors[idx]
    match current {
      None =>
        if @symquant.quantum_is_ket_expr(factor) ||
          @symquant.quantum_is_bra_expr(factor) {
          current = Some(factor)
        } else {
          scalar_terms.push(factor)
        }
      Some(state_expr) =>
        match
          sq_apply_fermion_operator_to_state(
            factor,
            state_expr,
            @symquant.quantum_is_ket_expr(state_expr),
          ) {
          Some(next) => current = Some(next)
          None =>
            if @symquant.quantum_is_bra_expr(factor) &&
              @symquant.quantum_is_ket_expr(state_expr) {
              current = Some(
                match sq_secondquant_inner_product_local(factor, state_expr) {
                  Some(value) => value
                  None =>
                    @symcore.raw_function("InnerProduct", [factor, state_expr])
                },
              )
            } else {
              return None
            }
        }
    }
  }
  match current {
    Some(value) => {
      let rebuilt : Array[Expr] = []
      let mut i = scalar_terms.length()
      while i > 0 {
        i -= 1
        rebuilt.push(scalar_terms[i])
      }
      rebuilt.push(value)
      Some(sq_raw_mul(rebuilt))
    }
    None => None
  }
}
