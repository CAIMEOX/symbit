///|
/// Polycyclic groups and collector.

///|
fn pc_free_group(rank : Int) -> FreeGroup {
  let names : Array[String] = Array::new()
  for i in 0..<rank {
    names.push("x\{i}")
  }
  let (g, _) = free_group_from_array(names)
  g
}

///|
pub struct PolycyclicGroup {
  pcgs : Array[Permutation]
  pc_series : Array[PermutationGroup]
  relative_order : Array[Int]
  collector : Collector
}

///|
pub fn PolycyclicGroup::new(
  pc_sequence : Array[Permutation],
  pc_series : Array[PermutationGroup],
  relative_order : Array[Int],
  collector? : Collector,
) -> PolycyclicGroup raise CombinatoricsError {
  let coll = match collector {
    Some(c) => c
    None => Collector::new(pc_sequence, pc_series, relative_order)
  }
  {
    pcgs: pc_sequence,
    pc_series,
    relative_order,
    collector: coll,
  }
}

///|
pub fn PolycyclicGroup::is_prime_order(self : PolycyclicGroup) -> Bool {
  for order in self.relative_order {
    if !@symntheory.isprime(BigInt::from_int(order)) {
      return false
    }
  }
  true
}

///|
pub fn PolycyclicGroup::length(self : PolycyclicGroup) -> Int {
  self.pcgs.length()
}

///|
pub struct Collector {
  pcgs : Array[Permutation]
  pc_series : Array[PermutationGroup]
  relative_order : Array[Int]
  free_group : FreeGroup
  index : Map[Int, Int]
  mut pc_presentation : Map[FreeGroupElement, FreeGroupElement]
}

///|
pub fn Collector::new(
  pcgs : Array[Permutation],
  pc_series : Array[PermutationGroup],
  relative_order : Array[Int],
  free_group? : FreeGroup,
) -> Collector raise CombinatoricsError {
  let fg = match free_group {
    Some(g) => g
    None => pc_free_group(pcgs.length())
  }
  let index : Map[Int, Int] = {}
  for i in 0..<fg.rank {
    index[i] = i
  }
  let c : Collector = {
    pcgs,
    pc_series,
    relative_order,
    free_group: fg,
    index,
    pc_presentation: {},
  }
  let rels = c.pc_relators()
  c.pc_presentation = rels
  c
}

///|
pub fn Collector::minimal_uncollected_subword(
  self : Collector,
  word : FreeGroupElement,
) -> Array[(Int, Int)]? {
  if word.is_identity() {
    return None
  }
  let array = word.array_form()
  let re = self.relative_order
  let index = self.index
  for i in 0..<array.length() {
    let s1 = array[i].0
    let e1 = array[i].1
    let idx = index[s1]
    let rel = re[idx]
    if rel != 0 && (e1 < 0 || e1 > rel - 1) {
      return Some([ (s1, e1) ])
    }
  }
  for i in 0..<(array.length() - 1) {
    let s1 = array[i].0
    let e1 = array[i].1
    let s2 = array[i + 1].0
    let e2 = array[i + 1].1
    if index[s1] > index[s2] {
      let e = if e2 > 0 { 1 } else { -1 }
      return Some([ (s1, e1), (s2, e) ])
    }
  }
  None
}

///|
pub fn Collector::relations(
  self : Collector,
) -> (Map[FreeGroupElement, FreeGroupElement], Map[FreeGroupElement, FreeGroupElement]) {
  let power_relators : Map[FreeGroupElement, FreeGroupElement] = {}
  let conjugate_relators : Map[FreeGroupElement, FreeGroupElement] = {}
  for key, value in self.pc_presentation {
    if key.array_form().length() == 1 {
      power_relators[key] = value
    } else {
      conjugate_relators[key] = value
    }
  }
  (power_relators, conjugate_relators)
}

///|
pub fn Collector::subword_index(
  self : Collector,
  word : FreeGroupElement,
  w : FreeGroupElement,
) -> (Int, Int) raise CombinatoricsError {
  let mut low = -1
  let mut high = -1
  let len_word = word.length()
  let len_w = w.length()
  let mut i = 0
  while i <= len_word - len_w {
    if word.subword(i, i + len_w) == w {
      low = i
      high = i + len_w
      break
    }
    i = i + 1
  }
  (low, high)
}

///|
pub fn Collector::map_relation(
  self : Collector,
  w : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  let array = w.array_form()
  let s1 = array[0].0
  let s2 = array[1].0
  let key = free_group_element_from_form(self.free_group, [ (s2, -1), (s1, 1), (s2, 1) ])
  match self.pc_presentation.get(key) {
    Some(v) => v
    None => self.free_group.identity()
  }
}

