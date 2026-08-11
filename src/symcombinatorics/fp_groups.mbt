///|
/// Finitely presented groups and their basic algorithms.
///
/// This file ports the central surface of `sympy.combinatorics.fp_groups`: creating a group
/// from a free group and relators, reducing words through the rewriting system, computing
/// coset tables, and deriving coarse invariants such as group order or subgroup index.

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
fn fp_group_name(
  free_group : FreeGroup,
  generators : Array[FreeGroupElement],
) -> String {
  if free_group.rank > 30 {
    "<fp group with \{free_group.rank} generators>"
  } else {
    let gens = generators.map(g => g.to_string()).join(", ")
    "<fp group on the generators (\{gens})>"
  }
}

///|
/// A finitely presented group `F/R` built from a free group and relators.
///
/// The object owns both a Todd-Coxeter coset-table cache and a rewriting system so that the
/// same group can answer membership, equality, and order queries through whichever algorithm
/// is appropriate.
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
/// Construct a finitely presented group from a free group and relators.
pub fn FpGroup::new(
  fr_grp : FreeGroup,
  relators : Array[FreeGroupElement],
) -> FpGroup {
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
/// Convenience constructor returning the group together with its distinguished generators.
pub fn fp_group(
  fr_grp : FreeGroup,
  relators : Array[FreeGroupElement],
) -> (FpGroup, Array[FreeGroupElement]) {
  let grp = FpGroup::new(fr_grp, relators)
  (grp, grp.generators)
}

///|
/// Compatibility alias for `fp_group`.
pub fn xfp_group(
  fr_grp : FreeGroup,
  relators : Array[FreeGroupElement],
) -> (FpGroup, Array[FreeGroupElement]) {
  fp_group(fr_grp, relators)
}

///|
/// Compatibility constructor returning only the group object.
pub fn vfp_group(
  fr_grp : FreeGroup,
  relators : Array[FreeGroupElement],
) -> FpGroup {
  let (g, _) = fp_group(fr_grp, relators)
  g
}

///|
/// Try to complete the rewriting system to a confluent one.
pub fn FpGroup::make_confluent(self : FpGroup) -> Unit raise CombinatoricsError {
  let _ = self.rewriting_system.make_confluent()
}

///|
/// Reduce a word modulo the defining relators using the rewriting system.
pub fn FpGroup::reduce(
  self : FpGroup,
  word : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  self.rewriting_system.reduce(word)
}

///|
/// Decide whether two words represent the same group element.
///
/// The result is `None` when the current rewriting data is insufficient to decide equality
/// conclusively.
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
/// Return the identity element of the finitely presented group.
pub fn FpGroup::identity(self : FpGroup) -> FreeGroupElement {
  self.free_group.identity()
}

///|
/// Return whether the ambient free-group word is formed from this group's generators.
pub fn FpGroup::contains(self : FpGroup, g : FreeGroupElement) -> Bool {
  self.free_group.contains(g)
}

///|
/// Run Todd-Coxeter coset enumeration for a subgroup.
///
/// `strategy` selects the relator-based or coset-table-based variant exposed by SymPy.
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
      Some(v) =>
        match draft {
          Some(d) =>
            coset_enumeration_r(
              self,
              subgroup,
              max_cosets=v,
              draft=d,
              incomplete~,
            )
          None => coset_enumeration_r(self, subgroup, max_cosets=v, incomplete~)
        }
      None =>
        match draft {
          Some(d) => coset_enumeration_r(self, subgroup, draft=d, incomplete~)
          None => coset_enumeration_r(self, subgroup, incomplete~)
        }
    }
  } else {
    match max_cosets {
      Some(v) =>
        match draft {
          Some(d) =>
            coset_enumeration_c(
              self,
              subgroup,
              max_cosets=v,
              draft=d,
              incomplete~,
            )
          None => coset_enumeration_c(self, subgroup, max_cosets=v, incomplete~)
        }
      None =>
        match draft {
          Some(d) => coset_enumeration_c(self, subgroup, draft=d, incomplete~)
          None => coset_enumeration_c(self, subgroup, incomplete~)
        }
    }
  }
}

///|
/// Standardize the cached coset table in-place.
pub fn FpGroup::standardize_coset_table(self : FpGroup) -> Unit {
  match self.coset_table_cache {
    Some(ct) => {
      ct.standardize()
      self.is_standardized = true
    }
    None => ()
  }
}

