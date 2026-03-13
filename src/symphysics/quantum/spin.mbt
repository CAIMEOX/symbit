///|
/// Angular-momentum operators and uncoupled spin eigenstates.
///
/// This slice covers the uncoupled `Jx`, `Jy`, and `Jz` bases: the global
/// operators `Jplus`, `Jminus`, `Jx`, `Jy`, `Jz`, `J2`, the eigenstates
/// `JxKet/JxBra`, `JyKet/JyBra`, `JzKet/JzBra`, exact ladder-operator action,
/// basis rewrites, and explicit matrix representations.

///|
fn spin_op_symbol(name : String) -> @symcore.Expr {
  @symcore.symbol(name)
}

///|
fn spin_numeric_args(args : Array[@symcore.Expr]) -> Bool {
  for arg in args {
    match arg {
      @symcore.Expr::Number(_) => ()
      _ => return false
    }
  }
  true
}

///|
fn spin_pi_multiple(num : Int, den : Int) -> @symcore.Expr {
  if num == 0 {
    @symcore.int(0)
  } else {
    @symcore.symbol("pi") * (try! @symcore.rational_from_ints(num, den))
  }
}

///|
fn spin_state_expr_name(basis_name : String, is_bra : Bool) -> String {
  match basis_name {
    "Jx" => if is_bra { "JxBra" } else { "JxKet" }
    "Jy" => if is_bra { "JyBra" } else { "JyKet" }
    _ => if is_bra { "JzBra" } else { "JzKet" }
  }
}

///|
fn spin_coupled_state_expr_name(basis_name : String, is_bra : Bool) -> String {
  "\{spin_state_expr_name(basis_name, is_bra)}Coupled"
}

///|
fn spin_basis_name_from_expr(expr : @symcore.Expr?) -> String? {
  match expr {
    Some(@symcore.Expr::Symbol(name)) if name == "Jx" ||
      name == "Jy" ||
      name == "Jz" => Some(name)
    _ => None
  }
}

///|
fn spin_operator_basis_name(op_expr : @symcore.Expr) -> String? {
  match op_expr {
    @symcore.Expr::Symbol("Jx") => Some("Jx")
    @symcore.Expr::Symbol("Jy") => Some("Jy")
    @symcore.Expr::Symbol("Jz") => Some("Jz")
    _ => None
  }
}

///|
fn spin_basis_operator_expr(basis_name : String) -> @symcore.Expr {
  match basis_name {
    "Jx" => jx()
    "Jy" => jy()
    _ => jz()
  }
}

///|
fn spin_basis_angles(
  source_basis : String,
  target_basis : String,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) {
  if source_basis == target_basis {
    return (@symcore.int(0), @symcore.int(0), @symcore.int(0))
  }
  match (source_basis, target_basis) {
    ("Jx", "Jy") => (spin_pi_multiple(3, 2), @symcore.int(0), @symcore.int(0))
    ("Jx", "Jz") => (@symcore.int(0), spin_pi_multiple(1, 2), @symcore.int(0))
    ("Jy", "Jx") => (@symcore.int(0), @symcore.int(0), spin_pi_multiple(-1, 2))
    ("Jy", "Jz") =>
      (spin_pi_multiple(3, 2), spin_pi_multiple(-1, 2), spin_pi_multiple(1, 2))
    ("Jz", "Jx") => (@symcore.int(0), spin_pi_multiple(3, 2), @symcore.int(0))
    ("Jz", "Jy") =>
      (spin_pi_multiple(3, 2), spin_pi_multiple(1, 2), spin_pi_multiple(1, 2))
    _ => (@symcore.int(0), @symcore.int(0), @symcore.int(0))
  }
}

///|
pub fn jplus() -> @symcore.Expr {
  spin_op_symbol("Jplus")
}

///|
pub fn jminus() -> @symcore.Expr {
  spin_op_symbol("Jminus")
}

///|
pub fn jx() -> @symcore.Expr {
  spin_op_symbol("Jx")
}

///|
pub fn jy() -> @symcore.Expr {
  spin_op_symbol("Jy")
}

///|
pub fn jz() -> @symcore.Expr {
  spin_op_symbol("Jz")
}

///|
pub fn j2() -> @symcore.Expr {
  spin_op_symbol("J2")
}

///|
pub struct SpinCoupling {
  left_index : Int
  right_index : Int
  j : @symcore.Expr
} derive(Eq)

///|
pub struct JzState {
  j : @symcore.Expr
  m : @symcore.Expr
  is_bra : Bool
  basis_name : String
  jn : Array[@symcore.Expr]
  coupling : Array[SpinCoupling]
} derive(Eq)

///|
pub struct RotationExpr {
  alpha : @symcore.Expr
  beta : @symcore.Expr
  gamma : @symcore.Expr
} derive(Eq)

///|
pub struct WignerDExpr {
  j : @symcore.Expr
  m : @symcore.Expr
  mp : @symcore.Expr
  alpha : @symcore.Expr
  beta : @symcore.Expr
  gamma : @symcore.Expr
} derive(Eq)

///|
fn spin_state_make(
  j : @symcore.Expr,
  m : @symcore.Expr,
  is_bra : Bool,
  basis_name : String,
  jn? : Array[@symcore.Expr] = [],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  JzState::{ j, m, is_bra, basis_name, jn, coupling }
}

///|
fn spin_default_coupling(
  jn : Array[@symcore.Expr],
  total_j : @symcore.Expr,
) -> Array[SpinCoupling] {
  let coupling : Array[SpinCoupling] = []
  guard jn.length() >= 2 else { return coupling }
  let mut running = jn[0]
  for idx in 1..<(jn.length() - 1) {
    running = running + jn[idx]
    coupling.push(SpinCoupling::{
      left_index: 1,
      right_index: idx + 1,
      j: running,
    })
  }
  coupling.push(SpinCoupling::{
    left_index: 1,
    right_index: jn.length(),
    j: total_j,
  })
  coupling
}

///|
pub fn JzState::is_coupled(self : JzState) -> Bool {
  !self.jn.is_empty()
}

///|
pub fn jx_ket(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  spin_state_make(j, m, false, "Jx")
}

///|
pub fn jx_bra(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  spin_state_make(j, m, true, "Jx")
}

