///|
/// Tensor canonicalization (SymPy tensor_can port).

///|
pub(all) struct TensorComponent {
  base : Array[Int]
  gens : Array[Permutation]
  count : Int
  sym : Int?
}

///|
struct TensorComponentFree {
  base : Array[Int]
  gens : Array[Permutation]
  free : Array[Array[Int]]
  sym : Int?
}

///|
fn copy_int_array(values : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for v in values {
    out.push(v)
  }
  out
}

///|
fn copy_int_arrays(values : Array[Array[Int]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for arr in values {
    out.push(copy_int_array(arr))
  }
  out
}

///|
fn range_array(start : Int, end : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  let mut i = start
  while i < end {
    out.push(i)
    i = i + 1
  }
  out
}

///|
fn slice_int_array(values : Array[Int], start : Int, end : Int) -> Array[Int] {
  let n = values.length()
  let mut s = start
  let mut e = end
  if s < 0 {
    s = 0
  }
  if e < s {
    e = s
  }
  if s > n {
    s = n
  }
  if e > n {
    e = n
  }
  let out : Array[Int] = Array::new()
  for i in s..<e {
    out.push(values[i])
  }
  out
}

///|
fn concat_int_arrays(a : Array[Int], b : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for v in a {
    out.push(v)
  }
  for v in b {
    out.push(v)
  }
  out
}

///|
fn index_of_int(values : Array[Int], target : Int) -> Int? {
  for i in 0..<values.length() {
    if values[i] == target {
      return Some(i)
    }
  }
  None
}

///|
fn min_int_array(values : Array[Int]) -> Int {
  let mut m = values[0]
  for i in 1..<values.length() {
    if values[i] < m {
      m = values[i]
    }
  }
  m
}

///|
fn lex_cmp_int_arrays(a : Array[Int], b : Array[Int]) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  if a.length() == b.length() {
    0
  } else if a.length() < b.length() {
    -1
  } else {
    1
  }
}

