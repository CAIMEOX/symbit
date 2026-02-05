///|
/// Free groups and free group elements (SymPy-style).

///|
pub enum GroupOrder {
  Finite(Int)
  Infinite
} derive(Eq)

///|
pub fn group_order_to_string(order : GroupOrder) -> String {
  match order {
    GroupOrder::Finite(n) => n.to_string()
    GroupOrder::Infinite => "oo"
  }
}

///|
pub impl Show for GroupOrder with output(self, logger : &Logger) -> Unit {
  logger.write_string(group_order_to_string(self))
}

///|
pub struct FreeGroup {
  symbols : Array[String]
  rank : Int
} derive(Eq)

///|
pub impl Hash for FreeGroup with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for FreeGroup with hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_int(self.rank)
  self.symbols.hash_combine(hasher)
}

///|
fn copy_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = Array::new()
  for v in values {
    out.push(v)
  }
  out
}

///|
fn parse_symbols_string(symbols : String) -> Array[String] {
  let out : Array[String] = Array::new()
  let mut buf = StringBuilder::new()
  let mut len = 0
  for c in symbols {
    if c == ',' || c.is_whitespace() {
      if len > 0 {
        out.push(buf.to_string())
        buf = StringBuilder::new()
        len = 0
      }
    } else {
      buf.write_char(c)
      len = len + 1
    }
  }
  if len > 0 {
    out.push(buf.to_string())
  }
  out
}

///|
pub fn FreeGroup::new(symbols : Array[String]) -> FreeGroup {
  let syms = copy_strings(symbols)
  { symbols: syms, rank: syms.length() }
}

///|
pub fn FreeGroup::symbols(self : FreeGroup) -> Array[String] {
  copy_strings(self.symbols)
}

///|
pub fn FreeGroup::generators(self : FreeGroup) -> Array[FreeGroupElement] {
  let out : Array[FreeGroupElement] = Array::new()
  for i in 0..<self.symbols.length() {
    out.push(free_group_element(self, [(i, 1)]))
  }
  out
}

///|
pub fn FreeGroup::identity(self : FreeGroup) -> FreeGroupElement {
  free_group_element(self, [])
}

///|
pub fn FreeGroup::index(
  self : FreeGroup,
  gen : FreeGroupElement,
) -> Int raise CombinatoricsError {
  if !free_group_same(self, gen.group) {
    raise CombinatoricsError::ValueError("generator not in free group")
  }
  let arr = gen.array_form
  if arr.length() != 1 || arr[0].1 != 1 {
    raise CombinatoricsError::ValueError(
      "expected a generator of the free group",
    )
  }
  arr[0].0
}

///|
pub fn FreeGroup::order(self : FreeGroup) -> GroupOrder {
  if self.rank == 0 {
    GroupOrder::Finite(1)
  } else {
    GroupOrder::Infinite
  }
}

///|
pub fn FreeGroup::elements(
  self : FreeGroup,
) -> Array[FreeGroupElement] raise CombinatoricsError {
  if self.rank == 0 {
    [self.identity()]
  } else {
    raise CombinatoricsError::ValueError(
      "group contains infinitely many elements",
    )
  }
}

///|
pub fn FreeGroup::is_abelian(self : FreeGroup) -> Bool {
  self.rank == 0 || self.rank == 1
}

///|
pub fn FreeGroup::contains(self : FreeGroup, g : FreeGroupElement) -> Bool {
  free_group_same(self, g.group)
}

///|
pub fn FreeGroup::center(self : FreeGroup) -> Array[FreeGroupElement] {
  [self.identity()]
}

///|
pub fn FreeGroup::to_string(self : FreeGroup) -> String {
  if self.rank > 30 {
    "<free group with \{self.rank} generators>"
  } else {
    let gens = self.generators().map(g => g.to_string()).join(", ")
    "<free group on the generators (\{gens})>"
  }
}

///|
pub impl Show for FreeGroup with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn free_group_same(a : FreeGroup, b : FreeGroup) -> Bool {
  a.symbols == b.symbols
}

