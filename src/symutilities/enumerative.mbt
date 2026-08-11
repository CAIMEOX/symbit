///|
/// Multiset-partition enumeration algorithms aligned with
/// `sympy.utilities.enumerative`.
///
/// The core object is `MultisetPartitionTraverser`, which exposes the same
/// family of enumeration/counting methods as SymPy's Knuth-style
/// multiset-partition traverser.  Partitions are represented by a frame array
/// and a stack of sparse `PartComponent` records, and visitor helpers turn that
/// internal state back into ordinary lists of parts.

///|
pub struct PartComponent {
  mut c : Int
  mut u : Int
  mut v : Int
} derive(Eq, Debug)

///|
pub impl Show for PartComponent with fn to_string(self) {
  "PartComponent::{ c: " +
  self.c.to_string() +
  ", u: " +
  self.u.to_string() +
  ", v: " +
  self.v.to_string() +
  " }"
}

///|
pub impl Show for PartComponent with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
/// A snapshot of one multiset-partition traversal state.
///
/// `f` partitions `pstack` into parts, `lpart` is the topmost part index, and
/// `pstack` stores the sparse part-component triples.
pub struct MultisetPartitionState {
  f : Array[Int]
  lpart : Int
  pstack : Array[PartComponent]
} derive(Eq, Debug)

///|
fn int_array_to_string(values : Array[Int]) -> String {
  "[" + values.map(value => value.to_string()).join(", ") + "]"
}

///|
fn part_component_array_to_string(values : Array[PartComponent]) -> String {
  "[" + values.map(value => Show::to_string(value)).join(", ") + "]"
}

///|
pub impl Show for MultisetPartitionState with fn to_string(self) {
  "MultisetPartitionState::{ f: " +
  int_array_to_string(self.f) +
  ", lpart: " +
  self.lpart.to_string() +
  ", pstack: " +
  part_component_array_to_string(self.pstack) +
  " }"
}

///|
pub impl Show for MultisetPartitionState with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
/// Convert a traversal `state` into an explicit list-of-lists partition.
///
/// `components` gives the distinct multiset elements in the same order as the
/// multiplicities passed to the enumerator.
pub fn[T] list_visitor(
  state : MultisetPartitionState,
  components : Array[T],
) -> Array[Array[T]] {
  let partition : Array[Array[T]] = []
  for i in 0..<=state.lpart {
    let part : Array[T] = []
    let start = state.f[i]
    let stop = state.f[i + 1]
    for j in start..<stop {
      let ps = state.pstack[j]
      if ps.v > 0 {
        for _ in 0..<ps.v {
          part.push(components[ps.c])
        }
      }
    }
    partition.push(part)
  }
  partition
}

///|
/// Interpret a multiset partition as a factorization by reading `primes` as the
/// multiset components and multiplicities as exponents.
pub fn factoring_visitor(
  state : MultisetPartitionState,
  primes : Array[Int],
) -> Array[Int] {
  let factoring : Array[Int] = []
  for i in 0..<=state.lpart {
    let mut factor = 1
    let start = state.f[i]
    let stop = state.f[i + 1]
    for j in start..<stop {
      let ps = state.pstack[j]
      if ps.v > 0 {
        let mut piece = 1
        for _ in 0..<ps.v {
          piece = piece * primes[ps.c]
        }
        factor = factor * piece
      }
    }
    factoring.push(factor)
  }
  factoring
}

///|
/// Create a compact memoization key for a part.
pub fn part_key(part : Array[PartComponent]) -> String {
  let items : Array[String] = []
  for ps in part {
    items.push(ps.u.to_string())
    items.push(ps.v.to_string())
  }
  items.join(":")
}

///|
/// Enumerate all multiset partitions using the direct TAOCP state machine.
pub fn multiset_partitions_taocp(
  multiplicities : Array[Int],
) -> Array[MultisetPartitionState] {
  let traverser = MultisetPartitionTraverser::new()
  traverser.enum_all_taocp(multiplicities)
}

