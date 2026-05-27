# Symbit Tensor — Current Design

`symtensor` implements the tensor-oriented runtime packages corresponding to
the indexed, array, and tensor-expression portions of SymPy's tensor stack.

## Package Layout

- `symtensor`
  - shared tensor-oriented types and helpers.
- `symtensor/indexed`
  - `Idx`, `IndexedBase`, `Indexed`, index analysis, and printing.
- `symtensor/array`
  - dense/sparse N-dimensional arrays, array construction, indexing, and array
    operations.
- `symtensor/tensor`
  - tensor index types, tensor indices, tensor heads, tensor expressions,
    canonicalization, operators, and LaTeX/string rendering.

## Indexed Layer

- `Idx` stores a name and optional upper bound/dimension.
- `IndexedBase` stores a name and optional shape.
- `Indexed` stores a base and non-empty index list.
- When a shape is present, shape length must match the index count for indexed
  values that rely on shape-aware operations.

## Array Layer

- `NDimArray` supports dense and sparse representations.
- Dense arrays store shape and row-major data.
- Sparse arrays store shape and keyed non-zero data.
- Constructors validate shape/data consistency and bounds where applicable.

## Tensor Layer

- `TensorIndexType` stores the index-family name, optional dimension, and metric
  symmetry metadata.
- `TensorIndex` stores name, index type, and variance.
- `TensorHead` stores name, index types, and symmetry data.
- `TensorExpr` represents tensor atoms, tensor additions/products, scalar
  expressions, and partial derivatives.
- Tensor additions/products are normalized by the package front doors.

## Printing And Canonicalization

The tensor packages provide stable `to_string`, debug, and LaTeX surfaces.
Canonicalization integrates with `symcombinatorics` tensor canonicalization
where the supported expression shape permits it.

## Testing And Parity

Oracle tests under `src/sympy/tensor` compare indexed, array, tensor,
operator, expression, tensor-canonicalization, and LaTeX behavior for supported
cases. Runtime tests cover construction invariants and deterministic rendering.
