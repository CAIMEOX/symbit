///|
/// Finitely presented groups (core operations).

///|
fn gcd_int_local(a0 : Int, b0 : Int) -> Int {
  let mut a = if a0 < 0 { -a0 } else { a0 }
  let mut b = if b0 < 0 { -b0 } else { b0 }
  while b != 0 {
    let t = a % b
    a = b
    b = t
  }
  a
}

///|
fn fp_group_name(free_group : FreeGroup, generators : Array[FreeGroupElement]) -> String {
  if free_group.rank > 30 {
    "<fp group with \{free_group.rank} generators>"
  } else {
    let gens = generators.map((g) => g.to_string()).join(", ")
    "<fp group on the generators (\{gens})>"
  }
}

///|
pub struct FpGroup {
  free_group : FreeGroup
  relators : Array[FreeGroupElement]
  generators : Array[FreeGroupElement]
  mut coset_table_cache : CosetTable?
  mut is_standardized : Bool
  mut order_cache : GroupOrder?
  center_cache : Array[FreeGroupElement]?
  rewriting_system : RewritingSystem
}

///|
pub fn FpGroup::new(fr_grp : FreeGroup, relators : Array[FreeGroupElement]) -> FpGroup {
  let gens = fr_grp.generators()
  let name = fp_group_name(fr_grp, gens)
  let rs = RewritingSystem::new(fr_grp, relators, gens, name)
  {
    free_group: fr_grp,
    relators,
    generators: gens,
    coset_table_cache: None,
    is_standardized: false,
    order_cache: None,
    center_cache: None,
    rewriting_system: rs,
  }
}

///|
pub fn fp_group(fr_grp : FreeGroup, relators : Array[FreeGroupElement]) -> (FpGroup, Array[FreeGroupElement]) {
  let grp = FpGroup::new(fr_grp, relators)
  (grp, grp.generators)
}

///|
pub fn xfp_group(fr_grp : FreeGroup, relators : Array[FreeGroupElement]) -> (FpGroup, Array[FreeGroupElement]) {
  fp_group(fr_grp, relators)
}

///|
pub fn vfp_group(fr_grp : FreeGroup, relators : Array[FreeGroupElement]) -> FpGroup {
  let (g, _) = fp_group(fr_grp, relators)
  g
}

///|
pub fn FpGroup::make_confluent(self : FpGroup) -> Unit raise CombinatoricsError {
  let _ = self.rewriting_system.make_confluent()
}

///|
pub fn FpGroup::reduce(self : FpGroup, word : FreeGroupElement) -> FreeGroupElement raise CombinatoricsError {
  self.rewriting_system.reduce(word)
}

///|
pub fn FpGroup::equals(
  self : FpGroup,
  word1 : FreeGroupElement,
  word2 : FreeGroupElement,
) -> Bool? raise CombinatoricsError {
  let diff = word1.mul(word2.inverse())
  if self.reduce(diff) == self.identity() {
    return Some(true)
  }
  if self.rewriting_system.is_confluent() {
    return Some(false)
  }
  None
}

///|
pub fn FpGroup::identity(self : FpGroup) -> FreeGroupElement {
  self.free_group.identity()
}

///|
pub fn FpGroup::contains(self : FpGroup, g : FreeGroupElement) -> Bool {
  self.free_group.contains(g)
}

///|
pub fn FpGroup::coset_enumeration(
  self : FpGroup,
  subgroup : Array[FreeGroupElement],
  strategy? : String = "relator_based",
  max_cosets? : Int,
  draft? : CosetTable,
  incomplete? : Bool = false,
) -> CosetTable raise CombinatoricsError {
  if strategy == "relator_based" {
    match max_cosets {
      Some(v) => {
        match draft {
          Some(d) => coset_enumeration_r(self, subgroup, max_cosets=v, draft=d, incomplete=incomplete)
          None => coset_enumeration_r(self, subgroup, max_cosets=v, incomplete=incomplete)
        }
      }
      None => {
        match draft {
          Some(d) => coset_enumeration_r(self, subgroup, draft=d, incomplete=incomplete)
          None => coset_enumeration_r(self, subgroup, incomplete=incomplete)
        }
      }
    }
  } else {
    match max_cosets {
      Some(v) => {
        match draft {
          Some(d) => coset_enumeration_c(self, subgroup, max_cosets=v, draft=d, incomplete=incomplete)
          None => coset_enumeration_c(self, subgroup, max_cosets=v, incomplete=incomplete)
        }
      }
      None => {
        match draft {
          Some(d) => coset_enumeration_c(self, subgroup, draft=d, incomplete=incomplete)
          None => coset_enumeration_c(self, subgroup, incomplete=incomplete)
        }
      }
    }
  }
}

