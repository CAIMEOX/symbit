# Symbit Simplify — Current Design

`symsimplify` provides the general simplification pipeline plus targeted
rewrite families for rational, radical, trigonometric, combinatorial,
hypergeometric, logarithmic, CSE, and traversal workflows.

## Package Layout

- `SimplifyPattern` and `SimplifyPlan` describe named rewrite families.
- `simplify` runs a bounded bottom-up fixed-point pipeline.
- Targeted front doors include:
  - core: `simplify`, `powsimp`, `trigsimp`, `signsimp`;
  - rational/radical: `radsimp`, `ratsimp`, `ratsimpmodprime`,
    `sqrtdenest`, `fraction`, `numer`, `denom`, `collect`, `rcollect`,
    `collect_const`;
  - special: `combsimp`, `hyperexpand`, `powdenest`, `exptrigsimp`,
    `gammasimp`, `logcombine`, `separatevars`, `posify`, `hypersimp`,
    `hypersimilar`, and the Fu rule family;
  - CSE/traversal: `cse`, `sub_pre`, `sub_post`, `EPath`, `epath`,
    `epath_apply`, `use`;
  - compatibility helpers: `besselsimp`, `kroneckersimp`, `nsimplify`.
- Oracle package `src/sympy/simplify` compares supported behavior with SymPy.

## Rewrite Model

Simplification is pure and compositional:

- recursively simplify children;
- apply local rewrite patterns;
- compare candidates by structural complexity;
- iterate to a bounded fixed point;
- preserve symbolic structure when a targeted rule does not apply.

The broad `simplify` pass composes sign normalization, local pattern rewrites,
simple expansion/factoring, rational structure cleanup, power simplification,
radical denesting, trigonometric/exponential rewrites, logarithmic combination,
special-function simplifiers, and final cleanup.

## Implemented Rewrite Families

- Exact arithmetic folding and numeric power evaluation.
- Additive term collection and multiplicative power merging.
- Simple factor/collect helpers.
- Rational numerator/denominator extraction and cancellation.
- Radical/rational denominator simplification.
- Trigonometric identities and the Fu `TR*`-style helper family.
- Exponential/trigonometric, logarithmic, gamma, combinatorial,
  hypergeometric, Bessel, and Kronecker-delta helpers.
- CSE extraction/reconstruction and traversal helpers.

## Current Limits

The package is heuristic and bounded. Difficult expressions can remain only
partially simplified, and many specialized SymPy internals are represented by
conservative front doors rather than full one-for-one ports.

## Oracle Parity

Parity tests compare selected outputs by converting MoonBit expressions through
the test-only Python bridge and comparing against direct SymPy calls. The parity
surface includes broad simplify calls, targeted simplify families, CSE helpers,
and Fu-style trigonometric rewrites.