///|
pub fn jy_ket(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  spin_state_make(j, m, false, "Jy")
}

///|
pub fn jy_bra(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  spin_state_make(j, m, true, "Jy")
}

///|
pub fn jz_ket(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  spin_state_make(j, m, false, "Jz")
}

///|
pub fn jz_bra(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  spin_state_make(j, m, true, "Jz")
}

///|
pub fn jx_ket_coupled(
  j : @symcore.Expr,
  m : @symcore.Expr,
  jn : Array[@symcore.Expr],
  coupling? : Array[SpinCoupling]? = None,
) -> JzState {
  let scheme = match coupling {
    Some(value) if !value.is_empty() => value
    _ => spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, false, "Jx", jn~, coupling=scheme)
}

///|
pub fn jx_bra_coupled(
  j : @symcore.Expr,
  m : @symcore.Expr,
  jn : Array[@symcore.Expr],
  coupling? : Array[SpinCoupling]? = None,
) -> JzState {
  let scheme = match coupling {
    Some(value) if !value.is_empty() => value
    _ => spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, true, "Jx", jn~, coupling=scheme)
}

///|
pub fn jy_ket_coupled(
  j : @symcore.Expr,
  m : @symcore.Expr,
  jn : Array[@symcore.Expr],
  coupling? : Array[SpinCoupling]? = None,
) -> JzState {
  let scheme = match coupling {
    Some(value) if !value.is_empty() => value
    _ => spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, false, "Jy", jn~, coupling=scheme)
}

///|
pub fn jy_bra_coupled(
  j : @symcore.Expr,
  m : @symcore.Expr,
  jn : Array[@symcore.Expr],
  coupling? : Array[SpinCoupling]? = None,
) -> JzState {
  let scheme = match coupling {
    Some(value) if !value.is_empty() => value
    _ => spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, true, "Jy", jn~, coupling=scheme)
}

///|
pub fn jz_ket_coupled(
  j : @symcore.Expr,
  m : @symcore.Expr,
  jn : Array[@symcore.Expr],
  coupling? : Array[SpinCoupling]? = None,
) -> JzState {
  let scheme = match coupling {
    Some(value) if !value.is_empty() => value
    _ => spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, false, "Jz", jn~, coupling=scheme)
}

///|
pub fn jz_bra_coupled(
  j : @symcore.Expr,
  m : @symcore.Expr,
  jn : Array[@symcore.Expr],
  coupling? : Array[SpinCoupling]? = None,
) -> JzState {
  let scheme = match coupling {
    Some(value) if !value.is_empty() => value
    _ => spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, true, "Jz", jn~, coupling=scheme)
}

///|
pub fn rotation(
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  gamma : @symcore.Expr,
) -> RotationExpr {
  RotationExpr::{ alpha, beta, gamma }
}

///|
pub fn rotation_d(
  j : @symcore.Expr,
  m : @symcore.Expr,
  mp : @symcore.Expr,
  beta : @symcore.Expr,
) -> WignerDExpr {
  WignerDExpr::{
    j,
    m,
    mp,
    alpha: @symcore.int(0),
    beta,
    gamma: @symcore.int(0),
  }
}

///|
pub fn rotation_D(
  j : @symcore.Expr,
  m : @symcore.Expr,
  mp : @symcore.Expr,
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  gamma : @symcore.Expr,
) -> WignerDExpr {
  WignerDExpr::{ j, m, mp, alpha, beta, gamma }
}

///|
pub fn JzState::as_expr(self : JzState) -> @symcore.Expr {
  if !self.is_coupled() {
    return @symcore.raw_function(
      spin_state_expr_name(self.basis_name, self.is_bra),
      [self.j, self.m],
    )
  }
  let coupling_args = self.coupling.map(c => {
    @symcore.function("Tuple", [
      @symcore.int(c.left_index),
      @symcore.int(c.right_index),
      c.j,
    ])
  })
  let args : Array[@symcore.Expr] = [
    self.j,
    self.m,
    @symcore.function("Tuple", self.jn),
  ]
  if !coupling_args.is_empty() {
    args.push(@symcore.function("Tuple", coupling_args))
  }
  @symcore.raw_function(
    spin_coupled_state_expr_name(self.basis_name, self.is_bra),
    args,
  )
}

///|
pub fn RotationExpr::as_expr(self : RotationExpr) -> @symcore.Expr {
  @symcore.raw_function("Rotation", [self.alpha, self.beta, self.gamma])
}

///|
pub fn RotationExpr::to_string(self : RotationExpr) -> String {
  "R(\{@symprint.to_string(self.alpha)},\{@symprint.to_string(self.beta)},\{@symprint.to_string(self.gamma)})"
}

///|
pub fn RotationExpr::inverse(self : RotationExpr) -> RotationExpr {
  rotation(
    @symcore.int(-1) * self.gamma,
    @symcore.int(-1) * self.beta,
    @symcore.int(-1) * self.alpha,
  )
}

///|
pub fn WignerDExpr::as_expr(self : WignerDExpr) -> @symcore.Expr {
  @symcore.raw_function("WignerD", [
    self.j,
    self.m,
    self.mp,
    self.alpha,
    self.beta,
    self.gamma,
  ])
}

///|
pub fn WignerDExpr::to_string(self : WignerDExpr) -> String {
  if self.alpha == @symcore.int(0) && self.gamma == @symcore.int(0) {
    "d(\{@symprint.to_string(self.j)},\{@symprint.to_string(self.m)},\{@symprint.to_string(self.mp)},\{@symprint.to_string(self.beta)})"
  } else {
    "D(\{@symprint.to_string(self.j)},\{@symprint.to_string(self.m)},\{@symprint.to_string(self.mp)},\{@symprint.to_string(self.alpha)},\{@symprint.to_string(self.beta)},\{@symprint.to_string(self.gamma)})"
  }
}