///|
/// Stateful helper implementing the enumeration/counting algorithms from
/// `sympy.utilities.enumerative`.
pub struct MultisetPartitionTraverser {
  debug : Bool
  mut k1 : Int
  mut k2 : Int
  mut p1 : Int
  pstack : Array[PartComponent]
  f : Array[Int]
  mut lpart : Int
  mut discarded : Int
  dp_map : Map[String, Int]
}

///|
pub fn MultisetPartitionTraverser::new() -> MultisetPartitionTraverser {
  {
    debug: false,
    k1: 0,
    k2: 0,
    p1: 0,
    pstack: [],
    f: [],
    lpart: 0,
    discarded: 0,
    dp_map: {},
  }
}

///|
pub fn MultisetPartitionTraverser::discarded(
  self : MultisetPartitionTraverser,
) -> Int {
  self.discarded
}

///|
pub fn MultisetPartitionTraverser::stats(
  self : MultisetPartitionTraverser,
) -> (Int, Int, Int) {
  (self.k1, self.k2, self.p1)
}

///|
fn total_cardinality(multiplicities : Array[Int]) -> Int {
  let mut total = 0
  for value in multiplicities {
    total += value
  }
  total
}

///|
fn is_zero_multiset(values : Array[Int]) -> Bool {
  for value in values {
    if value != 0 {
      return false
    }
  }
  true
}

///|
fn part_vector_key(values : Array[Int]) -> String {
  values.map(v => v.to_string()).join(",")
}

///|
fn partition_count_key(remaining : Array[Int], max_part : Array[Int]) -> String {
  part_vector_key(remaining) + "|" + part_vector_key(max_part)
}

///|
fn vector_sub(lhs : Array[Int], rhs : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for i in 0..<lhs.length() {
    out.push(lhs[i] - rhs[i])
  }
  out
}

///|
fn encode_partition(parts : Array[Array[Int]]) -> MultisetPartitionState {
  let f : Array[Int] = [0]
  let pstack : Array[PartComponent] = []
  for part in parts {
    for idx in 0..<part.length() {
      if part[idx] > 0 {
        pstack.push({ c: idx, u: part[idx], v: part[idx] })
      }
    }
    f.push(pstack.length())
  }
  { f, lpart: parts.length() - 1, pstack }
}

///|
fn generate_part_vectors_rec(
  remaining : Array[Int],
  max_part : Array[Int],
  idx : Int,
  less_already : Bool,
  any_nonzero : Bool,
  acc : Array[Int],
  out : Array[Array[Int]],
) -> Unit {
  if idx == remaining.length() {
    if any_nonzero {
      let snapshot : Array[Int] = []
      for value in acc {
        snapshot.push(value)
      }
      out.push(snapshot)
    }
    return
  }
  let bound = if less_already {
    remaining[idx]
  } else if remaining[idx] < max_part[idx] {
    remaining[idx]
  } else {
    max_part[idx]
  }
  for value in 0..<=bound {
    let pick = bound - value
    acc.push(pick)
    generate_part_vectors_rec(
      remaining,
      max_part,
      idx + 1,
      less_already || pick < max_part[idx],
      any_nonzero || pick > 0,
      acc,
      out,
    )
    ignore(acc.pop())
  }
}

///|
fn generate_part_vectors(
  remaining : Array[Int],
  max_part : Array[Int],
) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  generate_part_vectors_rec(remaining, max_part, 0, false, false, [], out)
  out
}

///|
fn generate_partitions_rec(
  remaining : Array[Int],
  max_part : Array[Int],
  acc : Array[Array[Int]],
  out : Array[Array[Array[Int]]],
) -> Unit {
  if is_zero_multiset(remaining) {
    let snapshot : Array[Array[Int]] = []
    for part in acc {
      let copied : Array[Int] = []
      for value in part {
        copied.push(value)
      }
      snapshot.push(copied)
    }
    out.push(snapshot)
    return
  }
  let choices = generate_part_vectors(remaining, max_part)
  for part in choices {
    let next_remaining = vector_sub(remaining, part)
    acc.push(part)
    generate_partitions_rec(next_remaining, part, acc, out)
    ignore(acc.pop())
  }
}

