///|
/// Typed symbolic distribution/process/model classification.

///|
pub(all) enum SymbolicFamily {
  Continuous
  Discrete
  Joint
  Process
  Matrix
} derive(Eq)

///|
pub(all) enum ContinuousTag {
  Arcsin
  Benini
  Beta
  BetaNoncentral
  BetaPrime
  BoundedPareto
  Cauchy
  Chi
  ChiNoncentral
  ChiSquared
  ContinuousRV
  ContinuousDistributionHandmade
  Dagum
  Davis
  Exponential
  Erlang
  ExGaussian
  ExponentialPower
  FDistribution
  FisherZ
  Frechet
  GammaInverse
  GaussianInverse
  Gompertz
  Gumbel
  Kumaraswamy
  Laplace
  Levy
  LogCauchy
  LogLogistic
  LogNormal
  Logarithmic
  Logistic
  LogitNormal
  Lomax
  Maxwell
  Moyal
  Nakagami
  Named(name~ : String)
  Pareto
  PowerFunction
  QuadraticU
  RaisedCosine
  Rayleigh
  Reciprocal
  ShiftedGompertz
  StudentT
  Trapezoidal
  Triangular
  Uniform
  UniformSum
  VonMises
  Wald
  Weibull
  WignerSemicircle
} derive(Eq)

///|
pub(all) enum DiscreteTag {
  BetaBinomial
  DiscreteRV
  DiscreteDistributionHandmade
  FiniteDistributionHandmade
  FlorySchulz
  Hermite
  Hypergeometric
  IdealSoliton
  Logarithmic
  RobustSoliton
  Skellam
  Multinomial
  NegativeMultinomial
  YuleSimon
  Zeta
  Named(name~ : String)
} derive(Eq)

///|
pub(all) enum JointTag {
  JointRV
  Dirichlet
  GeneralizedMultivariateLogGamma
  GeneralizedMultivariateLogGammaOmega
  MultivariateBeta
  MultivariateEwens
  MultivariateT
  NormalGamma
  MultivariateNormal
  MultivariateLaplace
  Named(name~ : String)
} derive(Eq)

///|
pub(all) enum ProcessTag {
  StochasticProcess
  DiscreteTimeStochasticProcess
  DiscreteMarkovChain
  ContinuousMarkovChain
  BernoulliProcess
  GammaProcess
  Named(name~ : String)
} derive(Eq)

///|
pub(all) enum MatrixTag {
  JointEigenDistribution
  LevelSpacingDistribution
  MatrixGamma
  MatrixStudentT
  CircularEnsemble
  CircularUnitaryEnsemble
  CircularOrthogonalEnsemble
  CircularSymplecticEnsemble
  GaussianEnsemble
  GaussianUnitaryEnsemble
  GaussianOrthogonalEnsemble
  GaussianSymplecticEnsemble
  Named(name~ : String)
} derive(Eq)

///|
pub(all) enum SymbolicKind {
  Continuous(ContinuousTag)
  Discrete(DiscreteTag)
  Joint(JointTag)
  Process(ProcessTag)
  Matrix(MatrixTag)
} derive(Eq)

