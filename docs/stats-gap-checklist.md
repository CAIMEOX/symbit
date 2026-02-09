# Stats Unaligned Checklist

Legend: `X` = currently unaligned or still fallback-based for this metric.
Metrics: density / cdf / mean / variance / mgf / cf / quantile / entropy

| Family | Distribution | density | cdf | mean | variance | mgf | cf | quantile | entropy |
|---|---|---|---|---|---|---|---|---|---|
| C | Arcsin |  |  |  |  | X | X |  |  |
| C | Benini |  |  | X | X | X | X | X | X |
| P | BernoulliProcess | X | X |  |  | X | X | X | X |
| C | Beta |  |  |  |  |  |  |  |  |
| D | BetaBinomial |  | X |  |  | X | X | X | X |
| C | BetaNoncentral | X | X | X | X | X | X | X | X |
| C | BetaPrime |  |  | X | X | X | X | X | X |
| C | BoundedPareto |  |  |  |  |  |  |  |  |
| C | Cauchy |  |  |  |  | X |  |  |  |
| C | Chi |  |  |  |  |  |  |  |  |
| C | ChiNoncentral |  | X | X | X | X | X | X | X |
| C | ChiSquared |  |  |  |  |  |  |  |  |
| M | CircularEnsemble | X | X | X | X | X | X | X | X |
| M | CircularOrthogonalEnsemble | X | X | X | X | X | X | X | X |
| M | CircularSymplecticEnsemble | X | X | X | X | X | X | X | X |
| M | CircularUnitaryEnsemble | X | X | X | X | X | X | X | X |
| C | ContinuousDistributionHandmade | X | X | X | X | X | X | X | X |
| P | ContinuousMarkovChain | X | X | X | X | X | X | X | X |
| C | ContinuousRV | X | X | X | X | X | X | X | X |
| C | Dagum |  |  | X | X | X | X | X | X |
| C | Davis |  | X | X | X | X | X | X | X |
| J | Dirichlet |  | X |  |  | X | X | X |  |
| D | DiscreteDistributionHandmade | X | X | X | X | X | X | X | X |
| P | DiscreteMarkovChain | X | X | X | X | X | X | X | X |
| D | DiscreteRV | X | X | X | X | X | X | X | X |
| P | DiscreteTimeStochasticProcess | X | X | X | X | X | X | X | X |
| C | Erlang |  |  |  |  |  |  |  |  |
| C | ExGaussian |  |  |  |  |  |  | X | X |
| C | ExponentialPower |  |  | X | X | X | X | X | X |
| C | FDistribution |  | X | X | X | X | X | X | X |
| D | FiniteDistributionHandmade | X | X | X | X | X | X | X | X |
| C | FisherZ |  | X | X | X | X | X | X | X |
| D | FlorySchulz |  |  |  |  |  |  | X | X |
| C | Frechet |  |  | X | X | X | X | X | X |
| C | GammaInverse |  |  | X | X | X |  | X | X |
| P | GammaProcess | X | X |  |  | X | X | X | X |
| M | GaussianEnsemble | X | X | X | X | X | X | X | X |
| C | GaussianInverse |  |  |  |  |  |  | X | X |
| M | GaussianOrthogonalEnsemble |  | X | X | X | X | X | X | X |
| M | GaussianSymplecticEnsemble |  | X | X | X | X | X | X | X |
| M | GaussianUnitaryEnsemble |  | X | X | X | X | X | X | X |
| J | GeneralizedMultivariateLogGamma | X | X | X | X | X | X | X | X |
| J | GeneralizedMultivariateLogGammaOmega | X | X | X | X | X | X | X | X |
| C | Gompertz |  |  |  |  |  |  |  |  |
| C | Gumbel |  |  |  |  |  |  |  |  |
| D | Hermite | X | X |  |  |  |  | X | X |
| D | Hypergeometric |  | X |  |  | X | X | X | X |
| D | IdealSoliton | X | X | X | X | X | X | X | X |
| M | JointEigenDistribution | X | X | X | X | X | X | X | X |
| J | JointRV | X | X | X | X | X | X | X | X |
| C | Kumaraswamy |  |  |  |  | X | X |  | X |
| C | Laplace |  |  |  |  |  |  |  |  |
| C | Levy |  |  | X | X | X |  |  |  |
| C | LogCauchy |  |  | X | X | X | X | X | X |
| C | LogLogistic |  |  |  |  | X | X |  |  |
| C | LogNormal |  |  |  |  |  |  |  |  |
| D | Logarithmic |  | X |  |  |  |  | X | X |
| C | Logistic |  |  |  |  |  |  |  |  |
| C | LogitNormal |  |  | X | X | X | X | X | X |
| C | Lomax |  |  | X | X | X | X |  |  |
| M | MatrixGamma |  | X | X | X | X | X | X | X |
| M | MatrixStudentT |  | X | X | X | X | X | X | X |
| C | Maxwell |  |  | X | X | X | X | X | X |
| C | Moyal |  |  |  |  |  |  |  |  |
| D | Multinomial | X | X |  |  | X | X | X | X |
| J | MultivariateBeta |  | X |  |  | X | X | X |  |
| J | MultivariateEwens | X | X | X | X | X | X | X | X |
| J | MultivariateLaplace |  | X |  |  |  |  | X | X |
| J | MultivariateNormal |  | X |  |  |  |  | X |  |
| J | MultivariateT |  | X |  |  | X | X | X | X |
| C | Nakagami |  |  | X | X | X | X | X | X |
| D | NegativeMultinomial | X | X |  |  | X | X | X | X |
| J | NormalGamma |  | X |  |  | X | X | X | X |
| C | Pareto |  |  |  |  |  |  |  |  |
| C | PowerFunction |  |  |  | X | X | X |  |  |
| C | QuadraticU |  |  |  | X |  |  | X | X |
| C | RaisedCosine |  |  |  |  |  |  | X | X |
| C | Rayleigh |  |  |  |  |  |  |  |  |
| C | Reciprocal |  |  |  |  |  |  |  |  |
| D | RobustSoliton | X | X | X | X | X | X | X | X |
| C | ShiftedGompertz |  |  | X | X | X | X | X | X |
| D | Skellam |  | X |  |  |  |  | X | X |
| P | StochasticProcess | X | X | X | X | X | X | X | X |
| C | StudentT |  |  |  |  | X |  |  |  |
| C | Trapezoidal |  |  |  |  | X | X |  |  |
| C | Triangular |  |  |  |  |  |  |  |  |
| C | Uniform |  |  |  |  |  |  |  |  |
| C | UniformSum | X | X |  |  |  |  | X | X |
| C | VonMises |  | X | X | X | X | X | X |  |
| C | Wald |  |  |  |  |  |  | X | X |
| C | Weibull |  |  |  |  | X | X |  |  |
| C | WignerSemicircle |  | X |  |  |  |  | X | X |
| D | YuleSimon |  |  |  | X |  |  | X | X |
| D | Zeta |  | X |  |  |  |  | X | X |
| M | level_spacing_distribution | X | X | X | X | X | X | X | X |

## Summary
- density: 29 missing of 95
- cdf: 51 missing of 95
- mean: 46 missing of 95
- variance: 49 missing of 95
- mgf: 64 missing of 95
- cf: 60 missing of 95
- quantile: 69 missing of 95
- entropy: 66 missing of 95