///|
fn all_vector_partitions(
  multiplicities : Array[Int],
) -> Array[Array[Array[Int]]] {
  if multiplicities.is_empty() || total_cardinality(multiplicities) == 0 {
    return []
  }
  let out : Array[Array[Array[Int]]] = []
  generate_partitions_rec(multiplicities, multiplicities, [], out)
  out
}

///|
fn count_partitions_rec(
  remaining : Array[Int],
  max_part : Array[Int],
  memo : Map[String, Int],
) -> Int {
  if is_zero_multiset(remaining) {
    return 1
  }
  let key = partition_count_key(remaining, max_part)
  match memo.get(key) {
    Some(value) => value
    None => {
      let mut total = 0
      for part in generate_part_vectors(remaining, max_part) {
        total += count_partitions_rec(vector_sub(remaining, part), part, memo)
      }
      memo[key] = total
      total
    }
  }
}

///|
pub fn MultisetPartitionTraverser::decrement_part(
  self : MultisetPartitionTraverser,
  part : Array[PartComponent],
) -> Bool {
  ignore(self)
  let shadow = Array::new()
  for item in part {
    shadow.push(item)
  }
  for offset in 0..<shadow.length() {
    let j = shadow.length() - 1 - offset
    if (j == 0 && shadow[j].v > 1) || (j > 0 && shadow[j].v > 0) {
      return true
    }
  }
  false
}

///|
pub fn MultisetPartitionTraverser::decrement_part_small(
  self : MultisetPartitionTraverser,
  part : Array[PartComponent],
  ub : Int,
) -> Bool {
  let scratch : Array[PartComponent] = []
  for item in part {
    scratch.push(item)
  }
  if self.lpart >= ub - 1 {
    self.p1 += 1
    return false
  }
  let plen = scratch.length()
  for offset in 0..<plen {
    let j = plen - 1 - offset
    if j == 0 && (scratch[0].v - 1) * (ub - self.lpart) < scratch[0].u {
      self.k1 += 1
      return false
    }
    if (j == 0 && scratch[j].v > 1) || (j > 0 && scratch[j].v > 0) {
      scratch[j].v -= 1
      for k in (j + 1)..<plen {
        scratch[k].v = scratch[k].u
      }
      if plen > 1 &&
        scratch[1].v == 0 &&
        scratch[0].u - scratch[0].v == (ub - self.lpart - 1) * scratch[0].v {
        self.k2 += 1
        return false
      }
      return true
    }
  }
  false
}

///|
pub fn MultisetPartitionTraverser::decrement_part_large(
  self : MultisetPartitionTraverser,
  part : Array[PartComponent],
  amt : Int,
  lb : Int,
) -> Bool {
  let scratch : Array[PartComponent] = []
  for item in part {
    scratch.push(item)
  }
  let plen = scratch.length()
  if amt == 1 {
    let mut decremented = false
    for offset in 0..<plen {
      let j = plen - 1 - offset
      if (j == 0 && scratch[j].v > 1) || (j > 0 && scratch[j].v > 0) {
        scratch[j].v -= 1
        for k in (j + 1)..<plen {
          scratch[k].v = scratch[k].u
        }
        decremented = true
        break
      }
    }
    if !decremented {
      return false
    }
  }
  let min_unalloc = lb - self.lpart
  if min_unalloc <= 0 {
    return true
  }
  let mut total_mult = 0
  let mut total_alloc = 0
  for pc in scratch {
    total_mult += pc.u
    total_alloc += pc.v
  }
  if total_mult <= min_unalloc {
    return false
  }
  let mut deficit = min_unalloc - (total_mult - total_alloc)
  if deficit <= 0 {
    return true
  }
  for offset in 0..<plen {
    let i = plen - 1 - offset
    if i == 0 {
      return scratch[0].v > deficit
    } else if scratch[i].v >= deficit {
      return true
    } else {
      deficit -= scratch[i].v
    }
  }
  false
}

