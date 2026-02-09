# Stats Unaligned Checklist

Legend: `X` = currently unaligned or still fallback-based for this metric.
Metrics: density / cdf / mean / variance / mgf / cf / quantile / entropy

| Family | Distribution | density | cdf | mean | variance | mgf | cf | quantile | entropy |
|---|---|---|---|---|---|---|---|---|---|
| C | Arcsin |  |  |  |  | X | X |  |  |
| C | Benini |  |  | X | X | X | X | X | X |
| P | BernoulliProcess |  |  |  |  | X | X | X | X |
| C | Beta |  |  |  |  |  |  |  |  |
| D | BetaBinomial |  |  |  |  | X | X | X | X |
| C | BetaNoncentral |  |  | X | X | X | X | X | X |
| C | BetaPrime |  |  | X | X | X | X | X | X |
| C | BoundedPareto |  |  |  |  |  |  |  |  |
| C | Cauchy |  |  |  |  | X |  |  |  |
| C | Chi |  |  |  |  |  |  |  |  |
| C | ChiNoncentral |  |  | X | X | X | X | X | X |
| C | ChiSquared |  |  |  |  |  |  |  |  |
| M | CircularEnsemble |  |  |  |  |  |  |  |  |
| M | CircularOrthogonalEnsemble |  |  |  |  |  |  |  |  |
| M | CircularSymplecticEnsemble |  |  |  |  |  |  |  |  |
| M | CircularUnitaryEnsemble |  |  |  |  |  |  |  |  |
| C | ContinuousDistributionHandmade |  |  |  |  |  |  |  |  |
| P | ContinuousMarkovChain |  |  |  |  |  |  |  |  |
| C | ContinuousRV |  |  |  |  |  |  |  |  |
| C | Dagum |  |  | X | X | X | X | X | X |
| C | Davis |  |  | X | X | X | X | X | X |
| J | Dirichlet |  |  |  |  | X | X | X |  |
| D | DiscreteDistributionHandmade |  |  |  |  |  |  |  |  |
| P | DiscreteMarkovChain |  |  |  |  |  |  |  |  |
| D | DiscreteRV |  |  |  |  |  |  |  |  |
| P | DiscreteTimeStochasticProcess |  |  |  |  |  |  |  |  |
| C | Erlang |  |  |  |  |  |  |  |  |
| C | ExGaussian |  |  |  |  |  |  | X | X |
| C | ExponentialPower |  |  | X | X | X | X | X | X |
| C | FDistribution |  |  | X | X | X | X | X | X |
| D | FiniteDistributionHandmade |  |  |  |  |  |  |  |  |
| C | FisherZ |  |  | X | X | X | X | X | X |
| D | FlorySchulz |  |  |  |  |  |  | X | X |
| C | Frechet |  |  | X | X | X | X | X | X |
| C | GammaInverse |  |  | X | X | X |  | X | X |
| P | GammaProcess |  |  |  |  | X | X | X | X |
| M | GaussianEnsemble |  |  |  |  |  |  |  |  |
| C | GaussianInverse |  |  |  |  |  |  | X | X |
| M | GaussianOrthogonalEnsemble |  |  | X | X | X | X | X | X |
| M | GaussianSymplecticEnsemble |  |  | X | X | X | X | X | X |
| M | GaussianUnitaryEnsemble |  |  | X | X | X | X | X | X |
| J | GeneralizedMultivariateLogGamma |  |  |  |  |  |  |  |  |
| J | GeneralizedMultivariateLogGammaOmega |  |  |  |  |  |  |  |  |
| C | Gompertz |  |  |  |  |  |  |  |  |
| C | Gumbel |  |  |  |  |  |  |  |  |
| D | Hermite |  |  |  |  |  |  | X | X |
| D | Hypergeometric |  |  |  |  | X | X | X | X |
| D | IdealSoliton |  |  | X | X | X | X | X | X |
| M | JointEigenDistribution |  |  |  |  |  |  |  |  |
| J | JointRV |  |  |  |  |  |  |  |  |
| C | Kumaraswamy |  |  |  |  | X | X |  | X |
| C | Laplace |  |  |  |  |  |  |  |  |
| C | Levy |  |  | X | X | X |  |  |  |
| C | LogCauchy |  |  | X | X | X | X | X | X |
| C | LogLogistic |  |  |  |  | X | X |  |  |
| C | LogNormal |  |  |  |  |  |  |  |  |
| D | Logarithmic |  |  |  |  |  |  | X | X |
| C | Logistic |  |  |  |  |  |  |  |  |
| C | LogitNormal |  |  | X | X | X | X | X | X |
| C | Lomax |  |  | X | X | X | X |  |  |
| M | MatrixGamma |  |  | X | X | X | X | X | X |
| M | MatrixStudentT |  |  | X | X | X | X | X | X |
| C | Maxwell |  |  | X | X | X | X | X | X |
| C | Moyal |  |  |  |  |  |  |  |  |
| D | Multinomial |  |  |  |  | X | X | X | X |
| J | MultivariateBeta |  |  |  |  | X | X | X |  |
| J | MultivariateEwens |  |  |  |  |  |  |  |  |
| J | MultivariateLaplace |  |  |  |  |  |  | X | X |
| J | MultivariateNormal |  |  |  |  |  |  | X |  |
| J | MultivariateT |  |  |  |  | X | X | X | X |
| C | Nakagami |  |  | X | X | X | X | X | X |
| D | NegativeMultinomial |  |  |  |  | X | X | X | X |
| J | NormalGamma |  |  |  |  | X | X | X | X |
| C | Pareto |  |  |  |  |  |  |  |  |
| C | PowerFunction |  |  |  | X | X | X |  |  |
| C | QuadraticU |  |  |  | X |  |  | X | X |
| C | RaisedCosine |  |  |  |  |  |  | X | X |
| C | Rayleigh |  |  |  |  |  |  |  |  |
| C | Reciprocal |  |  |  |  |  |  |  |  |
| D | RobustSoliton |  |  | X | X | X | X | X | X |
| C | ShiftedGompertz |  |  | X | X | X | X | X | X |
| D | Skellam |  |  |  |  |  |  | X | X |
| P | StochasticProcess |  |  |  |  |  |  |  |  |
| C | StudentT |  |  |  |  | X |  |  |  |
| C | Trapezoidal |  |  |  |  | X | X |  |  |
| C | Triangular |  |  |  |  |  |  |  |  |
| C | Uniform |  |  |  |  |  |  |  |  |
| C | UniformSum |  |  |  |  |  |  | X | X |
| C | VonMises |  |  | X | X | X | X |  |  |
| C | Wald |  |  |  |  |  |  | X | X |
| C | Weibull |  |  |  |  | X | X |  |  |
| C | WignerSemicircle |  |  |  |  |  |  | X | X |
| D | YuleSimon |  |  |  | X |  |  | X | X |
| D | Zeta |  |  |  |  |  |  | X | X |
| M | level_spacing_distribution |  |  |  |  |  |  |  |  |

## Summary
- density: 0 missing of 95
- cdf: 0 missing of 95
- mean: 26 missing of 95
- variance: 29 missing of 95
- mgf: 44 missing of 95
- cf: 40 missing of 95
- quantile: 48 missing of 95
- entropy: 46 missing of 95
