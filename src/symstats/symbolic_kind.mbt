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
    "Arcsin" => Arcsin
    "Benini" => Benini
    "Beta" => Beta
    "BetaNoncentral" => BetaNoncentral
    "BetaPrime" => BetaPrime
    "BoundedPareto" => BoundedPareto
    "Cauchy" => Cauchy
    "Chi" => Chi
    "ChiNoncentral" => ChiNoncentral
    "ChiSquared" => ChiSquared
    "ContinuousRV" => ContinuousRV
    "ContinuousDistributionHandmade" => ContinuousDistributionHandmade
    "Dagum" => Dagum
    "Davis" => Davis
    "Exponential" => Exponential
    "Erlang" => Erlang
    "ExGaussian" => ExGaussian
    "ExponentialPower" => ExponentialPower
    "FDistribution" => FDistribution
    "FisherZ" => FisherZ
    "Frechet" => Frechet
    "GammaInverse" => GammaInverse
    "GaussianInverse" => GaussianInverse
    "Gompertz" => Gompertz
    "Gumbel" => Gumbel
    "Kumaraswamy" => Kumaraswamy
    "Laplace" => Laplace
    "Levy" => Levy
    "LogCauchy" => LogCauchy
    "LogLogistic" => LogLogistic
    "LogNormal" => LogNormal
    "Logarithmic" => Logarithmic
    "Logistic" => Logistic
    "LogitNormal" => LogitNormal
    "Lomax" => Lomax
    "Maxwell" => Maxwell
    "Moyal" => Moyal
    "Nakagami" => Nakagami
    "Pareto" => Pareto
    "PowerFunction" => PowerFunction
    "QuadraticU" => QuadraticU
    "RaisedCosine" => RaisedCosine
    "Rayleigh" => Rayleigh
    "Reciprocal" => Reciprocal
    "ShiftedGompertz" => ShiftedGompertz
    "StudentT" => StudentT
    "Trapezoidal" => Trapezoidal
    "Triangular" => Triangular
    "Uniform" => Uniform
    "UniformSum" => UniformSum
    "VonMises" => VonMises
    "Wald" => Wald
    "Weibull" => Weibull
    "WignerSemicircle" => WignerSemicircle
    _ => Named(name~)
  }
}

///|
fn discrete_tag_from_name(name : String) -> DiscreteTag {
  match name {
    "BetaBinomial" => BetaBinomial
    "DiscreteRV" => DiscreteRV
    "DiscreteDistributionHandmade" => DiscreteDistributionHandmade
    "FiniteDistributionHandmade" => FiniteDistributionHandmade
    "FlorySchulz" => FlorySchulz
    "Hermite" => Hermite
    "Hypergeometric" => Hypergeometric
    "IdealSoliton" => IdealSoliton
    "Logarithmic" => Logarithmic
    "RobustSoliton" => RobustSoliton
    "Skellam" => Skellam
    "Multinomial" => Multinomial
    "NegativeMultinomial" => NegativeMultinomial
    "YuleSimon" => YuleSimon
    "Zeta" => Zeta
    _ => Named(name~)
  }
}

///|
fn joint_tag_from_name(name : String) -> JointTag {
  match name {
    "JointRV" => JointRV
    "Dirichlet" => Dirichlet
    "GeneralizedMultivariateLogGamma" => GeneralizedMultivariateLogGamma
    "GeneralizedMultivariateLogGammaOmega" =>
      GeneralizedMultivariateLogGammaOmega
    "MultivariateBeta" => MultivariateBeta
    "MultivariateEwens" => MultivariateEwens
    "MultivariateT" => MultivariateT
    "NormalGamma" => NormalGamma
    "MultivariateNormal" => MultivariateNormal
    "MultivariateLaplace" => MultivariateLaplace
    _ => Named(name~)
  }
}

///|
fn process_tag_from_name(name : String) -> ProcessTag {
  match name {
    "StochasticProcess" => StochasticProcess
    "DiscreteTimeStochasticProcess" => DiscreteTimeStochasticProcess
    "DiscreteMarkovChain" => DiscreteMarkovChain
    "ContinuousMarkovChain" => ContinuousMarkovChain
    "BernoulliProcess" => BernoulliProcess
    "GammaProcess" => GammaProcess
    _ => Named(name~)
  }
}

