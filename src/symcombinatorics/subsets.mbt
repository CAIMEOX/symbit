///|
/// Ranked subset objects and subset-order traversals.
///
/// This module follows `sympy.combinatorics.subsets`: a `Subset` is a chosen subset of a
/// fixed ordered superset, together with conversions between binary, lexicographic, and
/// Gray-code traversals.  The ordering always depends on the explicit order of the supplied
/// superset.

///|
/// A subset of a fixed ordered superset.
///
/// The object caches ranks in several traversal orders and provides the same rank/unrank
/// and successor/predecessor operations exposed by SymPy's `Subset`.
pub struct Subset[T] {
  subset : Array[T]
  superset : Array[T]
  rank_binary_cache : Int?
  rank_lex_cache : Int?
  rank_gray_cache : Int?
}

///|
fn array_contains(values : Array[Int], value : Int) -> Bool {
  values.any(v => v == value)
}

///|
fn array_remove_first(values : Array[Int], value : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  let mut removed = false
  for v in values {
    if !removed && v == value {
      removed = true
      continue
    }
    out.push(v)
  }
  out
}

///|
/// Build a subset object from explicit subset and superset arrays.
///
/// Validation matches SymPy: every subset element must occur in the superset, and the
/// subset cannot be larger than the superset itself.
pub fn[T : Eq] Subset::new(
  subset : Array[T],
  superset : Array[T],
) -> Subset[T] raise CombinatoricsError {
  if subset.length() > superset.length() {
    raise CombinatoricsError::ValueError(
      "The superset must be larger than the subset",
    )
  }
  for elem in subset {
    if !superset.any(v => v == elem) {
      raise CombinatoricsError::ValueError("Superset does not contain element")
    }
  }
  {
    subset,
    superset,
    rank_binary_cache: None,
    rank_lex_cache: None,
    rank_gray_cache: None,
  }
}

///|
/// Move by `k` steps in binary rank order.
///
/// The subset is represented by its characteristic bitlist and advanced modulo `2^n`,
/// where `n` is the size of the superset.
pub fn[T : Eq] Subset::iterate_binary(
  self : Subset[T],
  k : Int,
) -> Subset[T] raise CombinatoricsError {
  let bin_list = Subset::bitlist_from_subset(self.subset, self.superset)
  let n = bin_to_int(bin_list)
  let total = pow_int(2, self.superset.length())
  let mut next_rank = n + k
  if total > 0 {
    next_rank = (next_rank % total + total) % total
  }
  let bits = int_to_bin(next_rank, self.superset.length())
  Subset::subset_from_bitlist(self.superset, bits)
}

///|
/// Return the next subset in binary rank order.
pub fn[T : Eq] Subset::next_binary(
  self : Subset[T],
) -> Subset[T] raise CombinatoricsError {
  self.iterate_binary(1)
}

///|
/// Return the previous subset in binary rank order.
pub fn[T : Eq] Subset::prev_binary(
  self : Subset[T],
) -> Subset[T] raise CombinatoricsError {
  self.iterate_binary(-1)
}

///|
/// Return the next subset in SymPy's lexicographic subset order.
///
/// This order is induced by the ordered superset and is different from plain binary rank.
pub fn[T : Eq] Subset::next_lexicographic(
  self : Subset[T],
) -> Subset[T] raise CombinatoricsError {
  let mut i = self.superset.length() - 1
  let indices = Subset::subset_indices(self.subset, self.superset)
  let mut idx = indices
  if array_contains(idx, i) {
    if array_contains(idx, i - 1) {
      idx = array_remove_first(idx, i - 1)
    } else {
      idx = array_remove_first(idx, i)
      i = i - 1
      while i >= 0 && !array_contains(idx, i) {
        i = i - 1
      }
      if i >= 0 {
        idx = array_remove_first(idx, i)
        idx.push(i + 1)
      }
    }
  } else {
    while i >= 0 && !array_contains(idx, i) {
      i = i - 1
    }
    idx.push(i + 1)
  }
  let out : Array[T] = Array::new()
  for j in idx {
    out.push(self.superset[j])
  }
  Subset::new(out, self.superset)
}

