///|
/// Integer partition counts.

///|
let partition_cache : Array[BigInt] = [bi(1)]

///|
pub fn npartitions(n : Int) -> BigInt {
  if n < 0 {
    return bi(0)
  }
  extend_partition_cache(n)
  partition_cache[n]
}

///|
fn extend_partition_cache(n : Int) -> Unit {
  while partition_cache.length() <= n {
    let m = partition_cache.length()
    let mut total = bi(0)
    let mut k = 1
    while true {
      let g1 = generalized_pentagonal(k)
      if g1 > m {
        break
      }
      let sign = if k % 2 == 1 { bi(1) } else { bi(-1) }
      total = total + sign * partition_cache[m - g1]
      let g2 = generalized_pentagonal(-k)
      if g2 <= m {
        total = total + sign * partition_cache[m - g2]
      }
      k += 1
    }
    partition_cache.push(total)
  }
}

///|
fn generalized_pentagonal(k : Int) -> Int {
  k * (3 * k - 1) / 2
}
