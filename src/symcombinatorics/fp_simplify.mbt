///|
/// Simplify presentations and eliminate redundant generators.

///|
fn set_unique_words(
  values : Array[FreeGroupElement],
) -> Array[FreeGroupElement] {
  let seen : Map[FreeGroupElement, Bool] = {}
  let out : Array[FreeGroupElement] = Array::new()
  for v in values {
    if !seen.contains(v) {
      seen[v] = true
      out.push(v)
    }
  }
  out
}

///|
pub fn elimination_technique_1(
  gens : Array[FreeGroupElement],
  rels : Array[FreeGroupElement],
  identity : FreeGroupElement,
) -> (Array[FreeGroupElement], Array[FreeGroupElement]) raise CombinatoricsError {
  let rels_mut : Array[FreeGroupElement] = Array::new()
  for r in rels {
    rels_mut.push(r)
  }
  let gens_mut : Array[FreeGroupElement] = Array::new()
  for g in gens {
    gens_mut.push(g)
  }
  // shorter relators first (short-lex)
  let n = rels_mut.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if rels_mut[j] < rels_mut[i] {
        let tmp = rels_mut[i]
        rels_mut[i] = rels_mut[j]
        rels_mut[j] = tmp
      }
    }
  }
  let redundant_gens : Map[FreeGroupElement, FreeGroupElement] = {}
  let redundant_rels : Array[FreeGroupElement] = Array::new()
  let used_gens : Map[FreeGroupElement, Bool] = {}
  for rel in rels_mut {
    let contained = rel.contains_generators()
    let mut skip = false
    for g, _ in redundant_gens {
      if contained.any(c => c == g) {
        skip = true
        break
      }
    }
    if skip {
      continue
    }
    let contained_sorted : Array[FreeGroupElement] = contained
    let m = contained_sorted.length()
    for i in 0..<m {
      for j in (i + 1)..<m {
        if contained_sorted[j] > contained_sorted[i] {
          let tmp = contained_sorted[i]
          contained_sorted[i] = contained_sorted[j]
          contained_sorted[j] = tmp
        }
      }
    }
    for gen in contained_sorted {
      if rel.generator_count(gen) == 1 && !used_gens.contains(gen) {
        let k = rel.exponent_sum(gen)
        let gen_index = rel.index(gen.pow(k))
        let bk = rel.subword(gen_index + 1, rel.length())
        let fw = rel.subword(0, gen_index)
        let chi = bk.mul(fw)
        redundant_gens[gen] = chi.pow(-k)
        for g in chi.contains_generators() {
          used_gens[g] = true
        }
        redundant_rels.push(rel)
        break
      }
    }
  }
  let rels2 : Array[FreeGroupElement] = Array::new()
  for r in rels_mut {
    if !redundant_rels.any(x => x == r) {
      rels2.push(r)
    }
  }
  let mut rels3 : Array[FreeGroupElement] = Array::new()
  for r in rels2 {
    rels3.push(
      r
      .eliminate_words_map(redundant_gens, all=true)
      .identity_cyclic_reduction(),
    )
  }
  rels3 = set_unique_words(rels3)
  let cleaned : Array[FreeGroupElement] = Array::new()
  for r in rels3 {
    if r != identity {
      cleaned.push(r)
    }
  }
  let gens3 : Array[FreeGroupElement] = Array::new()
  for g in gens_mut {
    if !redundant_gens.contains(g) {
      gens3.push(g)
    }
  }
  (gens3, cleaned)
}

