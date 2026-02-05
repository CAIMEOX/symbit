///|
/// Permutations and cycles (SymPy-style).

///|
fn gcd_int(a0 : Int, b0 : Int) -> Int {
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
fn lcm_int(a : Int, b : Int) -> Int {
  if a == 0 || b == 0 {
    0
  } else {
    (a / gcd_int(a, b)) * b
  }
}

///|
fn factorial_int(n : Int) -> Int {
  if n < 0 {
    return 0
  }
  let mut acc = 1
  for i in 2..=n {
    acc = acc * i
  }
  acc
}

///|
fn af_rmul(a : Array[Int], b : Array[Int]) -> Array[Int] raise CombinatoricsError {
  if a.length() != b.length() {
    raise CombinatoricsError::ValueError("array length mismatch")
  }
  let out : Array[Int] = Array::new()
  for i in 0..<b.length() {
    out.push(a[b[i]])
  }
  out
}

///|
fn af_rmuln(arrays : Array[Array[Int]]) -> Array[Int] raise CombinatoricsError {
  if arrays.is_empty() {
    raise CombinatoricsError::ValueError("array list must not be empty")
  }
  let mut res : Array[Int] = Array::new()
  for v in arrays[0] {
    res.push(v)
  }
  if arrays.length() == 1 {
    return res
  }
  for i in 1..<arrays.length() {
    res = af_rmul(res, arrays[i])
  }
  res
}

///|
fn af_parity(pi : Array[Int]) -> Int {
  let n = pi.length()
  let visited : Array[Bool] = Array::make(n, false)
  let mut cycles = 0
  for j in 0..<n {
    if visited[j] {
      continue
    }
    cycles = cycles + 1
    let mut i = j
    while !visited[i] {
      visited[i] = true
      i = pi[i]
    }
  }
  (n - cycles) % 2
}

///|
fn af_invert(a : Array[Int]) -> Array[Int] {
  let n = a.length()
  let inv : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    inv.set(a[i], i)
  }
  inv
}

///|
fn af_pow(a : Array[Int], n : Int) -> Array[Int] {
  if n == 0 {
    let out : Array[Int] = Array::new()
    for i in 0..<a.length() {
      out.push(i)
    }
    return out
  }
  if n < 0 {
    return af_pow(af_invert(a), -n)
  }
  if n == 1 {
    let out : Array[Int] = Array::new()
    for v in a {
      out.push(v)
    }
    return out
  }
  let mut result : Array[Int] = Array::new()
  for i in 0..<a.length() {
    result.push(i)
  }
  let mut base : Array[Int] = Array::new()
  for v in a {
    base.push(v)
  }
  let mut exp = n
  while exp > 0 {
    if (exp & 1) == 1 {
      result = af_rmul(result, base) catch { _ => result }
    }
    base = af_rmul(base, base) catch { _ => base }
    exp = exp >> 1
  }
  result
}

///|
fn af_commutes_with(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[b[i]] != b[a[i]] {
      return false
    }
  }
  true
}

///|
fn rotate_cycle_to_min(cycle : Array[Int]) -> Array[Int] {
  if cycle.length() <= 1 {
    return cycle
  }
  let mut min_val = cycle[0]
  let mut min_idx = 0
  for i in 1..<cycle.length() {
    if cycle[i] < min_val {
      min_val = cycle[i]
      min_idx = i
    }
  }
  let out : Array[Int] = Array::new()
  for i in 0..<cycle.length() {
    out.push(cycle[(min_idx + i) % cycle.length()])
  }
  out
}

///|
fn take_prefix(values : Array[Int], n : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  let mut limit = n
  if limit < 0 {
    limit = 0
  }
  if limit > values.length() {
    limit = values.length()
  }
  for i in 0..<limit {
    out.push(values[i])
  }
  out
}

