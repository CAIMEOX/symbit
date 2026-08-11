///|
/// Polynomial algorithm configuration front doors.
///
/// Current Limits:
/// - Environment-variable loading is not modeled; `configure` resets the
///   package-local defaults directly.
/// - SymPy's `using` name is a MoonBit keyword, so the scoped callback front
///   door is exposed as `polyconfig_using`.

///|
/// Typed value stored in the polynomial configuration table.
///
/// - Does: Represents one boolean, integer, or string configuration value.
/// - Input: Constructed by `PolyConfigValue::Bool`, `Int`, or `Text`.
/// - Returns: A `PolyConfigValue`.
/// - Limits: Python objects outside these scalar value classes are not modeled.
pub(all) enum PolyConfigValue {
  Bool(Bool)
  Int(Int)
  Text(String)
} derive(Eq)

///|
let polyconfig_current : Map[String, PolyConfigValue] = Map([])

///|
fn polyconfig_default(key : String) -> PolyConfigValue? {
  match key {
    "USE_COLLINS_RESULTANT" => Some(Bool(false))
    "USE_SIMPLIFY_GCD" => Some(Bool(true))
    "USE_HEU_GCD" => Some(Bool(true))
    "USE_IRREDUCIBLE_IN_FACTOR" => Some(Bool(false))
    "USE_CYCLOTOMIC_FACTOR" => Some(Bool(true))
    "EEZ_RESTART_IF_NEEDED" => Some(Bool(true))
    "EEZ_NUMBER_OF_CONFIGS" => Some(Int(3))
    "EEZ_NUMBER_OF_TRIES" => Some(Int(5))
    "EEZ_MODULUS_STEP" => Some(Int(2))
    "GF_IRRED_METHOD" => Some(Text("rabin"))
    "GF_FACTOR_METHOD" => Some(Text("zassenhaus"))
    "GROEBNER" => Some(Text("buchberger"))
    _ => None
  }
}

///|
fn polyconfig_default_keys() -> Array[String] {
  [
    "USE_COLLINS_RESULTANT", "USE_SIMPLIFY_GCD", "USE_HEU_GCD", "USE_IRREDUCIBLE_IN_FACTOR",
    "USE_CYCLOTOMIC_FACTOR", "EEZ_RESTART_IF_NEEDED", "EEZ_NUMBER_OF_CONFIGS", "EEZ_NUMBER_OF_TRIES",
    "EEZ_MODULUS_STEP", "GF_IRRED_METHOD", "GF_FACTOR_METHOD", "GROEBNER",
  ]
}

///|
fn polyconfig_normalize_key(key : String) -> String {
  key.to_upper()
}

///|
fn polyconfig_reset_key(key : String) -> Unit raise PolyError {
  let norm = polyconfig_normalize_key(key)
  match polyconfig_default(norm) {
    Some(value) => polyconfig_current.set(norm, value)
    None => raise BadGenerator(norm)
  }
}

///|
/// Initialize the polynomial configuration table.
///
/// - Does: Resets all known polynomial algorithm options to their defaults.
/// - Input: No arguments.
/// - Returns: Unit.
/// - Limits: Does not read `SYMPY_*` environment variables.
pub fn configure() -> Unit {
  polyconfig_current.clear()
  for key in polyconfig_default_keys() {
    match polyconfig_default(key) {
      Some(value) => polyconfig_current.set(key, value)
      None => ()
    }
  }
}

///|
/// Assign or reset one polynomial configuration value.
///
/// - Does: With `value`, stores that value under the uppercased key; without
///   `value`, resets a known key to its default.
/// - Input: A key string and an optional `PolyConfigValue`.
/// - Returns: Unit.
/// - Limits: Resetting an unknown key raises `PolyError::BadGenerator`.
pub fn setup(key : String, value? : PolyConfigValue) -> Unit raise PolyError {
  let norm = polyconfig_normalize_key(key)
  match value {
    Some(v) => polyconfig_current.set(norm, v)
    None => polyconfig_reset_key(norm)
  }
}

///|
/// Query one polynomial configuration value.
///
/// - Does: Looks up the uppercased key in the current table, falling back to
///   the built-in default table for known options.
/// - Input: A key string.
/// - Returns: `Some(value)` for known or explicitly configured keys, otherwise
///   `None`.
/// - Limits: Values are returned as `PolyConfigValue`, not Python objects.
pub fn query(key : String) -> PolyConfigValue? {
  let norm = polyconfig_normalize_key(key)
  match polyconfig_current.get(norm) {
    Some(value) => Some(value)
    None => polyconfig_default(norm)
  }
}

///|
/// Temporarily override polynomial configuration values.
///
/// - Does: Applies overrides, runs `body`, then resets the touched keys to
///   their defaults.
/// - Input: `(key, value)` override pairs and a callback.
/// - Returns: Unit.
/// - Limits: This is the MoonBit spelling of SymPy's `using` context manager;
///   `using` itself is reserved syntax in MoonBit.
pub fn polyconfig_using(
  overrides : Array[(String, PolyConfigValue)],
  body : () -> Unit raise PolyError,
) -> Unit raise PolyError {
  let touched = overrides.map(item => polyconfig_normalize_key(item.0))
  for item in overrides {
    setup(item.0, value=item.1)
  }
  body() catch {
    err => {
      for key in touched {
        polyconfig_reset_key(key)
      }
      raise err
    }
  }
  for key in touched {
    polyconfig_reset_key(key)
  }
}
