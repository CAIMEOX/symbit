# Symbit

From SymPy to MoonBit.

## Status

Initial scaffolding for a SymPy-style core:

- `symnum`: `BigRational` with normalization/gcd, arithmetic, hashing.
- `symcore`: expression AST (`Number`, `Symbol`, `Add`, `Mul`, `Pow`, `Function`)
  with canonicalized constructors and substitution.
- `symprint`: stable printers (`debug_repr` S-expr + minimal infix).

## Quick check

```mbt check
test {
  let expr = @symbit.add([
    @symbit.integer(1),
    @symbit.mul([@symbit.symbol("x"), @symbit.pow(@symbit.symbol("y"), @symbit.integer(2))]),
  ])
  inspect(@symbit.debug_repr(expr), content="(+ 1 (* sym:x (^ sym:y 2)))")
}
```