///|
pub fn free_group(symbols : String) -> (FreeGroup, Array[FreeGroupElement]) {
  let syms = parse_symbols_string(symbols)
  let group = FreeGroup::new(syms)
  (group, group.generators())
}

///|
pub fn free_group_from_array(
  symbols : Array[String],
) -> (FreeGroup, Array[FreeGroupElement]) {
  let group = FreeGroup::new(symbols)
  (group, group.generators())
}

///|
pub fn xfree_group(symbols : String) -> (FreeGroup, Array[FreeGroupElement]) {
  free_group(symbols)
}

///|
pub fn vfree_group(symbols : String) -> FreeGroup {
  let (g, _) = free_group(symbols)
  g
}

///|
pub struct FreeGroupElement {
  group : FreeGroup
  array_form : Array[(Int, Int)]
} derive(Eq)

///|
pub impl Hash for FreeGroupElement with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for FreeGroupElement with hash_combine(self, hasher : Hasher) -> Unit {
  self.group.hash_combine(hasher)
  self.array_form.hash_combine(hasher)
}

///|
fn normalize_array_form(array : Array[(Int, Int)]) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = Array::new()
  for pair in array {
    let idx = pair.0
    let exp = pair.1
    if exp == 0 {
      continue
    }
    if !out.is_empty() && out[out.length() - 1].0 == idx {
      let prev = out[out.length() - 1]
      let sum = prev.1 + exp
      let _ = out.pop()
      if sum != 0 {
        out.push((idx, sum))
      }
    } else {
      out.push((idx, exp))
    }
  }
  out
}

///|
fn free_group_element(
  group : FreeGroup,
  array : Array[(Int, Int)],
) -> FreeGroupElement {
  { group, array_form: normalize_array_form(array) }
}

///|
pub fn free_group_element_from_form(
  group : FreeGroup,
  array : Array[(Int, Int)],
) -> FreeGroupElement {
  free_group_element(group, array)
}

///|
pub fn FreeGroupElement::copy(self : FreeGroupElement) -> FreeGroupElement {
  let out : Array[(Int, Int)] = Array::new()
  for pair in self.array_form {
    out.push(pair)
  }
  free_group_element(self.group, out)
}

///|
pub fn FreeGroupElement::is_identity(self : FreeGroupElement) -> Bool {
  self.array_form.is_empty()
}

///|
pub fn FreeGroupElement::array_form(
  self : FreeGroupElement,
) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = Array::new()
  for pair in self.array_form {
    out.push(pair)
  }
  out
}

///|
fn letter_from_pair(pair : (Int, Int)) -> Array[Int] {
  let idx = pair.0
  let exp = pair.1
  let count = if exp < 0 { -exp } else { exp }
  let letter = if exp < 0 { -(idx + 1) } else { idx }
  let out : Array[Int] = Array::new()
  for _ in 0..<count {
    out.push(letter)
  }
  out
}

///|
pub fn FreeGroupElement::letter_form(self : FreeGroupElement) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for pair in self.array_form {
    let letters = letter_from_pair(pair)
    for l in letters {
      out.push(l)
    }
  }
  out
}

///|
pub fn FreeGroupElement::letter_form_elm(
  self : FreeGroupElement,
) -> Array[FreeGroupElement] {
  let out : Array[FreeGroupElement] = Array::new()
  let letters = self.letter_form()
  for l in letters {
    out.push(letter_to_element(self.group, l))
  }
  out
}

///|
fn letter_to_element(group : FreeGroup, letter : Int) -> FreeGroupElement {
  let idx = if letter < 0 { -letter - 1 } else { letter }
  let exp = if letter < 0 { -1 } else { 1 }
  free_group_element(group, [(idx, exp)])
}

///|
pub fn FreeGroupElement::ext_rep(self : FreeGroupElement) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for pair in self.array_form {
    out.push(pair.0)
    out.push(pair.1)
  }
  out
}

///|
pub fn FreeGroupElement::length(self : FreeGroupElement) -> Int {
  let mut total = 0
  for pair in self.array_form {
    let exp = pair.1
    total = total + (if exp < 0 { -exp } else { exp })
  }
  total
}

