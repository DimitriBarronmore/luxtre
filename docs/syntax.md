
-  EVERYTHING IS LOCAL BY DEFAULT
    - global vars are prefaced by _ENV
    - values that are not yet initialized are considered global
    - vars not explictly initialized as global are initialized as local
    - declarations to global, local, and uninitialized vars can be mixed
    - global and local vars can shadow each other

- let-assignment
    - back-declares the local so that a value can refer to itself

- augmented assignment; all operators, including &= and |=
    - works with multiple assignment

- != works the same as ~=

- tables and strings can have methods used on them directly

- table constructors:
    - square-brackets no longer reqired; added implicitly to non-Name keys
    - ':' can be used instead of '='

- arrow-lambdas
    - `[( args )] -> statement`
    - fat arrows add a self parameter
    - `var ->` and `local var ->` 
    - single expressions are implicitly returned
        - WARNING: avoid ambiguity. expressions with operators should be wrapped in parens or bad things will happen. 

- function decorators
    - work on `[local] function name` and `[local] name ->`
    - can be nested; nested decorators apply bottom-to-top like python


----