///|
fn continuous_tag_from_name(name : String) -> ContinuousTag {
  match name {
    "Arcsin" => ContinuousTag::Arcsin
    "Benini" => ContinuousTag::Benini
    "Beta" => ContinuousTag::Beta
    "BetaNoncentral" => ContinuousTag::BetaNoncentral
    "BetaPrime" => ContinuousTag::BetaPrime
    "BoundedPareto" => ContinuousTag::BoundedPareto
    "Cauchy" => ContinuousTag::Cauchy
    "Chi" => ContinuousTag::Chi
    "ChiNoncentral" => ContinuousTag::ChiNoncentral
    "ChiSquared" => ContinuousTag::ChiSquared
    "ContinuousRV" => ContinuousTag::ContinuousRV
    "ContinuousDistributionHandmade" =>
      ContinuousTag::ContinuousDistributionHandmade
    "Dagum" => ContinuousTag::Dagum
    "Davis" => ContinuousTag::Davis
    "Exponential" => ContinuousTag::Exponential
    "Erlang" => ContinuousTag::Erlang
    "ExGaussian" => ContinuousTag::ExGaussian
    "ExponentialPower" => ContinuousTag::ExponentialPower
    "FDistribution" => ContinuousTag::FDistribution
    "FisherZ" => ContinuousTag::FisherZ
    "Frechet" => ContinuousTag::Frechet
    "GammaInverse" => ContinuousTag::GammaInverse
    "GaussianInverse" => ContinuousTag::GaussianInverse
    "Gompertz" => ContinuousTag::Gompertz
    "Gumbel" => ContinuousTag::Gumbel
    "Kumaraswamy" => ContinuousTag::Kumaraswamy
    "Laplace" => ContinuousTag::Laplace
    "Levy" => ContinuousTag::Levy
    "LogCauchy" => ContinuousTag::LogCauchy
    "LogLogistic" => ContinuousTag::LogLogistic
    "LogNormal" => ContinuousTag::LogNormal
    "Logarithmic" => ContinuousTag::Logarithmic
    "Logistic" => ContinuousTag::Logistic
    "LogitNormal" => ContinuousTag::LogitNormal
    "Lomax" => ContinuousTag::Lomax
    "Maxwell" => ContinuousTag::Maxwell
    "Moyal" => ContinuousTag::Moyal
    "Nakagami" => ContinuousTag::Nakagami
    "Pareto" => ContinuousTag::Pareto
    "PowerFunction" => ContinuousTag::PowerFunction
    "QuadraticU" => ContinuousTag::QuadraticU
    "RaisedCosine" => ContinuousTag::RaisedCosine
    "Rayleigh" => ContinuousTag::Rayleigh
    "Reciprocal" => ContinuousTag::Reciprocal
    "ShiftedGompertz" => ContinuousTag::ShiftedGompertz
    "StudentT" => ContinuousTag::StudentT
    "Trapezoidal" => ContinuousTag::Trapezoidal
    "Triangular" => ContinuousTag::Triangular
    "Uniform" => ContinuousTag::Uniform
    "UniformSum" => ContinuousTag::UniformSum
    "VonMises" => ContinuousTag::VonMises
    "Wald" => ContinuousTag::Wald
    "Weibull" => ContinuousTag::Weibull
    "WignerSemicircle" => ContinuousTag::WignerSemicircle
    _ => ContinuousTag::Named(name~)
  }
}

///|
fn discrete_tag_from_name(name : String) -> DiscreteTag {
  match name {
    "BetaBinomial" => DiscreteTag::BetaBinomial
    "DiscreteRV" => DiscreteTag::DiscreteRV
    "DiscreteDistributionHandmade" => DiscreteTag::DiscreteDistributionHandmade
    "FiniteDistributionHandmade" => DiscreteTag::FiniteDistributionHandmade
    "FlorySchulz" => DiscreteTag::FlorySchulz
    "Hermite" => DiscreteTag::Hermite
    "Hypergeometric" => DiscreteTag::Hypergeometric
    "IdealSoliton" => DiscreteTag::IdealSoliton
    "Logarithmic" => DiscreteTag::Logarithmic
    "RobustSoliton" => DiscreteTag::RobustSoliton
    "Skellam" => DiscreteTag::Skellam
    "Multinomial" => DiscreteTag::Multinomial
    "NegativeMultinomial" => DiscreteTag::NegativeMultinomial
    "YuleSimon" => DiscreteTag::YuleSimon
    "Zeta" => DiscreteTag::Zeta
    _ => DiscreteTag::Named(name~)
  }
}

///|
fn joint_tag_from_name(name : String) -> JointTag {
  match name {
    "JointRV" => JointTag::JointRV
    "Dirichlet" => JointTag::Dirichlet
    "GeneralizedMultivariateLogGamma" =>
      JointTag::GeneralizedMultivariateLogGamma
    "GeneralizedMultivariateLogGammaOmega" =>
      JointTag::GeneralizedMultivariateLogGammaOmega
    "MultivariateBeta" => JointTag::MultivariateBeta
    "MultivariateEwens" => JointTag::MultivariateEwens
    "MultivariateT" => JointTag::MultivariateT
    "NormalGamma" => JointTag::NormalGamma
    "MultivariateNormal" => JointTag::MultivariateNormal
    "MultivariateLaplace" => JointTag::MultivariateLaplace
    _ => JointTag::Named(name~)
  }
}

///|
fn process_tag_from_name(name : String) -> ProcessTag {
  match name {
    "StochasticProcess" => ProcessTag::StochasticProcess
    "DiscreteTimeStochasticProcess" => ProcessTag::DiscreteTimeStochasticProcess
    "DiscreteMarkovChain" => ProcessTag::DiscreteMarkovChain
    "ContinuousMarkovChain" => ProcessTag::ContinuousMarkovChain
    "BernoulliProcess" => ProcessTag::BernoulliProcess
    "GammaProcess" => ProcessTag::GammaProcess
    _ => ProcessTag::Named(name~)
  }
}

