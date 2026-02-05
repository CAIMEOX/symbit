///|
/// Combinatorics test utilities (ported from SymPy).

///|
fn perm_key(p : Permutation) -> String {
  p.array_form().map(x => "\{x}").join(",")
}

///|
pub fn _cmp_perm_lists(
  first : Array[Permutation],
  second : Array[Permutation],
) -> Bool {
  let a : Array[String] = Array::new()
  let b : Array[String] = Array::new()
  for p in first {
    a.push(perm_key(p))
  }
  for p in second {
    b.push(perm_key(p))
  }
  let n = a.length()
  if b.length() != n {
    return false
  }
  for i in 0..<n {
    for j in (i + 1)..<n {
      if a[j] < a[i] {
        let tmp = a[i]
        a[i] = a[j]
        a[j] = tmp
      }
      if b[j] < b[i] {
        let tmp2 = b[i]
        b[i] = b[j]
        b[j] = tmp2
      }
    }
  }
  for i in 0..<n {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
pub fn _naive_list_centralizer(
  group : PermutationGroup,
  other : PermutationGroup,
) -> Array[Permutation] raise CombinatoricsError {
  let elements = group.elements()
  let gens = other.generators()
  let out : Array[Permutation] = Array::new()
  for element in elements {
    let mut ok = true
    for gen in gens {
      if !element.commutes_with(gen) {
        ok = false
        break
      }
    }
    if ok {
      out.push(element)
    }
  }
  out
}

///|
pub fn _verify_bsgs(
  group : PermutationGroup,
  base : Array[Int],
  gens : Array[Permutation],
) -> Bool raise CombinatoricsError {
  let strong_gens_distr = _distribute_gens_by_base(base, gens)
  let mut current = group
  for i in 0..<base.length() {
    let candidate = PermutationGroup::new(strong_gens_distr[i])
    if current.order() != candidate.order() {
      return false
    }
    current = current.stabilizer(base[i])
  }
  current.order() == 1
}

///|
pub fn _verify_centralizer(
  group : PermutationGroup,
  arg : PermutationGroup,
  centr? : PermutationGroup,
) -> Bool raise CombinatoricsError {
  let c = match centr {
    Some(v) => v
    None => group.centralizer(arg)
  }
  let naive = _naive_list_centralizer(group, arg)
  let naive_group = PermutationGroup::new(naive)
  c.equals(naive_group)
}

///|
pub fn _verify_normal_closure(
  group : PermutationGroup,
  arg : PermutationGroup,
  closure? : PermutationGroup,
) -> Bool raise CombinatoricsError {
  let cl = match closure {
    Some(v) => v
    None => group.normal_closure(arg)
  }
  let conjugates : Array[Permutation] = Array::new()
  for el in group.elements() {
    for gen in arg.generators() {
      let conj = el.invert().mul(gen).mul(el)
      conjugates.push(conj)
    }
  }
  let naive = PermutationGroup::new(conjugates)
  cl.is_subgroup(naive)
}