///|
fn matrix_tag_from_name(name : String) -> MatrixTag {
  match name {
    "JointEigenDistribution" => JointEigenDistribution
    "level_spacing_distribution" => LevelSpacingDistribution
    "MatrixGamma" => MatrixGamma
    "MatrixStudentT" => MatrixStudentT
    "CircularEnsemble" => CircularEnsemble
    "CircularUnitaryEnsemble" => CircularUnitaryEnsemble
    "CircularOrthogonalEnsemble" => CircularOrthogonalEnsemble
    "CircularSymplecticEnsemble" => CircularSymplecticEnsemble
    "GaussianEnsemble" => GaussianEnsemble
    "GaussianUnitaryEnsemble" => GaussianUnitaryEnsemble
    "GaussianOrthogonalEnsemble" => GaussianOrthogonalEnsemble
    "GaussianSymplecticEnsemble" => GaussianSymplecticEnsemble
    _ => Named(name~)
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
    | "NegativeMultinomial" => Discrete(discrete_tag_from_name(name))
    "JointRV"
    | "Dirichlet"
    | "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega"
    | "MultivariateBeta"
    | "MultivariateEwens"
    | "MultivariateT"
    | "NormalGamma"
    | "MultivariateNormal"
    | "MultivariateLaplace" => Joint(joint_tag_from_name(name))
    "StochasticProcess"
    | "DiscreteTimeStochasticProcess"
    | "DiscreteMarkovChain"
    | "ContinuousMarkovChain"
    | "BernoulliProcess"
    | "GammaProcess" => Process(process_tag_from_name(name))
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
    | "GaussianSymplecticEnsemble" => Matrix(matrix_tag_from_name(name))
    _ => Continuous(continuous_tag_from_name(name))
  }
}

///|
fn continuous_tag_name(tag : ContinuousTag) -> String {
  match tag {
    Arcsin => "Arcsin"
    Benini => "Benini"
    Beta => "Beta"
    BetaNoncentral => "BetaNoncentral"
    BetaPrime => "BetaPrime"
    BoundedPareto => "BoundedPareto"
    Cauchy => "Cauchy"
    Chi => "Chi"
    ChiNoncentral => "ChiNoncentral"
    ChiSquared => "ChiSquared"
    ContinuousRV => "ContinuousRV"
    ContinuousDistributionHandmade => "ContinuousDistributionHandmade"
    Dagum => "Dagum"
    Davis => "Davis"
    Exponential => "Exponential"
    Erlang => "Erlang"
    ExGaussian => "ExGaussian"
    ExponentialPower => "ExponentialPower"
    FDistribution => "FDistribution"
    FisherZ => "FisherZ"
    Frechet => "Frechet"
    GammaInverse => "GammaInverse"
    GaussianInverse => "GaussianInverse"
    Gompertz => "Gompertz"
    Gumbel => "Gumbel"
    Kumaraswamy => "Kumaraswamy"
    Laplace => "Laplace"
    Levy => "Levy"
    LogCauchy => "LogCauchy"
    LogLogistic => "LogLogistic"
    LogNormal => "LogNormal"
    Logarithmic => "Logarithmic"
    Logistic => "Logistic"
    LogitNormal => "LogitNormal"
    Lomax => "Lomax"
    Maxwell => "Maxwell"
    Moyal => "Moyal"
    Nakagami => "Nakagami"
    Named(name~) => name
    Pareto => "Pareto"
    PowerFunction => "PowerFunction"
    QuadraticU => "QuadraticU"
    RaisedCosine => "RaisedCosine"
    Rayleigh => "Rayleigh"
    Reciprocal => "Reciprocal"
    ShiftedGompertz => "ShiftedGompertz"
    StudentT => "StudentT"
    Trapezoidal => "Trapezoidal"
    Triangular => "Triangular"
    Uniform => "Uniform"
    UniformSum => "UniformSum"
    VonMises => "VonMises"
    Wald => "Wald"
    Weibull => "Weibull"
    WignerSemicircle => "WignerSemicircle"
  }
}