///|
pub fn Collector::collected_word(
  self : Collector,
  word0 : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  let free_group = self.free_group
  let mut word = word0
  while true {
    let w_opt = self.minimal_uncollected_subword(word)
    match w_opt {
      None => break
      Some(w) => {
        let w_word = free_group_element_from_form(free_group, w)
        let (low, high) = self.subword_index(word, w_word)
        if low == -1 {
          continue
        }
        let s1 = w[0].0
        let e1 = w[0].1
        if w.length() == 1 {
          let idx = self.index[s1]
          let re = self.relative_order[idx]
          if re == 0 {
            break
          }
          let q = e1 / re
          let r = e1 - q * re
          let key = free_group_element_from_form(free_group, [ (s1, re) ])
          let pres = match self.pc_presentation.get(key) {
            Some(v) => v
            None => free_group.identity()
          }
          let word_ = if pres.is_identity() {
            if r != 0 {
              free_group_element_from_form(free_group, [ (s1, r) ])
            } else {
              free_group.identity()
            }
          } else {
            let pres_arr = pres.array_form()
            let sym = pres_arr[0].0
            let exp = pres_arr[0].1
            free_group_element_from_form(
              free_group,
              [ (s1, r), (sym, q * exp) ],
            )
          }
          word = word.eliminate_word(w_word, by=word_)
        }
        if w.length() == 2 && w[1].1 > 0 {
          let s2 = w[1].0
          let s2_word = free_group_element_from_form(free_group, [ (s2, 1) ])
          let mut word_ = self.map_relation(w_word)
          word_ = s2_word.mul(word_.pow(e1))
          word = word.substituted_word(low, high, word_)
        } else if w.length() == 2 && w[1].1 < 0 {
          let s2 = w[1].0
          let s2_word = free_group_element_from_form(free_group, [ (s2, 1) ])
          let mut word_ = self.map_relation(w_word)
          word_ = s2_word.inverse().mul(word_.pow(e1))
          word = word.substituted_word(low, high, word_)
        }
      }
    }
  }
  word
}

///|
pub fn Collector::pc_relators(self : Collector) -> Map[FreeGroupElement, FreeGroupElement] raise CombinatoricsError {
  let free_group = self.free_group
  let rel_order = self.relative_order
  let pc_relators : Map[FreeGroupElement, FreeGroupElement] = {}
  let perm_to_free : Map[Permutation, FreeGroupElement] = {}
  let fg_gens = free_group.generators()
  for i in 0..<self.pcgs.length() {
    let gen = self.pcgs[i]
    let sym = fg_gens[i]
    perm_to_free[gen] = sym
    perm_to_free[gen.invert()] = sym.inverse()
  }
  let pcgs_rev : Array[Permutation] = Array::new()
  let series_rev : Array[PermutationGroup] = Array::new()
  let rel_rev : Array[Int] = Array::new()
  let mut i = self.pcgs.length()
  while i > 0 {
    i = i - 1
    pcgs_rev.push(self.pcgs[i])
    series_rev.push(self.pc_series[i])
    rel_rev.push(rel_order[i])
  }
  let collected_gens : Array[Permutation] = Array::new()
  for i in 0..<pcgs_rev.length() {
    let gen = pcgs_rev[i]
    let re = rel_rev[i]
    let relation = perm_to_free[gen].pow(re)
    let g = series_rev[i]
    let l = g.generator_product(gen.pow(re), original=true)
    let l_rev : Array[Permutation] = Array::new()
    let mut j = l.length()
    while j > 0 {
      j = j - 1
      l_rev.push(l[j])
    }
    let mut word = free_group.identity()
    for gg in l_rev {
      word = word.mul(perm_to_free[gg])
    }
    word = self.collected_word(word)
    pc_relators[relation] = if word.is_identity() { free_group.identity() } else { word }
    self.pc_presentation = pc_relators
    collected_gens.push(gen)
    if collected_gens.length() > 1 {
      let conj = collected_gens[collected_gens.length() - 1]
      let conjugator = perm_to_free[conj]
      let mut j = 0
      while j < collected_gens.length() - 1 {
        let conjugated = perm_to_free[collected_gens[j]]
        let relation = conjugator.inverse().mul(conjugated).mul(conjugator)
        let gens = conj.pow(-1).mul(collected_gens[j]).mul(conj)
        let l2 = g.generator_product(gens, original=true)
        let l2_rev : Array[Permutation] = Array::new()
        let mut k = l2.length()
        while k > 0 {
          k = k - 1
          l2_rev.push(l2[k])
        }
        let mut word2 = free_group.identity()
        for gg in l2_rev {
          word2 = word2.mul(perm_to_free[gg])
        }
        word2 = self.collected_word(word2)
        pc_relators[relation] = if word2.is_identity() { free_group.identity() } else { word2 }
        self.pc_presentation = pc_relators
        j = j + 1
      }
    }
  }
  pc_relators
}