///|
pub fn FpGroup::standardize_coset_table(self : FpGroup) -> Unit raise CombinatoricsError {
  match self.coset_table_cache {
    Some(ct) => {
      ct.standardize()
      self.is_standardized = true
    }
    None => ()
  }
}

///|
pub fn FpGroup::coset_table(
  self : FpGroup,
  subgroup : Array[FreeGroupElement],
  strategy? : String = "relator_based",
  max_cosets? : Int,
  draft? : CosetTable,
  incomplete? : Bool = false,
) -> Array[Array[Int?]] raise CombinatoricsError {
  if subgroup.is_empty() {
    match self.coset_table_cache {
      Some(ct) => {
        if !self.is_standardized {
          ct.standardize()
          self.is_standardized = true
        }
        return ct.table
      }
      None => {
        let coset_table = match max_cosets {
          Some(v) => {
            match draft {
              Some(d) => self.coset_enumeration(
                [],
                strategy=strategy,
                max_cosets=v,
                draft=d,
                incomplete=incomplete,
              )
              None => self.coset_enumeration(
                [],
                strategy=strategy,
                max_cosets=v,
                incomplete=incomplete,
              )
            }
          }
          None => {
            match draft {
              Some(d) => self.coset_enumeration(
                [],
                strategy=strategy,
                draft=d,
                incomplete=incomplete,
              )
              None => self.coset_enumeration([], strategy=strategy, incomplete=incomplete)
            }
          }
        }
        self.coset_table_cache = Some(coset_table)
        self.standardize_coset_table()
        return self.coset_table_cache.unwrap().table
      }
    }
  } else {
    let coset_table = match max_cosets {
      Some(v) => {
        match draft {
          Some(d) => self.coset_enumeration(
            subgroup,
            strategy=strategy,
            max_cosets=v,
            draft=d,
            incomplete=incomplete,
          )
          None => self.coset_enumeration(
            subgroup,
            strategy=strategy,
            max_cosets=v,
            incomplete=incomplete,
          )
        }
      }
      None => {
        match draft {
          Some(d) => self.coset_enumeration(
            subgroup,
            strategy=strategy,
            draft=d,
            incomplete=incomplete,
          )
          None => self.coset_enumeration(subgroup, strategy=strategy, incomplete=incomplete)
        }
      }
    }
    coset_table.standardize()
    coset_table.table
  }
}

///|
fn used_generators(relators : Array[FreeGroupElement]) -> Array[FreeGroupElement] {
  let seen : Map[FreeGroupElement, Bool] = {}
  let out : Array[FreeGroupElement] = Array::new()
  for r in relators {
    for g in r.contains_generators() {
      if !seen.contains(g) {
        seen[g] = true
        out.push(g)
      }
    }
  }
  out
}

///|
pub fn FpGroup::_is_infinite(self : FpGroup) -> Bool? {
  let used = used_generators(self.relators)
  for g in self.generators {
    if !used.any(u => u == g) {
      return Some(true)
    }
  }
  None
}

///|
pub fn FpGroup::order(self : FpGroup, strategy? : String = "relator_based") -> GroupOrder raise CombinatoricsError {
  match self.order_cache {
    Some(o) => o
    None => {
      let ord = if self.coset_table_cache is Some(ct) {
        GroupOrder::Finite(ct.table.length())
      } else if self.relators.is_empty() {
        self.free_group.order()
      } else if self.generators.length() == 1 {
        let mut g = 0
        for r in self.relators {
          let exp = r.array_form()[0].1
          if g == 0 {
            g = exp
          } else {
            g = gcd_int_local(g, exp)
          }
        }
        GroupOrder::Finite(if g < 0 { -g } else { g })
      } else {
        match self._is_infinite() {
          Some(true) => GroupOrder::Infinite
          _ => {
            let (gens, table_opt) = self._finite_index_subgroup()
            match table_opt {
              Some(ct) => {
                let ind = ct.table.length()
                let sub = self.subgroup(gens, draft=ct)
                match sub.order(strategy=strategy) {
                  GroupOrder::Finite(n) => GroupOrder::Finite(ind * n)
                  GroupOrder::Infinite => GroupOrder::Infinite
                }
              }
              None => {
                let idx = self.index([])
                match idx {
                  GroupOrder::Finite(n) => GroupOrder::Finite(n)
                  GroupOrder::Infinite => GroupOrder::Infinite
                }
              }
            }
          }
        }
      }
      self.order_cache = Some(ord)
      ord
    }
  }
}

