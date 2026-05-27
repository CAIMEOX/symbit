# Symbit Assumptions — Current Design

`symassume` is the assumptions and predicate-query layer for Symbit. It follows
SymPy's tri-valued style while keeping assumptions external to `symcore.Symbol`.

## Package Layout

- `Tri` truth values: `True`, `False`, and `Unknown`.
- `SymbolFacts` and `AssumeEnv` for symbol-scoped assumptions.
- Predicate queries such as `is_zero`, `is_nonzero`, `is_integer`,
  `is_rational`, `is_real`, `is_positive`, and `is_nonnegative`.
- Q/ask layer:
  - `PredicateKey`;
  - `Query` AST (`Atom`, `Not`, `And`, `Or`, `Implies`, `Equivalent`);
  - SAT-backed `ask`;
  - global assumption APIs: `add_global_assumption`,
    `remove_global_assumption`, `clear_global_assumptions`,
    `get_global_assumptions`, and `ask_global`.
- Oracle package `src/sympy/assumptions` for SymPy parity tests.

## Data Model

`symcore.Expr::Symbol(name)` remains assumption-free. Assumptions are supplied
through `AssumeEnv`, so the same symbol can be queried under different
contexts.

## Invariants And Closure Rules

Facts are normalized through conservative implication closure:

- `integer -> rational -> real`
- `positive -> nonnegative & nonzero & real`
- `zero -> !nonzero & !positive & nonnegative & integer`
- `nonnegative & nonzero -> positive`

Conflicting input assumptions merge conservatively to `Unknown`.

## Predicate Inference Policy

Inference is monotonic and conservative: return `True` or `False` only when a
local rule, explicit assumption, or SAT consequence justifies it; otherwise
return `Unknown`.

Implemented structural inference includes numeric literals, arithmetic
structure (`Add`, `Mul`, `Pow`), common elementary functions, selected
relations, infinity/constant handling, and a matrix/tensor predicate subset.

## Q/Ask Coverage

- Propositional query core and CNF SAT solving.
- Relation family surface (`Eq`, `Ne`, `Gt`, `Ge`, `Lt`, `Le`) with consistency
  clauses.
- Numeric scalar family parity across key unary predicates.
- Sign and extended-sign handling for infinities and common constants.
- Global context handling and conjunction projection to `AssumeEnv`.
- Structural handlers for complex/finite/nonzero/extended-nonnegative and
  selected imaginary queries.
- Conservative symbolic relation inference for simple symbol-vs-constant and
  linear-form cases.
- Matrix/tensor predicate subset for positive-definite branches guarded by
  parity tests.

## Current Limits

Matrix/tensor-specific predicates such as richer symmetric/invertible families
and relation reasoning beyond the current conservative subset still return
`Unknown` unless an implemented handler can justify the result.

## Oracle Parity

Predicate tests compare against SymPy `expr.is_*` attributes and `ask` results
(`True`, `False`, `None`, plus an inconsistency sentinel for conflicting
assumptions).
