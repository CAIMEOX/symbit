# Strategies (SymPy port)

Scope: port `sympy.strategies` (core/rl/traverse/tools/tree + branch subpackage) into MoonBit.
The port targets SymPy semantics but adapts to MoonBit’s static types.

## API shape and deviations

- Rules are first-class functions. Branching rules return `Array[T]` instead of Python generators.
- Variadic rule combinators accept `Array[(T)->T]` (or `Array[(T)->Array[T]]`) instead of `*rules`.
- Tree strategies use a `Tree[T]` enum instead of Python lists/tuples.

```mbt
pub enum Tree[T] {
  Leaf(T)
  Choice(Array[Tree[T]])  // list in SymPy
  Seq(Array[Tree[T]])     // tuple in SymPy
}
```

- Debug wrappers accept an explicit `name` parameter because MoonBit cannot reflect a function name.

## Expr integration

- `symstrategies.util` defines `ExprOp` and `Fns` for `@symcore.Expr` trees.
- `basic_fns` uses *raw* constructors (no canonicalization) to mirror `Basic.__new__`.
- `expr_fns` uses canonical constructors (`@symcore.add/mul/pow/function`).

## Raw vs canonical constructors

Raw constructors are used for `basic_fns` and `rl.new`:
- `Expr::Add(args)` and `Expr::Mul(args)` preserve argument order and do not fold.
- `Expr::Pow(base, exp)` is not simplified.

Canonical constructors are used for `expr_fns` and `rl.rebuild`:
- `@symcore.add/mul/pow/function` rebuild canonical form.

## Testing and oracle parity

- Tests follow SymPy’s `sympy/strategies/tests` and `sympy/strategies/branch/tests`.
- Oracle package `sympy/strategies` calls SymPy strategies and returns:
  - `Int` results for numeric strategies,
  - `String` (SymPy `str`) for Expr/Basic trees,
  - `Array[String]` for branching rule results.
- Compare MoonBit results to oracle outputs (with normalization when needed).