///|
pub fn FreeGroupElement::to_string(self : FreeGroupElement) -> String {
  if self.is_identity() {
    return "<identity>"
  }
  let mut s = ""
  for i in 0..<self.array_form.length() {
    let pair = self.array_form[i]
    let name = self.group.symbols[pair.0]
    let exp = pair.1
    let part = if exp == 1 { name } else { "\{name}**\{exp}" }
    if i == 0 {
      s = part
    } else {
      s = "\{s}*\{part}"
    }
  }
  s
}

///|
pub impl Show for FreeGroupElement with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn FreeGroupElement::mul(
  self : FreeGroupElement,
  other : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  if !free_group_same(self.group, other.group) {
    raise CombinatoricsError::ValueError(
      "elements are from different free groups",
    )
  }
  if self.is_identity() {
    return other
  }
  if other.is_identity() {
    return self
  }
  let out : Array[(Int, Int)] = Array::new()
  for pair in self.array_form {
    out.push(pair)
  }
  for pair in other.array_form {
    out.push(pair)
  }
  free_group_element(self.group, out)
}

///|
pub fn FreeGroupElement::pow(
  self : FreeGroupElement,
  n : Int,
) -> FreeGroupElement raise CombinatoricsError {
  if n == 0 {
    return self.group.identity()
  }
  if n < 0 {
    return self.inverse().pow(-n)
  }
  if n == 1 {
    return self
  }
  let mut result = self.group.identity()
  let mut base = self
  let mut exp = n
  while exp > 0 {
    if (exp & 1) == 1 {
      result = result.mul(base)
    }
    exp = exp >> 1
    if exp == 0 {
      break
    }
    base = base.mul(base)
  }
  result
}

///|
pub fn FreeGroupElement::inverse(self : FreeGroupElement) -> FreeGroupElement {
  if self.is_identity() {
    return self
  }
  let out : Array[(Int, Int)] = Array::new()
  let mut idx = self.array_form.length()
  while idx > 0 {
    idx = idx - 1
    let pair = self.array_form[idx]
    out.push((pair.0, -pair.1))
  }
  free_group_element(self.group, out)
}

///|
pub fn FreeGroupElement::div(
  self : FreeGroupElement,
  other : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  self.mul(other.inverse())
}

///|
pub fn FreeGroupElement::order(self : FreeGroupElement) -> GroupOrder {
  if self.is_identity() {
    GroupOrder::Finite(1)
  } else {
    GroupOrder::Infinite
  }
}

///|
pub fn FreeGroupElement::commutator(
  self : FreeGroupElement,
  other : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  if !free_group_same(self.group, other.group) {
    raise CombinatoricsError::ValueError(
      "commutator requires elements from same group",
    )
  }
  self.inverse().mul(other.inverse()).mul(self).mul(other)
}

///|
pub fn FreeGroupElement::contains(
  self : FreeGroupElement,
  gen : FreeGroupElement,
) -> Bool {
  let arr = gen.array_form
  if arr.length() != 1 {
    return false
  }
  let idx = arr[0].0
  for pair in self.array_form {
    if pair.0 == idx {
      return true
    }
  }
  false
}

///|
pub fn FreeGroupElement::index(
  self : FreeGroupElement,
  gen : FreeGroupElement,
) -> Int raise CombinatoricsError {
  if gen.length() != 1 {
    raise CombinatoricsError::ValueError("expected generator or inverse")
  }
  let target = gen.letter_form()
  if target.is_empty() {
    raise CombinatoricsError::ValueError("empty generator")
  }
  let letters = self.letter_form()
  let idx = target[0]
  for i in 0..<letters.length() {
    if letters[i] == idx {
      return i
    }
  }
  raise CombinatoricsError::ValueError("generator not found in word")
}

