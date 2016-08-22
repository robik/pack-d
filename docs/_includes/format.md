### Available modifier characters

Modifier characters change byte order in place. Once set, it remains until the end of function call or until another one is set.
  
  Character   | Effect
  ------------|--------------------
  `=`         | Use native endian byte order
  `<`         | Use little endian byte order
  `>`         | Use big endian byte order
  `@`         | Use network byte order(big endian)
  
__Example__: `pack!"<i>ii"(500, 500, 900)` encodes first number in little endian and remaining two in big endian.

### Available type specifiers

> __TIP__: Common rule for (almost) all type specifiers is that all lowercase letters represent signed types and
uppercase letters represent unsigned types.

  Character  | Type       | Size  
  -----------|------------|----------
  `c`        | `char`     | 1
  `b`        | `byte`     | 1
  `B`        | `ubyte`    | 1
  `h`        | `short`    | 2 
  `H`        | `ushort`   | 2
  `i`        | `int`      | 4
  `I`        | `uint`     | 4
  `p`        | `ptrdiff_t`| 4/8
  `P`        | `size_t`   | 4/8
  `l`        | `long`     | 8
  `L`        | `ulong`    | 8
  `f`        | `float`    | 4
  `d`        | `double`   | 8
  `s`        | `string`   | string length + nul
  `S`        | `string`   | string length
  `x`        | -          | 1 (null/skip byte)


Types with size `4/8` (`p` and `P`) depend on local machine architecture. On 32 bit architectures they occupy 4 bytes, on 64 bit architectures they occupy 8 bytes.

### Arrays 

Type specifiers can be prefixed with `*` to denote dynamic array. If omitted, array elements will be written with no
length indicator or null terminator, which means that reading arrays encoded this way requires you to manually store array length.

```D
ubyte[] bytes = pack!`*i`([1,2,3]);
bytes.unpack!`*i` == tuple([1,2,3]); // tuple(int[])
```

In `pack` functions type specifier can prefixed with number, meaning exactly number of elements will be written. 
If array is too small `RangeError` is thrown. In `unpack` functions prefixing type specifier with number denotes static array.

```D
ubyte[] bytes = pack!`i`([1,2,3]); // all elements written without length or terminator
bytes.unpack!`3i` == tuple([1,2,3]); // tuple(int[3])
```

Character `x` have slighty different meaning depending if used in `pack` or `unpack` functions. When passed to `pack`, 
null byte is added to output. When passed to `unpack`, one byte is skipped from input data.

__Examples__:

 - `2h`  2 signed shorts (native endian)
 - `<2I` 2 unsigned integers (little endian)
 - `i4xL` signed integer, 4 null bytes and unsigned long
 - `Sx` or `s` null terminated string