///|
/// Return the previous subset in SymPy's lexicographic subset order.
pub fn[T : Eq] Subset::prev_lexicographic(
  self : Subset[T],
) -> Subset[T] raise CombinatoricsError {
  let mut i = self.superset.length() - 1
  let mut idx = Subset::subset_indices(self.subset, self.superset)
  while i >= 0 && !array_contains(idx, i) {
    i = i - 1
  }
  if i == 0 || array_contains(idx, i - 1) {
    if i >= 0 {
      idx = array_remove_first(idx, i)
    }
  } else {
    if i >= 0 {
      idx = array_remove_first(idx, i)
      idx.push(i - 1)
    }
    idx.push(self.superset.length() - 1)
  }
  let out : Array[T] = Array::new()
  for j in idx {
    out.push(self.superset[j])
  }
  Subset::new(out, self.superset)
}

///|
/// Move by `k` steps in Gray-code subset order.
///
/// Successive subsets in this order differ by one membership bit, which is useful when an
/// algorithm can update incrementally from the previous subset.
pub fn[T : Eq] Subset::iterate_graycode(
  self : Subset[T],
  k : Int,
) -> Subset[T] raise CombinatoricsError {
  let rank = self.rank_gray()
  let total = self.cardinality()
  let mut next_rank = rank + k
  if total > 0 {
    next_rank = (next_rank % total + total) % total
  }
  let code = GrayCode::unrank(self.superset.length(), next_rank)
  Subset::subset_from_bitlist(self.superset, code)
}

///|
/// Return the next subset in Gray-code order.
pub fn[T : Eq] Subset::next_gray(
  self : Subset[T],
) -> Subset[T] raise CombinatoricsError {
  self.iterate_graycode(1)
}

///|
/// Return the previous subset in Gray-code order.
pub fn[T : Eq] Subset::prev_gray(
  self : Subset[T],
) -> Subset[T] raise CombinatoricsError {
  self.iterate_graycode(-1)
}

///|
/// Return the binary rank of the subset's characteristic bitlist.
pub fn[T : Eq] Subset::rank_binary(self : Subset[T]) -> Int {
  match self.rank_binary_cache {
    Some(r) => r
    None => bin_to_int(Subset::bitlist_from_subset(self.subset, self.superset))
  }
}

///|
/// Return the rank of the subset in lexicographic subset order.
pub fn[T : Eq] Subset::rank_lexicographic(self : Subset[T]) -> Int {
  match self.rank_lex_cache {
    Some(r) => r
    None => {
      fn ranklex(indices : Array[Int], i : Int, n : Int) -> Int {
        if indices.is_empty() || i > n {
          return 0
        }
        if array_contains(indices, i) {
          let next = array_remove_first(indices, i)
          return 1 + ranklex(next, i + 1, n)
        }
        pow_int(2, n - i - 1) + ranklex(indices, i + 1, n)
      }

      let idx = Subset::subset_indices(self.subset, self.superset)
      ranklex(idx, 0, self.superset.length())
    }
  }
}

///|
/// Return the rank of the subset in Gray-code order.
pub fn[T : Eq] Subset::rank_gray(self : Subset[T]) -> Int {
  match self.rank_gray_cache {
    Some(r) => r
    None => {
      let bits = Subset::bitlist_from_subset(self.subset, self.superset)
      (GrayCode::new(bits.length(), start=bits) catch { _ => return 0 }).rank()
    }
  }
}

///|
/// Return the selected subset elements in superset order.
pub fn[T] Subset::subset(self : Subset[T]) -> Array[T] {
  self.subset
}

