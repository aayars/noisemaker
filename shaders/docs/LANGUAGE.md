# Polymorphic DSL Specification

Polymorphic is the DSL powering the Noisemaker Rendering Pipeline, enabling live-coding visuals by chaining functions like `noise().bloom().out()`. The Polymorphic DSL serves as the high-level builder for the pipeline, allowing users to define complex, multi-pass effects declaratively.

The language evaluates to a Directed Acyclic Graph (DAG) of render passes executed on the GPU. Each valid program must materialize its generator chains into explicit outputs so that the pipeline can schedule and double-buffer them deterministically.

## Grammar

```ebnf
Program        ::= Statement* RenderDirective?
Statement      ::= VarAssign | ChainStmt | IfStmt | LoopStmt | Break | Continue | Return | NamespaceDecl
RenderDirective::= 'render' '(' OutputRef ')'
Block          ::= '{' Statement* '}'
IfStmt         ::= 'if' '(' Expr ')' Block ('elif' '(' Expr ')' Block)* ('else' Block)?
LoopStmt       ::= 'loop' Expr? Block
Break          ::= 'break'
Continue       ::= 'continue'
Return         ::= 'return' Expr?
NamespaceDecl  ::= 'namespace' Ident
VarAssign      ::= 'let' Ident '=' Expr
ChainStmt      ::= Chain ('.out(' OutputRef? ')')?
Chain          ::= Call ( '.' Call )*
Expr           ::= Chain | NumberExpr | String | Boolean | Color | Ident | Member | OutputRef | SourceRef | Func | '(' Expr ')'
Call           ::= Ident '(' ArgList? ')'
ArgList        ::= Arg ( ',' Arg )* ','?
Arg            ::= NumberExpr | String | Boolean | Color | Ident | Member | OutputRef | SourceRef | Func
NumberExpr     ::= Number | 'Math.PI' | '(' NumberExpr ')' | NumberExpr ( '+' | '-' | '*' | '/' ) NumberExpr
Member         ::= Ident ( '.' Ident )+
Func           ::= '(' ')' '=>' Expr
OutputRef      ::= 'o' Digit+
SourceRef      ::= 'src'
Ident          ::= Letter ( Letter | Digit | '_' )*
Number         ::= Digit+ ( '.' Digit+ )?
String         ::= '"' [^"\n]* '"'
Digit          ::= '0'…'9'
Letter         ::= 'A'…'Z' | 'a'…'z'
Boolean        ::= 'true' | 'false'
Color          ::= '#' HexDigit HexDigit HexDigit ( HexDigit HexDigit HexDigit )? ( HexDigit HexDigit )?
HexDigit       ::= Digit | 'A'…'F' | 'a'…'f'
```

**Precedence & Associativity**:
*   `*`, `/` have higher precedence than `+`, `-`.
*   Operators are left-associative.
*   Parentheses `()` override precedence.

**Output Materialization**:
*   Any chain that begins with a generator **must** terminate with `.out(<surface>)`; omitting `.out()` on a generator chain yields diagnostic `S006`.
*   Chains that extend an existing surface (e.g., reading via `src(o0)` and applying additional nodes) may omit `.out()` only when they are nested inside another chain that eventually writes to a surface.

**Generators**:
A chain must start with a Generator function (an effect with no inputs).
*   Standard Generators: `osc`, `noise`, `voronoi`, `solid`, `image`, `video`, `camera`.
*   Custom Generators: Any effect defining `inputs: {}` or marked as generator.

**Colors**:
Hex colors support 3, 6, or 8 digits: `#RGB`, `#RRGGBB`, `#RRGGBBAA`. Alpha defaults to `FF` (1.0) if omitted.

**Arrow Functions**:
Currently restricted to zero-argument expression lambdas: `() => expr`. Used primarily for deferred evaluation in control structures or future callbacks.


## Language Features

### Functions & Arguments

Functions accept arguments either positionally or as named keywords. The two forms are mutually exclusive within a single call.

**Positional arguments:**
```js
osc(10, 0.1, 1)
```

**Keyword arguments:**
```js
osc(freq: 10, sync: 0.1, amp: 1)
```

Numeric arguments support inline arithmetic (`+`, `-`, `*`, `/`) and constants like `Math.PI`. Color arguments accept unquoted `#RGB` or `#RRGGBB` hex codes.

### Variables & Aliases

Programs may declare variables with `let` and reuse them. Variables can alias functions or capture partial applications.

```js
let waves = osc
waves(20).out(o0)
```

**Semantics**:
*   `let x = osc`: `x` becomes an alias for the `osc` function.
*   `let y = osc(10)`: `y` stores a **partial application** (Effect Instance with some parameters bound). It does *not* execute the effect.
*   `y(0.5)`: Creates a new Effect Instance, merging the stored parameters (`freq: 10`) with the new arguments (`sync: 0.5`). The original `y` remains unchanged (immutable).

### Partials

Invoking variables that store function calls merges stored arguments with call-site arguments.