///|
pub fn JzState::to_string(self : JzState) -> String {
  let parts : Array[String] = [
    @symprint.to_string(self.j),
    @symprint.to_string(self.m),
  ]
  if self.is_coupled() {
    for idx in 0..<self.jn.length() {
      parts.push("j\{idx + 1}=\{@symprint.to_string(self.jn[idx])}")
    }
    if self.coupling.length() >= 2 {
      for item in self.coupling[:self.coupling.length() - 1] {
        let label = if item.left_index < item.right_index {
          "\{item.left_index},\{item.right_index}"
        } else {
          "\{item.right_index},\{item.left_index}"
        }
        parts.push("j(\{label})=\{@symprint.to_string(item.j)}")
      }
    }
  }
  let contents = parts.join(",")
  if self.is_bra {
    "<\{contents}|"
  } else {
    "|\{contents}>"
  }
}

///|
pub fn JzState::dual(self : JzState) -> JzState {
  spin_state_make(
    self.j,
    self.m,
    !self.is_bra,
    self.basis_name,
    jn=self.jn,
    coupling=self.coupling,
  )
}

///|
pub fn JzState::rewrite(self : JzState, basis : @symcore.Expr) -> @symcore.Expr {
  let target_basis = match spin_basis_name_from_expr(Some(basis)) {
    Some(name) => name
    None => return self.as_expr()
  }
  let evaluate = spin_numeric_args([self.j])
  spin_rewrite_single_state(self.as_expr(), target_basis, evaluate)
}

///|
pub fn m_values(
  j : @symcore.Expr,
) -> (Int, Array[@symcore.Expr]) raise @symphysics.PhysicsError {
  let size_expr = @symcore.int(2) * j + @symcore.int(1)
  match size_expr {
    @symcore.Expr::Number(n) if n.is_integral() && n.numerator().to_int() > 0 => {
      let size = n.numerator().to_int()
      let values : Array[@symcore.Expr] = []
      for idx in 0..<size {
        values.push(j - @symcore.int(idx))
      }
      (size, values)
    }
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "Only integer or half-integer j values are supported for explicit spin bases",
      )
  }
}

///|
fn spin_state_from_expr_impl(expr : @symcore.Expr) -> JzState? {
  fn parse_tuple_items(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
    match expr {
      @symcore.Expr::Function("Tuple", args) => Some(args)
      _ => None
    }
  }

  fn parse_coupling_items(expr : @symcore.Expr) -> Array[SpinCoupling]? {
    match parse_tuple_items(expr) {
      Some(items) => {
        let couplings : Array[SpinCoupling] = []
        for item in items {
          match item {
            @symcore.Expr::Function("Tuple", [left, right, j]) =>
              match
                (quantum_integer_value(left), quantum_integer_value(right)) {
                (Some(left_index), Some(right_index)) =>
                  couplings.push(SpinCoupling::{ left_index, right_index, j })
                _ => return None
              }
            _ => return None
          }
        }
        Some(couplings)
      }
      None => None
    }
  }

  match expr {
    @symcore.Expr::Function("JxKet", args) if args.length() == 2 =>
      Some(jx_ket(args[0], args[1]))
    @symcore.Expr::Function("JxBra", args) if args.length() == 2 =>
      Some(jx_bra(args[0], args[1]))
    @symcore.Expr::Function("JyKet", args) if args.length() == 2 =>
      Some(jy_ket(args[0], args[1]))
    @symcore.Expr::Function("JyBra", args) if args.length() == 2 =>
      Some(jy_bra(args[0], args[1]))
    @symcore.Expr::Function("JzKet", args) if args.length() == 2 =>
      Some(jz_ket(args[0], args[1]))
    @symcore.Expr::Function("JzBra", args) if args.length() == 2 =>
      Some(jz_bra(args[0], args[1]))
    @symcore.Expr::Function("JxKetCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          Some(
            jx_ket_coupled(
              args[0],
              args[1],
              jn,
              coupling=if args.length() >= 4 {
                parse_coupling_items(args[3])
              } else {
                None
              },
            ),
          )
        None => None
      }
    @symcore.Expr::Function("JxBraCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          Some(
            jx_bra_coupled(
              args[0],
              args[1],
              jn,
              coupling=if args.length() >= 4 {
                parse_coupling_items(args[3])
              } else {
                None
              },
            ),
          )
        None => None
      }
    @symcore.Expr::Function("JyKetCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          Some(
            jy_ket_coupled(
              args[0],
              args[1],
              jn,
              coupling=if args.length() >= 4 {
                parse_coupling_items(args[3])
              } else {
                None
              },
            ),
          )
        None => None
      }
    @symcore.Expr::Function("JyBraCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          Some(
            jy_bra_coupled(
              args[0],
              args[1],
              jn,
              coupling=if args.length() >= 4 {
                parse_coupling_items(args[3])
              } else {
                None
              },
            ),
          )
        None => None
      }
    @symcore.Expr::Function("JzKetCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          Some(
            jz_ket_coupled(
              args[0],
              args[1],
              jn,
              coupling=if args.length() >= 4 {
                parse_coupling_items(args[3])
              } else {
                None
              },
            ),
          )
        None => None
      }
    @symcore.Expr::Function("JzBraCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          Some(
            jz_bra_coupled(
              args[0],
              args[1],
              jn,
              coupling=if args.length() >= 4 {
                parse_coupling_items(args[3])
              } else {
                None
              },
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
pub fn spin_state_from_expr(expr : @symcore.Expr) -> JzState? {
  spin_state_from_expr_impl(expr)
}

///|
pub fn jz_state_from_expr(expr : @symcore.Expr) -> JzState? {
  spin_state_from_expr_impl(expr)
}

///|
pub fn rotation_from_expr(expr : @symcore.Expr) -> RotationExpr? {
  match expr {
    @symcore.Expr::Function("Rotation", args) if args.length() == 3 =>
      Some(rotation(args[0], args[1], args[2]))
    _ => None
  }
}

///|
pub fn wigner_d_from_expr(expr : @symcore.Expr) -> WignerDExpr? {
  match expr {
    @symcore.Expr::Function("WignerD", args) if args.length() == 6 =>
      Some(rotation_D(args[0], args[1], args[2], args[3], args[4], args[5]))
    _ => None
  }
}

///|
fn spin_m_index(
  j : @symcore.Expr,
  value : @symcore.Expr,
) -> Int raise @symphysics.PhysicsError {
  let (_, values) = m_values(j)
  for idx in 0..<values.length() {
    if values[idx] == value {
      return idx
    }
  }
  raise @symphysics.PhysicsError::ValueError(
    "Invalid magnetic quantum number for the given j",
  )
}

///|
fn spin_wigner_d_value(
  item : WignerDExpr,
  evaluate? : Bool = false,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  if item.alpha == @symcore.int(0) &&
    item.beta == @symcore.int(0) &&
    item.gamma == @symcore.int(0) {
    if item.m == item.mp {
      return @symcore.int(1)
    } else {
      return @symcore.int(0)
    }
  }
  if !evaluate {
    return item.as_expr()
  }
  let matrix = try! @symphysics.wigner_d(
    item.j,
    item.alpha,
    item.beta,
    item.gamma,
  )
  let row = try! spin_m_index(item.j, item.mp)
  let col = try! spin_m_index(item.j, item.m)
  matrix.get(row, col)
}

///|
pub fn WignerDExpr::doit(
  self : WignerDExpr,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  try! spin_wigner_d_value(self, evaluate=true)
}

///|
fn spin_basis_transform_coeff(
  j : @symcore.Expr,
  source_m : @symcore.Expr,
  target_m : @symcore.Expr,
  source_basis : String,
  target_basis : String,
  evaluate : Bool,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  if source_basis == target_basis {
    if source_m == target_m {
      @symcore.int(1)
    } else {
      @symcore.int(0)
    }
  } else {
    let (alpha, beta, gamma) = spin_basis_angles(source_basis, target_basis)
    try! spin_wigner_d_value(
      rotation_D(j, target_m, source_m, alpha, beta, gamma),
      evaluate~,
    )
  }
}

///|
fn spin_sum_expr(
  body : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Sum", [
    body,
    @symcore.function("Tuple", [sym, lower, upper]),
  ])
}

