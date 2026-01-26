///|
/// Lightweight LCG RNG with modulus fallback.
fn lcg_next(seed : Int, modulus : Int) -> Int {
  let a = 1103515245
  let c = 12345
  let m = if modulus <= 1 { 2147483647 } else { modulus }
  let mut next = (seed * a + c) % m
  if next < 0 {
    next = next + m
  }
  next
}
