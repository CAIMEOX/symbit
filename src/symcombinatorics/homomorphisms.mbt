///|
/// Group homomorphisms (PermutationGroup, FpGroup, FreeGroup).

///|
pub(all) enum HomGroup {
  PermGroup(PermutationGroup)
  FpGroup(FpGroup)
  FreeGroup(FreeGroup)
}

///|
pub(all) enum HomElement {
  Perm(Permutation)
  Word(FreeGroupElement)
} derive(Eq)

///|
pub impl Hash for HomElement with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for HomElement with hash_combine(self, hasher : Hasher) -> Unit {
  match self {
    HomElement::Perm(p) => {
      hasher.combine_int(0)
      p.hash_combine(hasher)
    }
    Word(w) => {
      hasher.combine_int(1)
      w.hash_combine(hasher)
    }
  }
}

///|
pub(all) enum HomSubgroup {
  PermSub(PermutationGroup)
  FpSub(FpSubgroup)
}

///|
fn elem_is_identity(e : HomElement) -> Bool {
  match e {
    HomElement::Perm(p) => p.is_identity()
    Word(w) => w.is_identity()
  }
}

///|
fn elem_inverse(e : HomElement) -> HomElement raise CombinatoricsError {
  match e {
    HomElement::Perm(p) => HomElement::Perm(p.invert())
    Word(w) => Word(w.inverse())
  }
}

///|
fn elem_pow(e : HomElement, n : Int) -> HomElement raise CombinatoricsError {
  match e {
    HomElement::Perm(p) => HomElement::Perm(p.pow(n))
    Word(w) => Word(w.pow(n))
  }
}

///|
fn elem_mul(a : HomElement, b : HomElement) -> HomElement raise CombinatoricsError {
  match (a, b) {
    (HomElement::Perm(p1), HomElement::Perm(p2)) => HomElement::Perm(p1.mul(p2))
    (Word(w1), Word(w2)) => Word(w1.mul(w2))
    _ => raise CombinatoricsError::ValueError("element type mismatch")
  }
}

///|
fn hom_group_identity(group : HomGroup) -> HomElement {
  match group {
    HomGroup::PermGroup(g) => HomElement::Perm(g.identity())
    HomGroup::FpGroup(g) => Word(g.identity())
    HomGroup::FreeGroup(g) => Word(g.identity())
  }
}

///|
fn hom_group_generators(group : HomGroup) -> Array[HomElement] {
  let out : Array[HomElement] = Array::new()
  match group {
    HomGroup::PermGroup(g) => {
      for gen in g.generators() {
        out.push(HomElement::Perm(gen))
      }
    }
    HomGroup::FpGroup(g) => {
      for gen in g.generators {
        out.push(Word(gen))
      }
    }
    HomGroup::FreeGroup(g) => {
      for gen in g.generators() {
        out.push(Word(gen))
      }
    }
  }
  out
}

///|
fn hom_group_contains(group : HomGroup, elem : HomElement) -> Bool raise CombinatoricsError {
  match (group, elem) {
    (HomGroup::PermGroup(g), HomElement::Perm(p)) => g.contains(p, strict=true)
    (HomGroup::FpGroup(g), Word(w)) => g.contains(w)
    (HomGroup::FreeGroup(g), Word(w)) => g.contains(w)
    _ => false
  }
}

///|
fn hom_group_order(group : HomGroup) -> GroupOrder raise CombinatoricsError {
  match group {
    HomGroup::PermGroup(g) => GroupOrder::Finite(g.order())
    HomGroup::FpGroup(g) => g.order()
    HomGroup::FreeGroup(g) => g.order()
  }
}

///|
fn hom_group_is_abelian(group : HomGroup) -> Bool raise CombinatoricsError {
  match group {
    HomGroup::PermGroup(g) => g.is_abelian()
    HomGroup::FreeGroup(g) => g.is_abelian()
    HomGroup::FpGroup(g) => {
      match g.order() {
        GroupOrder::Finite(_) => {
          let (pg, _) = fp_group_to_perm_group(g)
          pg.is_abelian()
        }
        GroupOrder::Infinite => {
          match fp_group_is_abelian_status(g) {
            Some(v) => v
            None => true
          }
        }
      }
    }
  }
}

///|
fn hom_subgroup_order(sub : HomSubgroup) -> GroupOrder raise CombinatoricsError {
  match sub {
    HomSubgroup::PermSub(g) => GroupOrder::Finite(g.order())
    HomSubgroup::FpSub(s) => s.order()
  }
}