///|
fn matrix_tag_from_name(name : String) -> MatrixTag {
  match name {
    "JointEigenDistribution" => MatrixTag::JointEigenDistribution
    "level_spacing_distribution" => MatrixTag::LevelSpacingDistribution
    "MatrixGamma" => MatrixTag::MatrixGamma
    "MatrixStudentT" => MatrixTag::MatrixStudentT
    "CircularEnsemble" => MatrixTag::CircularEnsemble
    "CircularUnitaryEnsemble" => MatrixTag::CircularUnitaryEnsemble
    "CircularOrthogonalEnsemble" => MatrixTag::CircularOrthogonalEnsemble
    "CircularSymplecticEnsemble" => MatrixTag::CircularSymplecticEnsemble
    "GaussianEnsemble" => MatrixTag::GaussianEnsemble
    "GaussianUnitaryEnsemble" => MatrixTag::GaussianUnitaryEnsemble
    "GaussianOrthogonalEnsemble" => MatrixTag::GaussianOrthogonalEnsemble
    "GaussianSymplecticEnsemble" => MatrixTag::GaussianSymplecticEnsemble
    _ => MatrixTag::Named(name~)
  }
}

///|
pub fn symbolic_kind_from_name(name : String) -> SymbolicKind {
  match name {
    "BetaBinomial"
    | "Hypergeometric"
    | "IdealSoliton"
    | "RobustSoliton"
    | "FiniteDistributionHandmade"
    | "FlorySchulz"
    | "Hermite"
    | "Logarithmic"
    | "Skellam"
    | "YuleSimon"
    | "Zeta"
    | "DiscreteRV"
    | "DiscreteDistributionHandmade"
    | "Multinomial"
    | "NegativeMultinomial" =>
      SymbolicKind::Discrete(discrete_tag_from_name(name))
    "JointRV"
    | "Dirichlet"
    | "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega"
    | "MultivariateBeta"
    | "MultivariateEwens"
    | "MultivariateT"
    | "NormalGamma"
    | "MultivariateNormal"
    | "MultivariateLaplace" => SymbolicKind::Joint(joint_tag_from_name(name))
    "StochasticProcess"
    | "DiscreteTimeStochasticProcess"
    | "DiscreteMarkovChain"
    | "ContinuousMarkovChain"
    | "BernoulliProcess"
    | "GammaProcess" => SymbolicKind::Process(process_tag_from_name(name))
    "JointEigenDistribution"
    | "level_spacing_distribution"
    | "MatrixGamma"
    | "MatrixStudentT"
    | "CircularEnsemble"
    | "CircularUnitaryEnsemble"
    | "CircularOrthogonalEnsemble"
    | "CircularSymplecticEnsemble"
    | "GaussianEnsemble"
    | "GaussianUnitaryEnsemble"
    | "GaussianOrthogonalEnsemble"
    | "GaussianSymplecticEnsemble" =>
      SymbolicKind::Matrix(matrix_tag_from_name(name))
    _ => SymbolicKind::Continuous(continuous_tag_from_name(name))
  }
}

