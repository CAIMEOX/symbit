///|
/// Low index subgroups algorithm.

///|
pub fn low_index_subgroups(
  group : FpGroup,
  max_index : Int,
  subgroup? : Array[FreeGroupElement] = [],
) -> Array[CosetTable] raise CombinatoricsError {
  let table = CosetTable::new(
    group.free_group,
    group.relators,
    group.generators,
    group.to_string(),
    [],
  )
  let relators = group.relators
  let len_short_rel = 5
  let long_relators : Array[FreeGroupElement] = Array::new()
  let short_relators : Array[FreeGroupElement] = Array::new()
  for rel in relators {
    if rel.length() > len_short_rel {
      long_relators.push(rel)
    } else {
      short_relators.push(rel.identity_cyclic_reduction())
    }
  }
  let short_relator_buckets = table.conjugates(short_relators)
  let tables : Array[CosetTable] = Array::new()
  descendant_subgroups(tables, table, short_relator_buckets, long_relators, max_index, subgroup)
  tables
}

///|
fn descendant_subgroups(
  tables : Array[CosetTable],
  table : CosetTable,
  short_relator_buckets : Array[Array[FreeGroupElement]],
  long_relators : Array[FreeGroupElement],
  max_index : Int,
  subgroup : Array[FreeGroupElement],
) -> Unit raise CombinatoricsError {
  if table.is_complete() {
    for w in long_relators {
      for alpha in table.omega() {
        if !table.scan_check(alpha, w) {
          return
        }
      }
    }
    for w in subgroup {
      if !table.scan_check(0, w) {
        return
      }
    }
    tables.push(table)
  } else {
    let mut undefined_coset = 0
    let mut undefined_gen = table.alphabet[0]
    let mut found = false
    for alpha in 0..<table.table.length() {
      for x in table.alphabet {
        if table.table[alpha][table.alphabet_index[x]] is None {
          undefined_coset = alpha
          undefined_gen = x
          found = true
          break
        }
      }
      if found { break }
    }
    let reach : Array[Int] = table.omega()
    reach.push(table.n())
    for beta in reach {
      if beta < max_index {
        if beta == table.n() || table.table[beta][table.alphabet_inv_index[undefined_gen]] is None {
          try_descendant(
            tables,
            table,
            short_relator_buckets,
            long_relators,
            max_index,
            undefined_coset,
            undefined_gen,
            beta,
            subgroup,
          )
        }
      }
    }
  }
}

///|
fn try_descendant(
  tables : Array[CosetTable],
  table : CosetTable,
  short_relator_buckets : Array[Array[FreeGroupElement]],
  long_relators : Array[FreeGroupElement],
  max_index : Int,
  alpha : Int,
  x : FreeGroupElement,
  beta : Int,
  subgroup : Array[FreeGroupElement],
) -> Unit raise CombinatoricsError {
  let draft = table.copy()
  if beta == draft.n() && beta < max_index {
    draft.table.push(Array::make(draft.alphabet.length(), None))
    draft.p.push(beta)
  }
  draft.table[alpha][draft.alphabet_index[x]] = Some(beta)
  draft.table[beta][draft.alphabet_inv_index[x]] = Some(alpha)
  draft.deduction_stack.push((alpha, x))
  if !draft.process_deductions_check(
    short_relator_buckets[draft.alphabet_index[x]],
    short_relator_buckets[draft.alphabet_inv_index[x]],
  ) {
    return
  }
  for w in subgroup {
    if !draft.scan_check(0, w) {
      return
    }
  }
  if first_in_class(draft, subgroup) {
    descendant_subgroups(tables, draft, short_relator_buckets, long_relators, max_index, subgroup)
  }
}

///|
fn first_in_class(table : CosetTable, subgroup : Array[FreeGroupElement]) -> Bool raise CombinatoricsError {
  let n = table.n()
  let mut lamda = -1
  let nu : Array[Int?] = Array::make(n, None)
  let mu : Array[Int?] = Array::make(n, None)
  let mut next_alpha = false
  for alpha in 1..<n {
    for beta in 0..=lamda {
      match mu[beta] {
        Some(m) => nu[m] = None
        None => ()
      }
    }
    for w in subgroup {
      if table.table[alpha][table.alphabet_index[w]] != Some(alpha) {
        next_alpha = true
        break
      }
    }
    if next_alpha {
      next_alpha = false
      continue
    }
    mu[0] = Some(alpha)
    nu[alpha] = Some(0)
    lamda = 0
    let mut beta = 0
    while beta < n {
      for x in table.alphabet {
        let gamma = table.table[beta][table.alphabet_index[x]]
        let delta = match mu[beta] {
          Some(m) => table.table[m][table.alphabet_index[x]]
          None => None
        }
        if gamma is None || delta is None {
          next_alpha = true
          break
        }
        let g = gamma.unwrap()
        let d = delta.unwrap()
        if nu[d] is None {
          lamda = lamda + 1
          nu[d] = Some(lamda)
          mu[lamda] = Some(d)
        }
        let nud = nu[d].unwrap()
        if nud < g {
          return false
        }
        if nud > g {
          next_alpha = true
          break
        }
      }
      if next_alpha {
        next_alpha = false
        break
      }
      beta = beta + 1
    }
  }
  true
}
