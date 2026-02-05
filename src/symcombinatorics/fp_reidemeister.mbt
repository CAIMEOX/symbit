///|
/// Schreier generators and Reidemeister presentation utilities.

///|
pub fn define_schreier_generators(
  table : CosetTable,
  homomorphism? : Bool = false,
) -> Map[String, FreeGroupElement]? raise CombinatoricsError {
  let y : Array[String] = Array::new()
  let mut gamma = 1
  let f = table.free_group
  let gens = table.generators
  let tau : Map[Int, FreeGroupElement] = {}
  let gens_map : Map[String, FreeGroupElement] = {}
  if homomorphism {
    tau[0] = f.identity()
  }
  let labels : Array[Array[String?]] = Array::new()
  for _ in 0..<table.n() {
    labels.push(Array::make(table.alphabet.length(), None))
  }
  for alpha in table.omega() {
    for x in table.alphabet {
      let idx = table.alphabet_index[x]
      match table.table[alpha][idx] {
        Some(beta) =>
          if beta == gamma {
            labels[alpha][idx] = Some("<identity>")
            labels[beta][table.alphabet_inv_index[x]] = Some("<identity>")
            gamma = gamma + 1
            if homomorphism {
              let curr = tau[alpha]
              tau[beta] = curr.mul(x)
            }
          } else if gens.any(g => g == x) && labels[alpha][idx] is None {
            let name = "\{x.to_string()}_\{alpha}"
            y.push(name)
            labels[alpha][idx] = Some(name)
            if homomorphism {
              let curr = tau[alpha]
              let beta_word = tau[beta]
              gens_map[name] = curr.mul(x).mul(beta_word.inverse())
            }
          }
        None => ()
      }
    }
  }
  let (schreier_free, schreier_gens) = free_group_from_array(y)
  table.schreier_free_group = Some(schreier_free)
  table.schreier_generators = schreier_gens
  if homomorphism {
    table.schreier_gen_elem = gens_map
  }
  // replace labels with free group elements
  let word_table_new : Array[Array[FreeGroupElement?]] = Array::new()
  for _ in 0..<labels.length() {
    word_table_new.push(Array::make(table.alphabet.length(), None))
  }
  for i in 0..<labels.length() {
    for j in 0..<labels[i].length() {
      match labels[i][j] {
        Some(label) =>
          if label == "<identity>" {
            word_table_new[i][j] = Some(schreier_free.identity())
          } else {
            let mut idx = -1
            for k in 0..<y.length() {
              if y[k] == label {
                idx = k
                break
              }
            }
            if idx >= 0 && idx < schreier_gens.length() {
              let r = schreier_gens[idx]
              word_table_new[i][j] = Some(r)
              let beta = table.table[i][j].unwrap_or(-1)
              let inv_idx = j + 1
              if beta >= 0 &&
                beta < labels.length() &&
                inv_idx < labels[i].length() {
                word_table_new[beta][inv_idx] = Some(r.inverse())
              }
            }
          }
        None => ()
      }
    }
  }
  table.word_table = word_table_new
  if homomorphism {
    Some(gens_map)
  } else {
    None
  }
}

///|
pub fn rewrite(
  table : CosetTable,
  alpha0 : Int,
  w : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  let mut alpha = alpha0
  let mut v = table.schreier_free_group.unwrap().identity()
  let letters = w.letter_form_elm()
  for i in 0..<letters.length() {
    let x_i = letters[i]
    let idx = table.alphabet_index[x_i]
    let part = table.word_table[alpha][idx].unwrap_or(
      table.schreier_free_group.unwrap().identity(),
    )
    v = v.mul(part)
    alpha = table.table[alpha][idx].unwrap()
  }
  v
}

///|
pub fn reidemeister_relators(
  table : CosetTable,
) -> Unit raise CombinatoricsError {
  let rels : Array[FreeGroupElement] = Array::new()
  for w in table.relators {
    for coset in 0..<table.n() {
      rels.push(rewrite(table, coset, w))
    }
  }
  let order_1 : Array[FreeGroupElement] = Array::new()
  for r in rels {
    if r.length() == 1 {
      order_1.push(r)
    }
  }
  let filtered : Array[FreeGroupElement] = Array::new()
  for rel in rels {
    if !order_1.any(o => o == rel) {
      filtered.push(rel)
    }
  }
  let cleaned : Array[FreeGroupElement] = Array::new()
  for rel in filtered {
    let w = rel.eliminate_words(order_1, all=true)
    cleaned.push(w)
  }
  let gens_filtered : Array[FreeGroupElement] = Array::new()
  for g in table.schreier_generators {
    if !order_1.any(o => o == g || o == g.inverse()) {
      gens_filtered.push(g)
    }
  }
  table.schreier_generators = gens_filtered

  // remove cyclic conjugate duplicates
  let out : Array[FreeGroupElement] = Array::new()
  let mut i = 0
  while i < cleaned.length() {
    let w = cleaned[i]
    let mut dup = false
    for j in 0..<out.length() {
      if w.is_cyclic_conjugate(out[j]) {
        dup = true
        break
      }
    }
    if !dup {
      out.push(w)
    }
    i = i + 1
  }
  table.reidemeister_relators = out
}

///|
pub fn elimination_technique_2(
  table : CosetTable,
) -> (Array[FreeGroupElement], Array[FreeGroupElement]) raise CombinatoricsError {
  let mut rels = table.reidemeister_relators
  let gens = table.schreier_generators
  // sort descending by length
  let n = rels.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if rels[j] > rels[i] {
        let tmp = rels[i]
        rels[i] = rels[j]
        rels[j] = tmp
      }
    }
  }
  let mut i = gens.length()
  while i > 0 {
    i = i - 1
    let rel = rels[i]
    let mut j = gens.length()
    while j > 0 {
      j = j - 1
      let gen = gens[j]
      if rel.generator_count(gen) == 1 {
        let k = rel.exponent_sum(gen)
        let gen_index = rel.index(gen.pow(k))
        let bk = rel.subword(gen_index + 1, rel.length())
        let fw = rel.subword(0, gen_index)
        let rep_by = bk.mul(fw).pow(-k)
        ignore(rels.remove(i))
        ignore(gens.remove(j))
        let new_rels : Array[FreeGroupElement] = Array::new()
        for r in rels {
          new_rels.push(r.eliminate_word(gen, by=rep_by))
        }
        rels = new_rels
        break
      }
    }
  }
  table.reidemeister_relators = rels
  table.schreier_generators = gens
  (gens, rels)
}

///|
pub fn reidemeister_presentation(
  fp_grp : FpGroup,
  subgroup : Array[FreeGroupElement],
  draft? : CosetTable,
  homomorphism? : Bool = false,
) -> (Array[FreeGroupElement], Array[FreeGroupElement]) raise CombinatoricsError {
  let table = match draft {
    Some(ct) => ct
    None => coset_enumeration_r(fp_grp, subgroup)
  }
  table.compress()
  table.standardize()
  let _ = define_schreier_generators(table, homomorphism~)
  reidemeister_relators(table)
  let mut gens = table.schreier_generators
  let mut rels = table.reidemeister_relators
  let simplified = simplify_presentation(gens, rels, change_gens=true)
  gens = simplified.0
  rels = simplified.1
  table.schreier_generators = gens
  table.reidemeister_relators = rels
  (gens, rels)
}
