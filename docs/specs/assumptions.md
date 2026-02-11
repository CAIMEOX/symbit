# Symbit Assumptions — Initial Spec

Goal: add a MoonBit-first assumptions layer aligned with SymPy's tri-valued
predicate model, while keeping `symcore` unchanged.

## Package layout

- `symassume`
  - `Tri` truth values: `True | False | Unknown`.
  - `SymbolFacts` and `AssumeEnv` for symbol-scoped assumptions.
  - predicate queries: `is_zero`, `is_nonzero`, `is_integer`, `is_rational`,
    `is_real`, `is_positive`, `is_nonnegative`.
  - Q/ask layer:
    - `PredicateKey` + `Query` AST (`Atom/Not/And/Or/Implies/Equivalent`).
    - `ask(...)` with SAT-based tri-valued decision.
    - global assumptions APIs: `add/remove/clear/get_global_assumptions`,
      `ask_global`.
- `sympy/assumptions`
  - oracle bridge to evaluate SymPy `expr.is_*` attributes.
  - supports per-symbol assumptions and `ask(...)` parity tests.

## Data model

- `symcore.Expr::Symbol(name)` remains unchanged.
- assumptions are provided externally via `AssumeEnv : Map[String, SymbolFacts]`.
- `SymbolFacts` stores tri-state values for the seven baseline predicates.

## Invariants and closure rules

- Facts are normalized through implication closure:
  - `integer -> rational -> real`
  - `positive -> nonnegative & nonzero & real`
  - `zero -> !nonzero & !positive & nonnegative & integer`
  - `nonnegative & nonzero -> positive`
- Conflicting input assumptions merge conservatively to `Unknown`.

## Predicate inference policy

- Conservative and monotonic: only return `True/False` when justified by local
  rules; otherwise return `Unknown`.
- Supported structural inference:
  - numeric literals (`Number`)
  - `Add`, `Mul`, `Pow`
  - basic functions: `exp`, `log`, `sqrt`, `Abs/abs`, `sin/cos/tan`, `re/im`.

## Oracle parity

- Compare each `symassume` predicate with SymPy's `expr.is_*`.
- Build SymPy symbols using the same per-symbol assumptions from `AssumeEnv`.
- Use this as regression guard for supported rule surface.
- For Q/ask parity, compare stringified tri-values against SymPy `ask`
  (`True/False/None` plus `InconsistentAssumptions` sentinel on conflicting
  assumptions).

## Q/ask family checklist

- Done: propositional core (`And/Or/Not/Implies/Equivalent`) + CNF SAT solve.
- Done: relation family surface (`Eq/Ne/Gt/Ge/Lt/Le`) with consistency clauses.
- Done: numeric scalar family parity (`0/2/-3/1/2`) across key unary predicates.
- Done: sign and extended-sign family on infinities (`oo/-oo/zoo`) and
  transcendental constants (`I/pi/E`).
- Done: context handling (`ask_global`) and conjunction literal projection to
  `AssumeEnv` for structural reasoning.
- Done: structural handlers now covered by parity tests:
  `Q.complex(x+1)`, `Q.finite(x+1)`, `Q.nonzero(x+1)`,
  `Q.extended_nonnegative(x+1)`, `Q.imaginary(I*x)` under assumptions.
- Done: relation family adds conservative symbolic inference for
  `x` vs constant and linear forms `x + c` vs constant, aligned to current
  SymPy `ask` behavior (`Eq/Ne/Gt/Ge/Lt/Le` subset).
- Done: matrix/tensor predicate subset extended with
  `positive_definite(MatrixSymbol(...))` fine branches to
  `~hermitian` / `~antihermitian` (parity-guarded).
- Pending: matrix/tensor-specific predicates (`symmetric/invertible/...`) still
  use conservative `Unknown`-first behavior, parity-guarded where applicable.
- Pending: richer symbolic relation reasoning (beyond current conservative
  `ask` behavior) needs dedicated handler families aligned with SymPy internals.
