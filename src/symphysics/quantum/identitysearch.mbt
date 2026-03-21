///|
/// Gate-identity search aligned with `sympy.physics.quantum.identitysearch`.
///
/// SymPy models identities as circuits whose matrix representation is a scalar
/// multiple of the identity. The MoonBit port keeps the same core algorithms:
///
/// - scalar-matrix detection for exact explicit matrices;
/// - rule generation through the `LL/LR/RL/RR` moves;
/// - equivalent-identity generation;
/// - breadth-first and random identity searches.
///
/// The public API is more explicit than Python's tuple/set surface:
/// circuits are `Array[Expr]`, rules are `GateRule`, and search
/// results are deterministic arrays sorted by circuit string.

///|
pub struct GateRule {
  left : Array[Expr]
  right : Array[Expr]
} derive(Eq)

///|
fn gate_sequence_expr(sequence : Array[Expr]) -> Expr {
  quantum_mul_from_args_preserve(sequence)
}

///|
fn gate_sequence_key(sequence : Array[Expr]) -> String {
  @symprint.to_string(gate_sequence_expr(sequence))
}

///|
fn gate_rule_key(rule : GateRule) -> String {
  gate_sequence_key(rule.left) + " == " + gate_sequence_key(rule.right)
}

///|
fn gate_rule_reverse_key(rule : GateRule) -> String {
  gate_sequence_key(rule.right) + " == " + gate_sequence_key(rule.left)
}

///|
fn gate_rule_exists(rules : Array[GateRule], rule : GateRule) -> Bool {
  let key = gate_rule_key(rule)
  let reverse_key = gate_rule_reverse_key(rule)
  for item in rules {
    let item_key = gate_rule_key(item)
    if item_key == key || item_key == reverse_key {
      return true
    }
  }
  false
}

///|
fn gate_sequence_exists(
  sequences : Array[Array[Expr]],
  sequence : Array[Expr],
) -> Bool {
  let key = gate_sequence_key(sequence)
  for item in sequences {
    if gate_sequence_key(item) == key {
      return true
    }
  }
  false
}

///|
fn gate_min_qubits(expr : Expr) -> Int {
  match expr {
    Expr::Pow(base, _) => gate_min_qubits(base)
    Expr::Function("Dagger", args) if args.length() == 1 =>
      gate_min_qubits(args[0])
    Expr::Function("QFT", args)
    | Expr::Function("IQFT", args)
    | Expr::Function("OracleGate", args)
    | Expr::Function("WGate", args)
    | Expr::Function("CMod", args) if args.length() >= 1 =>
      match quantum_integer_value(args[0]) {
        Some(value) if value > 0 => value
        _ => 1
      }
    _ =>
      match gate_support(expr) {
        Some(support) if !support.is_empty() => {
          let mut max_index = support[0]
          for item in support {
            if item > max_index {
              max_index = item
            }
          }
          max_index + 1
        }
        _ => 1
      }
  }
}

///|
fn gate_scalar_matrix_from_expr(
  expr : Expr,
  nqubits : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  if quantum_is_scalar_like(expr) {
    @symphysics.explicit_matrix_eye(1 << nqubits).scale(expr)
  } else {
    represent_matrix(expr, nqubits~)
  }
}

///|
fn matrix_is_scalar_multiple(
  matrix : @symphysics.ExplicitMatrix,
  identity_only : Bool,
) -> Bool raise @symphysics.PhysicsError {
  guard matrix.height() == matrix.width() else { return false }
  guard matrix.height() > 0 else { return true }
  let diagonal = matrix.get(0, 0)
  if identity_only && diagonal != int(1) {
    return false
  }
  if diagonal == int(0) {
    for row in 0..<matrix.height() {
      for col in 0..<matrix.width() {
        if matrix.get(row, col) != int(0) {
          return false
        }
      }
    }
    return false
  }
  for row in 0..<matrix.height() {
    for col in 0..<matrix.width() {
      let value = matrix.get(row, col)
      if row == col {
        if value != diagonal {
          return false
        }
      } else if value != int(0) {
        return false
      }
    }
  }
  true
}

///|
pub fn is_scalar_nonsparse_matrix(
  circuit : Array[Expr],
  nqubits : Int,
  identity_only : Bool,
) -> Bool raise @symphysics.PhysicsError {
  let simplified = gate_simp(gate_sequence_expr(circuit))
  if quantum_is_scalar_like(simplified) {
    if identity_only {
      return simplified == int(1)
    } else {
      return true
    }
  }
  let matrix = gate_scalar_matrix_from_expr(simplified, nqubits)
  matrix_is_scalar_multiple(matrix, identity_only)
}

///|
pub fn is_scalar_sparse_matrix(
  circuit : Array[Expr],
  nqubits : Int,
  identity_only : Bool,
) -> Bool raise @symphysics.PhysicsError {
  is_scalar_nonsparse_matrix(circuit, nqubits, identity_only)
}

