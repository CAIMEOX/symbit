///|
test "memoization memoize caches unary calls" {
  let calls : Ref[Int] = { val: 0 }
  let f = memoize((x : Int) => {
    calls.val += 1
    x * x
  })
  assert_eq(f(5), 25)
  assert_eq(f(5), 25)
  assert_eq(calls.val, 1)
}

///|
test "memoization recurrence sequence" {
  let factorial = recurrence_memo([1])
  let f = (n : Int) => {
    factorial.apply(n, (i, prev) => i * prev[prev.length() - 1])
  }
  assert_eq(try! f(4), 24)
  assert_eq(factorial.cache_length(), 5)
  assert_eq(try! factorial.fetch_item(3), 6)
}

///|
test "memoization associated recurrence sequence" {
  let memo : AssocRecurrenceMemo[Int] = assoc_recurrence_memo()
  let value = try! memo.apply(3, 2, (_ : Int) => 1, (n, m, cache) => {
    if m == n {
      1
    } else {
      cache[n - 1][m - 1] + cache[n - 1][m]
    }
  })
  assert_eq(value, 3)
}