///|
fn spin_state_with_basis(
  state : JzState,
  basis_name : String,
  m : @symcore.Expr,
) -> JzState {
  spin_state_make(
    state.j,
    m,
    state.is_bra,
    basis_name,
    jn=state.jn,
    coupling=state.coupling,
  )
}

///|
fn spin_rewrite_single_state(
  state_expr : @symcore.Expr,
  target_basis : String,
  evaluate : Bool,
) -> @symcore.Expr {
  match spin_state_from_expr(state_expr) {
    Some(state) => {
      if state.basis_name == target_basis {
        return state_expr
      }
      if !evaluate || !spin_numeric_args([state.j]) {
        let mi = @symcore.symbol("mi")
        let (alpha, beta, gamma) = spin_basis_angles(
          state.basis_name,
          target_basis,
        )
        return spin_sum_expr(
          rotation_D(state.j, mi, state.m, alpha, beta, gamma).as_expr() *
          spin_state_with_basis(state, target_basis, mi).as_expr(),
          mi,
          @symcore.int(-1) * state.j,
          state.j,
        )
      }
      let (_, mvals) = try! m_values(state.j)
      let terms : Array[@symcore.Expr] = []
      for mp in mvals {
        let coeff = try! spin_basis_transform_coeff(
          state.j,
          state.m,
          mp,
          state.basis_name,
          target_basis,
          evaluate,
        )
        if coeff != @symcore.int(0) {
          terms.push(
            coeff * spin_state_with_basis(state, target_basis, mp).as_expr(),
          )
        }
      }
      quantum_add_from_args_preserve(terms)
    }
    None => state_expr
  }
}

///|
fn spin_rewrite_states_in_expr(
  expr : @symcore.Expr,
  target_basis : String,
  evaluate : Bool,
) -> @symcore.Expr {
  match spin_state_from_expr(expr) {
    Some(_) => spin_rewrite_single_state(expr, target_basis, evaluate)
    None =>
      match expr {
        @symcore.Expr::Add(args) =>
          quantum_add_from_args_preserve(
            args.map(arg => {
              spin_rewrite_states_in_expr(arg, target_basis, evaluate)
            }),
          )
        @symcore.Expr::Mul(args) =>
          quantum_mul_from_args_preserve(
            args.map(arg => {
              spin_rewrite_states_in_expr(arg, target_basis, evaluate)
            }),
          )
        @symcore.Expr::Function("Sum", args) if !args.is_empty() => {
          let rebuilt : Array[@symcore.Expr] = [
            spin_rewrite_states_in_expr(args[0], target_basis, evaluate),
          ]
          for idx in 1..<args.length() {
            rebuilt.push(args[idx])
          }
          @symcore.function("Sum", rebuilt)
        }
        @symcore.Expr::Function(name, args) =>
          @symcore.raw_function(
            name,
            args.map(arg => {
              spin_rewrite_states_in_expr(arg, target_basis, evaluate)
            }),
          )
        _ => expr
      }
  }
}

///|
pub struct SpinCoupleOrder {
  left_index : Int
  right_index : Int
} derive(Eq)

///|
struct SpinResolvedPair {
  left_ns : Array[Int]
  right_ns : Array[Int]
} derive(Eq)

///|
struct SpinResolvedCoupling {
  left_ns : Array[Int]
  right_ns : Array[Int]
  j : @symcore.Expr
} derive(Eq)

///|
pub fn spin_couple_order(
  left_index : Int,
  right_index : Int,
) -> SpinCoupleOrder {
  SpinCoupleOrder::{ left_index, right_index }
}

///|
fn spin_union_indices(left : Array[Int], right : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for value in left {
    out.push(value)
  }
  for value in right {
    out.push(value)
  }
  out.sort()
  out
}

///|
fn spin_min_int(left : Int, right : Int) -> Int {
  if left <= right {
    left
  } else {
    right
  }
}