///|
/// Return the ordered superset that defines all rank/unrank operations.
pub fn[T] Subset::superset(self : Subset[T]) -> Array[T] {
  self.superset
}

///|
/// Return the number of elements currently selected.
pub fn[T] Subset::size(self : Subset[T]) -> Int {
  self.subset.length()
}

///|
/// Return the size of the ambient superset.
pub fn[T] Subset::superset_size(self : Subset[T]) -> Int {
  self.superset.length()
}

///|
/// Return the total number of subsets of the ambient superset, namely `2^n`.
pub fn[T] Subset::cardinality(self : Subset[T]) -> Int {
  pow_int(2, self.superset.length())
}

///|
/// Build a `Subset` from a characteristic bitlist over `superset`.
pub fn[T : Eq] Subset::subset_from_bitlist(
  super_set : Array[T],
  bitlist : String,
) -> Subset[T] raise CombinatoricsError {
  if super_set.length() != bitlist.length() {
    raise CombinatoricsError::ValueError("The sizes of the lists are not equal")
  }
  let bits = string_to_chars(bitlist)
  let out : Array[T] = Array::new()
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      out.push(super_set[i])
    }
  }
  Subset::new(out, super_set)
}

///|
/// Return the characteristic bitlist of `subset` relative to `superset`.
pub fn[T : Eq] Subset::bitlist_from_subset(
  subset : Array[T],
  superset : Array[T],
) -> String {
  let bitlist : Array[Char] = Array::make(superset.length(), '0')
  let indices = Subset::subset_indices(subset, superset)
  for i in indices {
    bitlist.set(i, '1')
  }
  chars_to_string(bitlist)
}

///|
/// Return the subset of `superset` at the given binary rank.
pub fn[T : Eq] Subset::unrank_binary(
  rank : Int,
  superset : Array[T],
) -> Subset[T] raise CombinatoricsError {
  let bits = int_to_bin(rank, superset.length())
  Subset::subset_from_bitlist(superset, bits)
}

///|
/// Return the subset of `superset` at the given Gray-code rank.
pub fn[T : Eq] Subset::unrank_gray(
  rank : Int,
  superset : Array[T],
) -> Subset[T] raise CombinatoricsError {
  let bits = GrayCode::unrank(superset.length(), rank)
  Subset::subset_from_bitlist(superset, bits)
}

///|
/// Return the positions occupied by `subset` inside `superset`.
///
/// The indices are exactly the data used by the ranking algorithms.
pub fn[T : Eq] Subset::subset_indices(
  subset : Array[T],
  superset : Array[T],
) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for item in subset {
    let mut found = false
    for i in 0..<superset.length() {
      if superset[i] == item {
        out.push(i)
        found = true
        break
      }
    }
    if !found {
      return []
    }
  }
  out
}

///|
/// Enumerate all `k`-element subsets of `superset` in lexicographic index order.
pub fn[T] ksubsets(superset : Array[T], k : Int) -> Array[Array[T]] {
  let n = superset.length()
  if k < 0 || k > n {
    return []
  }
  if k == 0 {
    return [[]]
  }
  let indices : Array[Int] = Array::new()
  for i in 0..<k {
    indices.push(i)
  }
  let out : Array[Array[T]] = Array::new()
  fn add_subset(
    superset : Array[T],
    idx : Array[Int],
    out : Array[Array[T]],
  ) -> Unit {
    let subset : Array[T] = Array::new()
    for i in idx {
      subset.push(superset[i])
    }
    out.push(subset)
  }

  add_subset(superset, indices, out)
  let idx = indices
  while true {
    let mut i = k - 1
    while i >= 0 && idx[i] == i + n - k {
      i = i - 1
    }
    if i < 0 {
      break
    }
    idx[i] = idx[i] + 1
    for j in (i + 1)..<k {
      idx[j] = idx[j - 1] + 1
    }
    add_subset(superset, idx, out)
  }
  out
}
