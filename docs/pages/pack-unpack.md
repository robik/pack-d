---
layout: page
title: Pack and Unpack
permalink: /pack-unpack/
order: 4
---

This page describes `pack` and `unpack` family of functions. These functions work on *format strings* that
describe types of values to read/write. For example this snippet:

```D
auto writer = BinaryWriter(ByteOrder.LittleEndian); 
writer.write!ushort(15); 
writer.byteOrder = ByteOrder.BigEndian;
writer.write!ushort(615); 
writer.padFill(4); 
writer.writeString("test");
```

could be replaced with:

```D
ubyte[] data = pack!`<H>H4xs`(15, 615, "test");
```

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

## Packing

`pack` function family has two variants:

#### In-Memory packing
  
- `ubyte[] pack(string format)(T... params)`

  Packs specified parameters according to `format`. 
  Passing inconvertible parameter and type specifier results in static assert failure. All packed data is returned as `ubyte[]`.

- `ubyte[] pack()(T... params)`

  Works like above but format string is inferred (by `binary.format.formatOf` template).

#### File packing

These function take `File` instance as first argument followed by data to pack.

- `void pack(string format)(File file, T... params)`

  Packs specified parameters according to `format`. 
  Passing inconvertible parameter and type specifier results in static assert failure. All packed data is written to `file`.

- `void pack()(File file, T... params)`

  Works like above but format string is inferred (by `binary.format.formatOf` template).


## Unpacking

Similar to `pack` functions, unpacking functions have two variants, one taking `InputRange` of `ubyte`s and second taking `std.stdio.File`.

  - `void unpackTo(string format)([ref] Range range, ref T... params)` <br/>
    `void unpackTo(string format)(File range, ref T... params)`
   
    Unpacks data from `range` or `file` into `params`. All parameters must be valid references. Range is taken by reference whenever possible (`auto ref`), which means passed array of bytes is modified. To prevent that, pass `yourarray.save` as first parameter.

    > __NOTE__: Specified `Range` must be a valid input range of `ubyte` element type.

    ```D
    ubyte a; int b;
    file.unpackTo(a, b)
    ```

  - `void unpackTo()([ref] Range range, ref T... params)` <br/>
    `void unpackTo()(File range, ref T... params)`

     In this overload format string is inferred from argument types with `binary.format.formatOf` template.
    
  - `auto unpack(string format)([ref] Range range)` <br/>
    `auto unpack(string format)(File file)`
    
    Works exactly like previous ones, except that all data is returned as tuple. 
    In this overload `format` is __required__.

  - `unpacker(string format)(auto ref Range range)` <br/>
    `unpacker(string format)(File range)` <br/>
    
    Returns instance of `Unpacker` struct which is an `InputRange` of `tuple` (based on format string). Useful when there's repeating binary encoded data.
    
    ```D
    ubyte[] bytes = pack!`<hshs`(1, "one", 2, "two");
    auto unpacker = unpacker!`<hs`(bytes);
   
    foreach(num, str; unpacker) {
        writeln(num, " ", str); // Prints 1 one\n 2 two
    }
    ```