///|
fn continuous_tag_name(tag : ContinuousTag) -> String {
  match tag {
    ContinuousTag::Arcsin => "Arcsin"
    ContinuousTag::Benini => "Benini"
    ContinuousTag::Beta => "Beta"
    ContinuousTag::BetaNoncentral => "BetaNoncentral"
    ContinuousTag::BetaPrime => "BetaPrime"
    ContinuousTag::BoundedPareto => "BoundedPareto"
    ContinuousTag::Cauchy => "Cauchy"
    ContinuousTag::Chi => "Chi"
    ContinuousTag::ChiNoncentral => "ChiNoncentral"
    ContinuousTag::ChiSquared => "ChiSquared"
    ContinuousTag::ContinuousRV => "ContinuousRV"
    ContinuousTag::ContinuousDistributionHandmade =>
      "ContinuousDistributionHandmade"
    ContinuousTag::Dagum => "Dagum"
    ContinuousTag::Davis => "Davis"
    ContinuousTag::Exponential => "Exponential"
    ContinuousTag::Erlang => "Erlang"
    ContinuousTag::ExGaussian => "ExGaussian"
    ContinuousTag::ExponentialPower => "ExponentialPower"
    ContinuousTag::FDistribution => "FDistribution"
    ContinuousTag::FisherZ => "FisherZ"
    ContinuousTag::Frechet => "Frechet"
    ContinuousTag::GammaInverse => "GammaInverse"
    ContinuousTag::GaussianInverse => "GaussianInverse"
    ContinuousTag::Gompertz => "Gompertz"
    ContinuousTag::Gumbel => "Gumbel"
    ContinuousTag::Kumaraswamy => "Kumaraswamy"
    ContinuousTag::Laplace => "Laplace"
    ContinuousTag::Levy => "Levy"
    ContinuousTag::LogCauchy => "LogCauchy"
    ContinuousTag::LogLogistic => "LogLogistic"
    ContinuousTag::LogNormal => "LogNormal"
    ContinuousTag::Logarithmic => "Logarithmic"
    ContinuousTag::Logistic => "Logistic"
    ContinuousTag::LogitNormal => "LogitNormal"
    ContinuousTag::Lomax => "Lomax"
    ContinuousTag::Maxwell => "Maxwell"
    ContinuousTag::Moyal => "Moyal"
    ContinuousTag::Nakagami => "Nakagami"
    ContinuousTag::Named(name~) => name
    ContinuousTag::Pareto => "Pareto"
    ContinuousTag::PowerFunction => "PowerFunction"
    ContinuousTag::QuadraticU => "QuadraticU"
    ContinuousTag::RaisedCosine => "RaisedCosine"
    ContinuousTag::Rayleigh => "Rayleigh"
    ContinuousTag::Reciprocal => "Reciprocal"
    ContinuousTag::ShiftedGompertz => "ShiftedGompertz"
    ContinuousTag::StudentT => "StudentT"
    ContinuousTag::Trapezoidal => "Trapezoidal"
    ContinuousTag::Triangular => "Triangular"
    ContinuousTag::Uniform => "Uniform"
    ContinuousTag::UniformSum => "UniformSum"
    ContinuousTag::VonMises => "VonMises"
    ContinuousTag::Wald => "Wald"
    ContinuousTag::Weibull => "Weibull"
    ContinuousTag::WignerSemicircle => "WignerSemicircle"
  }
}

///|
fn discrete_tag_name(tag : DiscreteTag) -> String {
  match tag {
    DiscreteTag::BetaBinomial => "BetaBinomial"
    DiscreteTag::DiscreteRV => "DiscreteRV"
    DiscreteTag::DiscreteDistributionHandmade => "DiscreteDistributionHandmade"
    DiscreteTag::FiniteDistributionHandmade => "FiniteDistributionHandmade"
    DiscreteTag::FlorySchulz => "FlorySchulz"
    DiscreteTag::Hermite => "Hermite"
    DiscreteTag::Hypergeometric => "Hypergeometric"
    DiscreteTag::IdealSoliton => "IdealSoliton"
    DiscreteTag::Logarithmic => "Logarithmic"
    DiscreteTag::RobustSoliton => "RobustSoliton"
    DiscreteTag::Skellam => "Skellam"
    DiscreteTag::Multinomial => "Multinomial"
    DiscreteTag::NegativeMultinomial => "NegativeMultinomial"
    DiscreteTag::YuleSimon => "YuleSimon"
    DiscreteTag::Zeta => "Zeta"
    DiscreteTag::Named(name~) => name
  }
}

///|
fn joint_tag_name(tag : JointTag) -> String {
  match tag {
    JointTag::JointRV => "JointRV"
    JointTag::Dirichlet => "Dirichlet"
    JointTag::GeneralizedMultivariateLogGamma =>
      "GeneralizedMultivariateLogGamma"
    JointTag::GeneralizedMultivariateLogGammaOmega =>
      "GeneralizedMultivariateLogGammaOmega"
    JointTag::MultivariateBeta => "MultivariateBeta"
    JointTag::MultivariateEwens => "MultivariateEwens"
    JointTag::MultivariateT => "MultivariateT"
    JointTag::NormalGamma => "NormalGamma"
    JointTag::MultivariateNormal => "MultivariateNormal"
    JointTag::MultivariateLaplace => "MultivariateLaplace"
    JointTag::Named(name~) => name
  }
}

///|
fn process_tag_name(tag : ProcessTag) -> String {
  match tag {
    ProcessTag::StochasticProcess => "StochasticProcess"
    ProcessTag::DiscreteTimeStochasticProcess => "DiscreteTimeStochasticProcess"
    ProcessTag::DiscreteMarkovChain => "DiscreteMarkovChain"
    ProcessTag::ContinuousMarkovChain => "ContinuousMarkovChain"
    ProcessTag::BernoulliProcess => "BernoulliProcess"
    ProcessTag::GammaProcess => "GammaProcess"
    ProcessTag::Named(name~) => name
  }
}

