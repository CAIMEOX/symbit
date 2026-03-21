///|
/// Angular-momentum operators and uncoupled spin eigenstates.
///
/// This slice covers the uncoupled `Jx`, `Jy`, and `Jz` bases: the global
/// operators `Jplus`, `Jminus`, `Jx`, `Jy`, `Jz`, `J2`, the eigenstates
/// `JxKet/JxBra`, `JyKet/JyBra`, `JzKet/JzBra`, exact ladder-operator action,
/// basis rewrites, and explicit matrix representations.

///|
fn spin_op_symbol(name : String) -> Expr {
  symbol(name)
}

///|
fn spin_numeric_args(args : Array[Expr]) -> Bool {
  for arg in args {
    match arg {
      Expr::Number(_) => ()
      _ => return false
    }
  }
  true
}

///|
fn spin_pi_multiple(num : Int, den : Int) -> Expr {
  if num == 0 {
    int(0)
  } else {
    symbol("pi") * spin_exact_rational(num, den)
  }
}

///|
fn spin_exact_rational(num : Int, den : Int) -> Expr {
  let exact : Result[Expr, @symnum.RationalError] = try? @symcore.rational_from_ints(
    num, den,
  )
  match exact {
    Ok(value) => value
    Err(_) => int(num) * @symcore.pow(int(den), int(-1))
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
fn spin_basis_name_from_expr(expr : Expr?) -> String? {
  match expr {
    Some(Expr::Symbol(name)) if name == "Jx" || name == "Jy" || name == "Jz" =>
      Some(name)
    _ => None
  }
}

///|
fn spin_operator_basis_name(op_expr : Expr) -> String? {
  match op_expr {
    Expr::Symbol("Jx") => Some("Jx")
    Expr::Symbol("Jy") => Some("Jy")
    Expr::Symbol("Jz") => Some("Jz")
    _ => None
  }
}

///|
fn spin_basis_operator_expr(basis_name : String) -> Expr {
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
) -> (Expr, Expr, Expr) {
  if source_basis == target_basis {
    return (int(0), int(0), int(0))
  }
  match (source_basis, target_basis) {
    ("Jx", "Jy") => (spin_pi_multiple(3, 2), int(0), int(0))
    ("Jx", "Jz") => (int(0), spin_pi_multiple(1, 2), int(0))
    ("Jy", "Jx") => (int(0), int(0), spin_pi_multiple(-1, 2))
    ("Jy", "Jz") =>
      (spin_pi_multiple(3, 2), spin_pi_multiple(-1, 2), spin_pi_multiple(1, 2))
    ("Jz", "Jx") => (int(0), spin_pi_multiple(3, 2), int(0))
    ("Jz", "Jy") =>
      (spin_pi_multiple(3, 2), spin_pi_multiple(1, 2), spin_pi_multiple(1, 2))
    _ => (int(0), int(0), int(0))
  }
}

///|
pub fn jplus() -> Expr {
  spin_op_symbol("Jplus")
}

///|
pub fn jminus() -> Expr {
  spin_op_symbol("Jminus")
}

///|
pub fn jx() -> Expr {
  spin_op_symbol("Jx")
}

///|
pub fn jy() -> Expr {
  spin_op_symbol("Jy")
}

///|
pub fn jz() -> Expr {
  spin_op_symbol("Jz")
}

///|
pub fn j2() -> Expr {
  spin_op_symbol("J2")
}

///|
pub struct SpinCoupling {
  left_index : Int
  right_index : Int
  j : Expr
} derive(Eq)

///|
pub fn spin_coupling(
  left_index : Int,
  right_index : Int,
  j : Expr,
) -> SpinCoupling {
  SpinCoupling::{ left_index, right_index, j }
}

///|
pub struct JzState {
  j : Expr
  m : Expr
  is_bra : Bool
  basis_name : String
  jn : Array[Expr]
  coupling : Array[SpinCoupling]
} derive(Eq)

///|
pub struct RotationExpr {
  alpha : Expr
  beta : Expr
  gamma : Expr
} derive(Eq)

///|
pub struct WignerDExpr {
  j : Expr
  m : Expr
  mp : Expr
  alpha : Expr
  beta : Expr
  gamma : Expr
} derive(Eq)

///|
fn spin_state_make(
  j : Expr,
  m : Expr,
  is_bra : Bool,
  basis_name : String,
  jn? : Array[Expr] = [],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  JzState::{ j, m, is_bra, basis_name, jn, coupling }
}

///|
fn spin_default_coupling(
  jn : Array[Expr],
  total_j : Expr,
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
pub fn jx_ket(j : Expr, m : Expr) -> JzState {
  spin_state_make(j, m, false, "Jx")
}

///|
pub fn jx_bra(j : Expr, m : Expr) -> JzState {
  spin_state_make(j, m, true, "Jx")
}

///|
pub fn jy_ket(j : Expr, m : Expr) -> JzState {
  spin_state_make(j, m, false, "Jy")
}

///|
pub fn jy_bra(j : Expr, m : Expr) -> JzState {
  spin_state_make(j, m, true, "Jy")
}

///|
pub fn jz_ket(j : Expr, m : Expr) -> JzState {
  spin_state_make(j, m, false, "Jz")
}

///|
pub fn jz_bra(j : Expr, m : Expr) -> JzState {
  spin_state_make(j, m, true, "Jz")
}

///|
pub fn jx_ket_coupled(
  j : Expr,
  m : Expr,
  jn : Array[Expr],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  let scheme = if !coupling.is_empty() {
    coupling
  } else {
    spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, false, "Jx", jn~, coupling=scheme)
}

///|
pub fn jx_bra_coupled(
  j : Expr,
  m : Expr,
  jn : Array[Expr],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  let scheme = if !coupling.is_empty() {
    coupling
  } else {
    spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, true, "Jx", jn~, coupling=scheme)
}

///|
pub fn jy_ket_coupled(
  j : Expr,
  m : Expr,
  jn : Array[Expr],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  let scheme = if !coupling.is_empty() {
    coupling
  } else {
    spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, false, "Jy", jn~, coupling=scheme)
}

///|
pub fn jy_bra_coupled(
  j : Expr,
  m : Expr,
  jn : Array[Expr],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  let scheme = if !coupling.is_empty() {
    coupling
  } else {
    spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, true, "Jy", jn~, coupling=scheme)
}

///|
pub fn jz_ket_coupled(
  j : Expr,
  m : Expr,
  jn : Array[Expr],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  let scheme = if !coupling.is_empty() {
    coupling
  } else {
    spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, false, "Jz", jn~, coupling=scheme)
}

///|
pub fn jz_bra_coupled(
  j : Expr,
  m : Expr,
  jn : Array[Expr],
  coupling? : Array[SpinCoupling] = [],
) -> JzState {
  let scheme = if !coupling.is_empty() {
    coupling
  } else {
    spin_default_coupling(jn, j)
  }
  spin_state_make(j, m, true, "Jz", jn~, coupling=scheme)
}

///|
pub fn rotation(alpha : Expr, beta : Expr, gamma : Expr) -> RotationExpr {
  RotationExpr::{ alpha, beta, gamma }
}

///|
pub fn rotation_d(j : Expr, m : Expr, mp : Expr, beta : Expr) -> WignerDExpr {
  WignerDExpr::{ j, m, mp, alpha: int(0), beta, gamma: int(0) }
}

///|
pub fn rotation_D(
  j : Expr,
  m : Expr,
  mp : Expr,
  alpha : Expr,
  beta : Expr,
  gamma : Expr,
) -> WignerDExpr {
  WignerDExpr::{ j, m, mp, alpha, beta, gamma }
}

///|
pub fn JzState::as_expr(self : JzState) -> Expr {
  if !self.is_coupled() {
    return @symcore.raw_function(
      spin_state_expr_name(self.basis_name, self.is_bra),
      [self.j, self.m],
    )
  }
  let coupling_args = self.coupling.map(c => {
    @symcore.function("Tuple", [int(c.left_index), int(c.right_index), c.j])
  })
  let args : Array[Expr] = [self.j, self.m, @symcore.function("Tuple", self.jn)]
  if !coupling_args.is_empty() {
    args.push(@symcore.function("Tuple", coupling_args))
  }
  @symcore.raw_function(
    spin_coupled_state_expr_name(self.basis_name, self.is_bra),
    args,
  )
}

///|
pub fn RotationExpr::as_expr(self : RotationExpr) -> Expr {
  @symcore.raw_function("Rotation", [self.alpha, self.beta, self.gamma])
}

///|
pub fn RotationExpr::to_string(self : RotationExpr) -> String {
  "R(\{@symprint.to_string(self.alpha)},\{@symprint.to_string(self.beta)},\{@symprint.to_string(self.gamma)})"
}

///|
pub fn RotationExpr::inverse(self : RotationExpr) -> RotationExpr {
  rotation(int(-1) * self.gamma, int(-1) * self.beta, int(-1) * self.alpha)
}

///|
pub fn WignerDExpr::as_expr(self : WignerDExpr) -> Expr {
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
  if self.alpha == int(0) && self.gamma == int(0) {
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
pub fn JzState::rewrite(self : JzState, basis : Expr) -> Expr {
  let target_basis = match spin_basis_name_from_expr(Some(basis)) {
    Some(name) => name
    None => return self.as_expr()
  }
  let evaluate = spin_numeric_args([self.j])
  spin_rewrite_single_state(self.as_expr(), target_basis, evaluate)
}

///|
pub fn m_values(j : Expr) -> (Int, Array[Expr]) raise @symphysics.PhysicsError {
  let size_expr = int(2) * j + int(1)
  match size_expr {
    Expr::Number(n) if n.is_integral() && n.numerator().to_int() > 0 => {
      let size = n.numerator().to_int()
      let values : Array[Expr] = []
      for idx in 0..<size {
        values.push(j - int(idx))
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
fn spin_state_from_expr_impl(expr : Expr) -> JzState? {
  fn parse_tuple_items(expr : Expr) -> Array[Expr]? {
    match expr {
      Expr::Function("Tuple", args) => Some(args)
      _ => None
    }
  }

  fn parse_coupling_items(expr : Expr) -> Array[SpinCoupling]? {
    match parse_tuple_items(expr) {
      Some(items) => {
        let couplings : Array[SpinCoupling] = []
        for item in items {
          match item {
            Expr::Function("Tuple", [left, right, j]) =>
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
    Expr::Function("JxKet", args) if args.length() == 2 =>
      Some(jx_ket(args[0], args[1]))
    Expr::Function("JxBra", args) if args.length() == 2 =>
      Some(jx_bra(args[0], args[1]))
    Expr::Function("JyKet", args) if args.length() == 2 =>
      Some(jy_ket(args[0], args[1]))
    Expr::Function("JyBra", args) if args.length() == 2 =>
      Some(jy_bra(args[0], args[1]))
    Expr::Function("JzKet", args) if args.length() == 2 =>
      Some(jz_ket(args[0], args[1]))
    Expr::Function("JzBra", args) if args.length() == 2 =>
      Some(jz_bra(args[0], args[1]))
    Expr::Function("JxKetCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          if args.length() >= 4 {
            match parse_coupling_items(args[3]) {
              Some(coupling) =>
                Some(jx_ket_coupled(args[0], args[1], jn, coupling~))
              None => None
            }
          } else {
            Some(jx_ket_coupled(args[0], args[1], jn))
          }
        None => None
      }
    Expr::Function("JxBraCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          if args.length() >= 4 {
            match parse_coupling_items(args[3]) {
              Some(coupling) =>
                Some(jx_bra_coupled(args[0], args[1], jn, coupling~))
              None => None
            }
          } else {
            Some(jx_bra_coupled(args[0], args[1], jn))
          }
        None => None
      }
    Expr::Function("JyKetCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          if args.length() >= 4 {
            match parse_coupling_items(args[3]) {
              Some(coupling) =>
                Some(jy_ket_coupled(args[0], args[1], jn, coupling~))
              None => None
            }
          } else {
            Some(jy_ket_coupled(args[0], args[1], jn))
          }
        None => None
      }
    Expr::Function("JyBraCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          if args.length() >= 4 {
            match parse_coupling_items(args[3]) {
              Some(coupling) =>
                Some(jy_bra_coupled(args[0], args[1], jn, coupling~))
              None => None
            }
          } else {
            Some(jy_bra_coupled(args[0], args[1], jn))
          }
        None => None
      }
    Expr::Function("JzKetCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          if args.length() >= 4 {
            match parse_coupling_items(args[3]) {
              Some(coupling) =>
                Some(jz_ket_coupled(args[0], args[1], jn, coupling~))
              None => None
            }
          } else {
            Some(jz_ket_coupled(args[0], args[1], jn))
          }
        None => None
      }
    Expr::Function("JzBraCoupled", args) if args.length() >= 3 =>
      match parse_tuple_items(args[2]) {
        Some(jn) =>
          if args.length() >= 4 {
            match parse_coupling_items(args[3]) {
              Some(coupling) =>
                Some(jz_bra_coupled(args[0], args[1], jn, coupling~))
              None => None
            }
          } else {
            Some(jz_bra_coupled(args[0], args[1], jn))
          }
        None => None
      }
    _ => None
  }
}

///|
pub fn spin_state_from_expr(expr : Expr) -> JzState? {
  spin_state_from_expr_impl(expr)
}

///|
pub fn jz_state_from_expr(expr : Expr) -> JzState? {
  spin_state_from_expr_impl(expr)
}

///|
pub fn rotation_from_expr(expr : Expr) -> RotationExpr? {
  match expr {
    Expr::Function("Rotation", args) if args.length() == 3 =>
      Some(rotation(args[0], args[1], args[2]))
    _ => None
  }
}

///|
pub fn wigner_d_from_expr(expr : Expr) -> WignerDExpr? {
  match expr {
    Expr::Function("WignerD", args) if args.length() == 6 =>
      Some(rotation_D(args[0], args[1], args[2], args[3], args[4], args[5]))
    _ => None
  }
}

///|
fn spin_m_index(j : Expr, value : Expr) -> Int raise @symphysics.PhysicsError {
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
) -> Expr raise @symphysics.PhysicsError {
  if item.alpha == int(0) && item.beta == int(0) && item.gamma == int(0) {
    if item.m == item.mp {
      return int(1)
    } else {
      return int(0)
    }
  }
  if !evaluate {
    return item.as_expr()
  }
  let matrix = @symphysics.wigner_d(item.j, item.alpha, item.beta, item.gamma)
  let row = spin_m_index(item.j, item.mp)
  let col = spin_m_index(item.j, item.m)
  matrix.get(row, col)
}

///|
pub fn WignerDExpr::doit(
  self : WignerDExpr,
) -> Expr raise @symphysics.PhysicsError {
  spin_wigner_d_value(self, evaluate=true)
}

///|
fn spin_basis_transform_coeff(
  j : Expr,
  source_m : Expr,
  target_m : Expr,
  source_basis : String,
  target_basis : String,
  evaluate : Bool,
) -> Expr raise @symphysics.PhysicsError {
  if source_basis == target_basis {
    if source_m == target_m {
      int(1)
    } else {
      int(0)
    }
  } else {
    let (alpha, beta, gamma) = spin_basis_angles(source_basis, target_basis)
    spin_wigner_d_value(
      rotation_D(j, target_m, source_m, alpha, beta, gamma),
      evaluate~,
    )
  }
}

///|
fn spin_sum_expr(body : Expr, sym : Expr, lower : Expr, upper : Expr) -> Expr {
  @symcore.function("Sum", [
    body,
    @symcore.function("Tuple", [sym, lower, upper]),
  ])
}

///|
fn spin_state_with_basis(
  state : JzState,
  basis_name : String,
  m : Expr,
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
  state_expr : Expr,
  target_basis : String,
  evaluate : Bool,
) -> Expr {
  match spin_state_from_expr(state_expr) {
    Some(state) => {
      if state.basis_name == target_basis {
        return state_expr
      }
      if !evaluate || !spin_numeric_args([state.j]) {
        let mi = symbol("mi")
        let (alpha, beta, gamma) = spin_basis_angles(
          state.basis_name,
          target_basis,
        )
        return spin_sum_expr(
          rotation_D(state.j, mi, state.m, alpha, beta, gamma).as_expr() *
          spin_state_with_basis(state, target_basis, mi).as_expr(),
          mi,
          int(-1) * state.j,
          state.j,
        )
      }
      let mvals_result : Result[(Int, Array[Expr]), @symphysics.PhysicsError] = try? m_values(
        state.j,
      )
      let mvals = match mvals_result {
        Ok((_, values)) => values
        Err(_) => return state_expr
      }
      let terms : Array[Expr] = []
      for mp in mvals {
        let coeff_result : Result[Expr, @symphysics.PhysicsError] = try? spin_basis_transform_coeff(
          state.j,
          state.m,
          mp,
          state.basis_name,
          target_basis,
          evaluate,
        )
        let coeff = match coeff_result {
          Ok(value) => value
          Err(_) => return state_expr
        }
        if coeff != int(0) {
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
  expr : Expr,
  target_basis : String,
  evaluate : Bool,
) -> Expr {
  match spin_state_from_expr(expr) {
    Some(_) => spin_rewrite_single_state(expr, target_basis, evaluate)
    None =>
      match expr {
        Expr::Add(args) =>
          quantum_add_from_args_preserve(
            args.map(arg => {
              spin_rewrite_states_in_expr(arg, target_basis, evaluate)
            }),
          )
        Expr::Mul(args) =>
          quantum_mul_from_args_preserve(
            args.map(arg => {
              spin_rewrite_states_in_expr(arg, target_basis, evaluate)
            }),
          )
        Expr::Function("Sum", args) if !args.is_empty() => {
          let rebuilt : Array[Expr] = [
            spin_rewrite_states_in_expr(args[0], target_basis, evaluate),
          ]
          for idx in 1..<args.length() {
            rebuilt.push(args[idx])
          }
          @symcore.function("Sum", rebuilt)
        }
        Expr::Function(name, args) =>
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
  j : Expr
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
fn spin_sum_all(values : Array[Expr]) -> Expr {
  let mut total = int(0)
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
fn spin_sum_by_indices(values : Array[Expr], indices : Array[Int]) -> Expr {
  let mut total = int(0)
  for idx in indices {
    total = total + values[idx - 1]
  }
  total
}

///|
fn spin_twice_j(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) if n.denominator().equal_int(1) =>
      Some((n.numerator() * @bigint.BigInt::from_int(2)).to_int())
    Expr::Number(n) if n.denominator().equal_int(2) =>
      Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn spin_expr_from_twice_j(value : Int) -> Expr {
  if value % 2 == 0 {
    int(value / 2)
  } else {
    spin_exact_rational(value, 2)
  }
}

///|
fn spin_allowed_j_values(
  j1 : Expr,
  j2 : Expr,
) -> Array[Expr] raise @symphysics.PhysicsError {
  match (spin_twice_j(j1), spin_twice_j(j2)) {
    (Some(tj1), Some(tj2)) => {
      let values : Array[Expr] = []
      let lower = (tj1 - tj2).abs()
      for twice_j in lower..<=(tj1 + tj2) {
        if (twice_j - lower) % 2 == 0 {
          values.push(spin_expr_from_twice_j(twice_j))
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
  expr : Expr,
  f : (Expr) -> Expr raise @symphysics.PhysicsError,
) -> Expr raise @symphysics.PhysicsError {
  match expr {
    Expr::Function("TensorProduct", args) =>
      f(@symcore.raw_function("TensorProduct", args))
    Expr::Add(args) => {
      let mapped : Array[Expr] = []
      for arg in args {
        mapped.push(spin_map_tensor_products(arg, f))
      }
      quantum_add_from_args_preserve(mapped)
    }
    Expr::Mul(args) => {
      let mapped : Array[Expr] = []
      for arg in args {
        mapped.push(spin_map_tensor_products(arg, f))
      }
      quantum_mul_from_args_preserve(mapped)
    }
    Expr::Function(name, args) => {
      let mapped : Array[Expr] = []
      for arg in args {
        mapped.push(spin_map_tensor_products(arg, f))
      }
      @symcore.raw_function(name, mapped)
    }
    _ => expr
  }
}

///|
fn spin_map_states(
  expr : Expr,
  f : (Expr) -> Expr raise @symphysics.PhysicsError,
) -> Expr raise @symphysics.PhysicsError {
  match spin_state_from_expr(expr) {
    Some(_) => f(expr)
    None =>
      match expr {
        Expr::Add(args) => {
          let mapped : Array[Expr] = []
          for arg in args {
            mapped.push(spin_map_states(arg, f))
          }
          quantum_add_from_args_preserve(mapped)
        }
        Expr::Mul(args) => {
          let mapped : Array[Expr] = []
          for arg in args {
            mapped.push(spin_map_states(arg, f))
          }
          quantum_mul_from_args_preserve(mapped)
        }
        Expr::Function(name, args) => {
          let mapped : Array[Expr] = []
          for arg in args {
            mapped.push(spin_map_states(arg, f))
          }
          @symcore.raw_function(name, mapped)
        }
        _ => expr
      }
  }
}

///|
fn spin_couple_tensor_product(
  expr : Expr,
  orders? : Array[SpinCoupleOrder]? = None,
) -> Expr raise @symphysics.PhysicsError {
  match expr {
    Expr::Function("TensorProduct", args) if !args.is_empty() => {
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
      let resolved = spin_resolve_orders(items.length(), scheme)
      let numeric_args = items.map(s => s.j)
      for item in items {
        numeric_args.push(item.m)
      }
      if spin_numeric_args(numeric_args) {
        let jn = items.map(s => s.j)
        let mn = items.map(s => s.m)
        let total_m = spin_sum_all(mn)
        let terms : Array[Expr] = []

        fn go(
          step : Int,
          current_j : Array[Expr],
          coeff : Expr,
          triples : Array[SpinCoupling],
        ) -> Unit raise @symphysics.PhysicsError {
          if step >= resolved.length() {
            if coeff != int(0) {
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
          for j3 in spin_allowed_j_values(j1, j2) {
            let cg_coeff = cg(j1, m1, j2, m2, j3, m3).doit()
            if cg_coeff != int(0) {
              let updated = current_j.copy()
              updated[merged[0] - 1] = j3
              let next = triples.copy()
              next.push(SpinCoupling::{ left_index, right_index, j: j3 })
              go(step + 1, updated, coeff * cg_coeff, next)
            }
          }
        }

        go(0, items.map(s => s.j), int(1), [])
        quantum_add_from_args_preserve(terms)
      } else {
        let total_m = spin_sum_all(items.map(s => s.m))
        let total_j = symbol("j")
        let current_j = items.map(s => s.j)
        let coeffs : Array[Expr] = []
        let sum_specs : Array[Expr] = []
        let couplings : Array[SpinCoupling] = []

        fn coupling_symbol_name(indices : Array[Int]) -> String {
          let suffix = indices.map(idx => idx.to_string()).join("")
          "j\{suffix}"
        }

        for step in 0..<resolved.length() {
          let pair = resolved[step]
          let left_index = pair.left_ns[0]
          let right_index = pair.right_ns[0]
          let j1 = current_j[left_index - 1]
          let j2 = current_j[right_index - 1]
          let m1 = spin_sum_by_indices(items.map(s => s.m), pair.left_ns)
          let m2 = spin_sum_by_indices(items.map(s => s.m), pair.right_ns)
          let m3 = m1 + m2
          let merged = spin_union_indices(pair.left_ns, pair.right_ns)
          let j3 = if step + 1 == resolved.length() {
            total_j
          } else {
            symbol(coupling_symbol_name(merged))
          }
          coeffs.push(cg(j1, m1, j2, m2, j3, m3).as_expr())
          couplings.push(SpinCoupling::{
            left_index: scheme[step].left_index,
            right_index: scheme[step].right_index,
            j: j3,
          })
          sum_specs.push(@symcore.function("Tuple", [j3, m3, j1 + j2]))
          current_j[merged[0] - 1] = j3
        }
        let coupled_state = spin_state_make(
          total_j,
          total_m,
          first.is_bra,
          first.basis_name,
          jn=items.map(s => s.j),
          coupling=couplings,
        )
        let factors = coeffs.copy()
        factors.push(coupled_state.as_expr())
        let sum_args : Array[Expr] = [quantum_mul_from_args_preserve(factors)]
        for spec in sum_specs {
          sum_args.push(spec)
        }
        @symcore.function("Sum", sum_args)
      }
    }
    _ => expr
  }
}

///|
pub fn couple(
  expr : Expr,
  orders? : Array[SpinCoupleOrder] = [],
) -> Expr raise @symphysics.PhysicsError {
  spin_map_tensor_products(expr, expr => {
    spin_couple_tensor_product(
      expr,
      orders=if orders.is_empty() { None } else { Some(orders) },
    )
  })
}

///|
fn spin_uncouple_state_expr(
  expr : Expr,
  jn? : Array[Expr]? = None,
  coupling? : Array[SpinCoupling]? = None,
) -> Expr raise @symphysics.PhysicsError {
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
  let numeric_args : Array[Expr] = [coupled_state.j, coupled_state.m]
  for value in j_values {
    numeric_args.push(value)
  }
  if spin_numeric_args(numeric_args) {
    let resolved = spin_resolve_couplings(
      j_values.length(),
      coupled_state.coupling,
    )
    let m_lists : Array[Array[Expr]] = []
    for jv in j_values {
      m_lists.push(m_values(jv).1)
    }
    let chosen = Array::make(j_values.length(), int(0))
    let terms : Array[Expr] = []
    fn enumerate(idx : Int) -> Unit raise @symphysics.PhysicsError {
      if idx >= j_values.length() {
        let total_m = spin_sum_all(chosen)
        if total_m != coupled_state.m {
          return
        }
        let mut coeff = int(1)
        for item in resolved {
          let m1 = spin_sum_by_indices(chosen, item.left_ns)
          let m2 = spin_sum_by_indices(chosen, item.right_ns)
          let m3 = m1 + m2
          coeff = coeff *
            cg(
              j_values[item.left_ns[0] - 1],
              m1,
              j_values[item.right_ns[0] - 1],
              m2,
              item.j,
              m3,
            ).doit()
          if coeff == int(0) {
            return
          }
        }
        let states : Array[Expr] = []
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
        enumerate(idx + 1)
      }
    }
    enumerate(0)
    quantum_add_from_args_preserve(terms)
  } else {
    let mvars : Array[Expr] = []
    for idx in 0..<j_values.length() {
      mvars.push(symbol("m\{idx + 1}"))
    }
    let resolved = spin_resolve_couplings(
      j_values.length(),
      coupled_state.coupling,
    )
    let current_j = j_values.copy()
    let coeffs : Array[Expr] = []
    for idx in 0..<resolved.length() {
      let item = resolved[idx]
      let left_index = item.left_ns[0]
      let right_index = item.right_ns[0]
      let j1 = current_j[left_index - 1]
      let j2 = current_j[right_index - 1]
      let m1 = spin_sum_by_indices(mvars, item.left_ns)
      let m2 = spin_sum_by_indices(mvars, item.right_ns)
      let m3 = if idx + 1 == resolved.length() {
        coupled_state.m
      } else {
        m1 + m2
      }
      coeffs.push(cg(j1, m1, j2, m2, item.j, m3).as_expr())
      let merged = spin_union_indices(item.left_ns, item.right_ns)
      current_j[merged[0] - 1] = item.j
    }
    let states : Array[Expr] = []
    for idx in 0..<j_values.length() {
      states.push(
        spin_state_make(j_values[idx], mvars[idx], is_bra, basis_name).as_expr(),
      )
    }
    let factors : Array[Expr] = coeffs.copy()
    factors.push(tensor_product(states).as_expr())
    let sum_specs : Array[Expr] = []
    for idx in 0..<j_values.length() {
      sum_specs.push(
        @symcore.function("Tuple", [
          mvars[idx],
          int(-1) * j_values[idx],
          j_values[idx],
        ]),
      )
    }
    let sum_args : Array[Expr] = [quantum_mul_from_args_preserve(factors)]
    for spec in sum_specs {
      sum_args.push(spec)
    }
    @symcore.function("Sum", sum_args)
  }
}

///|
pub fn uncouple(
  expr : Expr,
  jn? : Array[Expr] = [],
  coupling? : Array[SpinCoupling] = [],
) -> Expr raise @symphysics.PhysicsError {
  spin_map_states(expr, expr => {
    spin_uncouple_state_expr(
      expr,
      jn=if jn.is_empty() { None } else { Some(jn) },
      coupling=if coupling.is_empty() { None } else { Some(coupling) },
    )
  })
}

///|
fn spin_linear_combination_from_vector(
  state : JzState,
  vector : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  let (_, mvals) = m_values(state.j)
  let terms : Array[Expr] = []
  for idx in 0..<mvals.length() {
    let coeff = vector.get(idx, 0)
    if coeff != int(0) {
      terms.push(
        coeff *
        spin_state_with_basis(state, state.basis_name, mvals[idx]).as_expr(),
      )
    }
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn spin_ladder_coeff(j : Expr, m : Expr, step : Int) -> Expr {
  if step > 0 {
    @symcore.raw_function("sqrt", [j * (j + int(1)) - m * (m + int(1))])
  } else {
    @symcore.raw_function("sqrt", [j * (j + int(1)) - m * (m - int(1))])
  }
}

///|
pub fn spin_apply_operator_to_ket(op_expr : Expr, ket_expr : Expr) -> Expr? {
  match (rotation_from_expr(op_expr), spin_state_from_expr(ket_expr)) {
    (Some(op), Some(state)) if !state.is_bra => {
      let mvals_result : Result[(Int, Array[Expr]), @symphysics.PhysicsError] = try? m_values(
        state.j,
      )
      let mvals = match mvals_result {
        Ok((_, values)) => values
        Err(_) => return None
      }
      let terms : Array[Expr] = []
      for mp in mvals {
        let coeff_result : Result[Expr, @symphysics.PhysicsError] = try? spin_wigner_d_value(
          rotation_D(state.j, state.m, mp, op.alpha, op.beta, op.gamma),
          evaluate=true,
        )
        let coeff = match coeff_result {
          Ok(value) => value
          Err(_) => return None
        }
        if coeff != int(0) {
          terms.push(
            coeff * spin_state_with_basis(state, state.basis_name, mp).as_expr(),
          )
        }
      }
      Some(quantum_add_from_args_preserve(terms))
    }
    _ =>
      match (op_expr, spin_state_from_expr(ket_expr)) {
        (Expr::Symbol(name), Some(state)) if !state.is_bra => {
          let j = state.j
          let m = state.m
          match spin_operator_basis_name(op_expr) {
            Some(op_basis) if op_basis == state.basis_name =>
              return Some(hbar * m * ket_expr)
            _ => ()
          }
          match name {
            "J2" => Some((hbar ^ int(2)) * j * (j + int(1)) * ket_expr)
            "Jplus" if state.basis_name == "Jz" =>
              if m == j {
                Some(int(0))
              } else {
                let raised_state = if state.is_coupled() {
                  jz_ket_coupled(
                    j,
                    m + int(1),
                    state.jn,
                    coupling=state.coupling,
                  )
                } else {
                  jz_ket(j, m + int(1))
                }
                Some(hbar * spin_ladder_coeff(j, m, 1) * raised_state.as_expr())
              }
            "Jminus" if state.basis_name == "Jz" =>
              if m == int(-1) * j {
                Some(int(0))
              } else {
                let lowered_state = if state.is_coupled() {
                  jz_ket_coupled(
                    j,
                    m - int(1),
                    state.jn,
                    coupling=state.coupling,
                  )
                } else {
                  jz_ket(j, m - int(1))
                }
                Some(
                  hbar * spin_ladder_coeff(j, m, -1) * lowered_state.as_expr(),
                )
              }
            "Jx" if state.basis_name == "Jz" =>
              Some(
                spin_exact_rational(1, 2) *
                (
                  spin_apply_operator_to_ket(jplus(), ket_expr).unwrap_or(
                    int(0),
                  ) +
                  spin_apply_operator_to_ket(jminus(), ket_expr).unwrap_or(
                    int(0),
                  )
                ),
              )
            "Jy" if state.basis_name == "Jz" =>
              Some(
                spin_exact_rational(1, 2) *
                int(-1) *
                symbol("I") *
                (
                  spin_apply_operator_to_ket(jplus(), ket_expr).unwrap_or(
                    int(0),
                  ) -
                  spin_apply_operator_to_ket(jminus(), ket_expr).unwrap_or(
                    int(0),
                  )
                ),
              )
            "Jplus" | "Jminus" | "Jx" | "Jy" | "Jz" =>
              if spin_numeric_args([state.j]) {
                let basis_expr = spin_basis_operator_expr(state.basis_name)
                let matrix_result : Result[
                  @symphysics.ExplicitMatrix,
                  @symphysics.PhysicsError,
                ] = try? represent_spin_operator(
                  op_expr,
                  state.j,
                  basis=Some(basis_expr),
                )
                let matrix = match matrix_result {
                  Ok(value) => value
                  Err(_) => return None
                }
                let vector_result : Result[
                  @symphysics.ExplicitMatrix,
                  @symphysics.PhysicsError,
                ] = try? represent_spin_state(
                  ket_expr,
                  basis=Some(basis_expr),
                  evaluate=true,
                )
                let vector = match vector_result {
                  Ok(value) => value
                  Err(_) => return None
                }
                let product_result : Result[
                  @symphysics.ExplicitMatrix,
                  @symphysics.PhysicsError,
                ] = try? matrix.mul(vector)
                let product = match product_result {
                  Ok(value) => value
                  Err(_) => return None
                }
                let state_result : Result[Expr, @symphysics.PhysicsError] = try? spin_linear_combination_from_vector(
                  state, product,
                )
                match state_result {
                  Ok(value) => Some(value)
                  Err(_) => None
                }
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
  op_expr : Expr,
  j : Expr,
  m : Expr,
  mp : Expr,
) -> Expr {
  match op_expr {
    Expr::Symbol(name) =>
      match name {
        "Jz" => if m == mp { hbar * mp } else { int(0) }
        "J2" =>
          if m == mp {
            (hbar ^ int(2)) * j * (j + int(1))
          } else {
            int(0)
          }
        "Jplus" =>
          if m == mp + int(1) {
            hbar * spin_ladder_coeff(j, mp, 1)
          } else {
            int(0)
          }
        "Jminus" =>
          if m == mp - int(1) {
            hbar * spin_ladder_coeff(j, mp, -1)
          } else {
            int(0)
          }
        "Jx" =>
          spin_exact_rational(1, 2) *
          (
            spin_op_matrix_element(jplus(), j, m, mp) +
            spin_op_matrix_element(jminus(), j, m, mp)
          )
        "Jy" =>
          spin_exact_rational(1, 2) *
          int(-1) *
          symbol("I") *
          (
            spin_op_matrix_element(jplus(), j, m, mp) -
            spin_op_matrix_element(jminus(), j, m, mp)
          )
        _ => int(0)
      }
    _ => int(0)
  }
}

///|
pub fn represent_spin_jz_operator(
  op_expr : Expr,
  j : Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let (size, mvals) = m_values(j)
  let rows : Array[Array[Expr]] = []
  for p in 0..<size {
    let row : Array[Expr] = []
    for q in 0..<size {
      row.push(spin_op_matrix_element(op_expr, j, mvals[p], mvals[q]))
    }
    rows.push(row)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn represent_spin_state(
  state_expr : Expr,
  basis? : Expr? = None,
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
        let row = Array::make(size, int(0))
        for idx in 0..<size {
          row[idx] = spin_basis_transform_coeff(
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
        let rows : Array[Array[Expr]] = []
        for idx in 0..<size {
          rows.push([
            spin_basis_transform_coeff(
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
fn spin_coupling_orders(
  coupling : Array[SpinCoupling],
) -> Array[SpinCoupleOrder] {
  let orders : Array[SpinCoupleOrder] = []
  for item in coupling {
    orders.push(SpinCoupleOrder::{
      left_index: item.left_index,
      right_index: item.right_index,
    })
  }
  orders
}

///|
fn spin_enumerate_coupling_schemes(
  jn : Array[Expr],
  coupling : Array[SpinCoupling],
) -> Array[Array[SpinCoupling]] raise @symphysics.PhysicsError {
  let orders = spin_coupling_orders(coupling)
  let resolved = spin_resolve_orders(jn.length(), orders)
  let results : Array[Array[SpinCoupling]] = []

  fn go(
    step : Int,
    current_j : Array[Expr],
    current : Array[SpinCoupling],
  ) -> Unit raise @symphysics.PhysicsError {
    if step >= resolved.length() {
      results.push(current.copy())
      return
    }
    let pair = resolved[step]
    let order = orders[step]
    let left_index = pair.left_ns[0]
    let right_index = pair.right_ns[0]
    let j1 = current_j[left_index - 1]
    let j2 = current_j[right_index - 1]
    let merged = spin_union_indices(pair.left_ns, pair.right_ns)
    for j3 in spin_allowed_j_values(j1, j2) {
      let updated = current_j.copy()
      updated[merged[0] - 1] = j3
      let next = current.copy()
      next.push(SpinCoupling::{
        left_index: order.left_index,
        right_index: order.right_index,
        j: j3,
      })
      go(step + 1, updated, next)
    }
  }

  go(0, jn.copy(), [])
  results
}

///|
pub fn represent_spin_coupled_state(
  state_expr : Expr,
  basis? : Expr? = None,
  evaluate? : Bool = true,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let state = match spin_state_from_expr(state_expr) {
    Some(value) if value.is_coupled() => value
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "Expected a coupled spin basis state",
      )
  }
  guard spin_numeric_args(state.jn) && spin_numeric_args([state.j]) else {
    raise @symphysics.PhysicsError::ValueError(
      "Only numeric coupled spin representations are supported",
    )
  }
  let target_basis = match spin_basis_name_from_expr(basis) {
    Some(name) => name
    None => state.basis_name
  }
  let sector = represent_spin_state(
    state_expr,
    basis=Some(spin_basis_operator_expr(target_basis)),
    evaluate~,
  )
  let schemes = spin_enumerate_coupling_schemes(state.jn, state.coupling)
  if state.is_bra {
    let row : Array[Expr] = []
    for scheme in schemes {
      let block_size = m_values(scheme[scheme.length() - 1].j).0
      if scheme == state.coupling {
        for col in 0..<block_size {
          row.push(sector.get(0, col))
        }
      } else {
        for _ in 0..<block_size {
          row.push(int(0))
        }
      }
    }
    @symphysics.explicit_matrix_from_rows([row])
  } else {
    let rows : Array[Array[Expr]] = []
    for scheme in schemes {
      let block_size = m_values(scheme[scheme.length() - 1].j).0
      if scheme == state.coupling {
        for row in 0..<block_size {
          rows.push([sector.get(row, 0)])
        }
      } else {
        for _ in 0..<block_size {
          rows.push([int(0)])
        }
      }
    }
    @symphysics.explicit_matrix_from_rows(rows)
  }
}

///|
pub fn represent_spin_jz_state(
  state_expr : Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  represent_spin_state(state_expr, basis=Some(jz()))
}

///|
fn spin_basis_matrix_in_jz(
  j : Expr,
  basis_name : String,
  evaluate : Bool,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let (size, mvals) = m_values(j)
  let rows : Array[Array[Expr]] = []
  for _ in 0..<size {
    rows.push(Array::make(size, int(0)))
  }
  for col in 0..<size {
    let state = @symcore.raw_function(spin_state_expr_name(basis_name, false), [
      j,
      mvals[col],
    ])
    let vector = represent_spin_state(state, basis=Some(jz()), evaluate~)
    for row in 0..<size {
      rows[row][col] = vector.get(row, 0)
    }
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn represent_spin_operator(
  op_expr : Expr,
  j : Expr,
  basis? : Expr? = None,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let target_basis = match spin_basis_name_from_expr(basis) {
    Some(name) => name
    None => "Jz"
  }
  let z_matrix = represent_spin_jz_operator(op_expr, j)
  if target_basis == "Jz" {
    return z_matrix
  }
  let change = spin_basis_matrix_in_jz(j, target_basis, true)
  matrix_dagger(change).mul(z_matrix).mul(change)
}

///|
pub fn represent_spin_rotation(
  expr : Expr,
  j : Expr,
  evaluate? : Bool = false,
) -> @symphysics.ExplicitMatrix? raise @symphysics.PhysicsError {
  match rotation_from_expr(expr) {
    Some(op) => {
      let (_, mvals) = m_values(j)
      let rows : Array[Array[Expr]] = []
      for m in mvals {
        let row : Array[Expr] = []
        for mp in mvals {
          row.push(
            spin_wigner_d_value(
              rotation_D(j, m, mp, op.alpha, op.beta, op.gamma),
              evaluate~,
            ),
          )
        }
        rows.push(row)
      }
      Some(@symphysics.explicit_matrix_from_rows(rows))
    }
    None => None
  }
}

///|
pub fn spin_inner_product(bra_expr : Expr, ket_expr : Expr) -> Expr? {
  match (spin_state_from_expr(bra_expr), spin_state_from_expr(ket_expr)) {
    (Some(bra), Some(ket)) if bra.is_bra && !ket.is_bra => {
      if bra.is_coupled() != ket.is_coupled() {
        return None
      }
      if bra.is_coupled() && (bra.jn != ket.jn || bra.coupling != ket.coupling) {
        return Some(int(0))
      }
      let j_factor = if bra.j == ket.j {
        int(1)
      } else if spin_numeric_args([bra.j, ket.j]) {
        int(0)
      } else {
        @symcore.raw_function("KroneckerDelta", [bra.j, ket.j])
      }
      if j_factor == int(0) {
        return Some(int(0))
      }
      if bra.basis_name == ket.basis_name {
        if bra.m == ket.m {
          return Some(j_factor)
        }
        if spin_numeric_args([bra.m, ket.m]) {
          return Some(int(0))
        }
        return Some(
          j_factor * @symcore.raw_function("KroneckerDelta", [bra.m, ket.m]),
        )
      }
      let coeff_result : Result[Expr, @symphysics.PhysicsError] = try? spin_basis_transform_coeff(
        ket.j,
        ket.m,
        bra.m,
        ket.basis_name,
        bra.basis_name,
        spin_numeric_args([ket.j]),
      )
      match coeff_result {
        Ok(coeff) => Some(j_factor * coeff)
        Err(_) => None
      }
    }
    _ => None
  }
}
