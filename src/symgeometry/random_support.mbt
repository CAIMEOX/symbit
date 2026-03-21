///|
let geo_random_source : @random.Rand = @random.Rand::new()

///|
fn geo_random_from_seed(seed : Int) -> @random.Rand {
  let bytes = Bytes::makei(32, i => ((seed + i * 73) & 255).to_byte())
  @random.Rand::chacha8(seed=bytes)
}

///|
fn geo_random_symmetric_rational(
  rng : @random.Rand,
  scale? : Int = 1_000_000,
) -> Expr {
  let denom = if scale <= 0 { 1_000_000 } else { scale }
  let numer = rng.int(limit=2 * denom + 1) - denom
  match
    (
      try? @symcore.rational_from_ints(numer, denom) :
      Result[Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) =>
      @symcore.mul([
        @symcore.int(numer),
        @symcore.pow(@symcore.int(denom), @symcore.int(-1)),
      ])
  }
}