///|
pub fn FreeGroupElement::letter_at(
  self : FreeGroupElement,
  index : Int,
) -> FreeGroupElement raise CombinatoricsError {
  let letters = self.letter_form()
  let mut idx = index
  if idx < 0 {
    idx = letters.length() + idx
  }
  if idx < 0 || idx >= letters.length() {
    raise CombinatoricsError::ValueError("letter index out of range")
  }
  letter_to_element(self.group, letters[idx])
}

///|
pub fn FreeGroupElement::exponent_sum(
  self : FreeGroupElement,
  gen : FreeGroupElement,
) -> Int raise CombinatoricsError {
  if gen.length() != 1 {
    raise CombinatoricsError::ValueError("gen must be a generator or inverse")
  }
  let gpair = gen.array_form[0]
  let idx = gpair.0
  let sign = gpair.1
  let mut total = 0
  for pair in self.array_form {
    if pair.0 == idx {
      total = total + pair.1
    }
  }
  total * sign
}

///|
pub fn FreeGroupElement::generator_count(
  self : FreeGroupElement,
  gen : FreeGroupElement,
) -> Int raise CombinatoricsError {
  if gen.length() != 1 || gen.array_form[0].1 < 0 {
    raise CombinatoricsError::ValueError("gen must be a generator")
  }
  let idx = gen.array_form[0].0
  let mut total = 0
  for pair in self.array_form {
    if pair.0 == idx {
      let exp = pair.1
      total = total + (if exp < 0 { -exp } else { exp })
    }
  }
  total
}

///|
pub fn FreeGroupElement::subword(
  self : FreeGroupElement,
  from_i : Int,
  to_j : Int,
  strict? : Bool = true,
) -> FreeGroupElement raise CombinatoricsError {
  let len = self.length()
  let mut start = from_i
  let mut end = to_j
  if !strict {
    if start < 0 {
      start = 0
    }
    if end > len {
      end = len
    }
  }
  if start < 0 || end > len {
    raise CombinatoricsError::ValueError("subword indices out of range")
  }
  if end <= start {
    return self.group.identity()
  }
  let letters = self.letter_form()
  let slice : Array[Int] = Array::new()
  for i in start..<end {
    slice.push(letters[i])
  }
  let arr = letter_form_to_array_form(slice)
  free_group_element(self.group, arr)
}