///|
pub fn is_scalar_matrix(
  circuit : Array[Expr],
  nqubits : Int,
  identity_only : Bool,
) -> Bool raise @symphysics.PhysicsError {
  is_scalar_nonsparse_matrix(circuit, nqubits, identity_only)
}

///|
fn ll_op(
  left : Array[Expr],
  right : Array[Expr],
) -> GateRule? raise @symphysics.PhysicsError {
  guard !left.is_empty() else { return None }
  let gate = left[0]
  if !is_scalar_matrix([dagger(gate), gate], gate_min_qubits(gate), true) {
    return None
  }
  let new_right : Array[Expr] = [dagger(gate)]
  for item in right {
    new_right.push(item)
  }
  Some(GateRule::{ left: left[1:left.length()].to_array(), right: new_right })
}

///|
fn lr_op(
  left : Array[Expr],
  right : Array[Expr],
) -> GateRule? raise @symphysics.PhysicsError {
  guard !left.is_empty() else { return None }
  let gate = left[left.length() - 1]
  if !is_scalar_matrix([dagger(gate), gate], gate_min_qubits(gate), true) {
    return None
  }
  let new_right = right.copy()
  new_right.push(dagger(gate))
  Some(GateRule::{
    left: left[0:left.length() - 1].to_array(),
    right: new_right,
  })
}

///|
fn rl_op(
  left : Array[Expr],
  right : Array[Expr],
) -> GateRule? raise @symphysics.PhysicsError {
  guard !right.is_empty() else { return None }
  let gate = right[0]
  if !is_scalar_matrix([dagger(gate), gate], gate_min_qubits(gate), true) {
    return None
  }
  let new_left : Array[Expr] = [dagger(gate)]
  for item in left {
    new_left.push(item)
  }
  Some(GateRule::{ left: new_left, right: right[1:right.length()].to_array() })
}

///|
fn rr_op(
  left : Array[Expr],
  right : Array[Expr],
) -> GateRule? raise @symphysics.PhysicsError {
  guard !right.is_empty() else { return None }
  let gate = right[right.length() - 1]
  if !is_scalar_matrix([dagger(gate), gate], gate_min_qubits(gate), true) {
    return None
  }
  let new_left = left.copy()
  new_left.push(dagger(gate))
  Some(GateRule::{
    left: new_left,
    right: right[0:right.length() - 1].to_array(),
  })
}

///|
fn gate_rule_sort_key(rule : GateRule) -> String {
  gate_sequence_key(rule.left) + "|" + gate_sequence_key(rule.right)
}

///|
pub fn generate_gate_rules(
  gate_seq : Array[Expr],
) -> Array[GateRule] raise @symphysics.PhysicsError {
  let rules : Array[GateRule] = [GateRule::{ left: gate_seq.copy(), right: [] }]
  let queue : Array[(Array[Expr], Array[Expr], Int)] = [
    (gate_seq.copy(), [], 0),
  ]
  let max_ops = gate_seq.length()
  let mut head = 0
  while head < queue.length() {
    let (left, right, ops) = queue[head]
    head += 1
    let candidates : Array[GateRule?] = [
      ll_op(left, right),
      lr_op(left, right),
      rl_op(left, right),
      rr_op(left, right),
    ]
    for candidate in candidates {
      match candidate {
        Some(rule) =>
          if !gate_rule_exists(rules, rule) {
            rules.push(rule)
            if ops + 1 < max_ops {
              queue.push((rule.left.copy(), rule.right.copy(), ops + 1))
            }
          }
        None => ()
      }
    }
  }
  rules.sort_by((lhs, rhs) => {
    gate_rule_sort_key(lhs).compare(gate_rule_sort_key(rhs))
  })
  rules
}

///|
pub fn generate_equivalent_ids(
  gate_seq : Array[Expr],
) -> Array[Expr] raise @symphysics.PhysicsError {
  let out : Array[Array[Expr]] = []
  let rules = generate_gate_rules(gate_seq)
  for rule in rules {
    if rule.left.is_empty() {
      if !gate_sequence_exists(out, rule.right) {
        out.push(rule.right.copy())
      }
    } else if rule.right.is_empty() {
      if !gate_sequence_exists(out, rule.left) {
        out.push(rule.left.copy())
      }
    }
  }
  out.sort_by((lhs, rhs) => {
    gate_sequence_key(lhs).compare(gate_sequence_key(rhs))
  })
  out.map(gate_sequence_expr)
}

///|
pub fn build_gate_identity(
  gate_seq : Array[Expr],
) -> GateIdentity raise @symphysics.PhysicsError {
  let rules = generate_gate_rules(gate_seq)
  let equivalent_ids = generate_equivalent_ids(gate_seq)
  GateIdentity::{
    sequence: gate_seq.copy(),
    rules,
    equivalent_ids: equivalent_ids.map(expr => {
      match expr {
        Expr::Mul(args) => args.copy()
        Expr::Number(n) if n.is_integral() && n.numerator().to_int() == 1 => []
        _ => [expr]
      }
    }),
  }
}