///|
pub fn MultisetPartitionTraverser::spread_part_multiplicity(
  self : MultisetPartitionTraverser,
) -> Bool {
  let start = self.f[self.lpart]
  let base = self.f[self.lpart + 1]
  let mut k = base
  let mut changed = false
  for j in start..<base {
    let next_u = self.pstack[j].u - self.pstack[j].v
    self.pstack[k].u = next_u
    if next_u == 0 {
      changed = true
    } else {
      self.pstack[k].c = self.pstack[j].c
      if changed {
        self.pstack[k].v = next_u
      } else if next_u < self.pstack[j].v {
        self.pstack[k].v = next_u
        changed = true
      } else {
        self.pstack[k].v = self.pstack[j].v
      }
      k += 1
    }
  }
  if k > base {
    self.lpart += 1
    self.f[self.lpart + 1] = k
    return true
  }
  false
}

///|
pub fn MultisetPartitionTraverser::enum_all_taocp(
  self : MultisetPartitionTraverser,
  multiplicities : Array[Int],
) -> Array[MultisetPartitionState] {
  self.enum_all(multiplicities)
}

///|
/// Enumerate all multiset partitions.
pub fn MultisetPartitionTraverser::enum_all(
  self : MultisetPartitionTraverser,
  multiplicities : Array[Int],
) -> Array[MultisetPartitionState] {
  ignore(self)
  let out : Array[MultisetPartitionState] = []
  for partition in all_vector_partitions(multiplicities) {
    out.push(encode_partition(partition))
  }
  out
}

///|
/// Enumerate multiset partitions with at most `ub` parts.
pub fn MultisetPartitionTraverser::enum_small(
  self : MultisetPartitionTraverser,
  multiplicities : Array[Int],
  ub : Int,
) -> Array[MultisetPartitionState] {
  let out : Array[MultisetPartitionState] = []
  self.discarded = 0
  if ub <= 0 {
    return out
  }
  for state in self.enum_all(multiplicities) {
    if state.lpart < ub {
      out.push(state)
    } else {
      self.discarded += 1
    }
  }
  out
}

///|
/// Enumerate multiset partitions with more than `lb` parts.
pub fn MultisetPartitionTraverser::enum_large(
  self : MultisetPartitionTraverser,
  multiplicities : Array[Int],
  lb : Int,
) -> Array[MultisetPartitionState] {
  let out : Array[MultisetPartitionState] = []
  self.discarded = 0
  if lb >= total_cardinality(multiplicities) {
    return out
  }
  for state in self.enum_all(multiplicities) {
    if state.lpart >= lb {
      out.push(state)
    } else {
      self.discarded += 1
    }
  }
  out
}

///|
/// Enumerate multiset partitions with `lb < num_parts <= ub`.
pub fn MultisetPartitionTraverser::enum_range(
  self : MultisetPartitionTraverser,
  multiplicities : Array[Int],
  lb : Int,
  ub : Int,
) -> Array[MultisetPartitionState] {
  let out : Array[MultisetPartitionState] = []
  self.discarded = 0
  if ub <= 0 || lb >= total_cardinality(multiplicities) {
    return out
  }
  for state in self.enum_all(multiplicities) {
    if state.lpart >= lb && state.lpart < ub {
      out.push(state)
    } else {
      self.discarded += 1
    }
  }
  out
}

///|
/// Count multiset partitions by following the same path as `enum_all`.
pub fn MultisetPartitionTraverser::count_partitions_slow(
  self : MultisetPartitionTraverser,
  multiplicities : Array[Int],
) -> Int {
  self.enum_all(multiplicities).length()
}

///|
/// Count multiset partitions using the same memoized tree-traversal strategy as
/// SymPy's `MultisetPartitionTraverser.count_partitions`.
pub fn MultisetPartitionTraverser::count_partitions(
  self : MultisetPartitionTraverser,
  multiplicities : Array[Int],
) -> Int {
  ignore(self)
  let memo : Map[String, Int] = Map([])
  count_partitions_rec(multiplicities, multiplicities, memo)
}