///|
pub fn _simplify_relators(
  rels : Array[FreeGroupElement],
) -> Array[FreeGroupElement] raise CombinatoricsError {
  let rels_mut : Array[FreeGroupElement] = Array::new()
  for r in rels {
    rels_mut.push(r)
  }
  if rels_mut.is_empty() {
    return []
  }
  let identity = rels_mut[0].group.identity()
  let exps : Map[FreeGroupElement, FreeGroupElement] = {}
  for i in 0..<rels_mut.length() {
    let rel = rels_mut[i]
    if rel.number_syllables() == 1 {
      let g = rel.letter_at(0)
      let mut exp = rel.array_form()[0].1
      if exp < 0 {
        rels_mut[i] = rel.inverse()
        exp = -exp
      }
      if exps.contains(g) {
        let prev = exps[g].array_form()[0].1
        exp = gcd_int(exp, prev)
      }
      exps[g] = g.pow(exp)
    }
  }
  let one_syllable : Array[FreeGroupElement] = Array::new()
  for _, v in exps {
    one_syllable.push(v)
  }
  let out : Array[FreeGroupElement] = Array::new()
  for rel in rels_mut {
    if one_syllable.any(w => w == rel) {
      out.push(rel)
      continue
    }
    let mut w = rel.eliminate_words(one_syllable, all=true)
    for g in w.contains_generators() {
      if exps.contains(g) {
        let exp = exps[g].array_form()[0].1
        let max_exp = (exp + 1) / 2
        w = w.eliminate_word(g.pow(max_exp), by=g.pow(max_exp - exp), all=true)
        w = w.eliminate_word(
          g.pow(-max_exp),
          by=g.pow(-(max_exp - exp)),
          all=true,
        )
      }
    }
    out.push(w)
  }
  let mut reduced : Array[FreeGroupElement] = Array::new()
  for r in out {
    reduced.push(r.identity_cyclic_reduction())
  }
  for w in one_syllable {
    reduced.push(w)
  }
  reduced = set_unique_words(reduced)
  let final_rels : Array[FreeGroupElement] = Array::new()
  for r in reduced {
    if r != identity {
      final_rels.push(r)
    }
  }
  // sort
  let n = final_rels.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if final_rels[j] < final_rels[i] {
        let tmp = final_rels[i]
        final_rels[i] = final_rels[j]
        final_rels[j] = tmp
      }
    }
  }
  final_rels
}

///|
pub fn simplify_presentation(
  gens : Array[FreeGroupElement],
  rels : Array[FreeGroupElement],
  change_gens? : Bool = false,
) -> (Array[FreeGroupElement], Array[FreeGroupElement]) raise CombinatoricsError {
  if gens.is_empty() {
    return (gens, rels)
  }
  let identity = gens[0].group.identity()
  let mut gens_mut : Array[FreeGroupElement] = Array::new()
  for g in gens {
    gens_mut.push(g)
  }
  let mut rels_mut : Array[FreeGroupElement] = Array::new()
  for r in rels {
    rels_mut.push(r)
  }
  let mut prev_gens : Array[FreeGroupElement] = Array::new()
  let mut prev_rels : Array[FreeGroupElement] = Array::new()
  while set_unique_words(prev_rels) != set_unique_words(rels_mut) {
    prev_rels = rels_mut
    while change_gens &&
          set_unique_words(prev_gens) != set_unique_words(gens_mut) {
      prev_gens = gens_mut
      let res = elimination_technique_1(gens_mut, rels_mut, identity)
      gens_mut = res.0
      rels_mut = res.1
    }
    rels_mut = _simplify_relators(rels_mut)
  }
  if change_gens {
    let syms : Array[String] = Array::new()
    for g in gens_mut {
      let idx = g.array_form()[0].0
      syms.push(g.group.symbols[idx])
    }
    let (new_group, new_gens) = free_group_from_array(syms)
    let subs : Map[String, FreeGroupElement] = {}
    for i in 0..<syms.length() {
      subs[syms[i]] = new_gens[i]
    }
    let new_rels : Array[FreeGroupElement] = Array::new()
    for r in rels_mut {
      let mut rel = new_group.identity()
      for pair in r.array_form() {
        let name = r.group.symbols[pair.0]
        let gen = subs[name]
        rel = rel.mul(gen.pow(pair.1))
      }
      new_rels.push(rel)
    }
    gens_mut = new_gens
    rels_mut = new_rels
  }
  (gens_mut, rels_mut)
}
