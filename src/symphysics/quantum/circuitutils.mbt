///|
/// Primitive circuit operations aligned with `sympy.physics.quantum.circuitutils`.
///
/// SymPy treats a quantum circuit as a tuple of gate factors, with `Mul`
/// accepted as shorthand input. The MoonBit port keeps the same search and
/// rewrite semantics while exposing explicit sequence-oriented helpers:
///
/// - `circuit_factors` normalizes a gate product into an ordered factor array;
/// - `find_subcircuit` and `replace_subcircuit` use the same KMP-based search;
/// - `convert_to_symbolic_indices` and `convert_to_real_indices` rewrite gate
///   targets/controls between concrete integers and symbolic `i0`, `i1`, ...;
/// - `random_reduce` and `random_insert` keep the deterministic seed-list mode
///   that SymPy uses in tests.
///
/// This module is the missing glue for circuit manipulation, qasm parsing, and
/// identity-search style algorithms in `physics.quantum`.

///|
pub struct SymbolicCircuit {
  circuit : Array[Expr]
  qubit_map : Map[String, Int]
  next_index : Int
}

///|
pub struct GateIdentity {
  sequence : Array[Expr]
  rules : Array[GateRule]
  equivalent_ids : Array[Array[Expr]]
}

///|
fn circuit_from_factors(factors : Array[Expr]) -> Expr {
  quantum_mul_from_args_preserve(factors)
}

///|
pub fn circuit_factors(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Mul(args) => args.copy()
    Expr::Number(n) if n.is_integral() && n.numerator().to_int() == 1 => []
    _ => [expr]
  }
}

///|
pub fn gate_identity(equivalent_ids : Array[Expr]) -> GateIdentity {
  GateIdentity::{
    sequence: [],
    rules: [],
    equivalent_ids: equivalent_ids.map(circuit_factors),
  }
}

///|
pub fn kmp_table(word : Array[Expr]) -> Array[Int] {
  let table = [-1, 0]
  let mut pos = 2
  let mut cnd = 0
  while pos < word.length() {
    if word[pos - 1] == word[cnd] {
      cnd += 1
      table.push(cnd)
      pos += 1
    } else if cnd > 0 {
      cnd = table[cnd]
    } else {
      table.push(0)
      pos += 1
    }
  }
  table
}

///|
pub fn find_subcircuit(
  circuit : Expr,
  subcircuit : Expr,
  start? : Int = 0,
  end? : Int = 0,
) -> Int {
  let circuit_items = circuit_factors(circuit)
  let sub_items = circuit_factors(subcircuit)
  if sub_items.is_empty() || sub_items.length() > circuit_items.length() {
    return -1
  }
  let stop = if end < 1 { circuit_items.length() } else { end }
  let table = kmp_table(sub_items)
  let mut pos = if start < 0 { 0 } else { start }
  let mut index = 0
  while pos + index < stop {
    if sub_items[index] == circuit_items[pos + index] {
      index += 1
    } else {
      pos = pos + index - table[index]
      index = if table[index] > -1 { table[index] } else { 0 }
    }
    if index == sub_items.length() {
      return pos
    }
  }
  -1
}

///|
pub fn replace_subcircuit(
  circuit : Expr,
  subcircuit : Expr,
  replace? : Expr? = None,
  pos? : Int = 0,
) -> Array[Expr] {
  let circuit_items = circuit_factors(circuit)
  let sub_items = circuit_factors(subcircuit)
  let replace_items = match replace {
    Some(expr) => circuit_factors(expr)
    None => []
  }
  let loc = find_subcircuit(
    circuit_from_factors(circuit_items),
    circuit_from_factors(sub_items),
    start=if pos < 0 { 0 } else { pos },
  )
  if loc < 0 {
    return circuit_items
  }
  let out : Array[Expr] = []
  for idx in 0..<loc {
    out.push(circuit_items[idx])
  }
  for item in replace_items {
    out.push(item)
  }
  for idx in (loc + sub_items.length())..<circuit_items.length() {
    out.push(circuit_items[idx])
  }
  out
}

///|
fn circuit_symbol_name(index : Int) -> String {
  "i\{index.to_string()}"
}

///|
fn clone_index_map(qubit_map : Map[String, Int]) -> Map[String, Int] {
  let out : Map[String, Int] = Map::new()
  for key in qubit_map.keys() {
    match qubit_map.get(key) {
      Some(value) => out.set(key, value)
      None => ()
    }
  }
  out
}

///|
fn index_inverse_map(qubit_map : Map[String, Int]) -> Map[Int, String] {
  let out : Map[Int, String] = Map::new()
  for key in qubit_map.keys() {
    match qubit_map.get(key) {
      Some(value) => out.set(value, key)
      None => ()
    }
  }
  out
}

///|
fn next_symbolic_index(
  qubit_map : Map[String, Int],
  next_index : Int,
) -> (String, Int) {
  let mut current = if next_index < 0 { 0 } else { next_index }
  while qubit_map.contains(circuit_symbol_name(current)) {
    current += 1
  }
  (circuit_symbol_name(current), current + 1)
}

