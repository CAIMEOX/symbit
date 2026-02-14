# Symbit Simplify — ADT + Pattern Matching

Goal: port `sympy.simplify` in staged, oracle-verified increments with a
MoonBit-first functional architecture centered on ADT-driven rewrite passes.

## Package layout

- `symsimplify`
  - `SimplifyPattern` / `SimplifyPlan` ADTs.
  - bottom-up rewrite engine driven by pattern matching.
  - public APIs:
    - core: `simplify`, `powsimp`, `trigsimp`, `signsimp`
    - rational: `radsimp`, `ratsimp`, `ratsimpmodprime`, `sqrtdenest`,
      `fraction`, `numer`, `denom`, `collect`, `rcollect`, `collect_const`
    - special: `combsimp`, `hyperexpand`, `powdenest`, `exptrigsimp`,
      `gammasimp`, `logcombine`, `separatevars`, `posify`, `hypersimp`,
      `hypersimilar`, `fu`
    - cse/traversal: `cse`, `sub_pre`, `sub_post`, `EPath`, `epath`,
      `epath_apply`, `use`
    - compat: `besselsimp`, `kroneckersimp`, `nsimplify`
- `sympy/simplify`
  - oracle wrappers for SymPy simplify family.
  - returns `srepr` strings for stable parity checks.

## Functional rewrite model

- Rules are declared as ADT variants:
  - `FoldConstants`
  - `AddLikeTerms`
  - `MulLikeBases`
  - `PowDenest`
  - `TrigPythagorean`
  - `FunctionIdentities`
- Execution is pure and compositional:
  - recurse bottom-up,
  - apply one local rule with `match`,
  - chain rule list,
  - iterate to fixed point (bounded passes).

## Implemented rewrites (current)

- Arithmetic:
  - combine like-add terms (`x + x -> 2*x`, `x + 2*x -> 3*x`)
  - combine multiplicative powers (`x*x*y -> x^2*y`, `x^a*x^b -> x^(a+b)` for numeric exponents)
  - denest numeric power towers (`(x^2)^3 -> x^6`)
  - evaluate numeric powers with integer exponent (`2^3 -> 8`).
- Function identities:
  - `sin(0)`, `cos(0)`, `tan(0)`, `exp(0)`, `log(1)`, `log(E)`, `sqrt(0/1)`, `Abs(number)`.
- Trigonometric:
  - `sin(x)^2 + cos(x)^2 -> 1`.

## Oracle parity

- Compare `srepr` of:
  - MoonBit output converted via Python bridge,
  - direct SymPy call output (`simplify`, `powsimp`, `trigsimp`, `signsimp`).
- Current parity set also includes:
  - `radsimp/ratsimp/sqrtdenest/combsimp/hyperexpand`
  - `powdenest/exptrigsimp/gammasimp/logcombine`
  - `separatevars/hypersimp/hypersimilar/fu`
  - `besselsimp/kroneckersimp/nsimplify/ratsimpmodprime`
  - `cse_opts.sub_pre/sub_post`
