///|
/// Integer partition counts.

///|
pub fn npartitions(n : Int) -> BigInt {
  if n < 0 {
    return bi(0)
  }
  let dp : Array[BigInt] = Array::new()
  for _ in 0..<=n {
    dp.push(bi(0))
  }
  dp[0] = bi(1)
  for k in 1..<=n {
    for i in k..<=n {
      dp[i] = dp[i] + dp[i - k]
    }
  }
  dp[n]
}
