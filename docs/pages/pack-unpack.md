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

{% include format.md %}

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