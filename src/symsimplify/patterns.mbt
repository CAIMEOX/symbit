///|
pub(all) enum SimplifyPattern {
  FoldConstants
  AddLikeTerms
  MulLikeBases
  PowDenest
  TrigPythagorean
  FunctionIdentities
} derive(Eq, Show)

///|
pub(all) enum SimplifyPlan {
  Default
  Aggressive
  Custom(Array[SimplifyPattern])
} derive(Eq, Show)

///|
pub fn plan_patterns(plan : SimplifyPlan) -> Array[SimplifyPattern] {
  match plan {
    SimplifyPlan::Default => default_patterns()
    SimplifyPlan::Aggressive => aggressive_patterns()
    SimplifyPlan::Custom(patterns) => patterns.map(p => p)
  }
}

///|
fn default_patterns() -> Array[SimplifyPattern] {
  [
    SimplifyPattern::FoldConstants,
    SimplifyPattern::FunctionIdentities,
    SimplifyPattern::PowDenest,
    SimplifyPattern::MulLikeBases,
    SimplifyPattern::AddLikeTerms,
    SimplifyPattern::TrigPythagorean,
    SimplifyPattern::FoldConstants,
  ]
}

///|
fn aggressive_patterns() -> Array[SimplifyPattern] {
  [
    SimplifyPattern::FoldConstants,
    SimplifyPattern::FunctionIdentities,
    SimplifyPattern::PowDenest,
    SimplifyPattern::MulLikeBases,
    SimplifyPattern::AddLikeTerms,
    SimplifyPattern::TrigPythagorean,
    SimplifyPattern::MulLikeBases,
    SimplifyPattern::AddLikeTerms,
    SimplifyPattern::FoldConstants,
  ]
}