///|
pub fn GateRule::left_expr(self : GateRule) -> Expr {
  gate_sequence_expr(self.left)
}

///|
pub fn GateRule::right_expr(self : GateRule) -> Expr {
  gate_sequence_expr(self.right)
}

///|
pub fn GateRule::to_string(self : GateRule) -> String {
  gate_rule_key(self)
}

///|
pub fn GateIdentity::circuit(self : GateIdentity) -> Expr {
  if self.sequence.is_empty() {
    if self.equivalent_ids.is_empty() {
      int(1)
    } else {
      gate_simp(gate_sequence_expr(self.equivalent_ids[0]))
    }
  } else {
    gate_simp(gate_sequence_expr(self.sequence))
  }
}

///|
pub fn GateIdentity::sequence_exprs(self : GateIdentity) -> Array[Expr] {
  if self.sequence.is_empty() {
    if self.equivalent_ids.is_empty() {
      []
    } else {
      self.equivalent_ids[0].copy()
    }
  } else {
    self.sequence.copy()
  }
}

///|
pub fn GateIdentity::gate_rules(self : GateIdentity) -> Array[GateRule] {
  self.rules.copy()
}

///|
pub fn GateIdentity::equivalent_id_exprs(self : GateIdentity) -> Array[Expr] {
  self.equivalent_ids.map(gate_sequence_expr)
}

///|
pub fn GateIdentity::to_string(self : GateIdentity) -> String {
  @symprint.to_string(self.circuit())
}

///|
pub fn is_degenerate(
  identity_set : Array[GateIdentity],
  gate_seq : Array[Expr],
) -> Bool {
  let key = gate_sequence_key(gate_seq)
  for identity in identity_set {
    for expr in identity.equivalent_id_exprs() {
      if @symprint.to_string(expr) == key {
        return true
      }
    }
  }
  false
}

///|
pub fn is_reducible(
  circuit : Array[Expr],
  nqubits : Int,
  begin : Int,
  end_ : Int,
) -> Bool raise @symphysics.PhysicsError {
  let mut current : Array[Expr] = []
  let mut idx = end_ - 1
  while idx >= begin {
    let next_current : Array[Expr] = [circuit[idx]]
    for item in current {
      next_current.push(item)
    }
    current = next_current
    let is_scalar = is_scalar_matrix(current, nqubits, false)
    if is_scalar {
      return true
    }
    idx -= 1
  }
  false
}

///|
pub fn bfs_identity_search(
  gate_list : Array[Expr],
  nqubits : Int,
  max_depth? : Int = -1,
  identity_only? : Bool = false,
) -> Array[GateIdentity] raise @symphysics.PhysicsError {
  let effective_depth = if max_depth <= 0 {
    gate_list.length()
  } else {
    max_depth
  }
  let ids : Array[GateIdentity] = []
  let queue : Array[Array[Expr]] = [[]]
  let mut head = 0
  while head < queue.length() {
    let current = queue[head]
    head += 1
    for gate in gate_list {
      let next = current.copy()
      next.push(gate)
      let reducible = if next.length() > 1 {
        is_reducible(next, nqubits, 1, next.length())
      } else {
        false
      }
      let is_scalar = is_scalar_matrix(next, nqubits, identity_only)
      if !reducible && is_scalar && !is_degenerate(ids, next) {
        ids.push(build_gate_identity(next))
      } else if !reducible && next.length() < effective_depth {
        queue.push(next)
      }
    }
  }
  ids.sort_by((lhs, rhs) => lhs.to_string().compare(rhs.to_string()))
  ids
}

///|
let identitysearch_random_source : @random.Rand = @random.Rand::new()

///|
fn identitysearch_random_from_seed(seed : Int) -> @random.Rand {
  let bytes = Bytes::makei(32, i => ((seed + i * 29) & 255).to_byte())
  @random.Rand::chacha8(seed=bytes)
}

///|
pub fn random_identity_search(
  gate_list : Array[Expr],
  numgates : Int,
  nqubits : Int,
  seed? : Int = -1,
) -> Array[Expr]? raise @symphysics.PhysicsError {
  guard numgates >= 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "random_identity_search expects numgates >= 0",
    )
  }
  guard !gate_list.is_empty() else {
    raise @symphysics.PhysicsError::ValueError(
      "random_identity_search expects a non-empty gate list",
    )
  }
  let rng = if seed >= 0 {
    identitysearch_random_from_seed(seed)
  } else {
    identitysearch_random_source
  }
  let circuit : Array[Expr] = []
  for _ in 0..<numgates {
    circuit.push(gate_list[rng.int(limit=gate_list.length())])
  }
  let is_scalar = is_scalar_matrix(circuit, nqubits, false)
  if is_scalar {
    Some(circuit)
  } else {
    None
  }
}