///|
fn discrete_tag_name(tag : DiscreteTag) -> String {
  match tag {
    BetaBinomial => "BetaBinomial"
    DiscreteRV => "DiscreteRV"
    DiscreteDistributionHandmade => "DiscreteDistributionHandmade"
    FiniteDistributionHandmade => "FiniteDistributionHandmade"
    FlorySchulz => "FlorySchulz"
    Hermite => "Hermite"
    Hypergeometric => "Hypergeometric"
    IdealSoliton => "IdealSoliton"
    Logarithmic => "Logarithmic"
    RobustSoliton => "RobustSoliton"
    Skellam => "Skellam"
    Multinomial => "Multinomial"
    NegativeMultinomial => "NegativeMultinomial"
    YuleSimon => "YuleSimon"
    Zeta => "Zeta"
    Named(name~) => name
  }
}

///|
fn joint_tag_name(tag : JointTag) -> String {
  match tag {
    JointRV => "JointRV"
    Dirichlet => "Dirichlet"
    GeneralizedMultivariateLogGamma => "GeneralizedMultivariateLogGamma"
    GeneralizedMultivariateLogGammaOmega =>
      "GeneralizedMultivariateLogGammaOmega"
    MultivariateBeta => "MultivariateBeta"
    MultivariateEwens => "MultivariateEwens"
    MultivariateT => "MultivariateT"
    NormalGamma => "NormalGamma"
    MultivariateNormal => "MultivariateNormal"
    MultivariateLaplace => "MultivariateLaplace"
    Named(name~) => name
  }
}

///|
fn process_tag_name(tag : ProcessTag) -> String {
  match tag {
    StochasticProcess => "StochasticProcess"
    DiscreteTimeStochasticProcess => "DiscreteTimeStochasticProcess"
    DiscreteMarkovChain => "DiscreteMarkovChain"
    ContinuousMarkovChain => "ContinuousMarkovChain"
    BernoulliProcess => "BernoulliProcess"
    GammaProcess => "GammaProcess"
    Named(name~) => name
  }
}

///|
fn matrix_tag_name(tag : MatrixTag) -> String {
  match tag {
    JointEigenDistribution => "JointEigenDistribution"
    LevelSpacingDistribution => "level_spacing_distribution"
    MatrixGamma => "MatrixGamma"
    MatrixStudentT => "MatrixStudentT"
    CircularEnsemble => "CircularEnsemble"
    CircularUnitaryEnsemble => "CircularUnitaryEnsemble"
    CircularOrthogonalEnsemble => "CircularOrthogonalEnsemble"
    CircularSymplecticEnsemble => "CircularSymplecticEnsemble"
    GaussianEnsemble => "GaussianEnsemble"
    GaussianUnitaryEnsemble => "GaussianUnitaryEnsemble"
    GaussianOrthogonalEnsemble => "GaussianOrthogonalEnsemble"
    GaussianSymplecticEnsemble => "GaussianSymplecticEnsemble"
    Named(name~) => name
  }
}

///|
pub fn symbolic_kind_family(kind : SymbolicKind) -> SymbolicFamily {
  match kind {
    Continuous(_) => Continuous
    Discrete(_) => Discrete
    Joint(_) => Joint
    Process(_) => Process
    Matrix(_) => Matrix
  }
}

///|
pub fn symbolic_kind_name(kind : SymbolicKind) -> String {
  match kind {
    Continuous(tag) => continuous_tag_name(tag)
    Discrete(tag) => discrete_tag_name(tag)
    Joint(tag) => joint_tag_name(tag)
    Process(tag) => process_tag_name(tag)
    Matrix(tag) => matrix_tag_name(tag)
  }
}

///|
pub fn symbolic_kind_is_opaque(kind : SymbolicKind) -> Bool {
  match kind {
    Continuous(ContinuousRV | ContinuousDistributionHandmade) => true
    Discrete(
      DiscreteRV
      | FiniteDistributionHandmade
      | DiscreteDistributionHandmade
    ) => true
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
      | MultivariateEwens
    ) => true
    Process(
      StochasticProcess
      | DiscreteTimeStochasticProcess
      | DiscreteMarkovChain
      | ContinuousMarkovChain
    ) => true
    Matrix(
      JointEigenDistribution
      | LevelSpacingDistribution
      | MatrixGamma
      | MatrixStudentT
      | CircularEnsemble
      | CircularUnitaryEnsemble
      | CircularOrthogonalEnsemble
      | CircularSymplecticEnsemble
      | GaussianEnsemble
      | GaussianUnitaryEnsemble
      | GaussianOrthogonalEnsemble
      | GaussianSymplecticEnsemble
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
