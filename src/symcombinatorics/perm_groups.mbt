///|
/// Permutation groups (brute-force closure for correctness on small groups).

///|
fn array_key(values : Array[Int]) -> String {
  values.map((x) => "\{x}").join(",")
}

///|
fn sort_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = Array::new()
  for v in values {
    out.push(v)
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if out[j] < out[i] {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn perm_eq(a : Permutation, b : Permutation) -> Bool {
  if a.size() != b.size() {
    return false
  }
  let aa = a.array_form()
  let bb = b.array_form()
  if aa.length() != bb.length() {
    return false
  }
  for i in 0..<aa.length() {
    if aa[i] != bb[i] {
      return false
    }
  }
  true
}

///|
fn perm_array_contains(values : Array[Permutation], target : Permutation) -> Bool {
  for v in values {
    if perm_eq(v, target) {
      return true
    }
  }
  false
}

///|
fn normalize_generators(gens : Array[Permutation], degree : Int) -> Array[Permutation] raise CombinatoricsError {
  let out : Array[Permutation] = Array::new()
  for g in gens {
    let gg = if g.size() == degree { g } else { g.resize(degree) }
    out.push(gg)
  }
  out
}

///|
fn closure_from_gens(gens : Array[Permutation], degree : Int) -> Array[Permutation] raise CombinatoricsError {
  let identity = Permutation::identity(degree)
  let elements : Array[Permutation] = Array::new()
  elements.push(identity)
  let mut idx = 0
  while idx < elements.length() {
    let g = elements[idx]
    for gen in gens {
      let h = g.mul(gen)
      if !perm_array_contains(elements, h) {
        elements.push(h)
      }
    }
    idx = idx + 1
  }
  elements
}

///|
pub struct PermutationGroup {
  generators : Array[Permutation]
  degree : Int
  mut elements_cache : Array[Permutation]?
  mut order_cache : Int?
  mut is_abelian_cache : Bool?
  mut is_transitive_cache : Bool?
  mut is_dihedral_cache : Bool?
  mut is_symmetric_cache : Bool?
  mut is_alternating_cache : Bool?
  mut is_nilpotent_cache : Bool?
  mut is_solvable_cache : Bool?
  mut is_cyclic_cache : Bool?
}

///|
pub fn PermutationGroup::new(
  gens0 : Array[Permutation],
  dups? : Bool = true,
) -> PermutationGroup raise CombinatoricsError {
  let gens : Array[Permutation] = Array::new()
  for g in gens0 {
    gens.push(g)
  }
  if gens.is_empty() {
    gens.push(Permutation::identity(0))
  }
  let mut degree = 0
  for g in gens {
    if g.size() > degree {
      degree = g.size()
    }
  }
  let normalized = normalize_generators(gens, degree)
  let filtered : Array[Permutation] = Array::new()
  for g in normalized {
    if g.is_identity() && normalized.length() > 1 {
      continue
    }
    if dups {
      if !perm_array_contains(filtered, g) {
        filtered.push(g)
      }
    } else {
      filtered.push(g)
    }
  }
  {
    generators: filtered,
    degree,
    elements_cache: None,
    order_cache: None,
    is_abelian_cache: None,
    is_transitive_cache: None,
    is_dihedral_cache: None,
    is_symmetric_cache: None,
    is_alternating_cache: None,
    is_nilpotent_cache: None,
    is_solvable_cache: None,
    is_cyclic_cache: None,
  }
}

///|
pub fn PermutationGroup::generators(self : PermutationGroup) -> Array[Permutation] {
  let out : Array[Permutation] = Array::new()
  for g in self.generators {
    out.push(g)
  }
  out
}

///|
pub fn PermutationGroup::degree(self : PermutationGroup) -> Int {
  self.degree
}

///|
pub fn PermutationGroup::identity(self : PermutationGroup) -> Permutation {
  Permutation::identity(self.degree)
}

///|
pub fn PermutationGroup::elements(self : PermutationGroup) -> Array[Permutation] raise CombinatoricsError {
  match self.elements_cache {
    Some(elems) => elems
    None => {
      let elems = closure_from_gens(self.generators, self.degree)
      self.elements_cache = Some(elems)
      self.elements_cache.unwrap()
    }
  }
}

///|
pub fn PermutationGroup::order(self : PermutationGroup) -> Int raise CombinatoricsError {
  match self.order_cache {
    Some(o) => o
    None => {
      let o = self.elements().length()
      self.order_cache = Some(o)
      o
    }
  }
}

///|
pub fn PermutationGroup::contains(
  self : PermutationGroup,
  g : Permutation,
  strict? : Bool = true,
) -> Bool raise CombinatoricsError {
  let mut gg = g
  if strict {
    if g.size() != self.degree {
      return false
    }
  } else {
    if g.size() > self.degree {
      return false
    }
    if g.size() < self.degree {
      gg = g.resize(self.degree)
    }
  }
  perm_array_contains(self.elements(), gg)
}

///|
pub fn PermutationGroup::equals(self : PermutationGroup, other : PermutationGroup) -> Bool raise CombinatoricsError {
  let a = self.elements()
  let b = other.elements()
  if a.length() != b.length() {
    return false
  }
  let keys_a : Array[String] = Array::new()
  for p in a {
    keys_a.push(array_key(p.array_form()))
  }
  let keys_b : Array[String] = Array::new()
  for p in b {
    keys_b.push(array_key(p.array_form()))
  }
  let sa = sort_strings(keys_a)
  let sb = sort_strings(keys_b)
  for i in 0..<sa.length() {
    if sa[i] != sb[i] {
      return false
    }
  }
  true
}

///|
pub fn PermutationGroup::mul(self : PermutationGroup, other : PermutationGroup) -> PermutationGroup raise CombinatoricsError {
  let m = self.degree
  let n = other.degree
  let gens : Array[Permutation] = Array::new()
  for g in self.generators {
    let arr : Array[Int] = Array::new()
    for i in 0..<(m + n) {
      arr.push(i)
    }
    let garr = g.array_form()
    for i in 0..<m {
      arr[i] = garr[i]
    }
    gens.push(Permutation::from_array(arr))
  }
  for g in other.generators {
    let arr : Array[Int] = Array::new()
    for i in 0..<(m + n) {
      arr.push(i)
    }
    let garr = g.array_form()
    for i in 0..<n {
      arr[m + i] = m + garr[i]
    }
    gens.push(Permutation::from_array(arr))
  }
  PermutationGroup::new(gens, dups=false)
}

///|
pub fn PermutationGroup::generate_dimino(self : PermutationGroup) -> Array[Permutation] raise CombinatoricsError {
  self.elements()
}

///|
pub fn PermutationGroup::generate_dimino_af(self : PermutationGroup) -> Array[Array[Int]] raise CombinatoricsError {
  let elems = self.elements()
  let out : Array[Array[Int]] = Array::new()
  for p in elems {
    out.push(p.array_form())
  }
  out
}

///|
pub fn PermutationGroup::generate_schreier_sims(self : PermutationGroup) -> Array[Permutation] raise CombinatoricsError {
  self.elements()
}

///|
pub fn PermutationGroup::generate(self : PermutationGroup) -> Array[Permutation] raise CombinatoricsError {
  self.elements()
}

///|
pub fn PermutationGroup::orbit(self : PermutationGroup, alpha : Int) -> Array[Int] raise CombinatoricsError {
  let seen : Array[Bool] = Array::make(self.degree, false)
  let queue : Array[Int] = Array::new()
  queue.push(alpha)
  seen[alpha] = true
  let mut idx = 0
  while idx < queue.length() {
    let x = queue[idx]
    for gen in self.generators {
      let y = gen.apply_index(x)
      if y >= 0 && y < self.degree && !seen[y] {
        seen[y] = true
        queue.push(y)
      }
    }
    idx = idx + 1
  }
  let out : Array[Int] = Array::new()
  for i in 0..<seen.length() {
    if seen[i] {
      out.push(i)
    }
  }
  out
}

///|
pub fn PermutationGroup::is_transitive(self : PermutationGroup) -> Bool raise CombinatoricsError {
  match self.is_transitive_cache {
    Some(v) => v
    None => {
      let orb = self.orbit(0)
      let v = orb.length() == self.degree
      self.is_transitive_cache = Some(v)
      v
    }
  }
}

///|
pub fn PermutationGroup::is_abelian(self : PermutationGroup) -> Bool raise CombinatoricsError {
  match self.is_abelian_cache {
    Some(v) => v
    None => {
      let elems = self.elements()
      for i in 0..<elems.length() {
        for j in (i + 1)..<elems.length() {
          if !elems[i].commutes_with(elems[j]) {
            self.is_abelian_cache = Some(false)
            return false
          }
        }
      }
      self.is_abelian_cache = Some(true)
      true
    }
  }
}

///|
pub fn PermutationGroup::is_symmetric(self : PermutationGroup) -> Bool raise CombinatoricsError {
  match self.is_symmetric_cache {
    Some(v) => v
    None => {
      let v = self.order() == factorial_int(self.degree)
      self.is_symmetric_cache = Some(v)
      v
    }
  }
}

///|
pub fn PermutationGroup::is_alternating(self : PermutationGroup) -> Bool raise CombinatoricsError {
  match self.is_alternating_cache {
    Some(v) => v
    None => {
      let target = factorial_int(self.degree) / 2
      if self.order() != target {
        self.is_alternating_cache = Some(false)
        return false
      }
      for p in self.elements() {
        if !p.is_even() {
          self.is_alternating_cache = Some(false)
          return false
        }
      }
      self.is_alternating_cache = Some(true)
      true
    }
  }
}

///|
pub fn PermutationGroup::is_cyclic(self : PermutationGroup) -> Bool raise CombinatoricsError {
  match self.is_cyclic_cache {
    Some(v) => v
    None => {
      let ord = self.order()
      for p in self.elements() {
        if p.order() == ord {
          self.is_cyclic_cache = Some(true)
          return true
        }
      }
      self.is_cyclic_cache = Some(false)
      false
    }
  }
}

///|
pub fn PermutationGroup::is_dihedral(self : PermutationGroup) -> Bool raise CombinatoricsError {
  match self.is_dihedral_cache {
    Some(v) => v
    None => {
      let n = self.degree
      let ord = self.order()
      if ord != 2 * n {
        self.is_dihedral_cache = Some(false)
        return false
      }
      let mut has_rotation = false
      let mut has_reflection = false
      for p in self.elements() {
        let o = p.order()
        if o == n {
          has_rotation = true
        } else if o == 2 {
          has_reflection = true
        }
      }
      let v = has_rotation && has_reflection
      self.is_dihedral_cache = Some(v)
      v
    }
  }
}

///|
pub fn PermutationGroup::make_perm(self : PermutationGroup, word : Array[Int]) -> Permutation raise CombinatoricsError {
  let mut p = self.identity()
  for idx in word {
    if idx < 0 || idx >= self.generators.length() {
      raise CombinatoricsError::ValueError("generator index out of range")
    }
    p = p.mul(self.generators[idx])
  }
  p
}

///|
pub fn PermutationGroup::random(self : PermutationGroup) -> Permutation raise CombinatoricsError {
  let elems = self.elements()
  if elems.is_empty() {
    return self.identity()
  }
  let rand = @random.Rand::new()
  let idx = rand.int(limit=elems.length())
  elems[idx]
}

///|
pub fn PermutationGroup::subgroup(
  self : PermutationGroup,
  gens : Array[Permutation],
) -> PermutationGroup raise CombinatoricsError {
  for g in gens {
    if !self.contains(g, strict=false) {
      raise CombinatoricsError::ValueError("generator not in group")
    }
  }
  PermutationGroup::new(gens)
}

///|
pub fn PermutationGroup::is_subgroup(
  self : PermutationGroup,
  other : PermutationGroup,
) -> Bool raise CombinatoricsError {
  if self.degree != other.degree {
    return false
  }
  for g in self.elements() {
    if !other.contains(g, strict=true) {
      return false
    }
  }
  true
}

///|
pub fn PermutationGroup::generator_product(
  self : PermutationGroup,
  g0 : Permutation,
  original? : Bool = false,
) -> Array[Permutation] raise CombinatoricsError {
  let mut g = g0
  if g.size() != self.degree {
    if g.size() > self.degree {
      raise CombinatoricsError::ValueError("element size mismatch")
    }
    g = g.resize(self.degree)
  }
  if g.is_identity() {
    return []
  }
  let gens = self.generators
  if gens.is_empty() {
    raise CombinatoricsError::ValueError("group has no generators")
  }
  let moves : Array[Permutation] = Array::new()
  for gen in gens {
    if !moves.any(x => x == gen) {
      moves.push(gen)
    }
    let inv = gen.invert()
    if !moves.any(x => x == inv) {
      moves.push(inv)
    }
  }
  let identity = self.identity()
  let visited : Map[Permutation, Bool] = {}
  let parent : Map[Permutation, (Permutation, Permutation)] = {}
  let queue : Array[Permutation] = Array::new()
  queue.push(identity)
  visited[identity] = true
  let mut head = 0
  let mut found = false
  while head < queue.length() && !found {
    let cur = queue[head]
    head = head + 1
    for mv in moves {
      let next = cur.mul(mv)
      if !visited.contains(next) {
        visited[next] = true
        parent[next] = (cur, mv)
        if next == g {
          found = true
          break
        }
        queue.push(next)
      }
    }
  }
  if !found {
    raise CombinatoricsError::ValueError("element not in group")
  }
  let prod : Array[Permutation] = Array::new()
  let mut cur = g
  while cur != identity {
    let entry = match parent.get(cur) {
      Some(v) => v
      None => raise CombinatoricsError::ValueError("generator decomposition failed")
    }
    prod.push(entry.1)
    cur = entry.0
  }
  let out : Array[Permutation] = Array::new()
  let mut i = prod.length()
  while i > 0 {
    i = i - 1
    out.push(prod[i])
  }
  if original {
    out
  } else {
    out
  }
}

///|
pub fn PermutationGroup::stabilizer(
  self : PermutationGroup,
  alpha : Int,
) -> PermutationGroup raise CombinatoricsError {
  self.pointwise_stabilizer([alpha])
}

///|
pub fn PermutationGroup::centralizer(
  self : PermutationGroup,
  other : PermutationGroup,
) -> PermutationGroup raise CombinatoricsError {
  let elems = self.elements()
  let gens = other.generators()
  let out : Array[Permutation] = Array::new()
  for g in elems {
    let mut ok = true
    for h in gens {
      if !g.commutes_with(h) {
        ok = false
        break
      }
    }
    if ok {
      out.push(g)
    }
  }
  if out.is_empty() {
    out.push(self.identity())
  }
  PermutationGroup::new(out)
}

///|
pub fn PermutationGroup::normal_closure(
  self : PermutationGroup,
  other : PermutationGroup,
) -> PermutationGroup raise CombinatoricsError {
  let elems = self.elements()
  let gens = other.generators()
  let conj : Array[Permutation] = Array::new()
  for g in gens {
    for h in elems {
      let h_inv = h.invert()
      conj.push(h_inv.mul(g).mul(h))
    }
  }
  if conj.is_empty() {
    conj.push(self.identity())
  }
  PermutationGroup::new(conj)
}

///|
pub fn PermutationGroup::derived_subgroup(self : PermutationGroup) -> PermutationGroup raise CombinatoricsError {
  let gens = self.generators
  let comms : Array[Permutation] = Array::new()
  for g in gens {
    for h in gens {
      comms.push(g.commutator(h))
    }
  }
  if comms.is_empty() {
    comms.push(self.identity())
  }
  PermutationGroup::new(comms)
}

///|
pub fn PermutationGroup::derived_series(self : PermutationGroup) -> Array[PermutationGroup] raise CombinatoricsError {
  let series : Array[PermutationGroup] = Array::new()
  series.push(self)
  let mut current = self
  let mut steps = 0
  while current.order() != 1 && steps < 100 {
    let next = current.derived_subgroup()
    series.push(next)
    current = next
    steps = steps + 1
  }
  series
}

///|
pub fn PermutationGroup::is_solvable(self : PermutationGroup) -> Bool raise CombinatoricsError {
  match self.is_solvable_cache {
    Some(v) => v
    None => {
      let series = self.derived_series()
      let last = series[series.length() - 1]
      let v = last.order() == 1
      self.is_solvable_cache = Some(v)
      v
    }
  }
}

///|
pub fn PermutationGroup::is_polycyclic(self : PermutationGroup) -> Bool raise CombinatoricsError {
  self.is_solvable()
}

///|
pub fn PermutationGroup::polycyclic_group(self : PermutationGroup) -> PolycyclicGroup raise CombinatoricsError {
  if !self.is_polycyclic() {
    raise CombinatoricsError::ValueError("The group must be solvable")
  }
  let der = self.derived_series()
  let pc_series_rev : Array[PermutationGroup] = Array::new()
  let pc_sequence_rev : Array[Permutation] = Array::new()
  let relative_order_rev : Array[Int] = Array::new()
  pc_series_rev.push(der[der.length() - 1])
  let der_rev : Array[PermutationGroup] = Array::new()
  let mut i = der.length()
  while i > 0 {
    i = i - 1
    der_rev.push(der[i])
  }
  for i in 0..<(der_rev.length() - 1) {
    let mut h = der_rev[i]
    let next = der_rev[i + 1]
    for g in next.generators() {
      if !h.contains(g, strict=true) {
        let new_gens : Array[Permutation] = [g]
        for gg in h.generators() {
          new_gens.push(gg)
        }
        h = PermutationGroup::new(new_gens)
        pc_series_rev.push(h)
        pc_sequence_rev.push(g)
        let g1 = pc_series_rev[pc_series_rev.length() - 1].order()
        let g2 = pc_series_rev[pc_series_rev.length() - 2].order()
        relative_order_rev.push(g1 / g2)
      }
    }
  }
  let pc_series : Array[PermutationGroup] = Array::new()
  let pc_sequence : Array[Permutation] = Array::new()
  let relative_order : Array[Int] = Array::new()
  let mut j = pc_series_rev.length()
  while j > 0 {
    j = j - 1
    pc_series.push(pc_series_rev[j])
  }
  let mut k = pc_sequence_rev.length()
  while k > 0 {
    k = k - 1
    pc_sequence.push(pc_sequence_rev[k])
  }
  let mut m = relative_order_rev.length()
  while m > 0 {
    m = m - 1
    relative_order.push(relative_order_rev[m])
  }
  PolycyclicGroup::new(pc_sequence, pc_series, relative_order)
}

///|
fn perm_fixes_points(p : Permutation, points : Array[Int]) -> Bool {
  let arr = p.array_form()
  for pt in points {
    if pt < 0 || pt >= arr.length() {
      return false
    }
    if arr[pt] != pt {
      return false
    }
  }
  true
}

///|
pub fn PermutationGroup::pointwise_stabilizer(
  self : PermutationGroup,
  points : Array[Int],
) -> PermutationGroup raise CombinatoricsError {
  for pt in points {
    if pt < 0 || pt >= self.degree {
      raise CombinatoricsError::ValueError("pointwise_stabilizer index out of range")
    }
  }
  let elems = self.elements()
  let stabs : Array[Permutation] = Array::new()
  for g in elems {
    if perm_fixes_points(g, points) {
      stabs.push(g)
    }
  }
  if stabs.is_empty() {
    stabs.push(self.identity())
  }
  PermutationGroup::new(stabs)
}

///|
pub fn PermutationGroup::schreier_sims_incremental(
  self : PermutationGroup,
) -> (Array[Int], Array[Permutation]) raise CombinatoricsError {
  let elems = self.elements()
  let base : Array[Int] = Array::new()
  let mut current : Array[Permutation] = Array::new()
  for g in elems {
    current.push(g)
  }
  for i in 0..<self.degree {
    let mut all_fix = true
    for g in current {
      let arr = g.array_form()
      if arr[i] != i {
        all_fix = false
        break
      }
    }
    if !all_fix {
      base.push(i)
      let filtered : Array[Permutation] = Array::new()
      for g in current {
        let arr = g.array_form()
        if arr[i] == i {
          filtered.push(g)
        }
      }
      current = filtered
    }
  }
  (base, elems)
}

///|
pub struct SymmetricPermutationGroup {
  degree : Int
  mut order_cache : Int?
}

///|
pub fn SymmetricPermutationGroup::new(deg : Int) -> SymmetricPermutationGroup {
  { degree: deg, order_cache: None }
}

///|
pub fn SymmetricPermutationGroup::degree(self : SymmetricPermutationGroup) -> Int {
  self.degree
}

///|
pub fn SymmetricPermutationGroup::order(self : SymmetricPermutationGroup) -> Int {
  match self.order_cache {
    Some(o) => o
    None => {
      let o = factorial_int(self.degree)
      self.order_cache = Some(o)
      o
    }
  }
}

///|
pub fn SymmetricPermutationGroup::contains(self : SymmetricPermutationGroup, p : Permutation) -> Bool {
  p.size() == self.degree
}

///|
pub fn SymmetricPermutationGroup::identity(self : SymmetricPermutationGroup) -> Permutation {
  Permutation::identity(self.degree)
}

///|
pub struct Coset {
  g : Permutation
  h : PermutationGroup
  dir : String
}

///|
pub fn Coset::new(g : Permutation, h : PermutationGroup, dir? : String = "+") -> Coset raise CombinatoricsError {
  if g.size() != h.degree() {
    raise CombinatoricsError::ValueError("coset size mismatch")
  }
  { g, h, dir }
}

///|
pub fn Coset::is_left(self : Coset) -> Bool {
  self.dir == "-"
}

///|
pub fn Coset::is_right(self : Coset) -> Bool {
  self.dir == "+"
}

///|
pub fn Coset::as_list(self : Coset) -> Array[Permutation] raise CombinatoricsError {
  let elems = self.h.elements()
  let out : Array[Permutation] = Array::new()
  if self.is_right() {
    for h in elems {
      out.push(h.mul(self.g))
    }
  } else {
    for h in elems {
      out.push(self.g.mul(h))
    }
  }
  out
}
