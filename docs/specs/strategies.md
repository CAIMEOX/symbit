# Symbit Strategies — Current Design

`symstrategies` implements the strategy-combinator stack corresponding to
SymPy's `strategies` packages (`core`, `rl`, `traverse`, `tools`, `tree`, and
the `branch` subpackage). It targets the same observable rewrite semantics while
using MoonBit's static types.

## API Shape And Deviations

- Rules are first-class functions.
- Branching rules return `Array[T]` instead of Python generators.
- Variadic rule combinators accept arrays of functions instead of `*rules`.
- Tree strategies use a typed `Tree[T]` enum instead of Python lists/tuples.

```mbt
pub enum Tree[T] {
  Leaf(T)
  Choice(Array[Tree[T]])  // list-like branch
  Seq(Array[Tree[T]])     // tuple-like sequence
}
```

- Debug wrappers accept an explicit `name` parameter because MoonBit cannot
  reflect a function name.

## Expr Integration

- `symstrategies.util` defines `ExprOp` and `Fns` for `@symcore.Expr` trees.
- `basic_fns` uses raw constructors to mirror `Basic.__new__`-style structural
  preservation.
- `expr_fns` uses canonical constructors (`@symcore.add`, `mul`, `pow`,
  `function`).

## Raw Vs Canonical Constructors

Raw constructors are used for `basic_fns` and `rl.new`:

- `Expr::Add(args)` and `Expr::Mul(args)` preserve argument order and do not
  fold.
- `Expr::Pow(base, exp)` is not simplified.

Canonical constructors are used for `expr_fns` and `rl.rebuild`:

- `@symcore.add`, `mul`, `pow`, and `function` rebuild canonical form.

## Testing And Parity

Oracle tests under `src/sympy/strategies` call SymPy strategies and return
numeric results, stringified expression trees, or branching result arrays.
Runtime tests compare MoonBit results to oracle outputs with normalization where
needed.
