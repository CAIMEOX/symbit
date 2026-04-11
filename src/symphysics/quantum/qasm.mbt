///|
/// QASM parsing helpers aligned with `sympy.physics.quantum.qasm`.
///
/// This port keeps the original command language: qubit declarations,
/// one- and two-qubit builtins, simple `qdef` custom gates, and circuit
/// assembly with SymPy-compatible index flipping.

///|
pub struct QasmDefinition {
  ncontrols : Int
  symbol : String
} derive(Eq)

///|
fn qasm_builtin_gate(symbol : String, args : Array[Int]) -> Expr {
  @symcore.raw_function(symbol, args.map(@symcore.int))
}

///|
fn qasm_measure_gate(target : Int) -> Expr {
  mz(target)
}

///|
fn qasm_product(exprs : Array[Expr]) -> Expr {
  if exprs.is_empty() {
    int(1)
  } else {
    quantum_mul_from_args_preserve(exprs)
  }
}

///|
pub fn flip_index(index : Int, nqubits : Int) -> Int {
  nqubits - index - 1
}

///|
pub fn trim(line : String) -> String {
  let parts = Array::from_iter(line.split("#"))
  if parts.is_empty() {
    line
  } else {
    parts[0].to_string()
  }
}

///|
pub fn fixcommand(command : String) -> String {
  let lower = command.to_lower()
  let out = lower.replace(old="-", new="")
  if out == "def" {
    "qdef"
  } else {
    out
  }
}

///|
pub fn stripquotes(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    if ch != '"' && ch != '\'' {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
pub fn get_index(
  target : String,
  labels : Array[String],
) -> Int raise @symphysics.PhysicsError {
  let mut found = -1
  for idx in 0..<labels.length() {
    if labels[idx] == target {
      found = idx
      break
    }
  }
  guard found >= 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "Unknown QASM qubit label: " + target,
    )
  }
  flip_index(found, labels.length())
}

///|
pub fn get_indices(
  targets : Array[String],
  labels : Array[String],
) -> Array[Int] raise @symphysics.PhysicsError {
  let out : Array[Int] = []
  for target in targets {
    out.push(get_index(target, labels))
  }
  out
}

///|
fn qasm_nonblank(lines : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for line in lines {
    let cleaned = trim(line)
    if cleaned.trim() != "" {
      out.push(cleaned)
    }
  }
  out
}

///|
fn qasm_fullsplit(
  line : String,
) -> (String, Array[String]) raise @symphysics.PhysicsError {
  let trimmed = line.trim()
  guard trimmed != "" else {
    raise @symphysics.PhysicsError::ValueError("QASM line cannot be empty")
  }
  let raw_words = Array::from_iter(trimmed.split(" "))
  let words : Array[String] = []
  for raw in raw_words {
    let word = raw.trim().to_string()
    if word != "" {
      words.push(word)
    }
  }
  guard !words.is_empty() else {
    raise @symphysics.PhysicsError::ValueError("QASM line cannot be empty")
  }
  let command = fixcommand(words[0])
  let rest = if words.length() <= 1 {
    ""
  } else {
    let suffix : Array[String] = []
    for idx in 1..<words.length() {
      suffix.push(words[idx])
    }
    suffix.join(" ")
  }
  let args = if rest == "" {
    []
  } else {
    Array::from_iter(rest.split(",")).map(part => part.trim().to_string())
  }
  (command, args)
}

///|
pub struct Qasm {
  defs : Map[String, QasmDefinition]
  circuit : Array[Expr]
  labels : Array[String]
  inits : Map[String, String]
} derive(Eq)

///|
pub fn qasm(lines : Array[String]) -> Qasm raise @symphysics.PhysicsError {
  let parser = Qasm::{ defs: {}, circuit: [], labels: [], inits: {} }
  parser.add(lines)
  parser
}

///|
pub fn read_qasm(text : String) -> Qasm raise @symphysics.PhysicsError {
  qasm(text.split("\n").map(part => part.to_string()).collect())
}

///|
pub fn Qasm::add(
  self : Qasm,
  lines : Array[String],
) -> Unit raise @symphysics.PhysicsError {
  for line in qasm_nonblank(lines) {
    let (command, rest) = qasm_fullsplit(line)
    match self.defs.get(command) {
      Some(definition) => {
        let indices = self.indices(rest)
        self.circuit.push(qasm_apply_definition(definition, indices))
      }
      None => qasm_apply_builtin(self, command, rest)
    }
  }
}