```js
let tuned = osc(5)
tuned(amp:0.5).out(o0)
```

**Merge Rules**:
*   **Positional Arguments**: Appended to the stored arguments.
*   **Named Arguments**: Merged with stored arguments. **Call-site arguments override stored arguments** if keys conflict.
*   **Duplicate Keys**: If a named argument is provided multiple times in a single call, the last value wins.

### Control Flow

The language supports `if`, `elif`, `else` for conditionals, and `loop` for iteration.

**Conditionals:**
```js
if (mouse.down) {
    osc(10).out(o0)
} else {
    solid(#000).out(o0)
}
```

**Loops:**
```js
loop 5 {
    if (seed) break
    osc(5).out(o0)
}
```

**Loop Semantics**:
*   `loop N { ... }`: Executes the block `N` times. `N` must evaluate to a positive integer.
*   `loop { ... }`: Infinite loop. **Safety**: The runtime enforces a maximum iteration count (default: 1000) to prevent hangs.
*   `break` / `continue`: Valid only within a loop block. Using them outside a loop raises `ERR_CONTROL_FLOW_INVALID`.

**Arrow Functions**:
Arrow functions (`() => expr`) are treated as **lazy expressions**. They are not evaluated immediately but are passed as-is to the effect or control structure, which determines when (or if) to evaluate them.

## Namespaces

Polymorphic supports a namespace system to organize effects and ensure compatibility.

### Core Namespaces
*   **`nd`**: Wrappers for standard Noisemaker modules.
*   **`basics`**: Intrinsic Polymorphic effects and core shaders.

### Resolution Rules
1.  **Search Order**: Programs share a global namespace search order that defaults to `basics`, then `nd`.
2.  **Unqualified Identifiers**: Calls like `noise()` walk the active search order until a matching effect is found.
3.  **Namespace Directive**: A `namespace` declaration (e.g., `namespace nd`) sets the primary namespace for the file, placing it at the front of the search list.
4.  **Overrides**: The `from(ns, fn())` helper allows sourcing an operation from a specific namespace temporarily (e.g., `from(basics, noise())`).

**Note**: Bare namespace prefixes (e.g., `nd.noise()`) are **forbidden** in program chains.

## Enums

Many function arguments accept enumerated options defined in a global registry. Enums are defined at the top level in `std_enums.js` as global categories (e.g., `color`, `blend`, `wrap`).

For example, the `noise` effect accepts a `colorMode` parameter with values from the global `color` enum. You can reference enum values in three ways:
- **Shorthand identifier**: `colorMode: rgb` (validator auto-prefixes to `color.rgb`)
- **Full path**: `colorMode: color.rgb`
- **Member expression**: `let mode = color.mono; noise(colorMode: mode).out(o0)`

The runtime resolves these enum references to their integer counterparts before binding to the shader.

## Pipeline Integration

The DSL acts as a high-level builder for the Render Graph defined in `PIPELINE.md`. For a detailed look at how the DSL is compiled, see [COMPILER.md](./COMPILER.md).

### Mapping DSL to Effects

When the evaluator encounters a function call like `.bloom(0.5)`:
1.  **Lookup**: Retrieves the `Bloom` effect definition using the namespace resolution rules.
2.  **Instantiation**: Creates a logical instance of the effect.
3.  **Parameter Binding**: Binds arguments to the effect's `globals`.
4.  **Chain Connection**: Connects the output of the previous node to the input of the new instance.

### Surfaces and Outputs

The DSL allows writing to named outputs (Surfaces) and reading from them.

*   **Global Surfaces**: `o0`, `o1`, `o2`, `o3`, `o4`, `o5`, `o6`, `o7` are persistent textures.
*   **Output**: `.out(o0)` marks the chain as writing to `o0`.
*   **Input**: `src(o0)` creates a read dependency on `o0`.

### Feedback Loops

If a chain reads from a Surface that hasn't been written to yet in the current frame (or reads from itself), it reads the texture content from the **previous frame**. This enables feedback effects.

## Diagnostics

| Code | Stage   | Severity | Message |
| ---- | ------- | -------- | ------- |
| L001 | Lexer   | Error    | Unexpected character |
| L002 | Lexer   | Error    | Unterminated string literal |
| P001 | Parser  | Error    | Unexpected token |
| P002 | Parser  | Error    | Expected closing parenthesis |
| S001 | Semantic| Error    | Unknown identifier |
| S002 | Semantic| Warning  | Argument out of range |
| S003 | Semantic| Error    | Variable used before assignment |
| S005 | Semantic| Error    | Illegal chain structure |
| S006 | Semantic| Error    | Starter chain missing out() call |
| R001 | Runtime | Error    | Runtime error |

### Common Errors
*   **S005 (Illegal chain structure)**: Generator functions (like `osc`, `noise`) must appear at the start of a chain. They cannot consume an existing chain output.
*   **S006 (Starter chain missing out)**: Generator-driven chains must end with `.out()` to produce a reusable surface.