///|
/// Return the subgroup coset table as raw table data.
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
          Some(v) =>
            match draft {
              Some(d) =>
                self.coset_enumeration(
                  [],
                  strategy~,
                  max_cosets=v,
                  draft=d,
                  incomplete~,
                )
              None =>
                self.coset_enumeration([], strategy~, max_cosets=v, incomplete~)
            }
          None =>
            match draft {
              Some(d) =>
                self.coset_enumeration([], strategy~, draft=d, incomplete~)
              None => self.coset_enumeration([], strategy~, incomplete~)
            }
        }
        self.coset_table_cache = Some(coset_table)
        self.standardize_coset_table()
        return self.coset_table_cache.unwrap().table
      }
    }
  } else {
    let coset_table = match max_cosets {
      Some(v) =>
        match draft {
          Some(d) =>
            self.coset_enumeration(
              subgroup,
              strategy~,
              max_cosets=v,
              draft=d,
              incomplete~,
            )
          None =>
            self.coset_enumeration(
              subgroup,
              strategy~,
              max_cosets=v,
              incomplete~,
            )
        }
      None =>
        match draft {
          Some(d) =>
            self.coset_enumeration(subgroup, strategy~, draft=d, incomplete~)
          None => self.coset_enumeration(subgroup, strategy~, incomplete~)
        }
    }
    coset_table.standardize()
    coset_table.table
  }
}

///|
fn used_generators(
  relators : Array[FreeGroupElement],
) -> Array[FreeGroupElement] {
  let seen : Map[FreeGroupElement, Bool] = Map([])
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
/// Heuristically decide whether the group is infinite.
///
/// `None` means the current quick tests are inconclusive.
pub fn FpGroup::_is_infinite(self : FpGroup) -> Bool? {
  let used = used_generators(self.relators)
  for g in self.generators {
    if !used.any(u => u == g) {
      return Some(true)
    }
  }
  let inv = fp_group_abelian_invariants(self)
  if inv.rank > 0 {
    return Some(true)
  }
  None
}

///|
/// Return the group order when it can be determined.
///
/// The result uses `GroupOrder` because finitely presented groups may be infinite.
pub fn FpGroup::order(
  self : FpGroup,
  strategy? : String = "relator_based",
) -> GroupOrder raise CombinatoricsError {
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
                match sub.order(strategy~) {
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
/// Return the generator occurring most frequently in the relators.
pub fn FpGroup::most_frequent_generator(
  self : FpGroup,
) -> FreeGroupElement raise CombinatoricsError {
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
/// Return a pseudo-random element of the group by random walks in the generators.
pub fn FpGroup::random(
  self : FpGroup,
) -> FreeGroupElement raise CombinatoricsError {
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
/// Search for a finite-index subgroup generated by the supplied words.
pub fn FpGroup::_finite_index_subgroup(
  self : FpGroup,
  s? : Array[FreeGroupElement],
) -> (Array[FreeGroupElement], CosetTable?) raise CombinatoricsError {
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
    None =>
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
        while rels.any(r => {
                r == rand || r == rand.inverse() || rand.is_identity()
              }) &&
              i < 10 {
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
  let mid = (s_local.length() + 1) / 2
  let half1 = s_local[:mid].to_owned()
  let half2 = s_local[mid:].to_owned()
  let mut draft1 : CosetTable? = None
  let mut draft2 : CosetTable? = None
  let mut m = 200
  let mut table_opt : CosetTable? = None
  let mut half : Array[FreeGroupElement] = half1
  while table_opt is None && m / 2 < coset_table_max_limit {
    if m > coset_table_max_limit {
      m = coset_table_max_limit
    }
    draft1 = Some(
      match draft1 {
        Some(d) =>
          self.coset_enumeration(half1, max_cosets=m, draft=d, incomplete=true)
        None => self.coset_enumeration(half1, max_cosets=m, incomplete=true)
      },
    )
    if draft1.unwrap().is_complete() {
      table_opt = draft1
      half = half1
    } else {
      draft2 = Some(
        match draft2 {
          Some(d) =>
            self.coset_enumeration(
              half2,
              max_cosets=m,
              draft=d,
              incomplete=true,
            )
          None => self.coset_enumeration(half2, max_cosets=m, incomplete=true)
        },
      )
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
/// Return the index of a subgroup inside the group.
pub fn FpGroup::index(
  self : FpGroup,
  subgroup : Array[FreeGroupElement],
  strategy? : String = "relator_based",
) -> GroupOrder raise CombinatoricsError {
  if subgroup.is_empty() {
    return self.order(strategy~)
  }
  let coset_table = self.coset_enumeration(subgroup, strategy~)
  GroupOrder::Finite(coset_table.table.length())
}

///|
/// Construct the subgroup generated by the given words.
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
/// Return a readable description of the finitely presented group.
pub impl Show for FpGroup with fn to_string(self) -> String {
  fp_group_name(self.free_group, self.generators)
}

///|
pub impl Show for FpGroup with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
/// Elements of an `FpGroup` are represented by the same reduced-word type as free-group elements.
pub type FpGroupElement = FreeGroupElement
