# Tensor migration spec (symtensor)

## Scope

Port SymPy `sympy/tensor` into MoonBit `symtensor` in staged layers:

- indexed: Idx / IndexedBase / Indexed + index analysis
- array: NDimArray / Dense / Sparse + tensor ops
- tensor: abstract index notation types (TensorIndexType / TensorIndex / TensorHead / TensorSymmetry) and tensor expressions
- canonicalization: hook tensor_can from symcombinatorics
- operators: partial derivatives + array expressions (minimal parity)

## Data structures

### Indexed layer

- `Idx`: name + optional upper bound (dimension). Keep `lower` implicit as 0.
- `IndexedBase`: name + optional shape (array of Expr). Optional label `assumptions` TBD.
- `Indexed`: base + indices (array of Expr or Idx).

Invariants:
- `Indexed` must have at least one index.
- `IndexedBase` shape length matches indices length when both present.

### Array layer

- `NDimArray`: sum type with `Dense` and `Sparse` variants.
- Dense stores `shape : Array[Int]`, `data : Array[Expr]` (row-major).
- Sparse stores `shape : Array[Int]`, `data : Map[String, Expr]` with index key `"i,j,k"`.

Invariants:
- `data.length == product(shape)` for dense.
- Sparse keys must be within bounds.

### Tensor layer

- `TensorIndexType` : name + dim (Expr?) + metric symmetry info.
- `TensorIndex` : name + type + variance (up/down).
- `TensorHead` : name + index types + symmetry object.
- `TensorExpr` : sum type with `Tensor`, `TensAdd`, `TensMul`, `Scalar`, `PartialDerivative`.

Invariants:
- Tensor indices length matches head rank.
- `TensAdd` and `TensMul` are flattened, zero/one removed.

## Printers

- `symtensor.print` should provide stable `to_string` and `debug_repr` for tensor types.
- String form follows SymPy pretty string when possible (e.g., `A[i, j]`, `TensorHead(i, j)` style).

## Oracle parity

- Use `sympy/tensor` oracle to compare string / srepr.
- Skip parity for constructs with non-determinism (e.g., Dummy indices) and document in tests.

## Tests

- Stage 1: indexed construction + get_indices/contraction structure.
- Stage 2: array ops on small integer arrays + compare with SymPy array printing.
- Stage 3: tensor index bookkeeping + basic add/mul.
- Stage 4: tensor_can canonicalization parity.
- Stage 5: operators / expression layer parity.