///|
pub fn Collector::exponent_vector(
  self : Collector,
  element : Permutation,
) -> Array[Int] raise CombinatoricsError {
  let free_group = self.free_group
  let g = PermutationGroup::new(self.pcgs)
  let gens = g.generator_product(element, original=true)
  let gens_rev : Array[Permutation] = Array::new()
  let mut j = gens.length()
  while j > 0 {
    j = j - 1
    gens_rev.push(gens[j])
  }
  let perm_to_free : Map[Permutation, FreeGroupElement] = {}
  let fg_gens = free_group.generators()
  for i in 0..<self.pcgs.length() {
    let gen = self.pcgs[i]
    let sym = fg_gens[i]
    perm_to_free[gen] = sym
    perm_to_free[gen.invert()] = sym.inverse()
  }
  let mut w = free_group.identity()
  for gg in gens_rev {
    w = w.mul(perm_to_free[gg])
  }
  let word = self.collected_word(w)
  let exp_vector : Array[Int] = Array::make(self.pcgs.length(), 0)
  for t in word.array_form() {
    exp_vector[self.index[t.0]] = t.1
  }
  exp_vector
}

///|
pub fn Collector::depth(self : Collector, element : Permutation) -> Int raise CombinatoricsError {
  let exp = self.exponent_vector(element)
  for i in 0..<exp.length() {
    if exp[i] != 0 {
      return i + 1
    }
  }
  self.pcgs.length() + 1
}

///|
pub fn Collector::leading_exponent(self : Collector, element : Permutation) -> Int? raise CombinatoricsError {
  let exp = self.exponent_vector(element)
  let depth = self.depth(element)
  if depth != self.pcgs.length() + 1 {
    return Some(exp[depth - 1])
  }
  None
}

///|
fn mod_inv(a0 : Int, m0 : Int) -> Int {
  let mut a = a0
  let mut m = m0
  let mut x0 = 1
  let mut x1 = 0
  while m != 0 {
    let q = a / m
    let t = a - q * m
    a = m
    m = t
    let t2 = x0 - q * x1
    x0 = x1
    x1 = t2
  }
  let mut inv = x0
  if inv < 0 {
    inv = inv % m0 + m0
  } else {
    inv = inv % m0
  }
  inv
}

///|
fn Collector::sift_z(
  self : Collector,
  z : Array[Permutation?],
  g : Permutation,
) -> Permutation raise CombinatoricsError {
  let mut h = g
  let mut d = self.depth(h)
  while d < self.pcgs.length() {
    match z[d - 1] {
      Some(k) => {
        let le_h = self.leading_exponent(h).unwrap_or(0)
        let le_k = self.leading_exponent(k).unwrap_or(1)
        let rel = self.relative_order[d - 1]
        let inv = if rel == 0 { 1 } else { mod_inv(le_k, rel) }
        let mut e = le_h * inv
        if rel != 0 {
          e = e % rel
        }
        h = k.pow(-e).mul(h)
        d = self.depth(h)
      }
      None => break
    }
  }
  h
}

///|
pub fn Collector::induced_pcgs(
  self : Collector,
  gens0 : Array[Permutation],
) -> Array[Permutation] raise CombinatoricsError {
  let z : Array[Permutation?] = Array::make(self.pcgs.length(), None)
  let gens : Array[Permutation] = Array::new()
  for g in gens0 { gens.push(g) }
  while !gens.is_empty() {
    let g = gens.remove(0)
    let h = self.sift_z(z, g)
    let d = self.depth(h)
    if d <= self.pcgs.length() && z[d - 1] is None {
      for gen in z {
        match gen {
          Some(v) => gens.push(h.pow(-1).mul(v.pow(-1)).mul(h).mul(v))
          None => ()
        }
      }
      z[d - 1] = Some(h)
    }
  }
  let out : Array[Permutation] = Array::new()
  for gen in z {
    match gen {
      Some(v) => out.push(v)
      None => ()
    }
  }
  out
}

///|
pub fn Collector::constructive_membership_test(
  self : Collector,
  ipcgs : Array[Permutation],
  g : Permutation,
) -> Array[Int]? raise CombinatoricsError {
  let e : Array[Int] = Array::make(ipcgs.length(), 0)
  let mut h = g
  let mut d = self.depth(h)
  let mut i = 0
  while i < ipcgs.length() {
    let gen = ipcgs[i]
    while self.depth(gen) == d {
      let le_h = self.leading_exponent(h).unwrap_or(0)
      let le_g = self.leading_exponent(gen).unwrap_or(0)
      let mut f = le_h * le_g
      let rel = self.relative_order[d - 1]
      if rel != 0 {
        f = f % rel
      }
      h = gen.pow(-f).mul(h)
      e[i] = f
      d = self.depth(h)
    }
    i = i + 1
  }
  if h.is_identity() {
    Some(e)
  } else {
    None
  }
}