///|
fn spin_max_int(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn spin_sum_all(values : Array[@symcore.Expr]) -> @symcore.Expr {
  let mut total = @symcore.int(0)
  for value in values {
    total = total + value
  }
  total
}

///|
fn spin_resolve_orders(
  count : Int,
  orders : Array[SpinCoupleOrder],
) -> Array[SpinResolvedPair] raise @symphysics.PhysicsError {
  let active : Array[Array[Int]] = []
  for idx in 1..<=count {
    active.push([idx])
  }
  let resolved : Array[SpinResolvedPair] = []
  for order in orders {
    guard order.left_index >= 1 &&
      order.right_index >= 1 &&
      order.left_index <= count &&
      order.right_index <= count &&
      order.left_index != order.right_index else {
      raise @symphysics.PhysicsError::ValueError("Invalid spin coupling order")
    }
    let left_ns = active[order.left_index - 1]
    let right_ns = active[order.right_index - 1]
    guard !left_ns.is_empty() && !right_ns.is_empty() else {
      raise @symphysics.PhysicsError::ValueError(
        "Coupling orders must reference active spin spaces",
      )
    }
    resolved.push(SpinResolvedPair::{ left_ns, right_ns })
    active[spin_min_int(order.left_index, order.right_index) - 1] = spin_union_indices(
      left_ns, right_ns,
    )
    active[spin_max_int(order.left_index, order.right_index) - 1] = []
  }
  resolved
}

///|
fn spin_resolve_couplings(
  count : Int,
  coupling : Array[SpinCoupling],
) -> Array[SpinResolvedCoupling] raise @symphysics.PhysicsError {
  let active : Array[Array[Int]] = []
  for idx in 1..<=count {
    active.push([idx])
  }
  let resolved : Array[SpinResolvedCoupling] = []
  for item in coupling {
    guard item.left_index >= 1 &&
      item.right_index >= 1 &&
      item.left_index <= count &&
      item.right_index <= count &&
      item.left_index != item.right_index else {
      raise @symphysics.PhysicsError::ValueError("Invalid spin coupling")
    }
    let left_ns = active[item.left_index - 1]
    let right_ns = active[item.right_index - 1]
    guard !left_ns.is_empty() && !right_ns.is_empty() else {
      raise @symphysics.PhysicsError::ValueError(
        "Couplings must reference active spin spaces",
      )
    }
    resolved.push(SpinResolvedCoupling::{ left_ns, right_ns, j: item.j })
    active[spin_min_int(item.left_index, item.right_index) - 1] = spin_union_indices(
      left_ns, right_ns,
    )
    active[spin_max_int(item.left_index, item.right_index) - 1] = []
  }
  resolved
}

///|
fn spin_sum_by_indices(
  values : Array[@symcore.Expr],
  indices : Array[Int],
) -> @symcore.Expr {
  let mut total = @symcore.int(0)
  for idx in indices {
    total = total + values[idx - 1]
  }
  total
}

///|
fn spin_twice_j(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.denominator().equal_int(1) =>
      Some((n.numerator() * @bigint.BigInt::from_int(2)).to_int())
    @symcore.Expr::Number(n) if n.denominator().equal_int(2) =>
      Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn spin_expr_from_twice_j(value : Int) -> @symcore.Expr raise {
  if value % 2 == 0 {
    @symcore.int(value / 2)
  } else {
    try! @symcore.rational_from_ints(value, 2)
  }
}

///|
fn spin_allowed_j_values(
  j1 : @symcore.Expr,
  j2 : @symcore.Expr,
) -> Array[@symcore.Expr] raise @symphysics.PhysicsError {
  match (spin_twice_j(j1), spin_twice_j(j2)) {
    (Some(tj1), Some(tj2)) => {
      let values : Array[@symcore.Expr] = []
      let lower = (tj1 - tj2).abs()
      for twice_j in lower..<=(tj1 + tj2) {
        if (twice_j - lower) % 2 == 0 {
          values.push(try! spin_expr_from_twice_j(twice_j))
        }
      }
      values
    }
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "Only numeric integer or half-integer couplings are supported here",
      )
  }
}

///|
fn spin_default_orders(count : Int) -> Array[SpinCoupleOrder] {
  let orders : Array[SpinCoupleOrder] = []
  for idx in 2..<=count {
    orders.push(spin_couple_order(1, idx))
  }
  orders
}

///|
fn spin_map_tensor_products(
  expr : @symcore.Expr,
  f : (@symcore.Expr) -> @symcore.Expr raise @symphysics.PhysicsError,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  match expr {
    @symcore.Expr::Function("TensorProduct", args) =>
      try! f(@symcore.raw_function("TensorProduct", args))
    @symcore.Expr::Add(args) =>
      quantum_add_from_args_preserve(
        args.map(arg => try! spin_map_tensor_products(arg, f)),
      )
    @symcore.Expr::Mul(args) =>
      quantum_mul_from_args_preserve(
        args.map(arg => try! spin_map_tensor_products(arg, f)),
      )
    @symcore.Expr::Function(name, args) =>
      @symcore.raw_function(
        name,
        args.map(arg => try! spin_map_tensor_products(arg, f)),
      )
    _ => expr
  }
}

///|
fn spin_map_states(
  expr : @symcore.Expr,
  f : (@symcore.Expr) -> @symcore.Expr raise @symphysics.PhysicsError,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  match spin_state_from_expr(expr) {
    Some(_) => try! f(expr)
    None =>
      match expr {
        @symcore.Expr::Add(args) =>
          quantum_add_from_args_preserve(
            args.map(arg => try! spin_map_states(arg, f)),
          )
        @symcore.Expr::Mul(args) =>
          quantum_mul_from_args_preserve(
            args.map(arg => try! spin_map_states(arg, f)),
          )
        @symcore.Expr::Function(name, args) =>
          @symcore.raw_function(
            name,
            args.map(arg => try! spin_map_states(arg, f)),
          )
        _ => expr
      }
  }
}

///|
fn spin_couple_tensor_product(
  expr : @symcore.Expr,
  orders? : Array[SpinCoupleOrder]? = None,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  match expr {
    @symcore.Expr::Function("TensorProduct", args) if !args.is_empty() => {
      let states = args.map(arg => spin_state_from_expr(arg))
      guard states.all(item => item is Some(_)) else { return expr }
      let items = states.map(item => item.unwrap())
      let first = items[0]
      guard items.all(s => {
        s.basis_name == first.basis_name &&
        s.is_bra == first.is_bra &&
        !s.is_coupled()
      }) else {
        raise @symphysics.PhysicsError::ValueError(
          "All spin states in TensorProduct must share one uncoupled basis",
        )
      }
      let scheme = match orders {
        Some(value) if !value.is_empty() => value
        _ => spin_default_orders(items.length())
      }
      let resolved = try! spin_resolve_orders(items.length(), scheme)
      let numeric_args = items.map(s => s.j)
      for item in items {
        numeric_args.push(item.m)
      }
      if spin_numeric_args(numeric_args) {
        let jn = items.map(s => s.j)
        let mn = items.map(s => s.m)
        let total_m = spin_sum_all(mn)
        let terms : Array[@symcore.Expr] = []

        fn go(
          step : Int,
          current_j : Array[@symcore.Expr],
          coeff : @symcore.Expr,
          triples : Array[SpinCoupling],
        ) -> Unit raise @symphysics.PhysicsError {
          if step >= resolved.length() {
            if coeff != @symcore.int(0) {
              let final_state = spin_state_make(
                triples[triples.length() - 1].j,
                total_m,
                first.is_bra,
                first.basis_name,
                jn~,
                coupling=triples,
              )
              terms.push(coeff * final_state.as_expr())
            }
            return
          }
          let pair = resolved[step]
          let left_index = pair.left_ns[0]
          let right_index = pair.right_ns[0]
          let j1 = current_j[left_index - 1]
          let j2 = current_j[right_index - 1]
          let m1 = spin_sum_by_indices(mn, pair.left_ns)
          let m2 = spin_sum_by_indices(mn, pair.right_ns)
          let m3 = m1 + m2
          let merged = spin_union_indices(pair.left_ns, pair.right_ns)
          for j3 in (try! spin_allowed_j_values(j1, j2)) {
            let cg_coeff = try! cg(j1, m1, j2, m2, j3, m3).doit()
            if cg_coeff != @symcore.int(0) {
              let updated = current_j.copy()
              updated[merged[0] - 1] = j3
              let next = triples.copy()
              next.push(SpinCoupling::{ left_index, right_index, j: j3 })
              try! go(step + 1, updated, coeff * cg_coeff, next)
            }
          }
        }

        try! go(0, items.map(s => s.j), @symcore.int(1), [])
        quantum_add_from_args_preserve(terms)
      } else {
        guard items.length() == 2 else {
          raise @symphysics.PhysicsError::ValueError(
            "Symbolic spin coupling currently supports two spin spaces",
          )
        }
        let j = @symcore.symbol("j")
        let total_m = items[0].m + items[1].m
        let coupled_state = spin_state_make(
          j,
          total_m,
          first.is_bra,
          first.basis_name,
          jn=items.map(s => s.j),
          coupling=[SpinCoupling::{ left_index: 1, right_index: 2, j }],
        )
        spin_sum_expr(
          cg(items[0].j, items[0].m, items[1].j, items[1].m, j, total_m).as_expr() *
          coupled_state.as_expr(),
          j,
          total_m,
          items[0].j + items[1].j,
        )
      }
    }
    _ => expr
  }
}

///|
pub fn couple(
  expr : @symcore.Expr,
  orders? : Array[SpinCoupleOrder]? = None,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  try! spin_map_tensor_products(expr, expr => {
    spin_couple_tensor_product(expr, orders~)
  })
}

///|
fn spin_uncouple_state_expr(
  expr : @symcore.Expr,
  jn? : Array[@symcore.Expr]? = None,
  coupling? : Array[SpinCoupling]? = None,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  let state = match spin_state_from_expr(expr) {
    Some(value) => value
    None => return expr
  }
  let coupled_state = if state.is_coupled() {
    state
  } else {
    let resolved_jn = match jn {
      Some(value) if !value.is_empty() => value
      _ =>
        raise @symphysics.PhysicsError::ValueError(
          "Must provide jn when uncoupling a non-coupled spin state",
        )
    }
    let resolved_coupling = match coupling {
      Some(value) if !value.is_empty() => value
      _ => spin_default_coupling(resolved_jn, state.j)
    }
    spin_state_make(
      state.j,
      state.m,
      state.is_bra,
      state.basis_name,
      jn=resolved_jn,
      coupling=resolved_coupling,
    )
  }
  let basis_name = coupled_state.basis_name
  let is_bra = coupled_state.is_bra
  let j_values = coupled_state.jn
  let numeric_args : Array[@symcore.Expr] = [coupled_state.j, coupled_state.m]
  for value in j_values {
    numeric_args.push(value)
  }
  if spin_numeric_args(numeric_args) {
    let resolved = try! spin_resolve_couplings(
      j_values.length(),
      coupled_state.coupling,
    )
    let m_lists = j_values.map(jv => (try! m_values(jv)).1)
    let chosen = Array::make(j_values.length(), @symcore.int(0))
    let terms : Array[@symcore.Expr] = []
    fn enumerate(idx : Int) -> Unit raise @symphysics.PhysicsError {
      if idx >= j_values.length() {
        let total_m = spin_sum_all(chosen)
        if total_m != coupled_state.m {
          return
        }
        let mut coeff = @symcore.int(1)
        for item in resolved {
          let m1 = spin_sum_by_indices(chosen, item.left_ns)
          let m2 = spin_sum_by_indices(chosen, item.right_ns)
          let m3 = m1 + m2
          coeff = coeff *
            (try! cg(
              j_values[item.left_ns[0] - 1],
              m1,
              j_values[item.right_ns[0] - 1],
              m2,
              item.j,
              m3,
            ).doit())
          if coeff == @symcore.int(0) {
            return
          }
        }
        let states : Array[@symcore.Expr] = []
        for i in 0..<j_values.length() {
          states.push(
            spin_state_make(j_values[i], chosen[i], is_bra, basis_name).as_expr(),
          )
        }
        terms.push(coeff * tensor_product(states).as_expr())
        return
      }
      for value in m_lists[idx] {
        chosen[idx] = value
        try! enumerate(idx + 1)
      }
    }
    try! enumerate(0)
    quantum_add_from_args_preserve(terms)
  } else {
    guard j_values.length() == 2 else {
      raise @symphysics.PhysicsError::ValueError(
        "Symbolic spin uncoupling currently supports two spin spaces",
      )
    }
    let m1 = @symcore.symbol("m1")
    let m2 = @symcore.symbol("m2")
    let factors : Array[@symcore.Expr] = [
      spin_state_make(j_values[0], m1, is_bra, basis_name).as_expr(),
      spin_state_make(j_values[1], m2, is_bra, basis_name).as_expr(),
    ]
    @symcore.function("Sum", [
      cg(j_values[0], m1, j_values[1], m2, coupled_state.j, coupled_state.m).as_expr() *
      tensor_product(factors).as_expr(),
      @symcore.function("Tuple", [
        m1,
        @symcore.int(-1) * j_values[0],
        j_values[0],
      ]),
      @symcore.function("Tuple", [
        m2,
        @symcore.int(-1) * j_values[1],
        j_values[1],
      ]),
    ])
  }
}

///|
pub fn uncouple(
  expr : @symcore.Expr,
  jn? : Array[@symcore.Expr]? = None,
  coupling? : Array[SpinCoupling]? = None,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  try! spin_map_states(expr, expr => {
    spin_uncouple_state_expr(expr, jn~, coupling~)
  })
}

///|
fn spin_linear_combination_from_vector(
  state : JzState,
  vector : @symphysics.ExplicitMatrix,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  let (_, mvals) = m_values(state.j)
  let terms : Array[@symcore.Expr] = []
  for idx in 0..<mvals.length() {
    let coeff = vector.get(idx, 0)
    if coeff != @symcore.int(0) {
      terms.push(
        coeff *
        spin_state_with_basis(state, state.basis_name, mvals[idx]).as_expr(),
      )
    }
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn spin_ladder_coeff(
  j : @symcore.Expr,
  m : @symcore.Expr,
  step : Int,
) -> @symcore.Expr {
  if step > 0 {
    @symcore.raw_function("sqrt", [
      j * (j + @symcore.int(1)) - m * (m + @symcore.int(1)),
    ])
  } else {
    @symcore.raw_function("sqrt", [
      j * (j + @symcore.int(1)) - m * (m - @symcore.int(1)),
    ])
  }
}

///|
pub fn spin_apply_operator_to_ket(
  op_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (rotation_from_expr(op_expr), spin_state_from_expr(ket_expr)) {
    (Some(op), Some(state)) if !state.is_bra => {
      let (_, mvals) = try! m_values(state.j)
      let terms : Array[@symcore.Expr] = []
      for mp in mvals {
        let coeff = try! spin_wigner_d_value(
          rotation_D(state.j, state.m, mp, op.alpha, op.beta, op.gamma),
          evaluate=true,
        )
        if coeff != @symcore.int(0) {
          terms.push(
            coeff *
            @symcore.raw_function(
              spin_state_expr_name(state.basis_name, false),
              [state.j, mp],
            ),
          )
        }
      }
      Some(quantum_add_from_args_preserve(terms))
    }
    _ =>
      match (op_expr, spin_state_from_expr(ket_expr)) {
        (@symcore.Expr::Symbol(name), Some(state)) if !state.is_bra => {
          let j = state.j
          let m = state.m
          match spin_operator_basis_name(op_expr) {
            Some(op_basis) if op_basis == state.basis_name =>
              return Some(hbar * m * ket_expr)
            _ => ()
          }
          match name {
            "J2" =>
              Some(
                (hbar ^ @symcore.int(2)) * j * (j + @symcore.int(1)) * ket_expr,
              )
            "Jplus" if state.basis_name == "Jz" =>
              if m == j {
                Some(@symcore.int(0))
              } else {
                let raised_state = if state.is_coupled() {
                  jz_ket_coupled(
                    j,
                    m + @symcore.int(1),
                    state.jn,
                    coupling=Some(state.coupling),
                  )
                } else {
                  jz_ket(j, m + @symcore.int(1))
                }
                Some(hbar * spin_ladder_coeff(j, m, 1) * raised_state.as_expr())
              }
            "Jminus" if state.basis_name == "Jz" =>
              if m == @symcore.int(-1) * j {
                Some(@symcore.int(0))
              } else {
                let lowered_state = if state.is_coupled() {
                  jz_ket_coupled(
                    j,
                    m - @symcore.int(1),
                    state.jn,
                    coupling=Some(state.coupling),
                  )
                } else {
                  jz_ket(j, m - @symcore.int(1))
                }
                Some(
                  hbar * spin_ladder_coeff(j, m, -1) * lowered_state.as_expr(),
                )
              }
            "Jx" if state.basis_name == "Jz" =>
              Some(
                try! (@symcore.rational_from_ints(1, 2) *
                (
                  spin_apply_operator_to_ket(jplus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  ) +
                  spin_apply_operator_to_ket(jminus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  )
                )),
              )
            "Jy" if state.basis_name == "Jz" =>
              Some(
                try! (@symcore.rational_from_ints(1, 2) *
                @symcore.int(-1) *
                @symcore.symbol("I") *
                (
                  spin_apply_operator_to_ket(jplus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  ) -
                  spin_apply_operator_to_ket(jminus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  )
                )),
              )
            "Jplus" | "Jminus" | "Jx" | "Jy" | "Jz" =>
              if spin_numeric_args([state.j]) {
                let basis_expr = spin_basis_operator_expr(state.basis_name)
                let matrix = try! represent_spin_operator(
                  op_expr,
                  state.j,
                  basis=Some(basis_expr),
                )
                let vector = try! represent_spin_state(
                  ket_expr,
                  basis=Some(basis_expr),
                  evaluate=true,
                )
                Some(
                  try! spin_linear_combination_from_vector(
                    state,
                    try! matrix.mul(vector),
                  ),
                )
              } else {
                let in_jz = spin_rewrite_single_state(ket_expr, "Jz", false)
                let applied = qapply(@symcore.raw_mul([op_expr, in_jz]))
                Some(
                  spin_rewrite_states_in_expr(applied, state.basis_name, false),
                )
              }
            _ => None
          }
        }
        _ => None
      }
  }
}

///|
fn spin_op_matrix_element(
  op_expr : @symcore.Expr,
  j : @symcore.Expr,
  m : @symcore.Expr,
  mp : @symcore.Expr,
) -> @symcore.Expr {
  match op_expr {
    @symcore.Expr::Symbol(name) =>
      match name {
        "Jz" => if m == mp { hbar * mp } else { @symcore.int(0) }
        "J2" =>
          if m == mp {
            (hbar ^ @symcore.int(2)) * j * (j + @symcore.int(1))
          } else {
            @symcore.int(0)
          }
        "Jplus" =>
          if m == mp + @symcore.int(1) {
            hbar * spin_ladder_coeff(j, mp, 1)
          } else {
            @symcore.int(0)
          }
        "Jminus" =>
          if m == mp - @symcore.int(1) {
            hbar * spin_ladder_coeff(j, mp, -1)
          } else {
            @symcore.int(0)
          }
        "Jx" =>
          try! (@symcore.rational_from_ints(1, 2) *
          (
            spin_op_matrix_element(jplus(), j, m, mp) +
            spin_op_matrix_element(jminus(), j, m, mp)
          ))
        "Jy" =>
          try! (@symcore.rational_from_ints(1, 2) *
          @symcore.int(-1) *
          @symcore.symbol("I") *
          (
            spin_op_matrix_element(jplus(), j, m, mp) -
            spin_op_matrix_element(jminus(), j, m, mp)
          ))
        _ => @symcore.int(0)
      }
    _ => @symcore.int(0)
  }
}

///|
pub fn represent_spin_jz_operator(
  op_expr : @symcore.Expr,
  j : @symcore.Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let (size, mvals) = m_values(j)
  let rows : Array[Array[@symcore.Expr]] = []
  for p in 0..<size {
    let row : Array[@symcore.Expr] = []
    for q in 0..<size {
      row.push(spin_op_matrix_element(op_expr, j, mvals[p], mvals[q]))
    }
    rows.push(row)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn represent_spin_state(
  state_expr : @symcore.Expr,
  basis? : @symcore.Expr? = None,
  evaluate? : Bool = true,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match spin_state_from_expr(state_expr) {
    Some(state) => {
      let target_basis = match spin_basis_name_from_expr(basis) {
        Some(name) => name
        None => state.basis_name
      }
      let (size, mvals) = m_values(state.j)
      if state.is_bra {
        let row = Array::make(size, @symcore.int(0))
        for idx in 0..<size {
          row[idx] = try! spin_basis_transform_coeff(
            state.j,
            state.m,
            mvals[idx],
            state.basis_name,
            target_basis,
            evaluate,
          )
        }
        @symphysics.explicit_matrix_from_rows([row])
      } else {
        let rows : Array[Array[@symcore.Expr]] = []
        for idx in 0..<size {
          rows.push([
            try! spin_basis_transform_coeff(
              state.j,
              state.m,
              mvals[idx],
              state.basis_name,
              target_basis,
              evaluate,
            ),
          ])
        }
        @symphysics.explicit_matrix_from_rows(rows)
      }
    }
    None =>
      raise @symphysics.PhysicsError::ValueError("Expected a spin basis state")
  }
}

///|
pub fn represent_spin_jz_state(
  state_expr : @symcore.Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  try! represent_spin_state(state_expr, basis=Some(jz()))
}

///|
fn spin_basis_matrix_in_jz(
  j : @symcore.Expr,
  basis_name : String,
  evaluate : Bool,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let (size, mvals) = m_values(j)
  let rows : Array[Array[@symcore.Expr]] = []
  for _ in 0..<size {
    rows.push(Array::make(size, @symcore.int(0)))
  }
  for col in 0..<size {
    let state = @symcore.raw_function(spin_state_expr_name(basis_name, false), [
      j,
      mvals[col],
    ])
    let vector = try! represent_spin_state(state, basis=Some(jz()), evaluate~)
    for row in 0..<size {
      rows[row][col] = vector.get(row, 0)
    }
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn represent_spin_operator(
  op_expr : @symcore.Expr,
  j : @symcore.Expr,
  basis? : @symcore.Expr? = None,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let target_basis = match spin_basis_name_from_expr(basis) {
    Some(name) => name
    None => "Jz"
  }
  let z_matrix = try! represent_spin_jz_operator(op_expr, j)
  if target_basis == "Jz" {
    return z_matrix
  }
  let change = try! spin_basis_matrix_in_jz(j, target_basis, true)
  try! matrix_dagger(change).mul(z_matrix).mul(change)
}

///|
pub fn represent_spin_rotation(
  expr : @symcore.Expr,
  j : @symcore.Expr,
  evaluate? : Bool = false,
) -> @symphysics.ExplicitMatrix? raise @symphysics.PhysicsError {
  match rotation_from_expr(expr) {
    Some(op) => {
      let (_, mvals) = try! m_values(j)
      let rows : Array[Array[@symcore.Expr]] = []
      for m in mvals {
        let row : Array[@symcore.Expr] = []
        for mp in mvals {
          row.push(
            try! spin_wigner_d_value(
              rotation_D(j, m, mp, op.alpha, op.beta, op.gamma),
              evaluate~,
            ),
          )
        }
        rows.push(row)
      }
      Some(try! @symphysics.explicit_matrix_from_rows(rows))
    }
    None => None
  }
}

///|
pub fn spin_inner_product(
  bra_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (spin_state_from_expr(bra_expr), spin_state_from_expr(ket_expr)) {
    (Some(bra), Some(ket)) if bra.is_bra && !ket.is_bra => {
      if bra.is_coupled() != ket.is_coupled() {
        return None
      }
      if bra.is_coupled() && (bra.jn != ket.jn || bra.coupling != ket.coupling) {
        return Some(@symcore.int(0))
      }
      let j_factor = if bra.j == ket.j {
        @symcore.int(1)
      } else if spin_numeric_args([bra.j, ket.j]) {
        @symcore.int(0)
      } else {
        @symcore.raw_function("KroneckerDelta", [bra.j, ket.j])
      }
      if j_factor == @symcore.int(0) {
        return Some(@symcore.int(0))
      }
      if bra.basis_name == ket.basis_name {
        if bra.m == ket.m {
          return Some(j_factor)
        }
        if spin_numeric_args([bra.m, ket.m]) {
          return Some(@symcore.int(0))
        }
        return Some(
          j_factor * @symcore.raw_function("KroneckerDelta", [bra.m, ket.m]),
        )
      }
      let coeff = try! spin_basis_transform_coeff(
        ket.j,
        ket.m,
        bra.m,
        ket.basis_name,
        bra.basis_name,
        spin_numeric_args([ket.j]),
      )
      Some(j_factor * coeff)
    }
    _ => None
  }
}