///|
pub fn FpGroup::most_frequent_generator(self : FpGroup) -> FreeGroupElement raise CombinatoricsError {
  let gens = self.generators
  let rels = self.relators
  let mut max_idx = 0
  let mut max_val = -1
  for i in 0..<gens.length() {
    let mut total = 0
    for r in rels {
      total = total + r.generator_count(gens[i])
    }
    if total > max_val {
      max_val = total
      max_idx = i
    }
  }
  gens[max_idx]
}

///|
pub fn FpGroup::random(self : FpGroup) -> FreeGroupElement raise CombinatoricsError {
  let mut r = self.free_group.identity()
  let rand = @random.Rand::new()
  let len = 2 + rand.int(limit=2)
  for _ in 0..<len {
    let idx = rand.int(limit=self.generators.length())
    let gen = self.generators[idx]
    let sign = if rand.int(limit=2) == 0 { 1 } else { -1 }
    r = r.mul(gen.pow(sign))
  }
  r
}

///|
pub fn FpGroup::_finite_index_subgroup(self : FpGroup, s? : Array[FreeGroupElement])
  -> (Array[FreeGroupElement], CosetTable?) raise CombinatoricsError {
  let gen = self.most_frequent_generator()
  let rels : Array[FreeGroupElement] = Array::new()
  for g in self.generators {
    rels.push(g)
  }
  for r in self.relators {
    rels.push(r)
  }
  let s_local = match s {
    Some(v) => v
    None => {
      if self.generators.length() == 2 {
        let out : Array[FreeGroupElement] = Array::new()
        out.push(gen)
        for g in self.generators {
          if g != gen {
            out.push(g)
          }
        }
        out
      } else {
        let mut rand = self.free_group.identity()
        let mut i = 0
        while (rels.any(r => r == rand || r == rand.inverse() || rand.is_identity()) && i < 10) {
          rand = self.random()
          i = i + 1
        }
        let out : Array[FreeGroupElement] = Array::new()
        out.push(gen)
        out.push(rand)
        for g in self.generators {
          if g != gen && g != rand {
            out.push(g)
          }
        }
        out
      }
    }
  }
  let mid = (s_local.length() + 1) / 2
  let half1 = s_local[:mid].to_array()
  let half2 = s_local[mid:].to_array()
  let mut draft1 : CosetTable? = None
  let mut draft2 : CosetTable? = None
  let mut m = 200
  let mut table_opt : CosetTable? = None
  let mut half : Array[FreeGroupElement] = half1
  while table_opt is None && (m / 2 < coset_table_max_limit) {
    if m > coset_table_max_limit { m = coset_table_max_limit }
    draft1 = Some(match draft1 {
      Some(d) => self.coset_enumeration(half1, max_cosets=m, draft=d, incomplete=true)
      None => self.coset_enumeration(half1, max_cosets=m, incomplete=true)
    })
    if draft1.unwrap().is_complete() {
      table_opt = draft1
      half = half1
    } else {
      draft2 = Some(match draft2 {
        Some(d) => self.coset_enumeration(half2, max_cosets=m, draft=d, incomplete=true)
        None => self.coset_enumeration(half2, max_cosets=m, incomplete=true)
      })
      if draft2.unwrap().is_complete() {
        table_opt = draft2
        half = half2
      }
    }
    if table_opt is None {
      m = m * 2
    }
  }
  match table_opt {
    Some(ct) => {
      ct.compress()
      (half, Some(ct))
    }
    None => ([], None)
  }
}

///|
pub fn FpGroup::index(
  self : FpGroup,
  subgroup : Array[FreeGroupElement],
  strategy? : String = "relator_based",
)
  -> GroupOrder raise CombinatoricsError {
  if subgroup.is_empty() {
    return self.order(strategy=strategy)
  }
  let coset_table = self.coset_enumeration(subgroup, strategy=strategy)
  GroupOrder::Finite(coset_table.table.length())
}

///|
pub fn FpGroup::subgroup(
  self : FpGroup,
  gens : Array[FreeGroupElement],
  draft? : CosetTable,
) -> FpGroup raise CombinatoricsError {
  if !gens.all(g => g.group == self.free_group) {
    raise CombinatoricsError::ValueError("generators not in group")
  }
  let (schreier_gens, rels) = match draft {
    Some(d) => reidemeister_presentation(self, gens, draft=d)
    None => reidemeister_presentation(self, gens)
  }
  if schreier_gens.is_empty() {
    let (g0, _) = free_group("")
    return FpGroup::new(g0, [])
  }
  FpGroup::new(schreier_gens[0].group, rels)
}

///|
pub fn FpGroup::to_string(self : FpGroup) -> String {
  fp_group_name(self.free_group, self.generators)
}

///|
pub type FpGroupElement = FreeGroupElement