///|
fn qasm_apply_definition(
  definition : QasmDefinition,
  indices : Array[Int],
) -> Expr raise @symphysics.PhysicsError {
  if definition.ncontrols == 0 {
    guard indices.length() == 1 else {
      raise @symphysics.PhysicsError::ValueError(
        "Custom one-qubit QASM gate expects one target",
      )
    }
    create_one_qubit_gate(definition.symbol)(indices[0])
  } else {
    guard indices.length() == definition.ncontrols + 1 else {
      raise @symphysics.PhysicsError::ValueError(
        "Custom controlled QASM gate arity mismatch",
      )
    }
    create_cgate(definition.symbol)(
      indices[:definition.ncontrols].to_array(),
      indices[indices.length() - 1],
    )
  }
}

///|
fn qasm_apply_builtin(
  parser : Qasm,
  command : String,
  rest : Array[String],
) -> Unit raise @symphysics.PhysicsError {
  match command {
    "qubit" =>
      parser.qubit(
        rest[0],
        init=if rest.length() >= 2 { Some(rest[1]) } else { None },
      )
    "nop" => ()
    "x" => parser.circuit.push(qasm_builtin_gate("X", [parser.index(rest[0])]))
    "z" => parser.circuit.push(qasm_builtin_gate("Z", [parser.index(rest[0])]))
    "h" => parser.circuit.push(qasm_builtin_gate("H", [parser.index(rest[0])]))
    "s" => parser.circuit.push(qasm_builtin_gate("S", [parser.index(rest[0])]))
    "t" => parser.circuit.push(qasm_builtin_gate("T", [parser.index(rest[0])]))
    "measure" => parser.circuit.push(qasm_measure_gate(parser.index(rest[0])))
    "cnot" => {
      let indices = parser.indices(rest)
      parser.circuit.push(qasm_builtin_gate("CNOT", indices))
    }
    "swap" => {
      let indices = parser.indices(rest)
      parser.circuit.push(qasm_builtin_gate("SWAP", indices))
    }
    "cphase" => {
      let indices = parser.indices(rest)
      parser.circuit.push(cphase(indices[0], indices[1]))
    }
    "toffoli" => {
      let indices = parser.indices(rest)
      parser.circuit.push(
        cgate(indices[:2].to_array(), qasm_builtin_gate("X", [indices[2]])),
      )
    }
    "cx" => {
      let indices = parser.indices(rest)
      parser.circuit.push(
        cgate([indices[0]], qasm_builtin_gate("X", [indices[1]])),
      )
    }
    "cz" => {
      let indices = parser.indices(rest)
      parser.circuit.push(
        cgate([indices[0]], qasm_builtin_gate("Z", [indices[1]])),
      )
    }
    "defbox" => ()
    "qdef" => {
      guard rest.length() == 3 else {
        raise @symphysics.PhysicsError::ValueError(
          "qdef expects name, ncontrols, symbol",
        )
      }
      let ncontrols = @string.parse_int(rest[1], base=10) catch {
        _ =>
          raise @symphysics.PhysicsError::ValueError(
            "qdef control count must be an integer",
          )
      }
      parser.defs[fixcommand(rest[0])] = QasmDefinition::{
        ncontrols,
        symbol: stripquotes(rest[2]),
      }
    }
    _ => ()
  }
}

///|
pub fn Qasm::get_circuit(self : Qasm) -> Expr {
  let reversed : Array[Expr] = []
  for idx in 0..<self.circuit.length() {
    reversed.push(self.circuit[self.circuit.length() - 1 - idx])
  }
  qasm_product(reversed)
}

///|
pub fn Qasm::get_labels(self : Qasm) -> Array[String] {
  let out : Array[String] = []
  for idx in 0..<self.labels.length() {
    out.push(self.labels[self.labels.length() - 1 - idx])
  }
  out
}

///|
pub fn Qasm::qubit(self : Qasm, label : String, init? : String? = None) -> Unit {
  self.labels.push(label)
  match init {
    Some(value) => self.inits[label] = value
    None => ()
  }
}

///|
pub fn Qasm::indices(
  self : Qasm,
  args : Array[String],
) -> Array[Int] raise @symphysics.PhysicsError {
  get_indices(args, self.labels)
}

///|
pub fn Qasm::index(
  self : Qasm,
  arg : String,
) -> Int raise @symphysics.PhysicsError {
  get_index(arg, self.labels)
}