///|
pub fn FreeGroupElement::subword_index(
  self : FreeGroupElement,
  word : FreeGroupElement,
  start? : Int = 0,
) -> Int raise CombinatoricsError {
  let l = word.length()
  let self_lf = self.letter_form()
  let word_lf = word.letter_form()
  let mut i = start
  while i <= self_lf.length() - l {
    let mut ok = true
    for j in 0..<l {
      if self_lf[i + j] != word_lf[j] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
    i = i + 1
  }
  raise CombinatoricsError::ValueError("word is not a subword")
}

///|
pub fn FreeGroupElement::is_dependent(
  self : FreeGroupElement,
  word : FreeGroupElement,
) -> Bool {
  let res = try? self.subword_index(word)
  match res {
    Ok(_) => true
    Err(_) => {
      let res2 = try? self.subword_index(word.inverse())
      match res2 {
        Ok(_) => true
        Err(_) => false
      }
    }
  }
}

///|
pub fn FreeGroupElement::is_independent(
  self : FreeGroupElement,
  word : FreeGroupElement,
) -> Bool {
  !self.is_dependent(word)
}

///|
pub fn FreeGroupElement::contains_generators(
  self : FreeGroupElement,
) -> Array[FreeGroupElement] {
  let seen : Array[Bool] = Array::make(self.group.rank, false)
  let out : Array[FreeGroupElement] = Array::new()
  for pair in self.array_form {
    let idx = pair.0
    if idx >= 0 && idx < seen.length() && !seen[idx] {
      seen[idx] = true
      out.push(letter_to_element(self.group, idx))
    }
  }
  out
}

///|
pub fn FreeGroupElement::number_syllables(self : FreeGroupElement) -> Int {
  self.array_form.length()
}

///|
pub fn FreeGroupElement::exponent_syllable(
  self : FreeGroupElement,
  i : Int,
) -> Int raise CombinatoricsError {
  let mut idx = i
  let n = self.array_form.length()
  if idx < 0 {
    idx = n + idx
  }
  if idx < 0 || idx >= n {
    raise CombinatoricsError::ValueError("syllable index out of range")
  }
  self.array_form[idx].1
}

///|
pub fn FreeGroupElement::generator_syllable(
  self : FreeGroupElement,
  i : Int,
) -> Int raise CombinatoricsError {
  let mut idx = i
  let n = self.array_form.length()
  if idx < 0 {
    idx = n + idx
  }
  if idx < 0 || idx >= n {
    raise CombinatoricsError::ValueError("syllable index out of range")
  }
  self.array_form[idx].0
}

///|
pub fn FreeGroupElement::sub_syllables(
  self : FreeGroupElement,
  from_i : Int,
  to_j : Int,
) -> FreeGroupElement raise CombinatoricsError {
  if to_j <= from_i {
    return self.group.identity()
  }
  if from_i < 0 || to_j > self.array_form.length() {
    raise CombinatoricsError::ValueError("syllable indices out of range")
  }
  let out : Array[(Int, Int)] = Array::new()
  for i in from_i..<to_j {
    out.push(self.array_form[i])
  }
  free_group_element(self.group, out)
}

///|
pub fn FreeGroupElement::substituted_word(
  self : FreeGroupElement,
  from_i : Int,
  to_j : Int,
  by : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  let lw = self.length()
  if from_i >= to_j || from_i > lw || to_j > lw {
    raise CombinatoricsError::ValueError("values should be within bounds")
  }
  if from_i == 0 && to_j == lw {
    return by
  }
  if from_i == 0 {
    return by.mul(self.subword(to_j, lw))
  }
  if to_j == lw {
    return self.subword(0, from_i).mul(by)
  }
  self.subword(0, from_i).mul(by).mul(self.subword(to_j, lw))
}

///|
pub fn FreeGroupElement::eliminate_word(
  self : FreeGroupElement,
  gen : FreeGroupElement,
  by? : FreeGroupElement,
  all? : Bool = false,
  inverse? : Bool = true,
) -> FreeGroupElement raise CombinatoricsError {
  let by_word = match by {
    Some(v) => v
    None => self.group.identity()
  }
  if self.is_independent(gen) || gen == by_word {
    return self
  }
  if gen == self {
    return by_word
  }
  let mut local_all = all
  if gen.inverse() == by_word {
    local_all = false
  }
  let word = self
  let l = gen.length()
  let mut k = 1
  let i = match (try? word.subword_index(gen)) {
    Ok(v) => v
    Err(_) => {
      if !inverse {
        return word
      }
      let inv = gen.inverse()
      match (try? word.subword_index(inv)) {
        Ok(v2) => {
          k = -1
          v2
        }
        Err(_) => return word
      }
    }
  }
  let left = word.subword(0, i)
  let right = word.subword(i + l, word.length())
  let repl = by_word.pow(k)
  let reduced_right = right.eliminate_word(gen, by=by_word)
  let mut out = left.mul(repl).mul(reduced_right)
  if local_all {
    out = out.eliminate_word(gen, by=by_word, all=true, inverse~)
  }
  out
}

///|
pub fn FreeGroupElement::eliminate_words(
  self : FreeGroupElement,
  words : Array[FreeGroupElement],
  all? : Bool = false,
  inverse? : Bool = true,
) -> FreeGroupElement raise CombinatoricsError {
  let mut again = true
  let mut new_word = self
  while again {
    again = false
    for sub in words {
      let prev = new_word
      new_word = new_word.eliminate_word(sub, all~, inverse~)
      if new_word != prev {
        again = true
      }
    }
  }
  new_word
}

///|
pub fn FreeGroupElement::eliminate_words_map(
  self : FreeGroupElement,
  words : Map[FreeGroupElement, FreeGroupElement],
  all? : Bool = false,
  inverse? : Bool = true,
) -> FreeGroupElement raise CombinatoricsError {
  let mut again = true
  let mut new_word = self
  while again {
    again = false
    for sub, rep in words {
      let prev = new_word
      new_word = new_word.eliminate_word(sub, by=rep, all~, inverse~)
      if new_word != prev {
        again = true
      }
    }
  }
  new_word
}

///|
pub fn FreeGroupElement::cyclic_subword(
  self : FreeGroupElement,
  from_i : Int,
  to_j : Int,
) -> FreeGroupElement {
  let l = self.length()
  let letters = self.letter_form()
  if l == 0 {
    return self
  }
  let mut start = from_i
  let mut end = to_j
  let period1 = start / l
  if start >= l {
    start = start - l * period1
    end = end - l * period1
  }
  let diff = end - start
  let word : Array[Int] = Array::new()
  for i in start..<end {
    if i >= 0 && i < letters.length() {
      word.push(letters[i])
    }
  }
  let period2 = end / l - 1
  for _ in 0..<period2 {
    for ltr in letters {
      word.push(ltr)
    }
  }
  let extra = diff - l + start - l * period2
  if extra > 0 {
    for i in 0..<extra {
      let idx = i
      if idx >= 0 && idx < letters.length() {
        word.push(letters[idx])
      }
    }
  }
  let arr = letter_form_to_array_form(word)
  free_group_element(self.group, arr)
}

///|
pub fn FreeGroupElement::cyclic_conjugates(
  self : FreeGroupElement,
) -> Array[FreeGroupElement] {
  let out : Array[FreeGroupElement] = Array::new()
  let seen : Map[String, Bool] = {}
  let l = self.length()
  for i in 0..<l {
    let w = self.cyclic_subword(i, i + l)
    let key = word_key(w)
    if !seen.contains(key) {
      seen[key] = true
      out.push(w)
    }
  }
  out
}

///|
pub fn FreeGroupElement::is_cyclic_conjugate(
  self : FreeGroupElement,
  w : FreeGroupElement,
) -> Bool {
  if self.length() != w.length() {
    return false
  }
  let w1 = self.identity_cyclic_reduction()
  let w2 = w.identity_cyclic_reduction()
  let letter1 = w1.letter_form()
  let letter2 = w2.letter_form()
  if letter1.length() != letter2.length() {
    return false
  }
  if letter1.is_empty() {
    return true
  }
  let doubled : Array[Int] = Array::new()
  for ltr in letter2 {
    doubled.push(ltr)
  }
  for ltr in letter2 {
    doubled.push(ltr)
  }
  let n = letter1.length()
  let mut i = 0
  while i + n <= doubled.length() {
    let mut ok = true
    for j in 0..<n {
      if doubled[i + j] != letter1[j] {
        ok = false
        break
      }
    }
    if ok {
      return true
    }
    i = i + 1
  }
  false
}

///|
pub fn FreeGroupElement::is_cyclically_reduced(self : FreeGroupElement) -> Bool {
  if self.is_identity() {
    return true
  }
  let first = self.letter_at(0) catch { _ => return true }
  let last = self.letter_at(-1) catch { _ => return true }
  first != last.inverse()
}

///|
pub fn FreeGroupElement::identity_cyclic_reduction(
  self : FreeGroupElement,
) -> FreeGroupElement {
  let mut word = self.copy()
  while !word.is_cyclically_reduced() {
    let exp1 = word.exponent_syllable(0) catch { _ => 0 }
    let exp2 = word.exponent_syllable(-1) catch { _ => 0 }
    let r = exp1 + exp2
    let rep = if r == 0 {
      let slice : Array[(Int, Int)] = Array::new()
      let n = word.number_syllables()
      for i in 1..<(n - 1) {
        slice.push(word.array_form[i])
      }
      slice
    } else {
      let slice : Array[(Int, Int)] = Array::new()
      let gen = word.generator_syllable(0) catch { _ => 0 }
      slice.push((gen, r))
      let n = word.number_syllables()
      for i in 1..<(n - 1) {
        slice.push(word.array_form[i])
      }
      slice
    }
    word = free_group_element(word.group, rep)
  }
  word
}

///|
pub fn FreeGroupElement::cyclic_reduction(
  self : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  let (w, _) = self.cyclic_reduction_removed()
  w
}

///|
pub fn FreeGroupElement::cyclic_reduction_removed(
  self : FreeGroupElement,
) -> (FreeGroupElement, FreeGroupElement) raise CombinatoricsError {
  let mut word = self.copy()
  let mut g = self.group.identity()
  while !word.is_cyclically_reduced() {
    let exp1 = word.exponent_syllable(0) catch { _ => 0 }
    let exp2 = word.exponent_syllable(-1) catch { _ => 0 }
    let exp = if exp1 < 0 { -exp1 } else { exp1 }
    let expb = if exp2 < 0 { -exp2 } else { exp2 }
    let min_exp = if exp < expb { exp } else { expb }
    let start = word.letter_at(0) catch { _ => word.group.identity() }
    let end = word.letter_at(-1) catch { _ => word.group.identity() }
    let start_pow = start.pow(min_exp)
    let end_pow = end.pow(min_exp)
    word = start_pow.inverse().mul(word).mul(end_pow.inverse())
    g = g.mul(start_pow)
  }
  (word, g)
}

///|
pub fn FreeGroupElement::power_of(
  self : FreeGroupElement,
  other : FreeGroupElement,
) -> Bool raise CombinatoricsError {
  if self.is_identity() {
    return true
  }
  let l = other.length()
  if l == 1 {
    let gens = self.contains_generators()
    let mut has = false
    for g in gens {
      if g == other || g == other.inverse() {
        has = true
        break
      }
    }
    return gens.length() == 1 && has
  }
  let (reduced, r1) = self.cyclic_reduction_removed()
  if !r1.is_identity() {
    let (other_red, r2) = other.cyclic_reduction_removed()
    if r1 == r2 {
      return reduced.power_of(other_red)
    }
    return false
  }
  if self.length() < l || self.length() % l != 0 {
    return false
  }
  let prefix = self.subword(0, l) catch { _ => return false }
  if prefix == other || prefix == other.inverse() {
    let rest = self.subword(l, self.length()) catch { _ => return false }
    return rest.power_of(other)
  }
  false
}

///|
fn word_key(word : FreeGroupElement) -> String {
  let parts : Array[String] = Array::new()
  for pair in word.array_form {
    parts.push("\{pair.0}:\{pair.1}")
  }
  parts.join(",")
}

///|
pub fn letter_form_to_array_form(letters : Array[Int]) -> Array[(Int, Int)] {
  if letters.is_empty() {
    return []
  }
  let out : Array[(Int, Int)] = Array::new()
  let mut current = letters[0]
  let mut count = 1
  let flush = fn(current : Int, count : Int, out : Array[(Int, Int)]) -> Unit {
    let idx = if current < 0 { -current - 1 } else { current }
    let sign = if current < 0 { -1 } else { 1 }
    out.push((idx, sign * count))
  }
  for i in 1..<letters.length() {
    if letters[i] == current {
      count = count + 1
    } else {
      flush(current, count, out)
      current = letters[i]
      count = 1
    }
  }
  flush(current, count, out)
  out
}

///|
pub fn zero_mul_simp(values : Array[(Int, Int)]) -> Array[(Int, Int)] {
  normalize_array_form(values)
}

///|
pub impl Compare for FreeGroupElement with compare(
  self,
  other : FreeGroupElement,
) -> Int {
  if !free_group_same(self.group, other.group) {
    return self.group.symbols.join(",").compare(other.group.symbols.join(","))
  }
  let l = self.length()
  let m = other.length()
  if l != m {
    return l - m
  }
  for i in 0..<l {
    let a = self.letter_at(i) catch { _ => self }
    let b = other.letter_at(i) catch { _ => other }
    let ap = a.array_form[0]
    let bp = b.array_form[0]
    if ap.0 != bp.0 {
      return ap.0 - bp.0
    }
    if ap.1 != bp.1 {
      return ap.1 - bp.1
    }
  }
  0
}
