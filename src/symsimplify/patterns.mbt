///|
/// - Does: Enumerates the local rewrite families used by pattern-driven simplification.
/// - Input: One enum case.
/// - Returns: One `SimplifyPattern` value.
/// - Limits: Only the listed pattern families are available to the public front door.
pub(all) enum SimplifyPattern {
  FoldConstants
  AddLikeTerms
  MulLikeBases
  PowDenest
  TrigPythagorean
  FunctionIdentities
} derive(Eq, Debug)

///|
/// - Does: Enumerates the supported simplify execution plans.
/// - Input: One enum case, optionally carrying `Array[SimplifyPattern]` for `Custom`.
/// - Returns: One `SimplifyPlan` value.
/// - Limits: `Custom` plans run exactly the provided pattern list without extra validation.
pub(all) enum SimplifyPlan {
  Default
  Aggressive
  Custom(Array[SimplifyPattern])
} derive(Eq, Debug)

///|
/// - Does: Expands one simplify plan into the ordered pattern list it will run.
/// - Input: One `SimplifyPlan`.
/// - Returns: `Array[SimplifyPattern]`.
/// - Limits: `Custom` returns a shallow copy of the given list and does not normalize duplicates.
pub fn plan_patterns(plan : SimplifyPlan) -> Array[SimplifyPattern] {
  match plan {
    Default => default_patterns()
    Aggressive => aggressive_patterns()
    Custom(patterns) => patterns.map(p => p)
  }
}

///|
fn default_patterns() -> Array[SimplifyPattern] {
  [
    FoldConstants,
    FunctionIdentities,
    PowDenest,
    MulLikeBases,
    AddLikeTerms,
    TrigPythagorean,
    FoldConstants,
  ]
}

///|
fn aggressive_patterns() -> Array[SimplifyPattern] {
  [
    FoldConstants,
    FunctionIdentities,
    PowDenest,
    MulLikeBases,
    AddLikeTerms,
    TrigPythagorean,
    MulLikeBases,
    AddLikeTerms,
    FoldConstants,
  ]
}