///|
fn sort_cycles(cycles : Array[Array[Int]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for c in cycles {
    out.push(rotate_cycle_to_min(c))
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if out[j].length() > 0 && out[i].length() > 0 && out[j][0] < out[i][0] {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
pub struct Cycle {
  mapping : Map[Int, Int]
}

///|
pub fn Cycle::new(items : Array[Int]) -> Cycle raise CombinatoricsError {
  let mapping : Map[Int, Int] = {}
  if items.is_empty() {
    return Cycle::{ mapping }
  }
  let seen : Array[Int] = Array::new()
  for item in items {
    if item < 0 {
      raise CombinatoricsError::ValueError("negative integers are not allowed in a cycle")
    }
    if seen.any(v => v == item) {
      raise CombinatoricsError::ValueError("all elements must be unique in a cycle")
    }
    seen.push(item)
  }
  let n = items.length()
  for i in 0..<n {
    let curr = items[i]
    let next = items[(i + 1) % n]
    mapping[curr] = next
  }
  Cycle::{ mapping }
}

///|
pub fn Cycle::from_permutation(p : Permutation) -> Cycle {
  let mapping : Map[Int, Int] = {}
  for cycle in p.cyclic_form() {
    if cycle.length() == 1 {
      mapping[cycle[0]] = cycle[0]
    } else {
      for i in 0..<cycle.length() {
        mapping[cycle[i]] = cycle[(i + 1) % cycle.length()]
      }
    }
  }
  Cycle::{ mapping }
}

///|
pub fn Cycle::apply(self : Cycle, x : Int) -> Int {
  match self.mapping.get(x) {
    Some(v) => v
    None => x
  }
}

///|
pub fn Cycle::compose(self : Cycle, other : Cycle) -> Cycle {
  let rv : Map[Int, Int] = {}
  for k, v in other.mapping {
    rv[k] = v
  }
  for k, _ in self.mapping {
    rv[k] = other.apply(self.apply(k))
  }
  { mapping: rv }
}

///|
pub fn Cycle::list(self : Cycle, size? : Int) -> Array[Int] raise CombinatoricsError {
  if self.mapping.is_empty() && size is None {
    raise CombinatoricsError::ValueError("must give size for empty Cycle")
  }
  let mut sz = match size {
    Some(s) => s
    None => self.size()
  }
  if sz < 0 {
    sz = 0
  }
  if size is Some(_) {
    let mut big = 0
    for k, v in self.mapping {
      if v != k && k > big {
        big = k
      }
    }
    if sz < big + 1 {
      sz = big + 1
    }
  }
  let out : Array[Int] = Array::new()
  for i in 0..<sz {
    out.push(self.apply(i))
  }
  out
}

///|
pub fn Cycle::size(self : Cycle) -> Int {
  if self.mapping.is_empty() {
    return 0
  }
  let mut max_key = 0
  for k, _ in self.mapping {
    if k > max_key {
      max_key = k
    }
  }
  max_key + 1
}

///|
pub impl Show for Cycle with output(self, logger : &Logger) -> Unit {
  if self.mapping.is_empty() {
    logger.write_string("()")
    return
  }
  let p = Permutation::from_cycle(self, size=self.size()) catch {
    _ => Permutation::identity(0)
  }
  let cycles = p.cyclic_form()
  let mut s = ""
  for cycle in cycles {
    s = s + "(" + cycle.map((x) => "\{x}").join(" ") + ")"
  }
  let big = self.size() - 1
  let mut has_big = false
  for cycle in cycles {
    if cycle.any(v => v == big) {
      has_big = true
      break
    }
  }
  if !has_big {
    s = s + "(\{big})"
  }
  if s == "" {
    s = "()"
  }
  logger.write_string(s)
}

///|
pub struct Permutation {
  array_form : Array[Int]
  size : Int
  mut cyclic_form_cache : Array[Array[Int]]?
  mut full_cyclic_form_cache : Array[Array[Int]]?
  mut cycle_structure_cache : Map[Int, Int]?
  mut rank_cache : Int?
}

///|
fn validate_array_form(array : Array[Int]) -> Bool {
  let n = array.length()
  let seen : Array[Bool] = Array::make(n, false)
  for v in array {
    if v < 0 || v >= n {
      return false
    }
    if seen[v] {
      return false
    }
    seen[v] = true
  }
  true
}

///|
fn make_perm(array : Array[Int]) -> Permutation {
  {
    array_form: array,
    size: array.length(),
    cyclic_form_cache: None,
    full_cyclic_form_cache: None,
    cycle_structure_cache: None,
    rank_cache: None,
  }
}

///|
pub fn Permutation::new(array : Array[Int]) -> Permutation raise CombinatoricsError {
  if !validate_array_form(array) {
    raise CombinatoricsError::ValueError("invalid permutation array form")
  }
  let out : Array[Int] = Array::new()
  for v in array {
    out.push(v)
  }
  make_perm(out)
}

///|
pub fn Permutation::from_array(array : Array[Int], size? : Int) -> Permutation raise CombinatoricsError {
  let arr : Array[Int] = Array::new()
  for v in array {
    arr.push(v)
  }
  match size {
    Some(n) => {
      if n < arr.length() {
        raise CombinatoricsError::ValueError("size smaller than array length")
      }
      for v in arr {
        if v < 0 || v >= n {
          raise CombinatoricsError::ValueError("array contains element outside size")
        }
      }
      if n > arr.length() {
        let len = arr.length()
        for i in len..<n {
          arr.push(i)
        }
      }
    }
    None => ()
  }
  if !validate_array_form(arr) {
    raise CombinatoricsError::ValueError("invalid permutation array form")
  }
  make_perm(arr)
}

///|
pub fn Permutation::identity(size : Int) -> Permutation {
  let arr : Array[Int] = Array::new()
  for i in 0..<size {
    arr.push(i)
  }
  make_perm(arr)
}

///|
pub fn Permutation::from_cycle(cycle : Cycle, size? : Int) -> Permutation raise CombinatoricsError {
  let arr = match size {
    Some(s) => cycle.list(size=s)
    None => cycle.list()
  }
  match size {
    Some(s) => Permutation::from_array(arr, size=s)
    None => Permutation::from_array(arr)
  }
}

///|
pub fn Permutation::from_cycles(
  cycles : Array[Array[Int]],
  size? : Int,
) -> Permutation raise CombinatoricsError {
  let mut max_val = -1
  for cycle in cycles {
    for v in cycle {
      if v > max_val {
        max_val = v
      }
    }
  }
  let base_size = match size {
    Some(s) => s
    None => max_val + 1
  }
  let mut perm = Permutation::identity(if base_size < 0 { 0 } else { base_size })
  for cycle in cycles {
    let c = Cycle::new(cycle)
    let p = Permutation::from_cycle(c, size=perm.size())
    perm = perm.mul(p)
  }
  perm
}

///|
pub fn Permutation::from_sequence_chars(items : Array[Char]) -> Permutation {
  let pairs : Array[(Char, Int)] = Array::new()
  for i in 0..<items.length() {
    pairs.push((items[i], i))
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
  let indices : Array[Int] = Array::new()
  for pair in pairs {
    indices.push(pair.1)
  }
  let inv = af_invert(indices)
  make_perm(inv)
}

///|
pub fn Permutation::from_sequence_string(s : String) -> Permutation {
  let chars = string_to_chars(s)
  Permutation::from_sequence_chars(chars)
}

///|
pub fn Permutation::array_form(self : Permutation) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for v in self.array_form {
    out.push(v)
  }
  out
}

///|
pub fn Permutation::size(self : Permutation) -> Int {
  self.size
}

///|
pub fn Permutation::apply_index(self : Permutation, i : Int) -> Int raise CombinatoricsError {
  if i < 0 || i >= self.size {
    raise CombinatoricsError::ValueError("index out of range")
  }
  self.array_form[i]
}

///|
pub fn[T] Permutation::apply_array(self : Permutation, values : Array[T]) -> Array[T] raise CombinatoricsError {
  if values.length() != self.size {
    raise CombinatoricsError::ValueError("sequence length mismatch")
  }
  let out : Array[T] = Array::new()
  for i in 0..<self.size {
    out.push(values[self.array_form[i]])
  }
  out
}

///|
pub fn Permutation::apply_string(self : Permutation, value : String) -> Array[Char] raise CombinatoricsError {
  let chars = string_to_chars(value)
  self.apply_array(chars)
}

///|
pub fn Permutation::mul(self : Permutation, other : Permutation) -> Permutation raise CombinatoricsError {
  if self.size != other.size {
    raise CombinatoricsError::ValueError("permutation sizes differ")
  }
  let arr = af_rmul(other.array_form, self.array_form)
  make_perm(arr)
}

///|
pub fn Permutation::pow(self : Permutation, n : Int) -> Permutation {
  make_perm(af_pow(self.array_form, n))
}

///|
pub fn Permutation::invert(self : Permutation) -> Permutation {
  make_perm(af_invert(self.array_form))
}

///|
pub fn Permutation::parity(self : Permutation) -> Int {
  af_parity(self.array_form)
}

///|
pub fn Permutation::is_even(self : Permutation) -> Bool {
  self.parity() == 0
}

///|
pub fn Permutation::is_odd(self : Permutation) -> Bool {
  !self.is_even()
}

///|
pub fn Permutation::signature(self : Permutation) -> Int {
  if self.parity() == 0 { 1 } else { -1 }
}

///|
pub fn Permutation::support(self : Permutation) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for i in 0..<self.size {
    if self.array_form[i] != i {
      out.push(i)
    }
  }
  out
}

///|
pub fn Permutation::length(self : Permutation) -> Int {
  self.support().length()
}

///|
pub fn Permutation::min(self : Permutation) -> Int raise CombinatoricsError {
  let mut found = false
  let mut min_val = 0
  for i in 0..<self.size {
    let v = self.array_form[i]
    if v != i {
      if !found || v < min_val {
        min_val = v
        found = true
      }
    }
  }
  if !found {
    raise CombinatoricsError::ValueError("min() argument is empty")
  }
  min_val
}

///|
pub fn Permutation::max(self : Permutation) -> Int raise CombinatoricsError {
  let mut found = false
  let mut max_val = 0
  for i in 0..<self.size {
    let v = self.array_form[i]
    if v != i {
      if !found || v > max_val {
        max_val = v
        found = true
      }
    }
  }
  if !found {
    raise CombinatoricsError::ValueError("max() argument is empty")
  }
  max_val
}

///|
pub fn Permutation::ascents(self : Permutation) -> Array[Int] {
  let out : Array[Int] = Array::new()
  if self.size < 2 {
    return out
  }
  for i in 0..<(self.size - 1) {
    if self.array_form[i] < self.array_form[i + 1] {
      out.push(i)
    }
  }
  out
}

///|
pub fn Permutation::descents(self : Permutation) -> Array[Int] {
  let out : Array[Int] = Array::new()
  if self.size < 2 {
    return out
  }
  for i in 0..<(self.size - 1) {
    if self.array_form[i] > self.array_form[i + 1] {
      out.push(i)
    }
  }
  out
}

///|
pub fn Permutation::index(self : Permutation) -> Int {
  if self.size < 2 {
    return 0
  }
  let mut sum = 0
  for i in 0..<(self.size - 1) {
    if self.array_form[i] > self.array_form[i + 1] {
      sum = sum + i
    }
  }
  sum
}

///|
pub fn Permutation::inversions(self : Permutation) -> Int {
  let mut inv = 0
  for i in 0..<self.size {
    let vi = self.array_form[i]
    for j in (i + 1)..<self.size {
      if vi > self.array_form[j] {
        inv = inv + 1
      }
    }
  }
  inv
}

///|
pub fn Permutation::inversion_vector(self : Permutation) -> Array[Int] {
  let inv : Array[Int] = Array::new()
  if self.size <= 1 {
    return inv
  }
  for i in 0..<(self.size - 1) {
    let mut count = 0
    for j in (i + 1)..<self.size {
      if self.array_form[j] < self.array_form[i] {
        count = count + 1
      }
    }
    inv.push(count)
  }
  inv
}

///|
pub fn Permutation::from_inversion_vector(inversion : Array[Int]) -> Permutation raise CombinatoricsError {
  let size = inversion.length()
  let pool : Array[Int] = Array::new()
  for i in 0..=size {
    pool.push(i)
  }
  let perm : Array[Int] = Array::new()
  for k in 0..<size {
    if inversion[k] < 0 || inversion[k] >= pool.length() {
      raise CombinatoricsError::ValueError("invalid inversion vector")
    }
    let val = pool[inversion[k]]
    perm.push(val)
    let _ = pool.remove(inversion[k])
  }
  for v in pool {
    perm.push(v)
  }
  make_perm(perm)
}

///|
fn build_cycles(array : Array[Int], include_singletons : Bool) -> Array[Array[Int]] {
  let n = array.length()
  let visited : Array[Bool] = Array::make(n, false)
  let cycles : Array[Array[Int]] = Array::new()
  for i in 0..<n {
    if visited[i] {
      continue
    }
    let mut j = i
    let cycle : Array[Int] = Array::new()
    while !visited[j] {
      visited[j] = true
      cycle.push(j)
      j = array[j]
    }
    if cycle.length() == 1 && array[cycle[0]] == cycle[0] && !include_singletons {
      continue
    }
    cycles.push(rotate_cycle_to_min(cycle))
  }
  sort_cycles(cycles)
}

///|
pub fn Permutation::cyclic_form(self : Permutation) -> Array[Array[Int]] {
  match self.cyclic_form_cache {
    Some(c) => c
    None => {
      let c = build_cycles(self.array_form, false)
      self.cyclic_form_cache = Some(c)
      self.cyclic_form_cache.unwrap()
    }
  }
}

///|
pub fn Permutation::full_cyclic_form(self : Permutation) -> Array[Array[Int]] {
  match self.full_cyclic_form_cache {
    Some(c) => c
    None => {
      let c = build_cycles(self.array_form, true)
      self.full_cyclic_form_cache = Some(c)
      self.full_cyclic_form_cache.unwrap()
    }
  }
}

///|
pub fn Permutation::cycle_structure_pairs(self : Permutation) -> Array[(Int, Int)] {
  match self.cycle_structure_cache {
    Some(map) => {
      let pairs : Array[(Int, Int)] = Array::new()
      for k, v in map {
        pairs.push((k, v))
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
      pairs
    }
    None => {
      let map : Map[Int, Int] = {}
      let mut singletons = self.size
      for cycle in self.cyclic_form() {
        let len = cycle.length()
        singletons = singletons - len
        let curr = match map.get(len) {
          Some(v) => v
          None => 0
        }
        map[len] = curr + 1
      }
      if singletons > 0 {
        map[1] = singletons
      }
      self.cycle_structure_cache = Some(map)
      self.cycle_structure_pairs()
    }
  }
}

///|
pub fn Permutation::cycles(self : Permutation) -> Int {
  self.full_cyclic_form().length()
}

///|
pub fn Permutation::transpositions(self : Permutation) -> Array[(Int, Int)] {
  let res : Array[(Int, Int)] = Array::new()
  for cycle in self.cyclic_form() {
    let len = cycle.length()
    if len == 2 {
      res.push((cycle[0], cycle[1]))
    } else if len > 2 {
      let first = cycle[0]
      let mut idx = len - 1
      while idx > 0 {
        res.push((first, cycle[idx]))
        idx = idx - 1
      }
    }
  }
  res
}

///|
pub fn Permutation::order(self : Permutation) -> Int {
  let mut ord = 1
  for cycle in self.cyclic_form() {
    ord = lcm_int(ord, cycle.length())
  }
  if ord == 0 { 1 } else { ord }
}

///|
pub fn Permutation::cardinality(self : Permutation) -> Int {
  factorial_int(self.size)
}

///|
pub fn Permutation::rank(self : Permutation) -> Int {
  if self.size <= 1 {
    return 0
  }
  match self.rank_cache {
    Some(r) => r
    None => {
      let mut rank = 0
      let rho : Array[Int] = Array::new()
      for v in self.array_form {
        rho.push(v)
      }
      let mut n = self.size - 1
      let mut psize = factorial_int(n)
      for j in 0..<(self.size - 1) {
        rank = rank + rho[j] * psize
        for i in (j + 1)..<self.size {
          if rho[i] > rho[j] {
            rho[i] = rho[i] - 1
          }
        }
        if n > 0 {
          psize = psize / n
          n = n - 1
        }
      }
      self.rank_cache = Some(rank)
      rank
    }
  }
}

///|
pub fn Permutation::next_lex(self : Permutation) -> Permutation? {
  let perm : Array[Int] = self.array_form()
  let n = perm.length()
  if n < 2 {
    return None
  }
  let mut i = n - 2
  while i >= 0 && perm[i + 1] < perm[i] {
    if i == 0 {
      i = -1
      break
    }
    i = i - 1
  }
  if i < 0 {
    return None
  }
  let mut j = n - 1
  while perm[j] < perm[i] {
    j = j - 1
  }
  let tmp = perm[i]
  perm[i] = perm[j]
  perm[j] = tmp
  let mut left = i + 1
  let mut right = n - 1
  while left < right {
    let t = perm[left]
    perm[left] = perm[right]
    perm[right] = t
    left = left + 1
    right = right - 1
  }
  Some(make_perm(perm))
}

///|
pub fn Permutation::unrank_lex(size : Int, rank0 : Int) -> Permutation {
  let perm : Array[Int] = Array::make(size, 0)
  let mut psize = 1
  let mut rank = rank0
  for i in 0..<size {
    let new_psize = psize * (i + 1)
    let d = (rank % new_psize) / psize
    rank = rank - d * psize
    perm[size - i - 1] = d
    for j in (size - i)..<size {
      if perm[j] > d - 1 {
        perm[j] = perm[j] + 1
      }
    }
    psize = new_psize
  }
  make_perm(perm)
}

///|
pub fn Permutation::rank_nonlex(self : Permutation) -> Int {
  let n = self.size
  if n <= 1 {
    return 0
  }
  let perm : Array[Int] = self.array_form()
  let inv : Array[Int] = af_invert(perm)
  fn rank1(n0 : Int, perm0 : Array[Int], inv0 : Array[Int]) -> Int {
    if n0 == 1 {
      return 0
    }
    let s = perm0[n0 - 1]
    let t = inv0[n0 - 1]
    let tmp = perm0[n0 - 1]
    perm0[n0 - 1] = perm0[t]
    perm0[t] = tmp
    let tmp2 = inv0[n0 - 1]
    inv0[n0 - 1] = inv0[s]
    inv0[s] = tmp2
    s + n0 * rank1(n0 - 1, perm0, inv0)
  }
  rank1(n, perm, inv)
}

///|
pub fn Permutation::unrank_nonlex(size : Int, r0 : Int) -> Permutation {
  let n = size
  let mut r = r0
  let perm : Array[Int] = Array::new()
  for i in 0..<n {
    perm.push(i)
  }
  fn unrank1(n0 : Int, r1 : Int, a : Array[Int]) -> Unit {
    if n0 > 0 {
      let idx = r1 % n0
      let tmp = a[n0 - 1]
      a[n0 - 1] = a[idx]
      a[idx] = tmp
      unrank1(n0 - 1, r1 / n0, a)
    }
  }
  let card = factorial_int(n)
  if card > 0 {
    r = ((r % card) + card) % card
  }
  unrank1(n, r, perm)
  make_perm(perm)
}

///|
pub fn Permutation::next_nonlex(self : Permutation) -> Permutation? {
  let r = self.rank_nonlex()
  let card = self.cardinality()
  if card == 0 || r == card - 1 {
    return None
  }
  Some(Permutation::unrank_nonlex(self.size, r + 1))
}

///|
pub fn Permutation::rank_trotterjohnson(self : Permutation) -> Int {
  if self.array_form.is_empty() || self.is_identity() {
    return 0
  }
  if self.array_form.length() == 2 && self.array_form[0] == 1 && self.array_form[1] == 0 {
    return 1
  }
  let perm = self.array_form
  let n = self.size
  let mut rank = 0
  for j in 1..<n {
    let mut k = 1
    let mut i = 0
    while perm[i] != j {
      if perm[i] < j {
        k = k + 1
      }
      i = i + 1
    }
    let j1 = j + 1
    if rank % 2 == 0 {
      rank = j1 * rank + j1 - k
    } else {
      rank = j1 * rank + k - 1
    }
  }
  rank
}

///|
pub fn Permutation::unrank_trotterjohnson(size : Int, rank0 : Int) -> Permutation {
  let perm : Array[Int] = Array::make(size, 0)
  let mut r2 = 0
  let n = factorial_int(size)
  let mut pj = 1
  for j in 2..=size {
    pj = pj * j
    let r1 = (rank0 * pj) / n
    let k = r1 - j * r2
    if r2 % 2 == 0 {
      let pos = j - k - 1
      let mut i = j - 1
      while i > pos {
        perm[i] = perm[i - 1]
        i = i - 1
      }
      perm[pos] = j - 1
    } else {
      let pos = k
      let mut i = j - 1
      while i > pos {
        perm[i] = perm[i - 1]
        i = i - 1
      }
      perm[pos] = j - 1
    }
    r2 = r1
  }
  make_perm(perm)
}

///|
pub fn Permutation::next_trotterjohnson(self : Permutation) -> Permutation? {
  let pi = self.array_form()
  let n = pi.length()
  if n == 0 {
    return None
  }
  let mut st = 0
  let rho : Array[Int] = Array::new()
  for v in pi {
    rho.push(v)
  }
  let mut done = false
  let mut m = n - 1
  while m > 0 && !done {
    let mut d = 0
    for i in 0..<(m + 1) {
      if rho[i] == m {
        d = i
        break
      }
    }
    for i in d..<m {
      rho[i] = rho[i + 1]
    }
    let par = af_parity(take_prefix(rho, m))
    if par == 1 {
      if d == m {
        m = m - 1
      } else {
        let tmp = pi[st + d]
        pi[st + d] = pi[st + d + 1]
        pi[st + d + 1] = tmp
        done = true
      }
    } else {
      if d == 0 {
        m = m - 1
        st = st + 1
      } else {
        let tmp = pi[st + d]
        pi[st + d] = pi[st + d - 1]
        pi[st + d - 1] = tmp
        done = true
      }
    }
  }
  if m == 0 {
    return None
  }
  Some(make_perm(pi))
}

///|
pub fn Permutation::add(self : Permutation, other : Int) -> Permutation {
  let card = self.cardinality()
  let mut rank = self.rank() + other
  if card > 0 {
    rank = ((rank % card) + card) % card
  }
  Permutation::unrank_lex(self.size, rank)
}

///|
pub fn Permutation::sub(self : Permutation, other : Int) -> Permutation {
  self.add(-other)
}

///|
pub fn Permutation::commutes_with(self : Permutation, other : Permutation) -> Bool {
  af_commutes_with(self.array_form, other.array_form)
}

///|
pub fn Permutation::commutator(self : Permutation, other : Permutation) -> Permutation raise CombinatoricsError {
  let inv_other = other.invert()
  let inv_self = self.invert()
  let t1 = inv_other.mul(inv_self)
  let t2 = t1.mul(other)
  t2.mul(self)
}

///|
pub fn Permutation::is_identity(self : Permutation) -> Bool {
  if self.array_form.is_empty() {
    return true
  }
  for i in 0..<self.size {
    if self.array_form[i] != i {
      return false
    }
  }
  true
}

///|
pub fn Permutation::resize(self : Permutation, n : Int) -> Permutation raise CombinatoricsError {
  let aform = self.array_form()
  let l = aform.length()
  if n > l {
    for i in l..<n {
      aform.push(i)
    }
    return make_perm(aform)
  }
  if n < l {
    let new_cycles : Array[Array[Int]] = Array::new()
    for cycle in self.full_cyclic_form() {
      let mut cycle_min = cycle[0]
      let mut cycle_max = cycle[0]
      for v in cycle {
        if v < cycle_min {
          cycle_min = v
        }
        if v > cycle_max {
          cycle_max = v
        }
      }
      if cycle_min <= n - 1 {
        if cycle_max > n - 1 {
          raise CombinatoricsError::ValueError(
            "The permutation cannot be resized to \{n} because the cycle may break.",
          )
        }
        new_cycles.push(cycle)
      }
    }
    return Permutation::from_cycles(new_cycles, size=n)
  }
  self
}

///|
pub fn Permutation::random(n : Int) -> Permutation {
  let arr : Array[Int] = Array::new()
  for i in 0..<n {
    arr.push(i)
  }
  let rand = @random.Rand::new()
  rand.shuffle(n, (i, j) => {
    let tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
  })
  make_perm(arr)
}

///|
pub fn Permutation::cycle_structure(self : Permutation) -> Map[Int, Int] {
  let map : Map[Int, Int] = {}
  for pair in self.cycle_structure_pairs() {
    map[pair.0] = pair.1
  }
  map
}

///|
pub fn Permutation::is_disjoint(self : Permutation, other : Permutation) -> Bool {
  let sup = self.support()
  for v in other.support() {
    if sup.any(x => x == v) {
      return false
    }
  }
  true
}
