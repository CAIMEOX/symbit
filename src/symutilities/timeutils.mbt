///|\
/// Timing helpers aligned with `sympy.utilities.timeutils`.

///|
pub struct TimedResult {
  number : Int
  seconds_per_call : Double
  scaled : Double
  unit : String
} derive(Eq)

///|
pub struct TimethisReport {
  name : String
  elapsed_seconds : Double
} derive(Eq)

///|
fn pick_timing_unit(seconds : Double) -> (Double, String) {
  if seconds <= 0.0 {
    return (1000000000.0, "ns")
  }
  let log10 = @math.log10(seconds)
  let mut order = -(log10.floor().to_int() / 3)
  if order < 0 {
    order = 0
  }
  if order > 3 {
    order = 3
  }
  match order {
    0 => (1.0, "s")
    1 => (1000.0, "ms")
    2 => (1000000.0, "us")
    _ => (1000000000.0, "ns")
  }
}

///|
/// Adaptively time `func` until a stable per-call measurement is available.
pub fn timed(func : () -> Unit, limit? : Int? = None) -> TimedResult {
  let mut number = 1
  let repeat = 3
  let mut best = 0.0
  let mut stop = false
  while !stop {
    let mut local_best : Double? = None
    for _ in 0..<repeat {
      let start = @bench.monotonic_clock_start()
      for _ in 0..<number {
        func()
      }
      let elapsed_us = @bench.monotonic_clock_end(start)
      let elapsed = elapsed_us / 1000000.0
      local_best = match local_best {
        Some(v) => Some(if elapsed < v { elapsed } else { v })
        None => Some(elapsed)
      }
    }
    best = local_best.unwrap() / number.to_double()
    if best * number.to_double() >= 0.2 {
      stop = true
    } else {
      match limit {
        Some(max_calls) if number >= max_calls => stop = true
        _ => number *= 10
      }
    }
  }
  let (scale, unit) = pick_timing_unit(best)
  { number, seconds_per_call: best, scaled: best * scale, unit }
}

///|
/// Wrap a function with explicit timing. Unlike SymPy's environment-driven
/// decorator, the MoonBit adaptation takes an `enabled` flag and a callback
/// that receives the timing report.
pub fn[T, U] timethis(
  name : String,
  enabled? : Bool = true,
  reporter? : (TimethisReport) -> Unit = _ => (),
  f : (T) -> U,
) -> (T) -> U {
  if !enabled {
    return f
  }
  (arg : T) => {
    let start = @bench.monotonic_clock_start()
    let result = f(arg)
    let elapsed_seconds = @bench.monotonic_clock_end(start) / 1000000.0
    reporter({ name, elapsed_seconds })
    result
  }
}
