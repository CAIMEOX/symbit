///|
/// Additional gate helpers aligned with the remaining lightweight surface of
/// `sympy.physics.quantum.gate`.
///
/// The MoonBit port keeps the existing concrete gate ADT and adds:
/// - `normalized(bool)` to control the global Hadamard normalization flag;
/// - `random_circuit(...)` for deterministic or pseudo-random circuit samples;
/// - `zx_basis_transform()` / `zy_basis_transform()` using the cached matrices.

///|
priv struct GateNormalizationState {
  mut normalized : Bool
}

///|
let gate_normalization_state : GateNormalizationState = GateNormalizationState::{
  normalized: true,
}

///|
let gate_random_source : @random.Rand = @random.Rand::new()

///|
fn gate_random_from_seed(seed : Int) -> @random.Rand {
  let bytes = Bytes::makei(32, i => ((seed + i * 73) & 255).to_byte())
  @random.Rand::chacha8(seed=bytes)
}

///|
fn gate_hadamard_factor() -> Expr {
  if gate_normalization_state.normalized {
    sqrt2_over_2()
  } else {
    int(1)
  }
}

///|
pub fn normalized(normalize : Bool) -> Unit {
  gate_normalization_state.normalized = normalize
}

///|
fn random_gate_expr(
  kind : GateKind,
  nqubits : Int,
  rng : @random.Rand,
) -> Expr raise @symphysics.PhysicsError {
  guard nqubits > 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "random_circuit expects nqubits > 0",
    )
  }
  match kind {
    GateKind::Identity
    | GateKind::Hadamard
    | GateKind::X
    | GateKind::Y
    | GateKind::Z
    | GateKind::Phase
    | GateKind::T => {
      let target = rng.int(limit=nqubits)
      match kind {
        GateKind::Identity => identity_gate(target).as_expr()
        GateKind::Hadamard => hadamard_gate(target).as_expr()
        GateKind::X => x_gate(target).as_expr()
        GateKind::Y => y_gate(target).as_expr()
        GateKind::Z => z_gate(target).as_expr()
        GateKind::Phase => phase_gate(target).as_expr()
        GateKind::T => t_gate(target).as_expr()
        _ => abort("unreachable")
      }
    }
    GateKind::Swap | GateKind::CNot => {
      guard nqubits >= 2 else {
        raise @symphysics.PhysicsError::ValueError(
          "Two-qubit random gates need at least 2 qubits",
        )
      }
      let first = rng.int(limit=nqubits)
      let mut second = rng.int(limit=nqubits)
      while second == first {
        second = rng.int(limit=nqubits)
      }
      match kind {
        GateKind::Swap => swap_gate(first, second).as_expr()
        GateKind::CNot => cnot_gate(first, second).as_expr()
        _ => abort("unreachable")
      }
    }
  }
}

///|
pub fn random_circuit(
  ngates : Int,
  nqubits : Int,
  gate_space? : Array[GateKind] = [
    GateKind::X,
    GateKind::Y,
    GateKind::Z,
    GateKind::Phase,
    GateKind::T,
    GateKind::Hadamard,
    GateKind::CNot,
    GateKind::Swap,
  ],
  seed? : Int = -1,
) -> Expr raise @symphysics.PhysicsError {
  guard ngates >= 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "random_circuit expects ngates >= 0",
    )
  }
  guard !gate_space.is_empty() else {
    raise @symphysics.PhysicsError::ValueError(
      "random_circuit expects a non-empty gate space",
    )
  }
  let rng = if seed >= 0 {
    gate_random_from_seed(seed)
  } else {
    gate_random_source
  }
  let gates : Array[Expr] = []
  for _ in 0..<ngates {
    let index = rng.int(limit=gate_space.length())
    gates.push(random_gate_expr(gate_space[index], nqubits, rng))
  }
  quantum_mul_from_args_preserve(gates)
}

///|
pub fn zx_basis_transform() -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  quantum_matrix_cache.get_matrix("ZX")
}

///|
pub fn zy_basis_transform() -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  quantum_matrix_cache.get_matrix("ZY")
}