///|
fn matrix_tag_name(tag : MatrixTag) -> String {
  match tag {
    MatrixTag::JointEigenDistribution => "JointEigenDistribution"
    MatrixTag::LevelSpacingDistribution => "level_spacing_distribution"
    MatrixTag::MatrixGamma => "MatrixGamma"
    MatrixTag::MatrixStudentT => "MatrixStudentT"
    MatrixTag::CircularEnsemble => "CircularEnsemble"
    MatrixTag::CircularUnitaryEnsemble => "CircularUnitaryEnsemble"
    MatrixTag::CircularOrthogonalEnsemble => "CircularOrthogonalEnsemble"
    MatrixTag::CircularSymplecticEnsemble => "CircularSymplecticEnsemble"
    MatrixTag::GaussianEnsemble => "GaussianEnsemble"
    MatrixTag::GaussianUnitaryEnsemble => "GaussianUnitaryEnsemble"
    MatrixTag::GaussianOrthogonalEnsemble => "GaussianOrthogonalEnsemble"
    MatrixTag::GaussianSymplecticEnsemble => "GaussianSymplecticEnsemble"
    MatrixTag::Named(name~) => name
  }
}

///|
pub fn symbolic_kind_family(kind : SymbolicKind) -> SymbolicFamily {
  match kind {
    SymbolicKind::Continuous(_) => SymbolicFamily::Continuous
    SymbolicKind::Discrete(_) => SymbolicFamily::Discrete
    SymbolicKind::Joint(_) => SymbolicFamily::Joint
    SymbolicKind::Process(_) => SymbolicFamily::Process
    SymbolicKind::Matrix(_) => SymbolicFamily::Matrix
  }
}

///|
pub fn symbolic_kind_name(kind : SymbolicKind) -> String {
  match kind {
    SymbolicKind::Continuous(tag) => continuous_tag_name(tag)
    SymbolicKind::Discrete(tag) => discrete_tag_name(tag)
    SymbolicKind::Joint(tag) => joint_tag_name(tag)
    SymbolicKind::Process(tag) => process_tag_name(tag)
    SymbolicKind::Matrix(tag) => matrix_tag_name(tag)
  }
}

///|
pub fn symbolic_kind_is_opaque(kind : SymbolicKind) -> Bool {
  match kind {
    SymbolicKind::Continuous(
      ContinuousTag::ContinuousRV
      | ContinuousTag::ContinuousDistributionHandmade
    ) => true
    SymbolicKind::Discrete(
      DiscreteTag::DiscreteRV
      | DiscreteTag::FiniteDistributionHandmade
      | DiscreteTag::DiscreteDistributionHandmade
    ) => true
    SymbolicKind::Joint(
      JointTag::JointRV
      | JointTag::GeneralizedMultivariateLogGamma
      | JointTag::GeneralizedMultivariateLogGammaOmega
      | JointTag::MultivariateEwens
    ) => true
    SymbolicKind::Process(
      ProcessTag::StochasticProcess
      | ProcessTag::DiscreteTimeStochasticProcess
      | ProcessTag::DiscreteMarkovChain
      | ProcessTag::ContinuousMarkovChain
    ) => true
    SymbolicKind::Matrix(
      MatrixTag::JointEigenDistribution
      | MatrixTag::LevelSpacingDistribution
      | MatrixTag::MatrixGamma
      | MatrixTag::MatrixStudentT
      | MatrixTag::CircularEnsemble
      | MatrixTag::CircularUnitaryEnsemble
      | MatrixTag::CircularOrthogonalEnsemble
      | MatrixTag::CircularSymplecticEnsemble
      | MatrixTag::GaussianEnsemble
      | MatrixTag::GaussianUnitaryEnsemble
      | MatrixTag::GaussianOrthogonalEnsemble
      | MatrixTag::GaussianSymplecticEnsemble
    ) => true
    _ => false
  }
}

///|
pub fn symbolic_name_is_opaque(name : String) -> Bool {
  symbolic_kind_is_opaque(symbolic_kind_from_name(name))
}

///|
pub fn symbolic_name_family(name : String) -> SymbolicFamily {
  symbolic_kind_family(symbolic_kind_from_name(name))
}
