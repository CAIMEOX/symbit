# BoolAlg (SymPy logic/boolalg) Spec

## Scope
- Boolean atoms: True, False, Symbol
- Operators: Not, And, Or, Xor, Implies, Equivalent, ITE
- Derived helpers: Nand, Nor
- Canonicalization at construction time
- Stable ordering and string output

## AST
```
BoolExpr = True | False | Symbol(name)
         | Not(arg)
         | And(args...)
         | Or(args...)
         | Xor(args...)
         | Implies(a, b)
         | Equivalent(args...)
         | ITE(cond, t, f)
```

## Canonicalization rules
- `Not(True) -> False`, `Not(False) -> True`, `Not(Not(x)) -> x`
- `And`:
  - Flatten nested And
  - Remove `True`
  - If any `False` -> `False`
  - Remove duplicate arguments
  - Sort arguments by stable ordering
  - Empty -> `True`; single -> that arg
- `Or`:
  - Flatten nested Or
  - Remove `False`
  - If any `True` -> `True`
  - Remove duplicate arguments
  - Sort arguments by stable ordering
  - Empty -> `False`; single -> that arg
- `Xor`:
  - Flatten nested Xor
  - Remove `False`
  - Toggle on `True` (odd True count -> `Not` of remaining)
  - Cancel duplicate args pairwise (x ^ x -> False)
  - Empty -> `False`; single -> that arg
- `Implies`:
  - True -> consequent
  - False -> True
  - consequent True -> True
  - consequent False -> Not(antecedent)
  - antecedent == consequent -> True
- `Equivalent`:
  - Remove duplicates, sort args
  - If mix of True/False -> False
  - If only True present -> And(others)
  - If only False present -> And(Not(others))
  - If no args or 1 arg -> True
- `ITE`:
  - cond True/False -> branch
  - then == else -> then
  - (True, False) -> cond
  - (False, True) -> Not(cond)

## Ordering
Stable ordering for commutative arguments (And/Or/Xor/Equivalent):
- Primary: variant rank (Symbol < Not < And < Or < Xor < Implies < Equivalent < ITE < True < False)
- Secondary: recursive lexicographic compare of children

## Printing
- `True`, `False`
- `~x`, `x & y`, `x | y`
- Parentheses by precedence: `~` > `&` > `|`

## Tests
- Oracle parity via SymPy `sympify` of boolean strings
- Canonicalization examples: flatten, identity removal, duplicate removal, and precedence