///|
fn sort_int_arrays_lex(values : Array[Array[Int]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for arr in values {
    out.push(copy_int_array(arr))
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if lex_cmp_int_arrays(out[j], out[i]) < 0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn prefix_equal(a : Array[Int], b : Array[Int], upto : Int) -> Bool {
  let mut limit = upto
  if limit < 0 {
    limit = 0
  }
  if limit > a.length() {
    limit = a.length()
  }
  if limit > b.length() {
    limit = b.length()
  }
  for i in 0..<limit {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
priv struct TabEntry {
  s : Array[Int]
  d : Array[Int]
  h : Array[Int]
}

///|
fn sort_tab_by_h(tab : Array[TabEntry]) -> Array[TabEntry] {
  let out : Array[TabEntry] = Array::new()
  for entry in tab {
    out.push(entry)
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if lex_cmp_int_arrays(out[j].h, out[i].h) < 0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn remove_int_once(values : Array[Int], target : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  let mut removed = false
  for v in values {
    if !removed && v == target {
      removed = true
    } else {
      out.push(v)
    }
  }
  out
}

///|
pub fn dummy_sgs(dummies : Array[Int], sym : Int?, n : Int) -> Array[Array[Int]] raise CombinatoricsError {
  if dummies.length() > n {
    raise CombinatoricsError::ValueError("List too large")
  }
  let res : Array[Array[Int]] = Array::new()
  match sym {
    Some(s) => {
      let mut idx = 0
      while idx < dummies.length() {
        let j = dummies[idx]
        let a = range_array(0, n + 2)
        if s == 1 {
          a[n] = n + 1
          a[n + 1] = n
        }
        let tmp = a[j]
        a[j] = a[j + 1]
        a[j + 1] = tmp
        res.push(a)
        idx = idx + 2
      }
    }
    None => ()
  }
  let mut idx = 0
  while idx + 3 < dummies.length() {
    let j = dummies[idx]
    let a = range_array(0, n + 2)
    let v0 = a[j]
    let v1 = a[j + 1]
    let v2 = a[j + 2]
    let v3 = a[j + 3]
    a[j] = v2
    a[j + 1] = v3
    a[j + 2] = v0
    a[j + 3] = v1
    res.push(a)
    idx = idx + 2
  }
  res
}

///|
pub fn _min_dummies(
  dummies : Array[Array[Int]],
  sym : Array[Int?],
  indices : Array[Int],
) -> Array[Int] {
  let num_types = sym.length()
  let mins : Array[Int] = Array::new()
  for dx in dummies {
    if dx.is_empty() {
      mins.push(0)
    } else {
      mins.push(min_int_array(dx))
    }
  }
  let res = copy_int_array(indices)
  for c in 0..<indices.length() {
    let idx = indices[c]
    for j in 0..<num_types {
      if array_contains_int(dummies[j], idx) {
        res[c] = mins[j]
        break
      }
    }
  }
  res
}

///|
fn trace_S(
  s : Array[Int],
  j : Int,
  b : Int,
  s_cosets : Array[Array[Array[Int]]],
) -> Array[Int]? {
  if b < 0 || b >= s_cosets.length() {
    return None
  }
  for h in s_cosets[b] {
    if s[h[b]] == j {
      return Some(h)
    }
  }
  None
}

///|
fn trace_D(gj : Int, p_i : Int, dxtrav : Array[Array[Int]]) -> Array[Int]? {
  for h in dxtrav {
    if h[gj] == p_i {
      return Some(h)
    }
  }
  None
}

///|
fn dumx_remove(
  dumx : Array[Array[Int]],
  p0 : Int,
) -> (Array[Array[Int]], Array[Int]) {
  let res : Array[Array[Int]] = Array::new()
  for dx in dumx {
    if !array_contains_int(dx, p0) {
      res.push(copy_int_array(dx))
      continue
    }
    let mut idx = -1
    for i in 0..<dx.length() {
      if dx[i] == p0 {
        idx = i
        break
      }
    }
    if idx < 0 {
      res.push(copy_int_array(dx))
      continue
    }
    let paired = if idx % 2 == 0 { dx[idx + 1] } else { dx[idx - 1] }
    let ndx : Array[Int] = Array::new()
    for v in dx {
      if v != p0 && v != paired {
        ndx.push(v)
      }
    }
    res.push(ndx)
  }
  let flat : Array[Int] = Array::new()
  for dx in res {
    for v in dx {
      flat.push(v)
    }
  }
  (res, flat)
}

///|
fn transversal2coset(
  size : Int,
  base : Array[Int],
  transversal : Array[Map[Int, Array[Int]]],
) -> Array[Array[Array[Int]]] {
  if base.is_empty() {
    return []
  }
  let identity = range_array(0, size)
  let a : Array[Array[Array[Int]]] = Array::new()
  let mut j = 0
  for i in 0..<size {
    if array_contains_int(base, i) {
      let vals : Array[Array[Int]] = Array::new()
      for _, v in transversal[j] {
        vals.push(v)
      }
      a.push(sort_int_arrays_lex(vals))
      j = j + 1
    } else {
      a.push([copy_int_array(identity)])
    }
  }
  let mut k = a.length() - 1
  while k >= 0 {
    if a[k].length() == 1 && array_eq_ints(a[k][0], identity) {
      k = k - 1
    } else {
      break
    }
  }
  if k < 0 {
    []
  } else {
    let out : Array[Array[Array[Int]]] = Array::new()
    for i in 0..=k {
      out.push(a[i])
    }
    out
  }
}

///|
fn double_coset_bruteforce(
  dummies : Array[Array[Int]],
  sym : Array[Int?],
  sgens : Array[Permutation],
  g_perm : Permutation,
) -> Array[Int]? raise CombinatoricsError {
  let size = g_perm.size()
  let g_af = g_perm.array_form()
  let dgens : Array[Array[Int]] = Array::new()
  for i in 0..<sym.length() {
    let gens = dummy_sgs(dummies[i], sym[i], size - 2)
    for g1 in gens {
      dgens.push(g1)
    }
  }
  let dperms : Array[Permutation] = Array::new()
  for h in dgens {
    dperms.push(Permutation::from_array(h))
  }
  if dperms.is_empty() {
    dperms.push(Permutation::identity(size))
  }
  let s_group = PermutationGroup::new(sgens)
  let d_group = PermutationGroup::new(dperms)
  let dlist = d_group.generate_dimino_af()
  let uniq : Map[String, Array[Int]] = {}
  let s_elems = s_group.generate_dimino_af()
  for s in s_elems {
    let h = af_rmul(g_af, s)
    for d in dlist {
      let q = af_rmul(d, h)
      uniq[array_key(q)] = q
    }
  }
  let arrs : Array[Array[Int]] = Array::new()
  for _, v in uniq {
    arrs.push(v)
  }
  let sorted = sort_int_arrays_lex(arrs)
  let mut prev = Array::make(size, 0)
  for h in sorted {
    if prefix_equal(h, prev, size - 2) {
      if h[size - 1] != prev[size - 1] {
        return None
      }
    }
    prev = h
  }
  if sorted.is_empty() {
    None
  } else {
    Some(sorted[0])
  }
}

///|
pub fn double_coset_can_rep(
  dummies : Array[Array[Int]],
  sym : Array[Int?],
  b_S_in : Array[Int],
  sgens : Array[Permutation],
  s_transversals_in : Array[Map[Int, Array[Int]]],
  g_perm : Permutation,
) -> Array[Int]? raise CombinatoricsError {
  let size = g_perm.size()
  let g = g_perm.array_form()
  let num_dummies = size - 2
  let indices = range_array(0, num_dummies)
  let mut all_metrics_with_sym = true
  for s in sym {
    if s is None {
      all_metrics_with_sym = false
      break
    }
  }
  let num_types = sym.length()
  let mut dumx = copy_int_arrays(dummies)
  let mut b_S = copy_int_array(b_S_in)
  let sgensx : Array[Array[Int]] = Array::new()
  for h in sgens {
    sgensx.push(h.array_form())
  }
  let s_cosets = if !b_S.is_empty() {
    transversal2coset(size, b_S, s_transversals_in)
  } else {
    []
  }
  let mut dsgsx : Array[Array[Int]] = Array::new()
  for i in 0..<num_types {
    let gens = dummy_sgs(dumx[i], sym[i], num_dummies)
    for gen in gens {
      dsgsx.push(gen)
    }
  }
  let idn = range_array(0, size)
  let tab : Array[TabEntry] = Array::new()
  tab.push(TabEntry::{ s: copy_int_array(idn), d: copy_int_array(idn), h: g })
  for i in 0..<(size - 2) {
    if tab.is_empty() {
      return double_coset_bruteforce(dummies, sym, sgens, g_perm)
    }
    let b = i
    let testb = array_contains_int(b_S, b) && !sgensx.is_empty()
    let deltab = if testb {
      let sgensx1 : Array[Permutation] = Array::new()
      for h in sgensx {
        sgensx1.push(Permutation::from_array(h))
      }
      orbit_points(size, sgensx1, b)
    } else {
      [b]
    }
    let md = if all_metrics_with_sym {
      _min_dummies(dumx, sym, indices)
    } else {
      let md_local : Array[Int] = Array::new()
      let dsgsx1 : Array[Permutation] = Array::new()
      for h in dsgsx {
        dsgsx1.push(Permutation::from_array(h))
      }
      for ii in 0..<num_dummies {
        let orb = orbit_points(size, dsgsx1, ii)
        md_local.push(min_int_array(orb))
      }
      md_local
    }
    let mut p_i = size
    for entry in tab {
      let mut min_val = size
      for x in deltab {
        let val = md[entry.h[x]]
        if val < min_val {
          min_val = val
        }
      }
      if min_val < p_i {
        p_i = min_val
      }
    }
    if p_i == size {
      return double_coset_bruteforce(dummies, sym, sgens, g_perm)
    }
    let mut dxtrav : Array[Array[Int]]? = None
    if !dsgsx.is_empty() {
      let dsgsx1 : Array[Permutation] = Array::new()
      for h in dsgsx {
        dsgsx1.push(Permutation::from_array(h))
      }
      let (pairs, _) = orbit_transversal_af(size, dsgsx1, p_i)
      let trav : Array[Array[Int]] = Array::new()
      for pair in pairs {
        trav.push(pair.1)
      }
      let invs : Array[Array[Int]] = Array::new()
      for t in trav {
        invs.push(af_invert(t))
      }
      dxtrav = Some(invs)
    }
    let mut deltap : Array[Int] = Array::new()
    let mut found = false
    for ii in 0..<num_types {
      if array_contains_int(dumx[ii], p_i) {
        found = true
        match sym[ii] {
          Some(_) => {
            deltap = copy_int_array(dumx[ii])
          }
          None => {
            let idx_opt = index_of_int(dumx[ii], p_i)
            let idx_val = match idx_opt {
              Some(v) => v
              None => 0
            }
            let start = if idx_val % 2 == 0 { 0 } else { 1 }
            for j in start..<dumx[ii].length() {
              if (j - start) % 2 == 0 {
                deltap.push(dumx[ii][j])
              }
            }
          }
        }
        break
      }
    }
    if !found {
      deltap = [p_i]
    }
    let tab1 : Array[TabEntry] = Array::new()
    while !tab.is_empty() {
      let entry = tab.remove(tab.length() - 1)
      let mut min_val = size
      for x in deltap {
        let val = md[entry.h[x]]
        if val < min_val {
          min_val = val
        }
      }
      if min_val != p_i {
        continue
      }
      let deltab1 : Array[Int] = Array::new()
      for x in deltap {
        if md[entry.h[x]] == p_i {
          deltab1.push(x)
        }
      }
      let dg = af_rmul(entry.d, g)
      let dginv = af_invert(dg)
      let sdeltab : Array[Int] = Array::new()
      for x in deltab1 {
        sdeltab.push(entry.s[x])
      }
      let gdeltap : Array[Int] = Array::new()
      for x in deltap {
        gdeltap.push(dginv[x])
      }
      let next_vals : Array[Int] = Array::new()
      for x in sdeltab {
        if array_contains_int(gdeltap, x) {
          next_vals.push(x)
        }
      }
      for j in next_vals {
        let s1 = if testb {
          trace_S(entry.s, j, b, s_cosets)
        } else {
          Some(entry.s)
        }
        let s1 = match s1 {
          Some(v) => v
          None => continue
        }
        let s1 = if testb {
          let out : Array[Int] = Array::new()
          for ix in s1 {
            out.push(entry.s[ix])
          }
          out
        } else {
          entry.s
        }
        let d1 = if dxtrav is Some(trav) {
          trace_D(dg[j], p_i, trav)
        } else {
          if p_i != dg[j] {
            None
          } else {
            Some(copy_int_array(idn))
          }
        }
        let d1 = match d1 {
          Some(v) => v
          None => continue
        }
        let d1 = if dxtrav is Some(_) {
          let out : Array[Int] = Array::new()
          for ix in entry.d {
            out.push(d1[ix])
          }
          out
        } else {
          entry.d
        }
        let h1 : Array[Int] = Array::new()
        for ix in s1 {
          h1.push(d1[g[ix]])
        }
        tab1.push(TabEntry::{ s: s1, d: d1, h: h1 })
      }
    }
    let sorted = sort_tab_by_h(tab1)
    let mut prev : Array[Int] = Array::make(size, 0)
    for entry in sorted {
      if prefix_equal(entry.h, prev, size - 2) {
        if entry.h[size - 1] != prev[size - 1] {
          return None
        }
      } else {
        tab.push(entry)
      }
      prev = entry.h
    }
    let filtered_sgensx : Array[Array[Int]] = Array::new()
    for h in sgensx {
      if h[b] == b {
        filtered_sgensx.push(h)
      }
    }
    sgensx.clear()
    for h in filtered_sgensx {
      sgensx.push(h)
    }
    if array_contains_int(b_S, b) {
      b_S = remove_int_once(b_S, b)
    }
    let (new_dumx, _) = dumx_remove(dumx, p_i)
    dumx = new_dumx
    dsgsx = Array::new()
    for ii in 0..<num_types {
      let gens = dummy_sgs(dumx[ii], sym[ii], num_dummies)
      for gen in gens {
        dsgsx.push(gen)
      }
    }
  }
  if tab.is_empty() {
    None
  } else {
    Some(tab[0].h)
  }
}

///|
pub fn canonical_free(
  base_in : Array[Int],
  gens : Array[Permutation],
  g_perm : Permutation,
  num_free : Int,
) -> Array[Int] raise CombinatoricsError {
  let g = g_perm.array_form()
  let size = g.length()
  if base_in.is_empty() {
    return copy_int_array(g)
  }
  let transversals = get_transversals(base_in, gens)
  let mut h = copy_int_array(g)
  for transv in transversals {
    let mut h_i : Array[Int] = Array::new()
    for _ in 0..<num_free {
      h_i.push(size)
    }
    let mut best : Array[Int]? = None
    for _, sk in transv {
      let h1 = af_rmul(h, sk)
      let hi : Array[Int] = Array::new()
      for ix in 0..<num_free {
        let pos = index_of_int(h1, ix)
        match pos {
          Some(p) => hi.push(p)
          None => hi.push(size)
        }
      }
      if lex_cmp_int_arrays(hi, h_i) < 0 {
        h_i = hi
        best = Some(sk)
      }
    }
    match best {
      Some(s) => {
        h = af_rmul(h, s)
      }
      None => ()
    }
  }
  h
}

///|
fn _get_map_slots(size : Int, fixed_slots : Array[Int]) -> Array[Int] {
  let res = range_array(0, size)
  let mut pos = 0
  for i in 0..<size {
    if array_contains_int(fixed_slots, i) {
      continue
    }
    res[i] = pos
    pos = pos + 1
  }
  res
}

///|
fn _lift_sgens(
  size : Int,
  fixed_slots : Array[Int],
  free : Array[Int],
  s : Array[Int],
) -> Array[Int] {
  let pairs : Array[(Int, Int)] = Array::new()
  for i in 0..<fixed_slots.length() {
    pairs.push((fixed_slots[i], free[i]))
  }
  let n = pairs.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if pairs[j].0 < pairs[i].0 {
        let tmp = pairs[i]
        pairs[i] = pairs[j]
        pairs[j] = tmp
      }
    }
  }
  let fd : Array[Int] = Array::new()
  for p in pairs {
    fd.push(p.1)
  }
  let num_free = free.length()
  let a : Array[Int] = Array::new()
  let mut j = 0
  let mut k = 0
  for i in 0..<size {
    if array_contains_int(fixed_slots, i) {
      a.push(fd[k])
      k = k + 1
    } else {
      a.push(s[j] + num_free)
      j = j + 1
    }
  }
  a
}

///|
fn sym_valid(sym : Int?) -> Bool {
  match sym {
    None => true
    Some(v) => v == 0 || v == 1
  }
}

///|
pub fn canonicalize(
  g : Permutation,
  dummies : Array[Array[Int]],
  msym : Array[Int?],
  components : Array[TensorComponent],
) -> Array[Int]? raise CombinatoricsError {
  if msym.length() != dummies.length() {
    raise CombinatoricsError::ValueError("dummies and msym must have the same number of elements")
  }
  for s in msym {
    if !sym_valid(s) {
      raise CombinatoricsError::ValueError("msym entries must be 0, 1 or None")
    }
  }
  let size = g.size()
  let v1 : Array[TensorComponentFree] = Array::new()
  for comp in components {
    let mut base_i = comp.base
    let mut gens_i = comp.gens
    if !_is_minimal_bsgs(base_i, gens_i) {
      match get_minimal_bsgs(base_i, gens_i) {
        Some((b, gs)) => {
          base_i = b
          gens_i = gs
        }
        None => {
          return canonicalize_naive(g, dummies, msym, components)
        }
      }
    }
    let free_list : Array[Array[Int]] = Array::new()
    for _ in 0..<comp.count {
      free_list.push([])
    }
    v1.push(TensorComponentFree::{ base: base_i, gens: gens_i, free: free_list, sym: comp.sym })
  }
  let flat_dummies : Array[Int] = Array::new()
  for dumx in dummies {
    for v in dumx {
      flat_dummies.push(v)
    }
  }
  if !flat_dummies.is_empty() {
    let start = flat_dummies[0]
    let end = flat_dummies[flat_dummies.length() - 1]
    let expected = range_array(start, end + 1)
    if !array_eq_ints(flat_dummies, expected) {
      raise CombinatoricsError::ValueError("dummies is not valid")
    }
  }
  let (size1, sbase, sgens) = gens_products(v1)
  if size != size1 {
    raise CombinatoricsError::ValueError("g has size mismatch with generators")
  }
  let free : Array[Int] = Array::new()
  for i in 0..<(size - 2) {
    if !array_contains_int(flat_dummies, i) {
      free.push(i)
    }
  }
  let num_free = free.length()
  let g1 = canonical_free(sbase, sgens, g, num_free)
  if flat_dummies.is_empty() {
    return Some(g1)
  }
  let sign = if g1[g1.length() - 1] == size - 1 { 0 } else { 1 }
  let v2 : Array[TensorComponentFree] = Array::new()
  let mut start = 0
  for comp in v1 {
    let len_tens = comp.gens[0].size() - 2
    let free_i : Array[Array[Int]] = Array::new()
    for _ in 0..<comp.free.length() {
      let h = slice_int_array(g1, start, start + len_tens)
      let fr : Array[Int] = Array::new()
      for k in free {
        if array_contains_int(h, k) {
          match index_of_int(h, k) {
            Some(idx) => fr.push(idx)
            None => ()
          }
        }
      }
      free_i.push(fr)
      start = start + len_tens
    }
    v2.push(TensorComponentFree::{ base: comp.base, gens: comp.gens, free: free_i, sym: comp.sym })
  }
  let (size2, sbase2, sgens2) = gens_products(v2)
  let pos_free : Array[Int] = Array::new()
  for i in 0..<num_free {
    match index_of_int(g1, i) {
      Some(idx) => pos_free.push(idx)
      None => pos_free.push(0)
    }
  }
  let size_red = size2 - num_free
  let g1_red : Array[Int] = Array::new()
  for x in g1 {
    if array_contains_int(flat_dummies, x) {
      g1_red.push(x - num_free)
    }
  }
  if sign == 1 {
    g1_red.push(size_red - 1)
    g1_red.push(size_red - 2)
  } else {
    g1_red.push(size_red - 2)
    g1_red.push(size_red - 1)
  }
  let map_slots = _get_map_slots(size2, pos_free)
  let sbase_red : Array[Int] = Array::new()
  for i in sbase2 {
    if !array_contains_int(pos_free, i) {
      sbase_red.push(map_slots[i])
    }
  }
  let sgens_red : Array[Permutation] = Array::new()
  for y in sgens2 {
    let arr : Array[Int] = Array::new()
    for i in y.array_form() {
      if !array_contains_int(pos_free, i) {
        arr.push(map_slots[i])
      }
    }
    sgens_red.push(Permutation::from_array(arr))
  }
  let dummies_red : Array[Array[Int]] = Array::new()
  for y in dummies {
    let arr : Array[Int] = Array::new()
    for x in y {
      arr.push(x - num_free)
    }
    dummies_red.push(arr)
  }
  let transv_red = get_transversals(sbase_red, sgens_red)
  let g1_red_perm = Permutation::from_array(g1_red)
  let g2 = double_coset_can_rep(
    dummies_red,
    msym,
    sbase_red,
    sgens_red,
    transv_red,
    g1_red_perm,
  )
  match g2 {
    None => None
    Some(v) => Some(_lift_sgens(size2, pos_free, free, v))
  }
}

///|
pub fn canonicalize_single(
  g : Permutation,
  dummies : Array[Int],
  msym : Int?,
  components : Array[TensorComponent],
) -> Array[Int]? raise CombinatoricsError {
  canonicalize(g, [dummies], [msym], components)
}

///|
pub fn perm_af_direct_product(
  gens1_in : Array[Array[Int]],
  gens2_in : Array[Array[Int]],
  signed? : Bool = true,
) -> Array[Array[Int]] {
  let gens1 = copy_int_arrays(gens1_in)
  let gens2 = copy_int_arrays(gens2_in)
  let s = if signed { 2 } else { 0 }
  let n1 = gens1[0].length() - s
  let n2 = gens2[0].length() - s
  let start = range_array(0, n1)
  let end = range_array(n1, n1 + n2)
  let res : Array[Array[Int]] = Array::new()
  if signed {
    for gen in gens1 {
      let head = slice_int_array(gen, 0, n1)
      let tail = concat_int_arrays(end, [gen[gen.length() - 2] + n2, gen[gen.length() - 1] + n2])
      res.push(concat_int_arrays(head, tail))
    }
    for gen in gens2 {
      let shifted : Array[Int] = Array::new()
      for x in gen {
        shifted.push(x + n1)
      }
      res.push(concat_int_arrays(start, shifted))
    }
  } else {
    for gen in gens1 {
      res.push(concat_int_arrays(gen, end))
    }
    for gen in gens2 {
      let shifted : Array[Int] = Array::new()
      for x in gen {
        shifted.push(x + n1)
      }
      res.push(concat_int_arrays(start, shifted))
    }
  }
  res
}

///|
pub fn bsgs_direct_product(
  base1 : Array[Int],
  gens1 : Array[Permutation],
  base2 : Array[Int],
  gens2 : Array[Permutation],
  signed? : Bool = true,
) -> (Array[Int], Array[Permutation]) raise CombinatoricsError {
  let s = if signed { 2 } else { 0 }
  let n1 = gens1[0].size() - s
  let base = copy_int_array(base1)
  for x in base2 {
    base.push(x + n1)
  }
  let gens1_af : Array[Array[Int]] = Array::new()
  let gens2_af : Array[Array[Int]] = Array::new()
  for h in gens1 {
    gens1_af.push(h.array_form())
  }
  for h in gens2 {
    gens2_af.push(h.array_form())
  }
  let gens_af = perm_af_direct_product(gens1_af, gens2_af, signed=signed)
  let size = gens_af[0].length()
  let id_af = range_array(0, size)
  let gens : Array[Permutation] = Array::new()
  for h in gens_af {
    if !array_eq_ints(h, id_af) {
      gens.push(Permutation::from_array(h))
    }
  }
  if gens.is_empty() {
    gens.push(Permutation::from_array(id_af))
  }
  (base, gens)
}

///|
pub fn get_symmetric_group_sgs(
  n : Int,
  antisym? : Bool = false,
) -> (Array[Int], Array[Permutation]) raise CombinatoricsError {
  if n == 1 {
    return ([], [Permutation::from_array(range_array(0, 3))])
  }
  let gens : Array[Array[Int]] = Array::new()
  for i in 0..<(n - 1) {
    let arr = range_array(0, n)
    let tmp = arr[i]
    arr[i] = arr[i + 1]
    arr[i + 1] = tmp
    gens.push(arr)
  }
  let signed_gens : Array[Array[Int]] = Array::new()
  if antisym {
    for x in gens {
      signed_gens.push(concat_int_arrays(x, [n + 1, n]))
    }
  } else {
    for x in gens {
      signed_gens.push(concat_int_arrays(x, [n, n + 1]))
    }
  }
  let base = range_array(0, n - 1)
  let out_gens : Array[Permutation] = Array::new()
  for h in signed_gens {
    out_gens.push(Permutation::from_array(h))
  }
  (base, out_gens)
}

///|
pub let riemann_bsgs : (Array[Int], Array[Permutation]) = {
  let base : Array[Int] = [0, 2]
  let g1 = try! Permutation::from_cycles([[0, 1], [4, 5]], size=6)
  let g2 = try! Permutation::from_cycles([[2, 3], [4, 5]], size=6)
  let g3 = try! Permutation::from_cycles([[0, 2], [1, 3], [5]], size=6)
  (base, [g1, g2, g3])
}

///|
pub fn get_transversals(
  base : Array[Int],
  gens : Array[Permutation],
) -> Array[Map[Int, Array[Int]]] raise CombinatoricsError {
  if base.is_empty() {
    return []
  }
  let stabs = _distribute_gens_by_base(base, gens)
  let result = _orbits_transversals_from_bsgs(base, stabs)
  let transversals : Array[Map[Int, Array[Int]]] = Array::new()
  for trans in result.transversals {
    let out : Map[Int, Array[Int]] = {}
    for k, v in trans {
      out[k] = v.array_form()
    }
    transversals.push(out)
  }
  transversals
}

///|
pub fn _is_minimal_bsgs(base : Array[Int], gens : Array[Permutation]) -> Bool {
  let base1 : Array[Int] = Array::new()
  let mut sgs1 : Array[Permutation] = Array::new()
  for g in gens {
    sgs1.push(g)
  }
  let size = gens[0].size()
  for i in 0..<size {
    let mut all_fix = true
    for h in sgs1 {
      if h.array_form()[i] != i {
        all_fix = false
        break
      }
    }
    if !all_fix {
      base1.push(i)
      let filtered : Array[Permutation] = Array::new()
      for h in sgs1 {
        if h.array_form()[i] == i {
          filtered.push(h)
        }
      }
      sgs1 = filtered
    }
  }
  array_eq_ints(base1, base)
}

///|
pub fn get_minimal_bsgs(
  base : Array[Int],
  gens : Array[Permutation],
) -> (Array[Int], Array[Permutation])? raise CombinatoricsError {
  ignore(base)
  let group = PermutationGroup::new(gens)
  let (b, sgs) = group.schreier_sims_incremental()
  if !_is_minimal_bsgs(b, sgs) {
    return None
  }
  Some((b, sgs))
}

///|
pub fn tensor_gens(
  base : Array[Int],
  gens : Array[Permutation],
  list_free_indices : Array[Array[Int]],
  sym? : Int? = Some(0),
) -> (Int, Array[Int], Array[Permutation]) raise CombinatoricsError {
  fn get_bsgs_with_stabilizer(
    group : PermutationGroup?,
    base0 : Array[Int],
    gens0 : Array[Permutation],
    free_indices : Array[Int],
  ) -> (Array[Int], Array[Permutation]) raise CombinatoricsError {
    if free_indices.is_empty() {
      return (copy_int_array(base0), gens0)
    }
    match group {
      Some(g0) => {
        let h = g0.pointwise_stabilizer(free_indices)
        h.schreier_sims_incremental()
      }
      None => (copy_int_array(base0), gens0)
    }
  }
  let mut empty_count = 0
  for fr in list_free_indices {
    if fr.is_empty() {
      empty_count = empty_count + 1
    }
  }
  if base.is_empty() && empty_count < 2 {
    let n = list_free_indices.length()
    let size0 = gens[0].size()
    let size = n * (size0 - 2) + 2
    return (size, [], [Permutation::from_array(range_array(0, size))])
  }
  let group = if list_free_indices.any(fr => !fr.is_empty()) {
    Some(PermutationGroup::new(gens))
  } else {
    None
  }
  let no_free : Array[Array[Int]] = Array::new()
  let mut size = gens[0].size()
  let id_af = range_array(0, size)
  let num_indices = size - 2
  if list_free_indices.length() > 0 && list_free_indices[0].is_empty() {
    no_free.push(range_array(0, num_indices))
  }
  let res0 = get_bsgs_with_stabilizer(group, base, gens, list_free_indices[0])
  let mut res_base = res0.0
  let mut res_gens = res0.1
  for i in 1..<list_free_indices.length() {
    let (base1, gens1) = get_bsgs_with_stabilizer(group, base, gens, list_free_indices[i])
    let (new_base, new_gens) = bsgs_direct_product(res_base, res_gens, base1, gens1, signed=true)
    res_base = new_base
    res_gens = new_gens
    if list_free_indices[i].is_empty() {
      no_free.push(range_array(size - 2, size - 2 + num_indices))
    }
    size = size + num_indices
  }
  let nr = size - 2
  let filtered : Array[Permutation] = Array::new()
  for h in res_gens {
    if !array_eq_ints(h.array_form(), id_af) {
      filtered.push(h)
    }
  }
  res_gens = filtered
  if sym is None || no_free.is_empty() {
    if res_gens.is_empty() {
      res_gens = [Permutation::from_array(id_af)]
    }
    return (size, res_base, res_gens)
  }
  let base_comm : Array[Int] = Array::new()
  for i in 0..<(no_free.length() - 1) {
    let ind1 = no_free[i]
    let ind2 = no_free[i + 1]
    let a = range_array(0, ind1[0])
    for v in ind2 {
      a.push(v)
    }
    for v in ind1 {
      a.push(v)
    }
    base_comm.push(ind1[0])
    for v in range_array(ind2[ind2.length() - 1] + 1, nr) {
      a.push(v)
    }
    match sym {
      Some(0) => {
        a.push(nr)
        a.push(nr + 1)
      }
      Some(_) => {
        a.push(nr + 1)
        a.push(nr)
      }
      None => ()
    }
    res_gens.push(Permutation::from_array(a))
  }
  for i in base_comm {
    if !array_contains_int(res_base, i) {
      res_base.push(i)
    }
  }
  res_base = sort_int_array(res_base)
  if res_gens.is_empty() {
    res_gens = [Permutation::from_array(id_af)]
  }
  (size, res_base, res_gens)
}

///|
pub fn gens_products(
  components : Array[TensorComponentFree],
) -> (Int, Array[Int], Array[Permutation]) raise CombinatoricsError {
  let res0 =
    tensor_gens(components[0].base, components[0].gens, components[0].free, sym=components[0].sym)
  let mut res_base = res0.1
  let mut res_gens = res0.2
  for i in 1..<components.length() {
    let (size, base, gens) =
      tensor_gens(components[i].base, components[i].gens, components[i].free, sym=components[i].sym)
    let (new_base, new_gens) = bsgs_direct_product(res_base, res_gens, base, gens, signed=true)
    res_base = new_base
    res_gens = new_gens
    ignore(size)
  }
  let res_size = res_gens[0].size()
  let id_af = range_array(0, res_size)
  let filtered : Array[Permutation] = Array::new()
  for h in res_gens {
    if !array_eq_ints(h.array_form(), id_af) {
      filtered.push(h)
    }
  }
  res_gens = filtered
  if res_gens.is_empty() {
    res_gens = [Permutation::from_array(id_af)]
  }
  (res_size, res_base, res_gens)
}

///|
pub fn canonicalize_naive(
  g : Permutation,
  dummies : Array[Array[Int]],
  msym : Array[Int?],
  components : Array[TensorComponent],
) -> Array[Int]? raise CombinatoricsError {
  let v1 : Array[TensorComponentFree] = Array::new()
  for comp in components {
    let free_list : Array[Array[Int]] = Array::new()
    for _ in 0..<comp.count {
      free_list.push([])
    }
    v1.push(TensorComponentFree::{ base: comp.base, gens: comp.gens, free: free_list, sym: comp.sym })
  }
  let (size, _, sgens) = gens_products(v1)
  let dgens : Array[Array[Int]] = Array::new()
  for i in 0..<msym.length() {
    let gens = dummy_sgs(dummies[i], msym[i], size - 2)
    for g1 in gens {
      dgens.push(g1)
    }
  }
  let dperms : Array[Permutation] = Array::new()
  for h in dgens {
    dperms.push(Permutation::from_array(h))
  }
  if dperms.is_empty() {
    dperms.push(Permutation::identity(size))
  }
  let s_group = PermutationGroup::new(sgens)
  let d_group = PermutationGroup::new(dperms)
  let dlist = d_group.generate_dimino_af()
  let g_af = g.array_form()
  let uniq : Map[String, Array[Int]] = {}
  let s_elems = s_group.generate_dimino_af()
  for s in s_elems {
    let h = af_rmul(g_af, s)
    for d in dlist {
      let q = af_rmul(d, h)
      uniq[array_key(q)] = q
    }
  }
  let arrs : Array[Array[Int]] = Array::new()
  for _, v in uniq {
    arrs.push(v)
  }
  let sorted = sort_int_arrays_lex(arrs)
  let mut prev = Array::make(size, 0)
  for h in sorted {
    if prefix_equal(h, prev, size - 2) {
      if h[size - 1] != prev[size - 1] {
        return None
      }
    }
    prev = h
  }
  if sorted.is_empty() {
    None
  } else {
    Some(sorted[0])
  }
}
