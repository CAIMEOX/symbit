///|\
/// Memoization helpers aligned with `sympy.utilities.memoization`.

///|
pub fn[T : Eq + Hash, U] memoize(f : (T) -> U) -> (T) -> U {
  let cache : Ref[Map[T, U]] = { val: {} }
  (arg : T) => {
    match cache.val.get(arg) {
      Some(value) => value
      None => {
        let value = f(arg)
        cache.val[arg] = value
        value
      }
    }
  }
}

///|
pub fn[T : Eq + Hash, U] memoize_property(propfunc : (T) -> U) -> (T) -> U {
  memoize(propfunc)
}

///|
pub struct RecurrenceMemo[T] {
  cache : Ref[Array[T]]
}

///|
pub fn[T] recurrence_memo(initial : Array[T]) -> RecurrenceMemo[T] {
  { cache: { val: initial.map(x => x) } }
}

///|
pub fn[T] RecurrenceMemo::apply(
  self : RecurrenceMemo[T],
  n : Int,
  step : (Int, Array[T]) -> T,
) -> T raise UtilitiesError {
  if n < 0 {
    raise InvalidArgument("recurrence index must be non-negative")
  }
  let mut length = self.cache.val.length()
  if n < length {
    return self.cache.val[n]
  }
  while length <= n {
    self.cache.val.push(step(length, self.cache.val))
    length += 1
  }
  self.cache.val[n]
}

///|
pub fn[T] RecurrenceMemo::cache_length(self : RecurrenceMemo[T]) -> Int {
  self.cache.val.length()
}

///|
pub fn[T] RecurrenceMemo::fetch_item(
  self : RecurrenceMemo[T],
  index : Int,
) -> T raise UtilitiesError {
  if index < 0 || index >= self.cache.val.length() {
    raise InvalidArgument("cache index out of range")
  }
  self.cache.val[index]
}

///|
pub struct AssocRecurrenceMemo[T] {
  cache : Ref[Array[Array[T]]]
}

///|
pub fn[T] assoc_recurrence_memo() -> AssocRecurrenceMemo[T] {
  { cache: { val: [] } }
}

///|
pub fn[T] AssocRecurrenceMemo::apply(
  self : AssocRecurrenceMemo[T],
  n : Int,
  m : Int,
  base_seq : (Int) -> T,
  step : (Int, Int, Array[Array[T]]) -> T,
) -> T raise UtilitiesError {
  if n < 0 || m < 0 || m > n {
    raise InvalidArgument("expected 0 <= m <= n")
  }
  let mut length = self.cache.val.length()
  while length <= n {
    let i = length
    let row : Array[T] = [base_seq(i)]
    self.cache.val.push(row)
    for j in 1..<=i {
      let value = step(i, j, self.cache.val)
      self.cache.val[i].push(value)
    }
    length += 1
  }
  self.cache.val[n][m]
}
