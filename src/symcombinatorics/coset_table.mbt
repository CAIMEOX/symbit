///|
/// Coset tables and Todd-Coxeter enumeration (SymPy-style).

///|
let coset_table_max_limit : Int = 4096000

///|
let coset_table_max_stack_size : Int = 100

///|
fn copy_int_array_local(values : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for v in values {
    out.push(v)
  }
  out
}

///|
fn copy_row_int_opt(values : Array[Int?]) -> Array[Int?] {
  let out : Array[Int?] = Array::new()
  for v in values {
    out.push(v)
  }
  out
}

///|
fn copy_table_int_opt(values : Array[Array[Int?]]) -> Array[Array[Int?]] {
  let out : Array[Array[Int?]] = Array::new()
  for row in values {
    out.push(copy_row_int_opt(row))
  }
  out
}

///|
fn copy_deduction_stack(values : Array[(Int, FreeGroupElement)]) -> Array[(Int, FreeGroupElement)] {
  let out : Array[(Int, FreeGroupElement)] = Array::new()
  for v in values {
    out.push(v)
  }
  out
}

///|
fn bisect_left(values : Array[Int], item : Int) -> Int {
  let mut lo = 0
  let mut hi = values.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if values[mid] < item {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
pub struct CosetTable {
  free_group : FreeGroup
  relators : Array[FreeGroupElement]
  generators : Array[FreeGroupElement]
  group_name : String
  subgroup : Array[FreeGroupElement]
  coset_table_limit : Int
  mut p : Array[Int]
  alphabet : Array[FreeGroupElement]
  mut word_table : Array[Array[FreeGroupElement?]]
  mut table : Array[Array[Int?]]
  alphabet_index : Map[FreeGroupElement, Int]
  alphabet_inv_index : Map[FreeGroupElement, Int]
  mut deduction_stack : Array[(Int, FreeGroupElement)]
  _grp : FreeGroup
  p_p : Map[Int, FreeGroupElement]
  mut schreier_free_group : FreeGroup?
  mut schreier_generators : Array[FreeGroupElement]
  mut schreier_gen_elem : Map[String, FreeGroupElement]
  mut reidemeister_relators : Array[FreeGroupElement]
}

///|
pub fn CosetTable::new(
  free_group : FreeGroup,
  relators : Array[FreeGroupElement],
  generators : Array[FreeGroupElement],
  group_name : String,
  subgroup : Array[FreeGroupElement],
  max_cosets? : Int,
) -> CosetTable {
  let limit = match max_cosets {
    Some(v) => v
    None => coset_table_max_limit
  }
  let alphabet : Array[FreeGroupElement] = Array::new()
  for gen in generators {
    alphabet.push(gen)
    alphabet.push(gen.inverse())
  }
  let row : Array[Int?] = Array::make(alphabet.length(), None)
  let table : Array[Array[Int?]] = Array::new()
  table.push(copy_row_int_opt(row))
  let alphabet_index : Map[FreeGroupElement, Int] = {}
  let alphabet_inv_index : Map[FreeGroupElement, Int] = {}
  for i in 0..<alphabet.length() {
    let x = alphabet[i]
    alphabet_index[x] = i
  }
  for x, index in alphabet_index {
    if index % 2 == 0 {
      alphabet_inv_index[x] = index + 1
    } else {
      alphabet_inv_index[x] = index - 1
    }
  }
  let subgroup_gens = subgroup
  let names : Array[String] = Array::new()
  for i in 0..<subgroup_gens.length() {
    names.push("a_\{i}")
  }
  let (grp, _) = free_group_from_array(names)
  let p_p : Map[Int, FreeGroupElement] = {}
  p_p[0] = grp.identity()
  let word_table : Array[Array[FreeGroupElement?]] = Array::new()
  word_table.push(Array::make(alphabet.length(), None))
  {
    free_group,
    relators,
    generators,
    group_name,
    subgroup: subgroup_gens,
    coset_table_limit: limit,
    p: [0],
    alphabet,
    word_table,
    table,
    alphabet_index,
    alphabet_inv_index,
    deduction_stack: Array::new(),
    _grp: grp,
    p_p,
    schreier_free_group: None,
    schreier_generators: Array::new(),
    schreier_gen_elem: {},
    reidemeister_relators: Array::new(),
  }
}

///|
pub fn CosetTable::omega(self : CosetTable) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for coset in 0..<self.p.length() {
    if self.p[coset] == coset {
      out.push(coset)
    }
  }
  out
}

///|
pub fn CosetTable::copy(self : CosetTable) -> CosetTable {
  let copy = CosetTable::new(
    self.free_group,
    self.relators,
    self.generators,
    self.group_name,
    self.subgroup,
    max_cosets=self.coset_table_limit,
  )
  copy.table = copy_table_int_opt(self.table)
  copy.p = copy_int_array_local(self.p)
  copy.deduction_stack = copy_deduction_stack(self.deduction_stack)
  copy
}

///|
pub fn CosetTable::to_string(self : CosetTable) -> String {
  "Coset Table on \{self.group_name} with \{self.subgroup.length()} as subgroup generators"
}

///|
pub fn CosetTable::n(self : CosetTable) -> Int {
  if self.table.is_empty() {
    return 0
  }
  let mut max_live = -1
  for c in self.omega() {
    if c > max_live {
      max_live = c
    }
  }
  max_live + 1
}

///|
pub fn CosetTable::is_complete(self : CosetTable) -> Bool {
  for coset in self.omega() {
    let row = self.table[coset]
    for entry in row {
      if entry is None {
        return false
      }
    }
  }
  true
}

///|
pub fn CosetTable::define(
  self : CosetTable,
  alpha : Int,
  x : FreeGroupElement,
  modified? : Bool = false,
) -> Unit raise CombinatoricsError {
  let len_table = self.table.length()
  if len_table >= self.coset_table_limit {
    raise CombinatoricsError::ValueError("coset enumeration exceeded limit")
  }
  let row : Array[Int?] = Array::make(self.alphabet.length(), None)
  self.table.push(copy_row_int_opt(row))
  self.word_table.push(Array::make(self.alphabet.length(), None))
  let beta = len_table
  self.p.push(beta)
  let idx = self.alphabet_index[x]
  let idx_inv = self.alphabet_inv_index[x]
  self.table[alpha][idx] = Some(beta)
  self.table[beta][idx_inv] = Some(alpha)
  if modified {
    self.word_table[alpha][idx] = Some(self._grp.identity())
    self.word_table[beta][idx_inv] = Some(self._grp.identity())
    self.p_p[beta] = self._grp.identity()
  }
}

///|
pub fn CosetTable::define_c(self : CosetTable, alpha : Int, x : FreeGroupElement) -> Unit raise CombinatoricsError {
  let len_table = self.table.length()
  if len_table >= self.coset_table_limit {
    raise CombinatoricsError::ValueError("coset enumeration exceeded limit")
  }
  let row : Array[Int?] = Array::make(self.alphabet.length(), None)
  self.table.push(copy_row_int_opt(row))
  let beta = len_table
  self.p.push(beta)
  let idx = self.alphabet_index[x]
  let idx_inv = self.alphabet_inv_index[x]
  self.table[alpha][idx] = Some(beta)
  self.table[beta][idx_inv] = Some(alpha)
  self.deduction_stack.push((alpha, x))
}

///|
pub fn CosetTable::scan_c(
  self : CosetTable,
  alpha : Int,
  word : FreeGroupElement,
) -> Unit raise CombinatoricsError {
  let letters = word.letter_form_elm()
  let alphabet_index = self.alphabet_index
  let alphabet_inv_index = self.alphabet_inv_index
  let table = self.table
  let mut f = alpha
  let mut i = 0
  let r = letters.length()
  let mut b = alpha
  let mut j = r - 1
  while i <= j {
    let idx = alphabet_index[letters[i]]
    match table[f][idx] {
      Some(v) => {
        f = v
        i = i + 1
      }
      None => break
    }
  }
  if i > j {
    if f != b {
      self.coincidence_c(f, b)
    }
    return
  }
  while j >= i {
    let idx = alphabet_inv_index[letters[j]]
    match table[b][idx] {
      Some(v) => {
        b = v
        j = j - 1
      }
      None => break
    }
  }
  if j < i {
    self.coincidence_c(f, b)
  } else if j == i {
    let idx = alphabet_index[letters[i]]
    let idx_inv = alphabet_inv_index[letters[i]]
    table[f][idx] = Some(b)
    table[b][idx_inv] = Some(f)
    self.deduction_stack.push((f, letters[i]))
  }
}

///|
pub fn CosetTable::coincidence_c(self : CosetTable, alpha : Int, beta : Int)
  -> Unit raise CombinatoricsError {
  let alphabet_index = self.alphabet_index
  let alphabet_inv_index = self.alphabet_inv_index
  let table = self.table
  let q : Array[Int] = Array::new()
  self.merge(alpha, beta, q)
  while !q.is_empty() {
    let gamma = q.remove(0)
    for x, _ in alphabet_index {
      let idx = alphabet_index[x]
      match table[gamma][idx] {
        Some(delta) => {
          table[delta][alphabet_inv_index[x]] = None
          self.deduction_stack.push((delta, x.inverse()))
          let mu = self.rep(gamma)
          let nu = self.rep(delta)
          match table[mu][idx] {
            Some(val) => self.merge(nu, val, q)
            None => {
              match table[nu][alphabet_inv_index[x]] {
                Some(val2) => self.merge(mu, val2, q)
                None => {
                  table[mu][idx] = Some(nu)
                  table[nu][alphabet_inv_index[x]] = Some(mu)
                }
              }
            }
          }
        }
        None => ()
      }
    }
  }
}

///|
pub fn CosetTable::scan(
  self : CosetTable,
  alpha : Int,
  word : FreeGroupElement,
  y? : FreeGroupElement,
  fill? : Bool = false,
  modified? : Bool = false,
) -> Unit raise CombinatoricsError {
  let letters = word.letter_form_elm()
  let alphabet_index = self.alphabet_index
  let alphabet_inv_index = self.alphabet_inv_index
  let table = self.table
  let mut f = alpha
  let mut i = 0
  let r = letters.length()
  let mut b = alpha
  let mut j = r - 1
  let mut b_p = match y {
    Some(v) => v
    None => self._grp.identity()
  }
  let mut f_p = self._grp.identity()
  let mut flag = 0
  while fill || flag == 0 {
    flag = 1
    while i <= j {
      let idx = alphabet_index[letters[i]]
      match table[f][idx] {
        Some(v) => {
          if modified {
            match self.word_table[f][idx] {
              Some(pv) => f_p = f_p.mul(pv)
              None => ()
            }
          }
          f = v
          i = i + 1
        }
        None => break
      }
    }
    if i > j {
      if f != b {
        if modified {
          self.modified_coincidence(f, b, f_p.inverse().mul(b_p))
        } else {
          self.coincidence(f, b)
        }
      }
      return
    }
    while j >= i {
      let idx = alphabet_inv_index[letters[j]]
      match table[b][idx] {
        Some(v) => {
          if modified {
            match self.word_table[b][idx] {
              Some(pv) => b_p = b_p.mul(pv)
              None => ()
            }
          }
          b = v
          j = j - 1
        }
        None => break
      }
    }
    if j < i {
      if modified {
        self.modified_coincidence(f, b, f_p.inverse().mul(b_p))
      } else {
        self.coincidence(f, b)
      }
    } else if j == i {
      let idx = alphabet_index[letters[i]]
      let idx_inv = alphabet_inv_index[letters[i]]
      table[f][idx] = Some(b)
      table[b][idx_inv] = Some(f)
      if modified {
        self.word_table[f][idx] = Some(f_p.inverse().mul(b_p))
        self.word_table[b][idx_inv] = Some(b_p.inverse().mul(f_p))
      }
      return
    } else if fill {
      self.define(f, letters[i], modified=modified)
    }
  }
}

///|
pub fn CosetTable::scan_check(self : CosetTable, alpha : Int, word : FreeGroupElement) -> Bool {
  let letters = word.letter_form_elm()
  let alphabet_index = self.alphabet_index
  let alphabet_inv_index = self.alphabet_inv_index
  let table = self.table
  let mut f = alpha
  let mut i = 0
  let r = letters.length()
  let mut b = alpha
  let mut j = r - 1
  while i <= j {
    let idx = alphabet_index[letters[i]]
    match table[f][idx] {
      Some(v) => {
        f = v
        i = i + 1
      }
      None => break
    }
  }
  if i > j {
    return f == b
  }
  while j >= i {
    let idx = alphabet_inv_index[letters[j]]
    match table[b][idx] {
      Some(v) => {
        b = v
        j = j - 1
      }
      None => break
    }
  }
  if j < i {
    return false
  } else if j == i {
    let idx = alphabet_index[letters[i]]
    let idx_inv = alphabet_inv_index[letters[i]]
    table[f][idx] = Some(b)
    table[b][idx_inv] = Some(f)
  }
  true
}

///|
pub fn CosetTable::merge(
  self : CosetTable,
  k : Int,
  lamda : Int,
  q : Array[Int],
  w? : FreeGroupElement,
  modified? : Bool = false,
) -> Unit raise CombinatoricsError {
  let phi = self.rep(k, modified=modified)
  let psi = self.rep(lamda, modified=modified)
  if phi != psi {
    let mu = if phi < psi { phi } else { psi }
    let v = if phi < psi { psi } else { phi }
    self.p[v] = mu
    if modified {
      match w {
        Some(word) => {
          if v == phi {
            self.p_p[phi] = self.p_p[k].inverse().mul(word).mul(self.p_p[lamda])
          } else {
            self.p_p[psi] = self.p_p[lamda].inverse().mul(word.inverse()).mul(self.p_p[k])
          }
        }
        None => ()
      }
    }
    q.push(v)
  }
}

///|
pub fn CosetTable::rep(self : CosetTable, k : Int, modified? : Bool = false)
  -> Int raise CombinatoricsError {
  let p = self.p
  let mut lamda = k
  let mut rho = p[lamda]
  if modified {
    let s : Array[Int] = Array::new()
    for v in p {
      s.push(v)
    }
    while rho != lamda {
      s[rho] = lamda
      lamda = rho
      rho = p[lamda]
    }
    rho = s[lamda]
    while rho != k {
      let mu = rho
      rho = s[mu]
      p[rho] = lamda
      self.p_p[rho] = self.p_p[rho].mul(self.p_p[mu])
    }
  } else {
    let mut mu = k
    rho = p[mu]
    while rho != lamda {
      p[mu] = lamda
      mu = rho
      rho = p[mu]
    }
  }
  lamda
}

///|
pub fn CosetTable::coincidence(
  self : CosetTable,
  alpha : Int,
  beta : Int,
  w? : FreeGroupElement,
  modified? : Bool = false,
) -> Unit raise CombinatoricsError {
  let alphabet_index = self.alphabet_index
  let alphabet_inv_index = self.alphabet_inv_index
  let table = self.table
  let q : Array[Int] = Array::new()
  if modified {
    match w {
      Some(word) => self.modified_merge(alpha, beta, word, q)
      None => self.modified_merge(alpha, beta, self._grp.identity(), q)
    }
  } else {
    self.merge(alpha, beta, q)
  }
  while !q.is_empty() {
    let gamma = q.remove(0)
    for x, _ in alphabet_index {
      let idx = alphabet_index[x]
      match table[gamma][idx] {
        Some(delta) => {
          table[delta][alphabet_inv_index[x]] = None
          let mu = self.rep(gamma, modified=modified)
          let nu = self.rep(delta, modified=modified)
          match table[mu][idx] {
            Some(val) => {
              if modified {
                let v = self.p_p[delta]
                  .inverse()
                  .mul(self.word_table[gamma][idx].unwrap_or(self._grp.identity()).inverse())
                  .mul(self.p_p[gamma])
                  .mul(self.word_table[mu][idx].unwrap_or(self._grp.identity()))
                self.modified_merge(nu, val, v, q)
              } else {
                self.merge(nu, val, q)
              }
            }
            None => {
              match table[nu][alphabet_inv_index[x]] {
                Some(val2) => {
                  if modified {
                    let v = self.p_p[gamma]
                      .inverse()
                      .mul(self.word_table[gamma][idx].unwrap_or(self._grp.identity()))
                      .mul(self.p_p[delta])
                      .mul(self.word_table[mu][alphabet_inv_index[x]].unwrap_or(self._grp.identity()))
                    self.modified_merge(mu, val2, v, q)
                  } else {
                    self.merge(mu, val2, q)
                  }
                }
                None => {
                  table[mu][idx] = Some(nu)
                  table[nu][alphabet_inv_index[x]] = Some(mu)
                  if modified {
                    let v = self.p_p[gamma]
                      .inverse()
                      .mul(self.word_table[gamma][idx].unwrap_or(self._grp.identity()))
                      .mul(self.p_p[delta])
                    self.word_table[mu][idx] = Some(v)
                    self.word_table[nu][alphabet_inv_index[x]] = Some(v.inverse())
                  }
                }
              }
            }
          }
        }
        None => ()
      }
    }
  }
}

///|
pub fn CosetTable::scan_and_fill(self : CosetTable, alpha : Int, word : FreeGroupElement) -> Unit raise CombinatoricsError {
  self.scan(alpha, word, fill=true)
}

///|
pub fn CosetTable::scan_and_fill_c(
  self : CosetTable,
  alpha : Int,
  word : FreeGroupElement,
) -> Unit raise CombinatoricsError {
  let letters = word.letter_form_elm()
  let alphabet_index = self.alphabet_index
  let alphabet_inv_index = self.alphabet_inv_index
  let table = self.table
  let r = letters.length()
  let mut f = alpha
  let mut i = 0
  let mut b = alpha
  let mut j = r - 1
  while true {
    while i <= j {
      let idx = alphabet_index[letters[i]]
      match table[f][idx] {
        Some(v) => {
          f = v
          i = i + 1
        }
        None => break
      }
    }
    if i > j {
      if f != b {
        self.coincidence_c(f, b)
      }
      return
    }
    while j >= i {
      let idx = alphabet_inv_index[letters[j]]
      match table[b][idx] {
        Some(v) => {
          b = v
          j = j - 1
        }
        None => break
      }
    }
    if j < i {
      self.coincidence_c(f, b)
    } else if j == i {
      let idx = alphabet_index[letters[i]]
      let idx_inv = alphabet_inv_index[letters[i]]
      table[f][idx] = Some(b)
      table[b][idx_inv] = Some(f)
      self.deduction_stack.push((f, letters[i]))
    } else {
      self.define_c(f, letters[i])
    }
  }
}

///|
pub fn CosetTable::look_ahead(self : CosetTable) -> Unit raise CombinatoricsError {
  let relators = self.relators
  for beta in self.omega() {
    for w in relators {
      let _ = self.scan(beta, w)
      if self.p[beta] < beta {
        break
      }
    }
  }
}

///|
pub fn CosetTable::process_deductions(
  self : CosetTable,
  relators_by_x : Array[FreeGroupElement],
  relators_by_x_inv : Array[FreeGroupElement],
) -> Unit raise CombinatoricsError {
  let table = self.table
  while !self.deduction_stack.is_empty() {
    if self.deduction_stack.length() >= coset_table_max_stack_size {
      self.look_ahead()
      self.deduction_stack = Array::new()
      continue
    }
    let (alpha, x) = self.deduction_stack.pop().unwrap()
    if self.p[alpha] == alpha {
      for w in relators_by_x {
        self.scan_c(alpha, w)
        if self.p[alpha] < alpha {
          break
        }
      }
    }
    let idx = self.alphabet_index[x]
    match table[alpha][idx] {
      Some(beta) => {
        if self.p[beta] == beta {
          for w in relators_by_x_inv {
            self.scan_c(beta, w)
            if self.p[beta] < beta {
              break
            }
          }
        }
      }
      None => ()
    }
  }
}

///|
pub fn CosetTable::process_deductions_check(
  self : CosetTable,
  relators_by_x : Array[FreeGroupElement],
  relators_by_x_inv : Array[FreeGroupElement],
) -> Bool {
  let table = self.table
  while !self.deduction_stack.is_empty() {
    let (alpha, x) = self.deduction_stack.pop().unwrap()
    for w in relators_by_x {
      if !self.scan_check(alpha, w) {
        return false
      }
    }
    let idx = self.alphabet_index[x]
    match table[alpha][idx] {
      Some(beta) => {
        for w in relators_by_x_inv {
          if !self.scan_check(beta, w) {
            return false
          }
        }
      }
      None => ()
    }
  }
  true
}

///|
pub fn CosetTable::switch(self : CosetTable, beta : Int, gamma : Int) -> Unit {
  let alphabet = self.alphabet
  let alphabet_index = self.alphabet_index
  let table = self.table
  for x in alphabet {
    let idx = alphabet_index[x]
    let z = table[gamma][idx]
    table[gamma][idx] = table[beta][idx]
    table[beta][idx] = z
    for alpha in 0..<self.p.length() {
      if self.p[alpha] == alpha {
        if table[alpha][idx] == Some(beta) {
          table[alpha][idx] = Some(gamma)
        } else if table[alpha][idx] == Some(gamma) {
          table[alpha][idx] = Some(beta)
        }
      }
    }
  }
}

///|
pub fn CosetTable::standardize(self : CosetTable) -> Unit {
  let alphabet = self.alphabet
  let alphabet_index = self.alphabet_index
  let mut gamma = 1
  let n = self.n()
  for alpha in 0..<n {
    for x in alphabet {
      let beta = self.table[alpha][alphabet_index[x]].unwrap_or(-1)
      if beta >= gamma {
        if beta > gamma {
          self.switch(gamma, beta)
        }
        gamma = gamma + 1
        if gamma == self.n() {
          return
        }
      }
    }
  }
}

///|
pub fn CosetTable::compress(self : CosetTable) -> Unit {
  let mut gamma = -1
  let alphabet = self.alphabet
  let alphabet_index = self.alphabet_index
  let alphabet_inv_index = self.alphabet_inv_index
  let table = self.table
  let chi : Array[Int] = Array::new()
  for i in 0..<self.p.length() {
    if self.p[i] != i {
      chi.push(i)
    }
  }
  for alpha in self.omega() {
    gamma = gamma + 1
    if gamma != alpha {
      for x in alphabet {
        let idx = alphabet_index[x]
        let beta = table[alpha][idx].unwrap_or(-1)
        table[gamma][idx] = Some(beta)
        let _ = alphabet_inv_index[x]
        // preserve sympy no-op line (see sympy issue #27633)
      }
    }
  }
  let new_p : Array[Int] = Array::new()
  for i in 0..=gamma {
    new_p.push(i)
  }
  self.p = new_p
  while table.length() > self.p.length() {
    let _ = table.pop()
  }
  for row in table {
    for j in 0..<self.alphabet.length() {
      match row[j] {
        Some(v) => row[j] = Some(v - bisect_left(chi, v))
        None => ()
      }
    }
  }
}

///|
pub fn CosetTable::conjugates(
  self : CosetTable,
  relators : Array[FreeGroupElement],
) -> Array[Array[FreeGroupElement]] {
  let relator_set : Map[FreeGroupElement, Bool] = {}
  for rel in relators {
    for w in rel.cyclic_conjugates() {
      relator_set[w] = true
    }
    for w in rel.inverse().cyclic_conjugates() {
      relator_set[w] = true
    }
  }
  let relator_buckets : Array[Array[FreeGroupElement]] = Array::new()
  for x in self.alphabet {
    let subset : Array[FreeGroupElement] = Array::new()
    for w, _ in relator_set {
      let first = w.letter_at(0) catch { _ => w }
      if first == x {
        subset.push(w)
      }
    }
    relator_buckets.push(subset)
    for w in subset {
      relator_set.remove(w)
    }
  }
  relator_buckets
}

///|
pub fn CosetTable::coset_representative(self : CosetTable, coset : Int)
  -> FreeGroupElement raise CombinatoricsError {
  for x in self.alphabet {
    let gamma = self.table[coset][self.alphabet_index[x]].unwrap_or(-1)
    if coset == 0 {
      return self.free_group.identity()
    }
    if gamma >= 0 && gamma < coset {
      return self.coset_representative(gamma).mul(x.pow(-1))
    }
  }
  self.free_group.identity()
}

///|
pub fn CosetTable::modified_define(self : CosetTable, alpha : Int, x : FreeGroupElement) -> Unit raise CombinatoricsError {
  self.define(alpha, x, modified=true)
}

///|
pub fn CosetTable::modified_scan(
  self : CosetTable,
  alpha : Int,
  w : FreeGroupElement,
  y : FreeGroupElement,
  fill? : Bool = false,
) -> Unit raise CombinatoricsError {
  self.scan(alpha, w, y=y, fill=fill, modified=true)
}

///|
pub fn CosetTable::modified_scan_and_fill(
  self : CosetTable,
  alpha : Int,
  w : FreeGroupElement,
  y : FreeGroupElement,
) -> Unit raise CombinatoricsError {
  self.modified_scan(alpha, w, y, fill=true)
}

///|
pub fn CosetTable::modified_merge(
  self : CosetTable,
  k : Int,
  lamda : Int,
  w : FreeGroupElement,
  q : Array[Int],
) -> Unit raise CombinatoricsError {
  self.merge(k, lamda, q, w=w, modified=true)
}

///|
pub fn CosetTable::modified_rep(self : CosetTable, k : Int) -> Int raise CombinatoricsError {
  self.rep(k, modified=true)
}

///|
pub fn CosetTable::modified_coincidence(
  self : CosetTable,
  alpha : Int,
  beta : Int,
  w : FreeGroupElement,
) -> Unit raise CombinatoricsError {
  self.coincidence(alpha, beta, w=w, modified=true)
}

///|
pub fn coset_enumeration_r(
  fp_grp : FpGroup,
  subgroup : Array[FreeGroupElement],
  max_cosets? : Int,
  draft? : CosetTable,
  incomplete? : Bool = false,
  modified? : Bool = false,
) -> CosetTable raise CombinatoricsError {
  let coset_table = match max_cosets {
    Some(v) => CosetTable::new(
      fp_grp.free_group,
      fp_grp.relators,
      fp_grp.generators,
      fp_grp.to_string(),
      subgroup,
      max_cosets=v,
    )
    None => CosetTable::new(
      fp_grp.free_group,
      fp_grp.relators,
      fp_grp.generators,
      fp_grp.to_string(),
      subgroup,
    )
  }
  let scan_and_fill = fn(
    alpha : Int,
    w : FreeGroupElement,
    y_opt : FreeGroupElement?,
  ) -> Unit raise CombinatoricsError {
    if modified {
      let y_val = match y_opt {
        Some(v) => v
        None => coset_table._grp.identity()
      }
      coset_table.modified_scan_and_fill(alpha, w, y_val)
    } else {
      coset_table.scan_and_fill(alpha, w)
    }
  }
  let define_fn = fn(alpha : Int, x : FreeGroupElement) -> Unit raise CombinatoricsError {
    if modified {
      coset_table.modified_define(alpha, x)
    } else {
      coset_table.define(alpha, x)
    }
  }
  match draft {
    Some(d) => {
      coset_table.table = copy_table_int_opt(d.table)
      coset_table.p = copy_int_array_local(d.p)
    }
    None => ()
  }
  let relators = fp_grp.relators
  let alphabet_index = coset_table.alphabet_index
  let p = coset_table.p
  for i in 0..<subgroup.length() {
    if modified {
      scan_and_fill(0, subgroup[i], Some(coset_table._grp.generators()[i]))
    } else {
      scan_and_fill(0, subgroup[i], None)
    }
  }
  let mut alpha = 0
  while alpha < coset_table.n() {
    if p[alpha] == alpha {
      try {
        for w in relators {
          if modified {
            scan_and_fill(alpha, w, Some(coset_table._grp.identity()))
          } else {
            scan_and_fill(alpha, w, None)
          }
          if p[alpha] < alpha {
            break
          }
        }
        if p[alpha] == alpha {
          for x, _ in alphabet_index {
            if coset_table.table[alpha][alphabet_index[x]] is None {
              define_fn(alpha, x)
            }
          }
        }
      } catch {
        err => {
          if incomplete {
            return coset_table
          }
          raise err
        }
      }
    }
    alpha = alpha + 1
  }
  coset_table
}

///|
pub fn modified_coset_enumeration_r(
  fp_grp : FpGroup,
  subgroup : Array[FreeGroupElement],
  max_cosets? : Int,
  draft? : CosetTable,
  incomplete? : Bool = false,
) -> CosetTable raise CombinatoricsError {
  match max_cosets {
    Some(v) => {
      match draft {
        Some(d) => coset_enumeration_r(
          fp_grp,
          subgroup,
          max_cosets=v,
          draft=d,
          incomplete=incomplete,
          modified=true,
        )
        None => coset_enumeration_r(
          fp_grp,
          subgroup,
          max_cosets=v,
          incomplete=incomplete,
          modified=true,
        )
      }
    }
    None => {
      match draft {
        Some(d) => coset_enumeration_r(
          fp_grp,
          subgroup,
          draft=d,
          incomplete=incomplete,
          modified=true,
        )
        None => coset_enumeration_r(
          fp_grp,
          subgroup,
          incomplete=incomplete,
          modified=true,
        )
      }
    }
  }
}

///|
pub fn coset_enumeration_c(
  fp_grp : FpGroup,
  subgroup : Array[FreeGroupElement],
  max_cosets? : Int,
  draft? : CosetTable,
  incomplete? : Bool = false,
) -> CosetTable raise CombinatoricsError {
  let gens = fp_grp.generators
  let relators = fp_grp.relators
  let coset_table = match max_cosets {
    Some(v) => CosetTable::new(
      fp_grp.free_group,
      fp_grp.relators,
      fp_grp.generators,
      fp_grp.to_string(),
      subgroup,
      max_cosets=v,
    )
    None => CosetTable::new(
      fp_grp.free_group,
      fp_grp.relators,
      fp_grp.generators,
      fp_grp.to_string(),
      subgroup,
    )
  }
  match draft {
    Some(d) => {
      coset_table.table = copy_table_int_opt(d.table)
      coset_table.p = copy_int_array_local(d.p)
      coset_table.deduction_stack = copy_deduction_stack(d.deduction_stack)
      for alpha in 0..<coset_table.table.length() {
        for x in gens {
          if coset_table.table[alpha][coset_table.alphabet_index[x]] is Some(_) {
            coset_table.deduction_stack.push((alpha, x))
          }
        }
      }
    }
    None => ()
  }
  let relators_cyclic_reduced : Array[FreeGroupElement] = Array::new()
  for rel in relators {
    relators_cyclic_reduced.push(rel.identity_cyclic_reduction())
  }
  let relator_set : Map[FreeGroupElement, Bool] = {}
  for rel in relators_cyclic_reduced {
    for w in rel.cyclic_conjugates() {
      relator_set[w] = true
    }
    for w in rel.inverse().cyclic_conjugates() {
      relator_set[w] = true
    }
  }
  let relator_buckets : Array[Array[FreeGroupElement]] = Array::new()
  for x in coset_table.alphabet {
    let subset : Array[FreeGroupElement] = Array::new()
    for w, _ in relator_set {
      let first = w.letter_at(0) catch { _ => w }
      if first == x {
        subset.push(w)
      }
    }
    relator_buckets.push(subset)
    for w in subset {
      relator_set.remove(w)
    }
  }
  for w in subgroup {
    coset_table.scan_and_fill_c(0, w)
  }
  for x in coset_table.alphabet {
    coset_table.process_deductions(
      relator_buckets[coset_table.alphabet_index[x]],
      relator_buckets[coset_table.alphabet_inv_index[x]],
    )
  }
  let mut alpha = 0
  while alpha < coset_table.table.length() {
    if coset_table.p[alpha] == alpha {
      try {
        for x in coset_table.alphabet {
          if coset_table.p[alpha] != alpha {
            break
          }
          if coset_table.table[alpha][coset_table.alphabet_index[x]] is None {
            coset_table.define_c(alpha, x)
            coset_table.process_deductions(
              relator_buckets[coset_table.alphabet_index[x]],
              relator_buckets[coset_table.alphabet_inv_index[x]],
            )
          }
        }
      } catch {
        err => {
          if incomplete {
            return coset_table
          }
          raise err
        }
      }
    }
    alpha = alpha + 1
  }
  coset_table
}
