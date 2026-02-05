///|
/// Utilities for computational group theory (SymPy-style).

///|
fn array_contains_int(values : Array[Int], target : Int) -> Bool {
  for v in values {
    if v == target {
      return true
    }
  }
  false
}

///|
fn array_eq_ints(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn sort_int_array(values : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new()
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
fn arrays_equal_as_sets(a : Array[Int], b : Array[Int]) -> Bool {
  array_eq_ints(sort_int_array(a), sort_int_array(b))
}

///|
fn remove_perm_once(values : Array[Permutation], target : Permutation) -> Array[Permutation] {
  let out : Array[Permutation] = Array::new()
  let mut removed = false
  for v in values {
    if !removed && perm_eq(v, target) {
      removed = true
    } else {
      out.push(v)
    }
  }
  out
}

///|
fn orbit_points(degree : Int, generators : Array[Permutation], alpha : Int) -> Array[Int] raise CombinatoricsError {
  let gens_af : Array[Array[Int]] = Array::new()
  for g in generators {
    gens_af.push(g.array_form())
  }
  let used : Array[Bool] = Array::make(degree, false)
  let orb : Array[Int] = Array::new()
  orb.push(alpha)
  used[alpha] = true
  let mut idx = 0
  while idx < orb.length() {
    let b = orb[idx]
    for gen in gens_af {
      let temp = gen[b]
      if !used[temp] {
        used[temp] = true
        orb.push(temp)
      }
    }
    idx = idx + 1
  }
  sort_int_array(orb)
}

///|
fn orbit_transversal_af(
  degree : Int,
  generators : Array[Permutation],
  alpha : Int,
) -> (Array[(Int, Array[Int])], Map[Int, Array[Int]]) raise CombinatoricsError {
  let tr : Array[(Int, Array[Int])] = Array::new()
  let slp_dict : Map[Int, Array[Int]] = {}
  let identity : Array[Int] = Array::new()
  for i in 0..<degree {
    identity.push(i)
  }
  tr.push((alpha, identity))
  slp_dict[alpha] = []
  let used : Array[Bool] = Array::make(degree, false)
  used[alpha] = true
  let gens_af : Array[Array[Int]] = Array::new()
  for gen in generators {
    gens_af.push(gen.array_form())
  }
  let mut idx = 0
  while idx < tr.length() {
    let (x, px) = tr[idx]
    let px_slp = slp_dict[x]
    for gi in 0..<gens_af.length() {
      let gen = gens_af[gi]
      let temp = gen[x]
      if !used[temp] {
        let new_slp : Array[Int] = Array::new()
        new_slp.push(gi)
        for v in px_slp {
          new_slp.push(v)
        }
        slp_dict[temp] = new_slp
        let new_perm = af_rmul(gen, px)
        tr.push((temp, new_perm))
        used[temp] = true
      }
    }
    idx = idx + 1
  }
  (tr, slp_dict)
}

///|
fn isprime_int(n : Int) -> Bool {
  if n < 2 {
    return false
  }
  @symntheory.isprime(BigInt::from_int(n))
}

///|
pub fn _base_ordering(base : Array[Int], degree : Int) -> Array[Int] {
  let ordering : Array[Int] = Array::make(degree, 0)
  let base_len = base.length()
  let in_base : Array[Bool] = Array::make(degree, false)
  for i in 0..<base_len {
    let b = base[i]
    if b >= 0 && b < degree {
      ordering[b] = i
      in_base[b] = true
    }
  }
  let mut current = base_len
  for i in 0..<degree {
    if !in_base[i] {
      ordering[i] = current
      current = current + 1
    }
  }
  ordering
}

///|
pub fn _check_cycles_alt_sym(perm : Permutation) -> Bool {
  let n = perm.size()
  let af = perm.array_form()
  let mut current_len = 0
  let mut total_len = 0
  let used : Array[Bool] = Array::make(n, false)
  for i in 0..<(n / 2) {
    if !used[i] && i < n / 2 - total_len {
      current_len = 1
      used[i] = true
      let mut j = i
      while af[j] != i {
        current_len = current_len + 1
        j = af[j]
        used[j] = true
      }
      total_len = total_len + current_len
      if current_len > n / 2 && current_len < n - 2 && isprime_int(current_len) {
        return true
      }
    }
  }
  false
}

///|
pub fn _distribute_gens_by_base(
  base : Array[Int],
  gens : Array[Permutation],
) -> Array[Array[Permutation]] raise CombinatoricsError {
  let base_len = base.length()
  let stabs : Array[Array[Permutation]] = Array::new()
  for _ in 0..<base_len {
    stabs.push(Array::new())
  }
  if gens.is_empty() || base_len == 0 {
    return stabs
  }
  let degree = gens[0].size()
  let mut max_stab_index = 0
  for gen in gens {
    let garr = gen.array_form()
    let mut j = 0
    while j < base_len - 1 && garr[base[j]] == base[j] {
      j = j + 1
    }
    if j > max_stab_index {
      max_stab_index = j
    }
    for k in 0..=j {
      stabs[k].push(gen)
    }
  }
  for i in (max_stab_index + 1)..<base_len {
    stabs[i].push(Permutation::identity(degree))
  }
  stabs
}

///|
pub struct OrbitsTransversals {
  basic_orbits : Array[Array[Int]]
  transversals : Array[Map[Int, Permutation]]
  slps : Array[Map[Int, Array[Int]]]
}

///|
pub fn _orbits_transversals_from_bsgs(
  base : Array[Int],
  strong_gens_distr : Array[Array[Permutation]],
  transversals_only? : Bool = false,
  slp? : Bool = false,
) -> OrbitsTransversals raise CombinatoricsError {
  let base_len = base.length()
  let basic_orbits : Array[Array[Int]] = Array::new()
  let transversals : Array[Map[Int, Permutation]] = Array::new()
  let slps : Array[Map[Int, Array[Int]]] = Array::new()
  if base_len == 0 {
    return OrbitsTransversals::{ basic_orbits, transversals, slps }
  }
  let degree = strong_gens_distr[0][0].size()
  for i in 0..<base_len {
    let (pairs, slp_dict) = orbit_transversal_af(degree, strong_gens_distr[i], base[i])
    let trans_map : Map[Int, Permutation] = {}
    let orbit : Array[Int] = Array::new()
    for pair in pairs {
      let beta = pair.0
      let perm = Permutation::from_array(pair.1)
      trans_map[beta] = perm
      orbit.push(beta)
    }
    basic_orbits.push(sort_int_array(orbit))
    transversals.push(trans_map)
    slps.push(slp_dict)
  }
  OrbitsTransversals::{ basic_orbits, transversals, slps }
}

///|
pub fn _handle_precomputed_bsgs(
  base : Array[Int],
  strong_gens : Array[Permutation],
  transversals? : Array[Map[Int, Permutation]],
  basic_orbits? : Array[Array[Int]],
  strong_gens_distr? : Array[Array[Permutation]],
) -> (Array[Map[Int, Permutation]], Array[Array[Int]], Array[Array[Permutation]]) raise CombinatoricsError {
  let sg_distr = match strong_gens_distr {
    Some(v) => v
    None => _distribute_gens_by_base(base, strong_gens)
  }
  let mut trans = transversals
  let mut orbits = basic_orbits
  if trans is None {
    let result = _orbits_transversals_from_bsgs(base, sg_distr)
    trans = Some(result.transversals)
    orbits = Some(result.basic_orbits)
  } else {
    if orbits is None {
      let base_len = base.length()
      let out : Array[Array[Int]] = Array::new()
      for i in 0..<base_len {
        let keys : Array[Int] = Array::new()
        for k, _ in trans.unwrap()[i] {
          keys.push(k)
        }
        out.push(sort_int_array(keys))
      }
      orbits = Some(out)
    }
  }
  (trans.unwrap(), orbits.unwrap(), sg_distr)
}

///|
pub fn _remove_gens(
  base : Array[Int],
  strong_gens : Array[Permutation],
  basic_orbits? : Array[Array[Int]],
  strong_gens_distr? : Array[Array[Permutation]],
) -> Array[Permutation] raise CombinatoricsError {
  let base_len = base.length()
  if base_len == 0 || strong_gens.is_empty() {
    return strong_gens
  }
  let degree = strong_gens[0].size()
  let sg_distr = match strong_gens_distr {
    Some(v) => v
    None => _distribute_gens_by_base(base, strong_gens)
  }
  let mut orbits = basic_orbits
  if orbits is None {
    let out : Array[Array[Int]] = Array::new()
    for i in 0..<base_len {
      out.push(orbit_points(degree, sg_distr[i], base[i]))
    }
    orbits = Some(out)
  }
  let sg_distr_local : Array[Array[Permutation]] = Array::new()
  for part in sg_distr {
    let p : Array[Permutation] = Array::new()
    for g in part {
      p.push(g)
    }
    sg_distr_local.push(p)
  }
  sg_distr_local.push(Array::new())
  let mut res : Array[Permutation] = Array::new()
  for g in strong_gens {
    res.push(g)
  }
  let mut i = base_len
  while i > 0 {
    i = i - 1
    let mut gens_copy : Array[Permutation] = Array::new()
    for g in sg_distr_local[i] {
      gens_copy.push(g)
    }
    for gen in sg_distr_local[i] {
      if !perm_array_contains(sg_distr_local[i + 1], gen) {
        let temp_gens = remove_perm_once(gens_copy, gen)
        if temp_gens.is_empty() {
          continue
        }
        let temp_orbit = orbit_points(degree, temp_gens, base[i])
        if arrays_equal_as_sets(temp_orbit, orbits.unwrap()[i]) {
          gens_copy = temp_gens
          res = remove_perm_once(res, gen)
        }
      }
    }
  }
  res
}

///|
pub fn _strip(
  g : Permutation,
  base : Array[Int],
  orbits : Array[Array[Int]],
  transversals : Array[Map[Int, Permutation]],
) -> (Permutation, Int) raise CombinatoricsError {
  let mut h = g.array_form()
  let base_len = base.length()
  for i in 0..<base_len {
    let beta = h[base[i]]
    if beta == base[i] {
      continue
    }
    if !array_contains_int(orbits[i], beta) {
      return (Permutation::from_array(h), i + 1)
    }
    let u = match transversals[i].get(beta) {
      Some(p) => p.array_form()
      None => return (Permutation::from_array(h), i + 1)
    }
    h = af_rmul(af_invert(u), h)
  }
  (Permutation::from_array(h), base_len + 1)
}

///|
pub fn _strip_af(
  h0 : Array[Int],
  base : Array[Int],
  orbits : Array[Array[Int]],
  transversals : Array[Map[Int, Array[Int]]],
  j : Int,
  slp? : Array[(Int, Array[Int])] = [],
  slps? : Array[Map[Int, Array[Int]]] = [],
) -> (Array[Int]?, Int, Array[(Int, Array[Int])]) raise CombinatoricsError {
  let mut h : Array[Int] = Array::new()
  for v in h0 {
    h.push(v)
  }
  let base_len = base.length()
  let mut slp_acc : Array[(Int, Array[Int])] = Array::new()
  for pair in slp {
    slp_acc.push(pair)
  }
  let use_slp = slp_acc.length() > 0
  for i in (j + 1)..<base_len {
    let beta = h[base[i]]
    if beta == base[i] {
      continue
    }
    if !array_contains_int(orbits[i], beta) {
      return (Some(h), i + 1, slp_acc)
    }
    let u = match transversals[i].get(beta) {
      Some(arr) => arr
      None => return (Some(h), i + 1, slp_acc)
    }
    if array_eq_ints(h, u) {
      return (None, base_len + 1, slp_acc)
    }
    h = af_rmul(af_invert(u), h)
    if use_slp {
      let u_slp = if i < slps.length() {
        match slps[i].get(beta) {
          Some(v) => v
          None => []
        }
      } else {
        []
      }
      if !u_slp.is_empty() {
        let prefix : Array[(Int, Array[Int])] = Array::new()
        let mut idx = u_slp.length() - 1
        while idx >= 0 {
          prefix.push((i, [u_slp[idx]]))
          idx = idx - 1
        }
        let merged : Array[(Int, Array[Int])] = Array::new()
        for p in prefix {
          merged.push(p)
        }
        for p in slp_acc {
          merged.push(p)
        }
        slp_acc = merged
      }
    }
  }
  (Some(h), base_len + 1, slp_acc)
}

///|
pub fn _strong_gens_from_distr(
  strong_gens_distr : Array[Array[Permutation]],
) -> Array[Permutation] {
  if strong_gens_distr.length() == 1 {
    let out : Array[Permutation] = Array::new()
    for g in strong_gens_distr[0] {
      out.push(g)
    }
    return out
  }
  let result : Array[Permutation] = Array::new()
  for g in strong_gens_distr[0] {
    result.push(g)
  }
  if strong_gens_distr.length() > 1 {
    for gen in strong_gens_distr[1] {
      if !perm_array_contains(result, gen) {
        result.push(gen)
      }
    }
  }
  result
}