///|
fn subgroup_is_subgroup_of(sub : HomSubgroup, group : HomGroup) -> Bool raise CombinatoricsError {
  match (sub, group) {
    (HomSubgroup::PermSub(sg), HomGroup::PermGroup(g)) => sg.is_subgroup(g)
    (HomSubgroup::FpSub(sg), HomGroup::FpGroup(g)) => {
      for gen in sg.generators {
        if !g.contains(gen) {
          return false
        }
      }
      true
    }
    (HomSubgroup::FpSub(sg), HomGroup::FreeGroup(g)) => {
      for gen in sg.generators {
        if !g.contains(gen) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn normalize_elem_for_group(group : HomGroup, elem : HomElement) -> HomElement raise CombinatoricsError {
  match (group, elem) {
    (HomGroup::FpGroup(g), Word(w)) => Word(g.reduce(w))
    (HomGroup::PermGroup(_), HomElement::Perm(_)) => elem
    (HomGroup::FreeGroup(_), Word(_)) => elem
    _ => raise CombinatoricsError::ValueError("element type mismatch")
  }
}

///|
fn hom_elem_equal(group : HomGroup, a : HomElement, b : HomElement) -> Bool raise CombinatoricsError {
  match group {
    HomGroup::PermGroup(_) | HomGroup::FreeGroup(_) => a == b
    HomGroup::FpGroup(g) => match (a, b) {
      (Word(w1), Word(w2)) => {
        let res = g.equals(w1, w2)
        match res {
          Some(v) => v
          None => {
            g.make_confluent()
            let res2 = g.equals(w1, w2)
            match res2 {
              Some(v2) => v2
              None => raise CombinatoricsError::ValueError("cannot determine equality in FpGroup")
            }
          }
        }
      }
      _ => raise CombinatoricsError::ValueError("element type mismatch")
    }
  }
}

///|
fn fp_group_elements(fp : FpGroup) -> Array[FreeGroupElement] raise CombinatoricsError {
  match fp.order() {
    GroupOrder::Infinite =>
      raise CombinatoricsError::ValueError("cannot enumerate elements of infinite group")
    GroupOrder::Finite(_) => {
      let identity = fp.identity()
      let gens = fp.generators
      let moves : Array[FreeGroupElement] = Array::new()
      for g in gens {
        moves.push(g)
        moves.push(g.inverse())
      }
      let visited : Map[FreeGroupElement, Bool] = {}
      let queue : Array[FreeGroupElement] = Array::new()
      queue.push(identity)
      visited[identity] = true
      let mut head = 0
      while head < queue.length() {
        let cur = queue[head]
        head = head + 1
        for mv in moves {
          let next = fp.reduce(cur.mul(mv))
          if !visited.contains(next) {
            visited[next] = true
            queue.push(next)
          }
        }
      }
      queue
    }
  }
}

///|
fn fp_group_commutator(
  a : FreeGroupElement,
  b : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  a.mul(b).mul(a.inverse()).mul(b.inverse())
}

///|
fn fp_group_is_abelian_status(fp : FpGroup) -> Bool? raise CombinatoricsError {
  let gens = fp.generators
  if gens.length() <= 1 {
    return Some(true)
  }
  if fp.relators.is_empty() {
    return Some(false)
  }
  // fast path: explicit commutator relators
  let rel_set : Map[FreeGroupElement, Bool] = {}
  for r in fp.relators {
    rel_set[r] = true
    rel_set[r.inverse()] = true
  }
  let mut all_comm_rel = true
  for i in 0..<gens.length() {
    for j in (i + 1)..<gens.length() {
      let comm = fp_group_commutator(gens[i], gens[j])
      if !rel_set.contains(comm) {
        all_comm_rel = false
        break
      }
    }
    if !all_comm_rel { break }
  }
  if all_comm_rel {
    return Some(true)
  }
  let identity = fp.identity()
  let mut unknown = false
  for i in 0..<gens.length() {
    for j in (i + 1)..<gens.length() {
      let comm = fp_group_commutator(gens[i], gens[j])
      match fp.equals(comm, identity) {
        Some(true) => ()
        Some(false) => return Some(false)
        None => unknown = true
      }
    }
  }
  if !unknown {
    return Some(true)
  }
  None
}

///|
fn perm_group_from_coset_table(
  fp : FpGroup,
  ct : CosetTable,
) -> (PermutationGroup, GroupHomomorphism) raise CombinatoricsError {
  ct.standardize()
  let table = ct.table
  let gens = fp.generators
  let images : Array[Permutation] = Array::new()
  for g in gens {
    let idx = ct.alphabet_index[g]
    let arr : Array[Int] = Array::new()
    for i in 0..<table.length() {
      let v = table[i][idx].unwrap()
      arr.push(v)
    }
    images.push(Permutation::from_array(arr))
  }
  let pg = PermutationGroup::new(images)
  let hom = homomorphism(
    HomGroup::FpGroup(fp),
    HomGroup::PermGroup(pg),
    gens.map(g => Word(g)),
    images=images.map(p => HomElement::Perm(p)),
    check=false,
  )
  (pg, hom)
}

///|
fn fp_group_best_low_index_quotient(
  fp : FpGroup,
  max_index : Int,
) -> (PermutationGroup, GroupHomomorphism)? raise CombinatoricsError {
  let tables = low_index_subgroups(fp, max_index)
  if tables.is_empty() {
    return None
  }
  let mut best : (PermutationGroup, GroupHomomorphism)? = None
  let mut best_deg = -1
  for ct in tables {
    let deg = ct.table.length()
    if deg <= 1 {
      continue
    }
    let (pg, hom) = perm_group_from_coset_table(fp, ct)
    if deg > best_deg {
      best_deg = deg
      best = Some((pg, hom))
    }
  }
  best
}

///|
fn clamp_moduli(moduli : Array[Int], max_size : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for m in moduli { out.push(m) }
  fn prod_mods(ms : Array[Int]) -> Int {
    let mut prod = 1
    for m in ms {
      if m <= 0 { return 0 }
      if prod > max_size / m { return max_size + 1 }
      prod = prod * m
    }
    prod
  }
  while prod_mods(out) > max_size {
    let mut idx = -1
    let mut maxv = 1
    for i in 0..<out.length() {
      if out[i] > maxv {
        maxv = out[i]
        idx = i
      }
    }
    if idx < 0 { break }
    let v = out[idx]
    if v % 2 == 0 {
      out[idx] = 2
    } else if v % 3 == 0 {
      out[idx] = 3
    } else {
      out[idx] = 1
    }
  }
  out
}

///|
fn perm_from_vector(
  vec : Array[Int],
  moduli_in : Array[Int],
) -> Permutation raise CombinatoricsError {
  let moduli = clamp_moduli(moduli_in, 4096)
  let n = moduli.length()
  let strides : Array[Int] = Array::make(n, 1)
  let mut size = 1
  for i in 0..<n {
    strides[i] = size
    size = size * moduli[i]
  }
  if size <= 1 {
    return Permutation::identity(1)
  }
  let arr : Array[Int] = Array::make(size, 0)
  for idx in 0..<size {
    let coords : Array[Int] = Array::make(n, 0)
    let mut x = idx
    for i in 0..<n {
      let m = moduli[i]
      coords[i] = x % m
      x = x / m
    }
    for i in 0..<n {
      let m = moduli[i]
      if m != 0 {
        let mut delta = vec[i] % m
        if delta < 0 { delta = delta + m }
        coords[i] = (coords[i] + delta) % m
      }
    }
    let mut out = 0
    for i in 0..<n {
      out = out + coords[i] * strides[i]
    }
    arr[idx] = out
  }
  Permutation::from_array(arr)
}

///|
fn fp_group_abelian_quotient_perm_group(
  fp : FpGroup,
  free_mod? : Int = 2,
) -> (PermutationGroup, GroupHomomorphism) raise CombinatoricsError {
  let (moduli, basis) = fp_group_abelian_quotient_moduli(fp, free_mod=free_mod)
  let n = fp.generators.length()
  let images : Array[Permutation] = Array::new()
  for j in 0..<n {
    let col : Array[Int] = Array::new()
    for i in 0..<n {
      col.push(basis[i][j])
    }
    images.push(perm_from_vector(col, moduli))
  }
  let pg = PermutationGroup::new(images)
  let hom = homomorphism(
    HomGroup::FpGroup(fp),
    HomGroup::PermGroup(pg),
    fp.generators.map(g => Word(g)),
    images=images.map(p => HomElement::Perm(p)),
    check=false,
  )
  (pg, hom)
}

///|
fn fp_group_has_nonabelian_quotient(
  fp : FpGroup,
  max_index : Int,
) -> Bool raise CombinatoricsError {
  let tables = low_index_subgroups(fp, max_index)
  for ct in tables {
    let (pg, _) = perm_group_from_coset_table(fp, ct)
    if !pg.is_abelian() {
      return true
    }
  }
  false
}

///|
fn hom_group_elements(group : HomGroup) -> Array[HomElement] raise CombinatoricsError {
  let out : Array[HomElement] = Array::new()
  match group {
    HomGroup::PermGroup(g) => {
      for e in g.elements() {
        out.push(HomElement::Perm(e))
      }
    }
    HomGroup::FreeGroup(g) => match g.order() {
      GroupOrder::Finite(_) => out.push(Word(g.identity()))
      GroupOrder::Infinite =>
        raise CombinatoricsError::ValueError("cannot enumerate elements of infinite group")
    }
    HomGroup::FpGroup(g) => {
      for e in fp_group_elements(g) {
        out.push(Word(e))
      }
    }
  }
  out
}

///|
pub struct GroupHomomorphism {
  domain : HomGroup
  codomain : HomGroup
  domain_gens : Array[HomElement]
  images : Array[HomElement]
  mut inverses : Map[HomElement, HomElement]?
  mut kernel_cache : HomSubgroup?
  mut image_cache : HomSubgroup?
}

///|
fn image_for_generator(hom : GroupHomomorphism, gen : HomElement) -> HomElement raise CombinatoricsError {
  let gens = hom.domain_gens
  for i in 0..<gens.length() {
    if gens[i] == gen {
      return hom.images[i]
    }
  }
  match gen {
    HomElement::Perm(p) => {
      let inv = HomElement::Perm(p.invert())
      for i in 0..<gens.length() {
        if gens[i] == inv {
          return elem_inverse(hom.images[i])
        }
      }
    }
    Word(_) => ()
  }
  raise CombinatoricsError::ValueError("generator not in homomorphism domain")
}

///|
pub fn GroupHomomorphism::apply(self : GroupHomomorphism, elem : HomElement) -> HomElement raise CombinatoricsError {
  if !hom_group_contains(self.domain, elem) {
    raise CombinatoricsError::ValueError("element not in domain")
  }
  if elem_is_identity(elem) {
    return hom_group_identity(self.codomain)
  }
  match self.domain {
    HomGroup::PermGroup(g) => match elem {
      HomElement::Perm(p) => {
        let gens = g.generator_product(p, original=true)
        let mut value = hom_group_identity(self.codomain)
        for gen in gens {
          let img = image_for_generator(self, HomElement::Perm(gen))
          value = elem_mul(img, value)
        }
        normalize_elem_for_group(self.codomain, value)
      }
      _ => raise CombinatoricsError::ValueError("element type mismatch")
    }
    HomGroup::FpGroup(_) | HomGroup::FreeGroup(_) => match elem {
      Word(w) => {
        let mut value = hom_group_identity(self.codomain)
        let arr = w.array_form()
        for pair in arr {
          let idx = pair.0
          let exp = pair.1
          let img = self.images[idx]
          let pow_img = elem_pow(img, exp)
          value = elem_mul(value, pow_img)
        }
        normalize_elem_for_group(self.codomain, value)
      }
      _ => raise CombinatoricsError::ValueError("element type mismatch")
    }
  }
}

///|
pub fn GroupHomomorphism::apply_all(
  self : GroupHomomorphism,
  elems : Array[HomElement],
) -> Array[HomElement] raise CombinatoricsError {
  let out : Array[HomElement] = Array::new()
  for e in elems {
    out.push(self.apply(e))
  }
  out
}

///|
fn build_inverses(hom : GroupHomomorphism) -> Map[HomElement, HomElement] raise CombinatoricsError {
  let invs : Map[HomElement, HomElement] = {}
  let elems = hom_group_elements(hom.domain)
  for e in elems {
    let img = hom.apply(e)
    if !invs.contains(img) {
      invs[img] = e
    }
  }
  invs
}

///|
pub fn GroupHomomorphism::invert(self : GroupHomomorphism, elem : HomElement) -> HomElement raise CombinatoricsError {
  let target = normalize_elem_for_group(self.codomain, elem)
  if self.inverses is None {
    self.inverses = Some(build_inverses(self))
  }
  let invs = self.inverses.unwrap()
  match invs.get(target) {
    Some(v) => v
    None => raise CombinatoricsError::ValueError("element not in image")
  }
}

///|
pub fn GroupHomomorphism::invert_all(
  self : GroupHomomorphism,
  elems : Array[HomElement],
) -> Array[HomElement] raise CombinatoricsError {
  let out : Array[HomElement] = Array::new()
  for e in elems {
    out.push(self.invert(e))
  }
  out
}

///|
pub fn GroupHomomorphism::kernel(self : GroupHomomorphism) -> HomSubgroup raise CombinatoricsError {
  match self.kernel_cache {
    Some(k) => k
    None => {
      let identity = hom_group_identity(self.codomain)
      let elems = hom_group_elements(self.domain)
      match self.domain {
        HomGroup::PermGroup(_) => {
          let gens : Array[Permutation] = Array::new()
          for e in elems {
            match e {
              HomElement::Perm(p) => {
                if hom_elem_equal(self.codomain, self.apply(e), identity) {
                  gens.push(p)
                }
              }
              _ => ()
            }
          }
          let subgroup = PermutationGroup::new(gens)
          let out = HomSubgroup::PermSub(subgroup)
          self.kernel_cache = Some(out)
          out
        }
        HomGroup::FpGroup(g) => {
          let gens : Array[FreeGroupElement] = Array::new()
          for e in elems {
            match e {
              Word(w) => {
                if hom_elem_equal(self.codomain, self.apply(e), identity) {
                  gens.push(w)
                }
              }
              _ => ()
            }
          }
          let sub = FpSubgroup::new(SubgroupParent::Fp(g), gens, normal=true)
          let out = HomSubgroup::FpSub(sub)
          self.kernel_cache = Some(out)
          out
        }
        HomGroup::FreeGroup(g) => {
          let gens : Array[FreeGroupElement] = Array::new()
          for e in elems {
            match e {
              Word(w) => {
                if hom_elem_equal(self.codomain, self.apply(e), identity) {
                  gens.push(w)
                }
              }
              _ => ()
            }
          }
          let sub = FpSubgroup::new(SubgroupParent::Free(g), gens, normal=true)
          let out = HomSubgroup::FpSub(sub)
          self.kernel_cache = Some(out)
          out
        }
      }
    }
  }
}

///|
pub fn GroupHomomorphism::image(self : GroupHomomorphism) -> HomSubgroup raise CombinatoricsError {
  match self.image_cache {
    Some(v) => v
    None => {
      let vals : Array[HomElement] = Array::new()
      for img in self.images {
        if !vals.any(v => v == img) {
          vals.push(img)
        }
      }
      let out = match self.codomain {
        HomGroup::PermGroup(_) => {
          let gens : Array[Permutation] = Array::new()
          for v in vals {
            match v {
              HomElement::Perm(p) => gens.push(p)
              _ => ()
            }
          }
          HomSubgroup::PermSub(PermutationGroup::new(gens))
        }
        HomGroup::FpGroup(g) => {
          let gens : Array[FreeGroupElement] = Array::new()
          for v in vals {
            match v {
              Word(w) => gens.push(w)
              _ => ()
            }
          }
          HomSubgroup::FpSub(FpSubgroup::new(SubgroupParent::Fp(g), gens))
        }
        HomGroup::FreeGroup(g) => {
          let gens : Array[FreeGroupElement] = Array::new()
          for v in vals {
            match v {
              Word(w) => gens.push(w)
              _ => ()
            }
          }
          HomSubgroup::FpSub(FpSubgroup::new(SubgroupParent::Free(g), gens))
        }
      }
      self.image_cache = Some(out)
      out
    }
  }
}

///|
pub fn GroupHomomorphism::is_injective(self : GroupHomomorphism) -> Bool raise CombinatoricsError {
  match hom_subgroup_order(self.kernel()) {
    GroupOrder::Finite(n) => n == 1
    GroupOrder::Infinite => false
  }
}

///|
pub fn GroupHomomorphism::is_surjective(self : GroupHomomorphism) -> Bool? raise CombinatoricsError {
  let im = hom_subgroup_order(self.image())
  let oth = hom_group_order(self.codomain)
  match (im, oth) {
    (GroupOrder::Infinite, GroupOrder::Infinite) => None
    (GroupOrder::Finite(a), GroupOrder::Finite(b)) => Some(a == b)
    (GroupOrder::Finite(_), GroupOrder::Infinite) => Some(false)
    (GroupOrder::Infinite, GroupOrder::Finite(_)) => Some(false)
  }
}

///|
pub fn GroupHomomorphism::is_isomorphism(self : GroupHomomorphism) -> Bool? raise CombinatoricsError {
  let inj = self.is_injective()
  match self.is_surjective() {
    Some(v) => Some(inj && v)
    None => None
  }
}

///|
pub fn GroupHomomorphism::is_trivial(self : GroupHomomorphism) -> Bool raise CombinatoricsError {
  match hom_subgroup_order(self.image()) {
    GroupOrder::Finite(n) => n == 1
    GroupOrder::Infinite => false
  }
}

///|
pub fn GroupHomomorphism::compose(
  self : GroupHomomorphism,
  other : GroupHomomorphism,
) -> GroupHomomorphism raise CombinatoricsError {
  if !subgroup_is_subgroup_of(other.image(), self.domain) {
    raise CombinatoricsError::ValueError("image of other must be subgroup of domain")
  }
  let gens = other.domain_gens
  let images : Array[HomElement] = Array::new()
  for g in gens {
    images.push(self.apply(other.apply(g)))
  }
  homomorphism(other.domain, self.codomain, gens, images=images, check=false)
}

///|
pub fn GroupHomomorphism::restrict_to(
  self : GroupHomomorphism,
  h : PermutationGroup,
) -> GroupHomomorphism raise CombinatoricsError {
  match self.domain {
    HomGroup::PermGroup(g) => {
      if !h.is_subgroup(g) {
        raise CombinatoricsError::ValueError("given subgroup is not in domain")
      }
      let gens = h.generators().map(g0 => HomElement::Perm(g0))
      let images : Array[HomElement] = Array::new()
      for gen in gens {
        images.push(self.apply(gen))
      }
      homomorphism(HomGroup::PermGroup(h), self.codomain, gens, images=images, check=false)
    }
    _ => raise CombinatoricsError::ValueError("restriction only supported for permutation groups")
  }
}

///|
pub fn GroupHomomorphism::invert_subgroup(
  self : GroupHomomorphism,
  h : PermutationGroup,
) -> PermutationGroup raise CombinatoricsError {
  match (self.domain, self.codomain) {
    (HomGroup::PermGroup(dom), HomGroup::PermGroup(_)) => {
      let image = self.image()
      match image {
        HomSubgroup::PermSub(img) => {
          if !h.is_subgroup(img) {
            raise CombinatoricsError::ValueError("given subgroup not in image")
          }
        }
        _ => ()
      }
      let gens : Array[Permutation] = Array::new()
      let mut p = PermutationGroup::new([dom.identity()])
      for gen in h.generators() {
        let pre = self.invert(HomElement::Perm(gen))
        match pre {
          HomElement::Perm(pgen) => {
            if !p.contains(pgen, strict=false) {
              gens.push(pgen)
              p = PermutationGroup::new(gens)
            }
            match self.kernel() {
              HomSubgroup::PermSub(kern) => {
                for k in kern.generators() {
                  let prod = k.mul(pgen)
                  if !p.contains(prod, strict=false) {
                    gens.push(prod)
                    p = PermutationGroup::new(gens)
                  }
                }
              }
              _ => ()
            }
          }
          _ => ()
        }
      }
      p
    }
    _ => raise CombinatoricsError::ValueError("invert_subgroup requires permutation domain/codomain")
  }
}

///|
fn _check_homomorphism(
  domain : HomGroup,
  codomain : HomGroup,
  domain_gens : Array[HomElement],
  images : Array[HomElement],
) -> Bool raise CombinatoricsError {
  let identity = hom_group_identity(codomain)
  match domain {
    HomGroup::PermGroup(g) => {
      let elems = g.elements()
      for a in elems {
        for b in elems {
          let left = hom_apply_perm(codomain, domain_gens, images, a.mul(b))
          let right_a = hom_apply_perm(codomain, domain_gens, images, a)
          let right_b = hom_apply_perm(codomain, domain_gens, images, b)
          let right = elem_mul(right_a, right_b)
          if !hom_elem_equal(codomain, left, right) {
            return false
          }
        }
      }
      true
    }
    HomGroup::FreeGroup(_) => true
    HomGroup::FpGroup(g) => {
      let rels = g.relators
      for r in rels {
        let img = hom_apply_word(codomain, domain_gens, images, r)
        if !hom_elem_equal(codomain, img, identity) {
          return false
        }
      }
      true
    }
  }
}

///|
fn hom_apply_perm(
  codomain : HomGroup,
  domain_gens : Array[HomElement],
  images : Array[HomElement],
  elem : Permutation,
) -> HomElement raise CombinatoricsError {
  let mut value = hom_group_identity(codomain)
  let gens : Array[Permutation] = Array::new()
  for ge in domain_gens {
    match ge {
      HomElement::Perm(p) => gens.push(p)
      _ => ()
    }
  }
  let g = PermutationGroup::new(gens)
  let word = g.generator_product(elem, original=true)
  for gen in word {
    let img = image_for_generator({ domain: HomGroup::PermGroup(g), codomain, domain_gens, images, inverses: None, kernel_cache: None, image_cache: None }, HomElement::Perm(gen))
    value = elem_mul(img, value)
  }
  normalize_elem_for_group(codomain, value)
}

///|
fn hom_apply_word(
  codomain : HomGroup,
  _domain_gens : Array[HomElement],
  images : Array[HomElement],
  word : FreeGroupElement,
) -> HomElement raise CombinatoricsError {
  let mut value = hom_group_identity(codomain)
  let arr = word.array_form()
  for pair in arr {
    let idx = pair.0
    let exp = pair.1
    let img = images[idx]
    let pow_img = elem_pow(img, exp)
    value = elem_mul(value, pow_img)
  }
  normalize_elem_for_group(codomain, value)
}

///|
pub fn homomorphism(
  domain : HomGroup,
  codomain : HomGroup,
  gens : Array[HomElement],
  images? : Array[HomElement] = [],
  check? : Bool = true,
) -> GroupHomomorphism raise CombinatoricsError {
  let domain_gens = hom_group_generators(domain)
  let full_images : Array[HomElement] = Array::new()
  let identity = hom_group_identity(codomain)
  for _ in 0..<domain_gens.length() {
    full_images.push(identity)
  }
  if images.length() > 0 && images.length() != gens.length() {
    raise CombinatoricsError::ValueError("images length mismatch")
  }
  for i in 0..<gens.length() {
    let g = gens[i]
    let img = if images.length() == 0 { identity } else { images[i] }
    if !hom_group_contains(domain, g) {
      raise CombinatoricsError::ValueError("generator not in domain")
    }
    if !hom_group_contains(codomain, img) {
      raise CombinatoricsError::ValueError("image not in codomain")
    }
    let mut found = false
    let mut j = 0
    while j < domain_gens.length() {
      if domain_gens[j] == g {
        full_images[j] = img
        found = true
        break
      }
      j = j + 1
    }
    if !found {
      raise CombinatoricsError::ValueError("generator not in domain generators")
    }
  }
  if check {
    if !_check_homomorphism(domain, codomain, domain_gens, full_images) {
      raise CombinatoricsError::ValueError("images do not define a homomorphism")
    }
  }
  {
    domain,
    codomain,
    domain_gens,
    images: full_images,
    inverses: None,
    kernel_cache: None,
    image_cache: None,
  }
}

///|
fn fp_group_to_perm_group(fp : FpGroup) -> (PermutationGroup, GroupHomomorphism) raise CombinatoricsError {
  match fp.order() {
    GroupOrder::Finite(_) => {
      let ct = fp.coset_enumeration([])
      let (pg, hom) = perm_group_from_coset_table(fp, ct)
      (pg, hom)
    }
    GroupOrder::Infinite => {
      match fp_group_best_low_index_quotient(fp, 8) {
        Some((pg, hom)) => (pg, hom)
        None => fp_group_abelian_quotient_perm_group(fp, free_mod=2)
      }
    }
  }
}

///|
pub fn orbit_homomorphism(
  group : PermutationGroup,
  omega : Array[Int],
) -> GroupHomomorphism raise CombinatoricsError {
  let codomain = symmetric_group(omega.length())
  let gens = group.generators()
  let images : Array[Permutation] = Array::new()
  for g in gens {
    let arr : Array[Int] = Array::new()
    for o in omega {
      let im = g.apply_index(o)
      let mut idx = -1
      for i in 0..<omega.length() {
        if omega[i] == im {
          idx = i
          break
        }
      }
      if idx < 0 {
        raise CombinatoricsError::ValueError("omega not closed under action")
      }
      arr.push(idx)
    }
    images.push(Permutation::from_array(arr))
  }
  let hom = homomorphism(
    HomGroup::PermGroup(group),
    HomGroup::PermGroup(codomain),
    gens.map(g => HomElement::Perm(g)),
    images=images.map(p => HomElement::Perm(p)),
    check=false,
  )
  hom.kernel_cache = Some(HomSubgroup::PermSub(group.pointwise_stabilizer(omega)))
  hom
}

///|
pub fn block_homomorphism(
  group : PermutationGroup,
  blocks : Array[Int],
) -> GroupHomomorphism raise CombinatoricsError {
  let n = blocks.length()
  let mut m = 0
  let reps : Array[Int] = Array::new()
  let block_index : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if blocks[i] == i {
      reps.push(i)
      block_index[i] = m
      m = m + 1
    }
  }
  for i in 0..<n {
    block_index[i] = block_index[blocks[i]]
  }
  let codomain = symmetric_group(m)
  let gens = group.generators()
  let images : Array[Permutation] = Array::new()
  for g in gens {
    let arr : Array[Int] = Array::new()
    for i in 0..<m {
      let img = g.apply_index(reps[i])
      arr.push(block_index[img])
    }
    images.push(Permutation::from_array(arr))
  }
  homomorphism(
    HomGroup::PermGroup(group),
    HomGroup::PermGroup(codomain),
    gens.map(g => HomElement::Perm(g)),
    images=images.map(p => HomElement::Perm(p)),
    check=false,
  )
}

///|
fn gcd_int_local_hom(a0 : Int, b0 : Int) -> Int {
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
fn group_order_int(order : GroupOrder) -> Int? {
  match order {
    GroupOrder::Finite(n) => Some(n)
    GroupOrder::Infinite => None
  }
}

///|
fn group_iso_search(
  idx : Int,
  candidates : Array[Array[Permutation]],
  current : Array[Permutation],
  g_perm_gens : Array[Permutation],
  pg : PermutationGroup,
  ph : PermutationGroup,
  g : HomGroup,
  h : HomGroup,
  h_iso : GroupHomomorphism?,
) -> (Bool, GroupHomomorphism?) raise CombinatoricsError {
  if idx == candidates.length() {
    let gens_wrapped = g_perm_gens.map(p => HomElement::Perm(p))
    let imgs_wrapped = current.map(p => HomElement::Perm(p))
    let perm_hom = homomorphism(
      HomGroup::PermGroup(pg),
      HomGroup::PermGroup(ph),
      gens_wrapped,
      images=imgs_wrapped,
      check=true,
    )
    let iso_ok = match perm_hom.is_isomorphism() {
      Some(v) => v
      None => false
    }
    if !iso_ok {
      return (false, None)
    }
    match (g, h) {
      (HomGroup::PermGroup(_), HomGroup::PermGroup(_)) => return (true, Some(perm_hom))
      _ => {
        let final_images : Array[HomElement] = Array::new()
        match h {
          HomGroup::FpGroup(_) => {
            let inv = h_iso.unwrap()
            for img in current {
              final_images.push(inv.invert(HomElement::Perm(img)))
            }
          }
          HomGroup::PermGroup(_) => {
            for img in current {
              final_images.push(HomElement::Perm(img))
            }
          }
          _ => ()
        }
        let g_gens : Array[HomElement] = Array::new()
        match g {
          HomGroup::PermGroup(pg0) => for gg in pg0.generators() { g_gens.push(HomElement::Perm(gg)) }
          HomGroup::FpGroup(gfp) => for gg in gfp.generators { g_gens.push(Word(gg)) }
          _ => ()
        }
        let hom = homomorphism(g, h, g_gens, images=final_images, check=false)
        return (true, Some(hom))
      }
    }
  }
  let cand = candidates[idx]
  for image in cand {
    let next : Array[Permutation] = Array::new()
    for v in current { next.push(v) }
    next.push(image)
    let (ok, hom) = group_iso_search(
      idx + 1,
      candidates,
      next,
      g_perm_gens,
      pg,
      ph,
      g,
      h,
      h_iso,
    )
    if ok {
      return (ok, hom)
    }
  }
  (false, None)
}

///|
pub fn group_isomorphism(
  g_in : HomGroup,
  h_in : HomGroup,
  isomorphism? : Bool = true,
) -> (Bool, GroupHomomorphism?) raise CombinatoricsError {
  let g = g_in
  let h = h_in
  // handle free groups explicitly
  match (g, h) {
    (HomGroup::FreeGroup(gf), HomGroup::FreeGroup(hf)) => {
      if gf.rank != hf.rank {
        return (false, None)
      }
      if !isomorphism {
        return (true, None)
      }
      let hom = homomorphism(
        HomGroup::FreeGroup(gf),
        HomGroup::FreeGroup(hf),
        gf.generators().map(x => Word(x)),
        images=hf.generators().map(x => Word(x)),
        check=false,
      )
      return (true, Some(hom))
    }
    (HomGroup::FreeGroup(gf), HomGroup::FpGroup(hfp)) => {
      if hfp.relators.is_empty() && gf.rank == hfp.generators.length() {
        if !isomorphism {
          return (true, None)
        }
        let hom = homomorphism(
          HomGroup::FreeGroup(gf),
          HomGroup::FpGroup(hfp),
          gf.generators().map(x => Word(x)),
          images=hfp.generators.map(x => Word(x)),
          check=false,
        )
        return (true, Some(hom))
      }
      return (false, None)
    }
    (HomGroup::FpGroup(gfp), HomGroup::FreeGroup(hf)) => {
      if gfp.relators.is_empty() && hf.rank == gfp.generators.length() {
        if !isomorphism {
          return (true, None)
        }
        let hom = homomorphism(
          HomGroup::FpGroup(gfp),
          HomGroup::FreeGroup(hf),
          gfp.generators.map(x => Word(x)),
          images=hf.generators().map(x => Word(x)),
          check=false,
        )
        return (true, Some(hom))
      }
      return (false, None)
    }
    _ => ()
  }
  // shortcut for identical fp presentations
  match (g, h) {
    (HomGroup::FpGroup(gfp), HomGroup::FpGroup(hfp)) => {
      let (g_gens, g_rels) = simplify_presentation(gfp.generators, gfp.relators, change_gens=true)
      let (h_gens, h_rels) = simplify_presentation(hfp.generators, hfp.relators, change_gens=true)
      if g_gens.length() == h_gens.length() {
        let mut same_gens = true
        for i in 0..<g_gens.length() {
          if g_gens[i] != h_gens[i] {
            same_gens = false
            break
          }
        }
        if same_gens {
          let mut rels_ok = g_rels.length() == h_rels.length()
          if rels_ok {
            let g_sorted : Array[FreeGroupElement] = Array::new()
            let h_sorted : Array[FreeGroupElement] = Array::new()
            for r in g_rels { g_sorted.push(r) }
            for r in h_rels { h_sorted.push(r) }
            let n = g_sorted.length()
            for i in 0..<n {
              for j in (i + 1)..<n {
                if g_sorted[j] < g_sorted[i] {
                  let tmp = g_sorted[i]
                  g_sorted[i] = g_sorted[j]
                  g_sorted[j] = tmp
                }
                if h_sorted[j] < h_sorted[i] {
                  let tmp2 = h_sorted[i]
                  h_sorted[i] = h_sorted[j]
                  h_sorted[j] = tmp2
                }
              }
            }
            for i in 0..<n {
              if g_sorted[i] != h_sorted[i] {
                rels_ok = false
                break
              }
            }
          }
          if rels_ok {
            if !isomorphism {
              return (true, None)
            }
            let hom = homomorphism(
              HomGroup::FpGroup(gfp),
              HomGroup::FpGroup(hfp),
              gfp.generators.map(x => Word(x)),
              images=hfp.generators.map(x => Word(x)),
              check=false,
            )
            return (true, Some(hom))
          }
        }
      }
    }
    _ => ()
  }

  let g_order = hom_group_order(g)
  let h_order = hom_group_order(h)
  let g_ord = group_order_int(g_order)
  let h_ord = group_order_int(h_order)
  match (g_ord, h_ord) {
    (Some(gn), Some(hn)) => {
      if gn != hn {
        return (false, None)
      }
    }
    (Some(_), None) | (None, Some(_)) => return (false, None)
    (None, None) => ()
  }

  // infinite groups: best-effort classification
  if g_ord is None && h_ord is None {
    match (g, h) {
      (HomGroup::FpGroup(gfp), HomGroup::FpGroup(hfp)) => {
        let g_ab = fp_group_is_abelian_status(gfp)
        let h_ab = fp_group_is_abelian_status(hfp)
        match (g_ab, h_ab) {
          (Some(true), Some(true)) => {
            let g_inv = fp_group_abelian_invariants(gfp)
            let h_inv = fp_group_abelian_invariants(hfp)
            if g_inv.rank != h_inv.rank {
              return (false, None)
            }
            let g_torsion : Array[Int] = Array::new()
            let h_torsion : Array[Int] = Array::new()
            for v in g_inv.torsion { g_torsion.push(v) }
            for v in h_inv.torsion { h_torsion.push(v) }
            let n_t = g_torsion.length()
            for i in 0..<n_t {
              for j in (i + 1)..<n_t {
                if g_torsion[j] < g_torsion[i] {
                  let tmp = g_torsion[i]
                  g_torsion[i] = g_torsion[j]
                  g_torsion[j] = tmp
                }
              }
            }
            let m_t = h_torsion.length()
            for i in 0..<m_t {
              for j in (i + 1)..<m_t {
                if h_torsion[j] < h_torsion[i] {
                  let tmp = h_torsion[i]
                  h_torsion[i] = h_torsion[j]
                  h_torsion[j] = tmp
                }
              }
            }
            if g_torsion.length() != h_torsion.length() {
              return (false, None)
            }
            for i in 0..<g_torsion.length() {
              if g_torsion[i] != h_torsion[i] {
                return (false, None)
              }
            }
            if !isomorphism {
              return (true, None)
            }
            return (true, None)
          }
          (Some(false), Some(true)) | (Some(true), Some(false)) => return (false, None)
          _ => ()
        }
      }
      _ => ()
    }
    return (false, None)
  }

  let mut g_perm = None
  let mut h_perm = None
  let mut g_iso : GroupHomomorphism? = None
  let mut h_iso : GroupHomomorphism? = None
  match g {
    HomGroup::PermGroup(pg) => g_perm = Some(pg)
    HomGroup::FpGroup(gfp) => {
      let (pg, iso) = fp_group_to_perm_group(gfp)
      g_perm = Some(pg)
      g_iso = Some(iso)
    }
    _ => ()
  }
  match h {
    HomGroup::PermGroup(ph) => h_perm = Some(ph)
    HomGroup::FpGroup(hfp) => {
      let (pg, iso) = fp_group_to_perm_group(hfp)
      h_perm = Some(pg)
      h_iso = Some(iso)
    }
    _ => ()
  }
  let pg = g_perm.unwrap()
  let ph = h_perm.unwrap()
  let g_ab = hom_group_is_abelian(g)
  let h_ab = hom_group_is_abelian(h)
  if g_ab != h_ab {
    return (false, None)
  }
  if !isomorphism {
    let n = g_ord.unwrap()
    let tot = @symntheory.totient(BigInt::from_int(n)).to_int()
    if gcd_int_local_hom(n, tot) == 1 {
      return (true, None)
    }
  }

  let g_perm_gens : Array[Permutation] = Array::new()
  match g {
    HomGroup::PermGroup(pg0) => {
      for gen in pg0.generators() { g_perm_gens.push(gen) }
    }
    HomGroup::FpGroup(gfp) => {
      let iso = g_iso.unwrap()
      for gen in gfp.generators {
        let img = iso.apply(Word(gen))
        match img {
          HomElement::Perm(p) => g_perm_gens.push(p)
          _ => ()
        }
      }
    }
    _ => ()
  }
  let h_elems = ph.elements()
  let candidates : Array[Array[Permutation]] = Array::new()
  for gen in g_perm_gens {
    let order = gen.order()
    let cand : Array[Permutation] = Array::new()
    for el in h_elems {
      if el.order() == order {
        cand.push(el)
      }
    }
    candidates.push(cand)
  }

  let (ok, hom) = group_iso_search(
    0,
    candidates,
    [],
    g_perm_gens,
    pg,
    ph,
    g,
    h,
    h_iso,
  )
  if !isomorphism {
    return (ok, None)
  }
  (ok, hom)
}

///|
pub fn is_isomorphic(g : HomGroup, h : HomGroup) -> Bool raise CombinatoricsError {
  let (ok, _) = group_isomorphism(g, h, isomorphism=false)
  ok
}
