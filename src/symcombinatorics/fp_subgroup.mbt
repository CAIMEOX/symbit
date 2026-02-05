///|
/// Subgroups of free groups and finitely presented groups.

///|
pub enum SubgroupParent {
  Free(FreeGroup)
  Fp(FpGroup)
}

///|
enum MinWord {
  Word(FreeGroupElement)
  Family(FreeGroupElement, FreeGroupElement)
} derive(Eq)

///|
fn minword_is_subword(
  min_words : Array[MinWord],
  w : FreeGroupElement,
  normal : Bool,
) -> Bool raise CombinatoricsError {
  let (word, r) = w.cyclic_reduction_removed()
  if r.is_identity() || normal {
    for m in min_words {
      match m {
        MinWord::Word(v) => if v == word { return true }
        _ => ()
      }
    }
    return false
  }
  let fams : Array[FreeGroupElement] = Array::new()
  for m in min_words {
    match m {
      MinWord::Family(r0, p) => if r0 == r { fams.push(p) }
      _ => ()
    }
  }
  for p in fams {
    if word.power_of(p) {
      return true
    }
  }
  false
}

///|
fn minword_break(
  min_words : Array[MinWord],
  known : Map[FreeGroupElement, Bool],
  w : FreeGroupElement,
  normal : Bool,
) -> Bool raise CombinatoricsError {
  if w.length() == 0 {
    return true
  }
  let mut i = 0
  while i < w.length() {
    i = i + 1
    let prefix = w.subword(0, i)
    if !minword_is_subword(min_words, prefix, normal) {
      continue
    }
    let rest = w.subword(i, w.length())
    if known.contains(rest) {
      if known[rest] {
        return true
      }
    } else {
      let ok = minword_break(min_words, known, rest, normal)
      known[rest] = ok
      if ok {
        return true
      }
    }
  }
  false
}

///|
pub struct FpSubgroup {
  parent : SubgroupParent
  generators : Array[FreeGroupElement]
  normal : Bool
  mut min_words : Array[MinWord]?
  mut coset_table : CosetTable?
}

///|
pub fn FpSubgroup::new(
  parent : SubgroupParent,
  gens : Array[FreeGroupElement],
  normal? : Bool = false,
) -> FpSubgroup {
  let out : Array[FreeGroupElement] = Array::new()
  for g in gens {
    if !g.is_identity() {
      if !out.any(x => x == g) {
        out.push(g)
      }
    }
  }
  {
    parent,
    generators: out,
    normal,
    min_words: None,
    coset_table: None,
  }
}

///|
fn minword_process(w : FreeGroupElement) -> Array[MinWord] raise CombinatoricsError {
  let (p, r) = w.cyclic_reduction_removed()
  if !r.is_identity() {
    [ MinWord::Family(r, p) ]
  } else {
    [ MinWord::Word(w), MinWord::Word(w.inverse()) ]
  }
}

///|
pub fn FpSubgroup::contains(self : FpSubgroup, g0 : FreeGroupElement) -> Bool raise CombinatoricsError {
  match self.parent {
    SubgroupParent::Free(_) => {
      if self.min_words is None {
        let gens_list : Array[MinWord] = Array::new()
        for w0 in self.generators {
          let w = if self.normal { w0.cyclic_reduction() } else { w0 }
          for m in minword_process(w) { gens_list.push(m) }
        }
        // expand due to cancellations
        let mut i = 0
        while i < gens_list.length() {
          let w1 = gens_list[i]
          let mut j = 0
          while j < gens_list.length() {
            let w2 = gens_list[j]
            if w1 == w2 {
              j = j + 1
              continue
            }
            let (s1, s2) = match w1 {
              MinWord::Family(r, _) => (r.letter_at(0), r.letter_at(0).inverse())
              MinWord::Word(w) => (w.letter_at(0), w.letter_at(w.length() - 1))
            }
            let (r1, r2) = match w2 {
              MinWord::Family(r, _) => (r.letter_at(0), r.letter_at(0).inverse())
              MinWord::Word(w) => (w.letter_at(0), w.letter_at(w.length() - 1))
            }
            let p1 = match w1 {
              MinWord::Family(r, p) => r.mul(p).mul(r.inverse())
              MinWord::Word(w) => w
            }
            let p2 = match w2 {
              MinWord::Family(r, p) => r.mul(p).mul(r.inverse())
              MinWord::Word(w) => w
            }
            if r1.inverse() == s2 && !p1.mul(p2).is_identity() {
              let new_words = minword_process(p1.mul(p2))
              for nw in new_words {
                if !gens_list.any(x => x == nw) {
                  gens_list.push(nw)
                }
              }
            }
            if r2.inverse() == s1 && !p2.mul(p1).is_identity() {
              let new_words = minword_process(p2.mul(p1))
              for nw in new_words {
                if !gens_list.any(x => x == nw) {
                  gens_list.push(nw)
                }
              }
            }
            j = j + 1
          }
          i = i + 1
        }
        self.min_words = Some(gens_list)
      }
      let min_words = self.min_words.unwrap()

      let known : Map[FreeGroupElement, Bool] = {}
      let g = if self.normal { g0.cyclic_reduction() } else { g0 }
      return minword_break(min_words, known, g, self.normal)
    }
    SubgroupParent::Fp(parent) => {
      if self.coset_table is None {
        let coset_table = parent.coset_enumeration(self.generators)
        self.coset_table = Some(coset_table)
      }
      let coset_table = self.coset_table.unwrap()
      let mut i = 0
      let letters = g0.letter_form_elm()
      for j in 0..<letters.length() {
        let idx = coset_table.alphabet_index[letters[j]]
        match coset_table.table[i][idx] {
          Some(v) => i = v
          None => return false
        }
      }
      i == 0
    }
  }
}

///|
pub fn FpSubgroup::order(self : FpSubgroup) -> GroupOrder raise CombinatoricsError {
  if self.generators.is_empty() {
    return GroupOrder::Finite(1)
  }
  match self.parent {
    SubgroupParent::Free(_) => GroupOrder::Infinite
    SubgroupParent::Fp(parent) => {
      if self.coset_table is None {
        let coset_table = parent.coset_enumeration(self.generators)
        self.coset_table = Some(coset_table)
      }
      let coset_table = self.coset_table.unwrap()
      match parent.order() {
        GroupOrder::Finite(n) => GroupOrder::Finite(n / coset_table.table.length())
        GroupOrder::Infinite => GroupOrder::Infinite
      }
    }
  }
}

///|
pub fn FpSubgroup::to_fp_group(self : FpSubgroup) -> FpGroup raise CombinatoricsError {
  match self.parent {
    SubgroupParent::Free(_) => {
      let names : Array[String] = Array::new()
      for i in 0..<self.generators.length() {
        names.push("x_\{i}")
      }
      let (free_group, _) = free_group_from_array(names)
      FpGroup::new(free_group, [])
    }
    SubgroupParent::Fp(parent) => match self.coset_table {
      Some(ct) => parent.subgroup(self.generators, draft=ct)
      None => parent.subgroup(self.generators)
    }
  }
}

///|
pub fn FpSubgroup::to_string(self : FpSubgroup) -> String {
  if self.generators.length() > 30 {
    "<fp subgroup with \{self.generators.length()} generators>"
  } else {
    let gens = self.generators.map(g => g.to_string()).join(", ")
    "<fp subgroup on the generators (\{gens})>"
  }
}