///|
fn symbolic_index_expr(
  expr : Expr,
  qubit_map : Map[String, Int],
  inverse_map : Map[Int, String],
  next_index : Int,
) -> (Expr, Int) {
  match expr {
    Expr::Number(n) if n.is_integral() => {
      let value = n.numerator().to_int()
      match inverse_map.get(value) {
        Some(name) => (symbol(name), next_index)
        None => {
          let (name, next_value) = next_symbolic_index(qubit_map, next_index)
          qubit_map.set(name, value)
          inverse_map.set(value, name)
          (symbol(name), next_value)
        }
      }
    }
    Expr::Function(name, args) => {
      let out : Array[Expr] = []
      let mut cursor = next_index
      for arg in args {
        let (rewritten, next_cursor) = symbolic_index_expr(
          arg, qubit_map, inverse_map, cursor,
        )
        out.push(rewritten)
        cursor = next_cursor
      }
      (@symcore.raw_function(name, out), cursor)
    }
    Expr::Mul(args) => {
      let out : Array[Expr] = []
      let mut cursor = next_index
      for arg in args {
        let (rewritten, next_cursor) = symbolic_index_expr(
          arg, qubit_map, inverse_map, cursor,
        )
        out.push(rewritten)
        cursor = next_cursor
      }
      (@symcore.raw_mul(out), cursor)
    }
    Expr::Add(args) => {
      let out : Array[Expr] = []
      let mut cursor = next_index
      for arg in args {
        let (rewritten, next_cursor) = symbolic_index_expr(
          arg, qubit_map, inverse_map, cursor,
        )
        out.push(rewritten)
        cursor = next_cursor
      }
      (@symcore.raw_add(out), cursor)
    }
    Expr::Pow(base, exp) => {
      let (next_base, after_base) = symbolic_index_expr(
        base, qubit_map, inverse_map, next_index,
      )
      let (next_exp, after_exp) = symbolic_index_expr(
        exp, qubit_map, inverse_map, after_base,
      )
      (@symcore.raw_pow(next_base, next_exp), after_exp)
    }
    _ => (expr, next_index)
  }
}

///|
pub fn convert_to_symbolic_indices(
  seq : Expr,
  start_index? : Int = 0,
  qubit_map? : Map[String, Int] = Map::new(),
) -> SymbolicCircuit {
  let map_copy = clone_index_map(qubit_map)
  let inverse_map = index_inverse_map(map_copy)
  let out : Array[Expr] = []
  let mut cursor = if start_index < 0 { 0 } else { start_index }
  for item in circuit_factors(seq) {
    let (rewritten, next_cursor) = symbolic_index_expr(
      item, map_copy, inverse_map, cursor,
    )
    out.push(rewritten)
    cursor = next_cursor
  }
  SymbolicCircuit::{ circuit: out, qubit_map: map_copy, next_index: cursor }
}

///|
fn real_index_expr(expr : Expr, qubit_map : Map[String, Int]) -> Expr {
  match expr {
    Expr::Symbol(name) =>
      match qubit_map.get(name) {
        Some(value) => int(value)
        None => expr
      }
    Expr::Function(name, args) =>
      @symcore.raw_function(
        name,
        args.map(arg => real_index_expr(arg, qubit_map)),
      )
    Expr::Mul(args) =>
      @symcore.raw_mul(args.map(arg => real_index_expr(arg, qubit_map)))
    Expr::Add(args) =>
      @symcore.raw_add(args.map(arg => real_index_expr(arg, qubit_map)))
    Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        real_index_expr(base, qubit_map),
        real_index_expr(exp, qubit_map),
      )
    _ => expr
  }
}

///|
pub fn convert_to_real_indices(
  seq : Expr,
  qubit_map : Map[String, Int],
) -> Array[Expr] {
  circuit_factors(seq).map(item => real_index_expr(item, qubit_map))
}

///|
pub fn flatten_ids(ids : Array[GateIdentity]) -> Array[Array[Expr]] {
  let out : Array[Array[Expr]] = []
  for identity in ids {
    for circuit in identity.equivalent_ids {
      out.push(circuit)
    }
  }
  out
}

///|
fn seed_pick(limit : Int, seed : Array[Int], cursor : Int) -> (Int, Int) {
  guard limit > 0 else { return (0, cursor) }
  if seed.is_empty() {
    return (0, cursor)
  }
  let raw = seed[cursor % seed.length()]
  let value = if raw >= 0 { raw % limit } else { (raw % limit + limit) % limit }
  (value, cursor + 1)
}

///|
pub fn random_reduce(
  circuit : Expr,
  gate_ids : Array[GateIdentity],
  seed? : Array[Int] = [],
) -> Array[Expr] {
  if gate_ids.is_empty() {
    return circuit_factors(circuit)
  }
  let ids = flatten_ids(gate_ids)
  let work = circuit_factors(circuit)
  let remaining = ids.copy()
  let mut cursor = 0
  while !remaining.is_empty() {
    let (pick, next_cursor) = seed_pick(remaining.length(), seed, cursor)
    cursor = next_cursor
    let candidate = remaining.remove(pick)
    let loc = find_subcircuit(
      circuit_from_factors(work),
      circuit_from_factors(candidate),
    )
    if loc >= 0 {
      return replace_subcircuit(
        circuit_from_factors(work),
        circuit_from_factors(candidate),
      )
    }
  }
  work
}

///|
pub fn random_insert(
  circuit : Expr,
  choices : Array[Expr],
  seed? : Array[Int] = [],
) -> Array[Expr] {
  let base = circuit_factors(circuit)
  if choices.is_empty() {
    return base
  }
  let (loc, next_cursor) = seed_pick(base.length() + 1, seed, 0)
  let (choice_index, _) = seed_pick(choices.length(), seed, next_cursor)
  let inserted = circuit_factors(choices[choice_index])
  let out : Array[Expr] = []
  for idx in 0..<loc {
    out.push(base[idx])
  }
  for item in inserted {
    out.push(item)
  }
  for idx in loc..<base.length() {
    out.push(base[idx])
  }
  out
}
