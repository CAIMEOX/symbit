///|
/// Partitions and integer partitions.

///|
fn bell_number(n : Int) -> Int {
  if n < 0 {
    return 0
  }
  if n == 0 {
    return 1
  }
  let triangle : Array[Array[Int]] = Array::new()
  for _ in 0..=n {
    triangle.push(Array::make(n + 1, 0))
  }
  triangle[0].set(0, 1)
  for i in 1..=n {
    triangle[i].set(0, triangle[i - 1][i - 1])
    for j in 1..=i {
      triangle[i].set(j, triangle[i - 1][j - 1] + triangle[i][j - 1])
    }
  }
  triangle[n][0]
}

///|
fn[T : Show] sort_by_string(values : Array[T]) -> Array[T] {
  let out : Array[T] = Array::new()
  for v in values {
    out.push(v)
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if out[j].to_string() < out[i].to_string() {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn[T : Show] block_compare(a : Array[T], b : Array[T]) -> Int {
  let min_len = if a.length() < b.length() { a.length() } else { b.length() }
  let mut i = 0
  while i < min_len {
    let ca = a[i].to_string()
    let cb = b[i].to_string()
    if ca < cb {
      return -1
    }
    if ca > cb {
      return 1
    }
    i = i + 1
  }
  if a.length() < b.length() { -1 } else if a.length() > b.length() { 1 } else { 0 }
}

///|
fn[T : Show] sort_blocks(blocks : Array[Array[T]]) -> Array[Array[T]] {
  let out : Array[Array[T]] = Array::new()
  for b in blocks {
    out.push(sort_by_string(b))
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if block_compare(out[j], out[i]) < 0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn array_compare_int(a : Array[Int], b : Array[Int]) -> Int {
  let min_len = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<min_len {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  if a.length() < b.length() { -1 } else if a.length() > b.length() { 1 } else { 0 }
}

///|
pub struct Partition[T] {
  blocks : Array[Array[T]]
  members : Array[T]
  mut rank_cache : Int?
  mut partition_cache : Array[Array[T]]?
}

///|
pub fn[T : Eq + Show] Partition::new(blocks : Array[Array[T]]) -> Partition[T] raise CombinatoricsError {
  let all_items : Array[T] = Array::new()
  for block in blocks {
    let seen : Array[T] = Array::new()
    for item in block {
      if seen.any(v => v == item) {
        raise CombinatoricsError::ValueError("Partition contained duplicate elements")
      }
      seen.push(item)
      all_items.push(item)
    }
  }
  let unique : Array[T] = Array::new()
  for item in all_items {
    if !unique.any(v => v == item) {
      unique.push(item)
    } else {
      raise CombinatoricsError::ValueError("Partition contained duplicate elements")
    }
  }
  let members = sort_by_string(unique)
  { blocks, members, rank_cache: None, partition_cache: None }
}

///|
pub fn[T : Show] Partition::partition(self : Partition[T]) -> Array[Array[T]] {
  match self.partition_cache {
    Some(p) => p
    None => {
      let sorted = sort_blocks(self.blocks)
      self.partition_cache = Some(sorted)
      self.partition_cache.unwrap()
    }
  }
}

///|
pub fn[T : Show] Partition::rgs(self : Partition[T]) -> Array[Int] {
  let parts = self.partition()
  let rgs_map : Array[(String, Int)] = Array::new()
  for i in 0..<parts.length() {
    for item in parts[i] {
      rgs_map.push((item.to_string(), i))
    }
  }
  let out : Array[Int] = Array::new()
  for item in self.members {
    let key = item.to_string()
    let mut idx = 0
    for pair in rgs_map {
      if pair.0 == key {
        idx = pair.1
        break
      }
    }
    out.push(idx)
  }
  out
}

///|
pub fn[T : Show] Partition::rank(self : Partition[T]) -> Int {
  match self.rank_cache {
    Some(r) => r
    None => {
      let r = rgs_rank(self.rgs())
      self.rank_cache = Some(r)
      r
    }
  }
}

///|
pub fn[T : Eq + Show] Partition::add(self : Partition[T], other : Int) -> Partition[T] raise CombinatoricsError {
  let offset = self.rank() + other
  let total = rgs_enum(self.members.length())
  let mut rank = offset
  if total > 0 {
    rank = ((rank % total) + total) % total
  }
  let rgs = rgs_unrank(rank, self.members.length())
  Partition::from_rgs(rgs, self.members)
}

///|
pub fn[T : Eq + Show] Partition::sub(self : Partition[T], other : Int) -> Partition[T] raise CombinatoricsError {
  self.add(-other)
}

///|
pub fn[T : Eq + Show] Partition::from_rgs(
  rgs : Array[Int],
  elements : Array[T],
) -> Partition[T] raise CombinatoricsError {
  if rgs.length() != elements.length() {
    raise CombinatoricsError::ValueError("mismatch in rgs and element lengths")
  }
  let mut max_elem = 0
  for v in rgs {
    if v > max_elem {
      max_elem = v
    }
  }
  let blocks : Array[Array[T]] = Array::new()
  for _ in 0..=max_elem {
    blocks.push(Array::new())
  }
  for i in 0..<rgs.length() {
    let idx = rgs[i]
    blocks[idx].push(elements[i])
  }
  for b in blocks {
    if b.is_empty() {
      raise CombinatoricsError::ValueError("some blocks of the partition were empty")
    }
  }
  Partition::new(blocks)
}

///|
pub struct IntegerPartition {
  integer : Int
  partition : Array[Int]
  mut dict_cache : Map[Int, Int]?
  mut keys_cache : Array[Int]?
}

///|
pub fn IntegerPartition::new(
  partition : Array[Int],
  integer? : Int,
) -> IntegerPartition raise CombinatoricsError {
  let parts : Array[Int] = Array::new()
  for p in partition {
    if p < 1 {
      raise CombinatoricsError::ValueError("All integer summands must be greater than one")
    }
    parts.push(p)
  }
  parts.sort()
  let parts = array_reverse(parts)
  let total = parts.fold(init=0, (a, b) => a + b)
  let n = match integer {
    Some(v) => v
    None => total
  }
  if n != total {
    raise CombinatoricsError::ValueError("Partition did not add to integer")
  }
  { integer: n, partition: parts, dict_cache: None, keys_cache: None }
}

///|
pub fn IntegerPartition::from_dict(
  integer : Int,
  dict : Map[Int, Int],
) -> IntegerPartition raise CombinatoricsError {
  let parts : Array[Int] = Array::new()
  for key, value in dict {
    if value <= 0 {
      continue
    }
    for _ in 0..<value {
      parts.push(key)
    }
  }
  IntegerPartition::new(parts, integer=integer)
}

///|
pub fn IntegerPartition::as_dict(self : IntegerPartition) -> Map[Int, Int] {
  match self.dict_cache {
    Some(d) => d
    None => {
      let d : Map[Int, Int] = Map::new()
      for p in self.partition {
        let cur = match d.get(p) {
          Some(v) => v
          None => 0
        }
        d[p] = cur + 1
      }
      let keys : Array[Int] = Array::new()
      for k, _ in d {
        keys.push(k)
      }
      keys.sort()
      let keys = array_reverse(keys)
      self.dict_cache = Some(d)
      self.keys_cache = Some(keys)
      self.dict_cache.unwrap()
    }
  }
}

///|
pub fn IntegerPartition::prev_lex(self : IntegerPartition) -> IntegerPartition raise CombinatoricsError {
  let d : Map[Int, Int] = Map::new()
  for k, v in self.as_dict() {
    d[k] = v
  }
  let keys = self.keys_cache.unwrap()
  if keys.length() == 1 && keys[0] == 1 {
    let dict : Map[Int, Int] = Map::new()
    dict[self.integer] = 1
    return IntegerPartition::from_dict(self.integer, dict)
  }
  let last = keys[keys.length() - 1]
  if last != 1 {
    d[last] = d[last] - 1
    if last == 2 {
      d[1] = 2
    } else {
      d[last - 1] = 1
      d[1] = 1
    }
  } else {
    let second = keys[keys.length() - 2]
    d[second] = d[second] - 1
    let base = match d.get(1) {
      Some(v) => v
      None => 0
    }
    let mut left = base + second
    let mut newv = second
    d[1] = 0
    while left > 0 {
      newv = newv - 1
      if left - newv >= 0 {
        let mult = left / newv
        let cur = match d.get(newv) {
          Some(v) => v
          None => 0
        }
        d[newv] = cur + mult
        left = left - mult * newv
      }
    }
  }
  IntegerPartition::from_dict(self.integer, d)
}

///|
pub fn IntegerPartition::next_lex(self : IntegerPartition) -> IntegerPartition raise CombinatoricsError {
  let mut d : Map[Int, Int] = Map::new()
  for k, v in self.as_dict() {
    d[k] = v
  }
  let keys = self.keys_cache.unwrap()
  let a = keys[keys.length() - 1]
  if a == self.integer {
    let dict : Map[Int, Int] = Map::new()
    dict[1] = self.integer
    return IntegerPartition::from_dict(self.integer, dict)
  } else if a == 1 {
    if d[a] > 1 {
      let base = match d.get(a + 1) {
        Some(v) => v
        None => 0
      }
      d[a + 1] = base + 1
      d[a] = d[a] - 2
    } else {
      let b = keys[keys.length() - 2]
      let base = match d.get(b + 1) {
        Some(v) => v
        None => 0
      }
      d[b + 1] = base + 1
      d[1] = (d[b] - 1) * b
      d[b] = 0
    }
  } else {
    if d[a] > 1 {
      if keys.length() == 1 {
        let fresh : Map[Int, Int] = Map::new()
        fresh[a + 1] = 1
        fresh[1] = self.integer - a - 1
        d = fresh
      } else {
        let a1 = a + 1
        let base = match d.get(a1) {
          Some(v) => v
          None => 0
        }
        d[a1] = base + 1
        d[1] = d[a] * a - a1
        d[a] = 0
      }
    } else {
      let b = keys[keys.length() - 2]
      let b1 = b + 1
      let base = match d.get(b1) {
        Some(v) => v
        None => 0
      }
      d[b1] = base + 1
      let need = d[b] * b + d[a] * a - b1
      d[a] = 0
      d[b] = 0
      d[1] = need
    }
  }
  IntegerPartition::from_dict(self.integer, d)
}

///|
pub fn IntegerPartition::conjugate(self : IntegerPartition) -> Array[Int] {
  let mut j = 1
  let temp_arr : Array[Int] = Array::new()
  for v in self.partition {
    temp_arr.push(v)
  }
  temp_arr.push(0)
  let mut k = temp_arr[0]
  let b : Array[Int] = Array::make(k, 0)
  while k > 0 {
    while k > temp_arr[j] {
      b[k - 1] = j
      k = k - 1
    }
    j = j + 1
  }
  b
}

///|
pub fn IntegerPartition::as_ferrers(self : IntegerPartition, char? : Char = '#') -> String {
  let lines : Array[String] = Array::new()
  for p in self.partition {
    let chars : Array[Char] = Array::make(p, char)
    lines.push(chars_to_string(chars))
  }
  lines.join("\n")
}

///|
pub fn IntegerPartition::lt(self : IntegerPartition, other : IntegerPartition) -> Bool {
  let a = Array::new()
  let b = Array::new()
  for v in self.partition {
    a.push(v)
  }
  for v in other.partition {
    b.push(v)
  }
  let a = array_reverse(a)
  let b = array_reverse(b)
  array_compare_int(a, b) < 0
}

///|
pub fn IntegerPartition::le(self : IntegerPartition, other : IntegerPartition) -> Bool {
  let a = Array::new()
  let b = Array::new()
  for v in self.partition {
    a.push(v)
  }
  for v in other.partition {
    b.push(v)
  }
  let a = array_reverse(a)
  let b = array_reverse(b)
  array_compare_int(a, b) <= 0
}

///|
pub fn IntegerPartition::to_string(self : IntegerPartition) -> String {
  "\{self.partition}"
}

///|
pub fn random_integer_partition(n : Int, seed? : Array[Int]) -> Array[Int] raise CombinatoricsError {
  if n < 1 {
    raise CombinatoricsError::ValueError("n must be a positive integer")
  }
  let mut state = 0
  let mut seed_idx = 0
  let partition : Array[(Int, Int)] = Array::new()
  let mut remaining = n
  while remaining > 0 {
    let rand = match seed {
      Some(values) => {
        let val = values[seed_idx % values.length()]
        seed_idx = seed_idx + 1
        val
      }
      None => {
        state = (state * 1103515245 + 12345) & 0x7fffffff
        state
      }
    }
    let k = (rand % remaining) + 1
    let rand2 = match seed {
      Some(values) => {
        let val = values[seed_idx % values.length()]
        seed_idx = seed_idx + 1
        val
      }
      None => {
        state = (state * 1103515245 + 12345) & 0x7fffffff
        state
      }
    }
    let mult = (rand2 % (remaining / k)) + 1
    partition.push((k, mult))
    remaining = remaining - k * mult
  }
  let mut i = 0
  while i < partition.length() {
    let mut j = i + 1
    while j < partition.length() {
      if partition[j].0 > partition[i].0 {
        let tmp = partition[i]
        partition[i] = partition[j]
        partition[j] = tmp
      }
      j = j + 1
    }
    i = i + 1
  }
  let out : Array[Int] = Array::new()
  for pair in partition {
    let k = pair.0
    let mult = pair.1
    for _ in 0..<mult {
      out.push(k)
    }
  }
  out
}

///|
pub fn rgs_generalized(m : Int) -> Array[Array[Int]] {
  let d : Array[Array[Int]] = Array::new()
  for _ in 0..=m {
    d.push(Array::make(m + 1, 0))
  }
  for i in 0..=m {
    d[0].set(i, 1)
  }
  for i in 1..=m {
    for j in 0..<m {
      if j <= m - i {
        d[i].set(j, j * d[i - 1][j] + d[i - 1][j + 1])
      } else {
        d[i].set(j, 0)
      }
    }
  }
  d
}

///|
pub fn rgs_enum(m : Int) -> Int {
  if m < 1 {
    0
  } else if m == 1 {
    1
  } else {
    bell_number(m)
  }
}

///|
pub fn rgs_unrank(rank : Int, m : Int) -> Array[Int] raise CombinatoricsError {
  if m < 1 {
    raise CombinatoricsError::ValueError("The superset size must be >= 1")
  }
  let total = rgs_enum(m)
  if rank < 0 || rank >= total {
    raise CombinatoricsError::ValueError("Invalid arguments")
  }
  let mut r = rank
  let levels : Array[Int] = Array::make(m + 1, 1)
  let mut j = 1
  let d_table = rgs_generalized(m)
  for i in 2..=m {
    let v = d_table[m - i][j]
    let cr = j * v
    if cr <= r {
      levels[i] = j + 1
      r = r - cr
      j = j + 1
    } else {
      levels[i] = (r / v) + 1
      r = r % v
    }
  }
  let out : Array[Int] = Array::new()
  for i in 1..=m {
    out.push(levels[i] - 1)
  }
  out
}

///|
pub fn rgs_rank(rgs : Array[Int]) -> Int {
  let rgs_size = rgs.length()
  if rgs_size == 0 {
    return 0
  }
  let mut rank = 0
  let d_table = rgs_generalized(rgs_size)
  for i in 1..<rgs_size {
    let n = rgs_size - (i + 1)
    let mut m = 0
    for j in 0..<i {
      if rgs[j] > m {
        m = rgs[j]
      }
    }
    rank = rank + d_table[n][m + 1] * rgs[i]
  }
  rank
}
