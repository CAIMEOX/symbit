# Symbit Parsing — Draft Design and Execution Plan

This document records the parser migration plan for SymPy's `parsing` package
in a form that fits Symbit's MoonBit architecture.

The immediate target is **not** the full upstream `sympy.parsing` tree. The
first target is the core string parser represented by
`sympy.parsing.sympy_parser`, because that is the foundation required by later
LaTeX / Mathematica / Maxima / C / Fortran frontends.

## Current state

- There is currently **no** dedicated `symparse` package in Symbit.
- The repository contains many internal shape recognizers and local
  `parse_*` helpers, but no user-facing `parse_expr` surface.
- Therefore parser support should be treated as a new top-level migration,
  not as an incremental extension of an existing package.

## Upstream surface to mirror

SymPy's `parsing` package includes several distinct layers:

- `sympy_parser.py`
  - token transformations
  - implicit multiplication / implicit application
  - number coercions and symbol insertion
  - `parse_expr`
- `ast_parser.py`
  - Python-AST based safe expression parsing
- `latex/*`
  - LaTeX frontends and transformers
- `mathematica.py`, `maxima.py`
  - foreign syntax adapters
- `c/c_parser.py`, `fortran/fortran_parser.py`
  - source-language translators

The correct migration order is to build the **core expression parser first**,
then layer foreign syntaxes on top.

## Why the MoonBit implementation should differ

SymPy's parser is heavily shaped by Python:

- Python token streams
- Python AST transforms
- controlled `eval`-style expression construction
- dynamic name resolution

Symbit should not reproduce that architecture mechanically. MoonBit gives us
better tools for a typed and more explicit implementation:

- `Token` as an ADT rather than Python token tuples
- explicit `Ast` / concrete syntax nodes
- pure lexer and parser passes
- Pratt / precedence-climbing expression parsing
- explicit lowering into `symcore.Expr`
- explicit environments and registries instead of dynamic `eval`

So the migration goal is:

- keep the **user-facing semantics** as close to SymPy as practical
- intentionally make the **internal architecture** more functional, explicit,
  and typed

## Proposed package layout

Package: `src/symparse`

- `errors.mbt`
  - spans, parser errors
- `token.mbt`
  - token kinds and token records
- `ast.mbt`
  - parser AST for user syntax
- `lexer.mbt`
  - string -> token stream
- `parser_expr.mbt`
  - Pratt / precedence parser for infix expressions
- `lower_expr.mbt`
  - AST -> `symcore.Expr`
- `api.mbt`
  - public entry points such as `parse_expr`

Oracle package: `src/sympy/parsing`

- minimal Python/SymPy bridge for parity tests against
  `sympy.parsing.sympy_parser.parse_expr`

## Public API direction

The eventual API should look SymPy-like at the top, but stay explicit:

- `lex(src : String) -> Array[Token] raise ParseError`
- `parse_ast(src : String) -> Ast raise ParseError`
- `parse_expr(src : String) -> Expr raise ParseError`
- `parse_expr_with(src : String, options : ParseOptions) -> Expr raise ParseError`

`ParseOptions` should control only explicit parser behavior. It should not
smuggle runtime evaluation or Python-like execution into the parser.

## Stage plan

### Stage 0 — parser boundary and data model

Goal: establish a stable typed parser core.

- define `Span`, `ParseError`, `TokenKind`, `Token`
- define a parser AST that is independent from `symcore.Expr`
- define `ParseOptions`
- decide the lowering boundary into `symcore`

This stage should introduce no implicit-multiplication heuristics yet.

### Stage 1 — minimal expression grammar

Goal: parse and lower the core infix language reliably.

Required syntax:

- numbers
- identifiers
- parentheses
- unary `+` / `-`
- binary `+`, `-`, `*`, `/`, `**`
- `^` as configurable power sugar
- function calls `f(x, y)`
- tuples `(x, y)`
- comparison chains such as `x < y <= z`

Lowering rules:

- division lowers to multiplication by reciprocal power
- subtraction lowers to `Add(lhs, -rhs)`
- tuple lowers to a symbolic `Tuple(...)` form for now
- chained comparisons lower to `And(op(...), op(...), ...)`

### Stage 2 — SymPy-style token/AST transforms

Goal: close the first semantic gap with `sympy_parser.py`.

- implicit multiplication
- implicit application
- factorial notation
- auto symbol insertion
- repeated-decimal / rationalization passes
- `=` / `==` normalization

These should be implemented as typed passes over tokens / AST, not by copying
SymPy's Python token-hack pipeline.

### Stage 3 — more exact compatibility

- `evaluate=False` behavior
- better raw / non-canonical construction paths
- more complete symbolic name resolution
- error messages and source spans that survive lowering

### Stage 4 — parity hardening

- `*_port_test.mbt` coverage grouped by feature family
- black-box failure tests
- explicit documented list of still-unsupported constructs

### Stage 5 — LaTeX

This should be a separate frontend built on top of the typed expression core.
Do not block core parser work on LaTeX completeness.

### Stage 6 — foreign syntax adapters

- Mathematica
- Maxima
- C
- Fortran

These should also target the same lowering boundary instead of each inventing
its own partial expression builder.

## Stage 0/1 scope committed now

The implementation work starting now covers:

- a new `symparse` package
- a typed lexer
- a typed AST
- a precedence parser
- lowering to current `symcore.Expr`
- targeted black-box tests
- first oracle parity against SymPy `parse_expr`

This first cut is expected to cover the core arithmetic grammar only. It is
not yet the complete `sympy.parsing` port.
