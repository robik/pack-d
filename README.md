## pack-d

### License

Licensed under `MIT License`. See `LICENSE` file.


### About

Pack-D is small binary IO helper written in [D Programming Language](http://dlang.org) based on Python's `struct` module.


### Installation

__Manual__

Download `source/binary/pack.d` and add it to your project.

__Using DUB__

Add this dependency to your `package.json` file:

    "dependencies": {
    	"pack-d": ">=0.1.0"
    }


### Example

```D
import binary.pack;
import std.stdio;

void main()
{
    int a, b, c;
    ubyte[] bytes;
    
    /// Packing 3 integers to binary
    bytes = pack(20, 30, 40);
    
    /// Unpack 3 integers from bytes to a, b and c
    bytes.unpack(a, b, c);
    writefln("%d %d %d", a, b, c); // 20 30 40
    
    /// Pack 2 shorts and a string
    bytes = pack!`hhs`(42, 18, "hello, world!");
    writeln(bytes.unpack!`hhs`); /// Tuple!(short, short, string)(42, 18, "hello, world!")
    
    /// Pack ushort, uint and ulong (big endian)
    bytes = pack!`>HIL`(42, 80, 150);
    /// Unpack ushort, skip 4 bytes and unpack ulong
    writeln(bytes.unpack!`>H4xL`); /// Tuple!(ushort, ulong)(42, 150)
}
```

### Format reference

Most Pack-D functions use a format string to define types of values. 
Format string can be ommited and value types are inferred,
although it is strongly recommended to specify it whenever possible.

__Available modifier characters__
  
  Character   | Effect
  ------------|--------------------
  `=`         | Change to native endian
  `<`         | Change to little endian
  `>`         | Change to big endian
  `@`         | Change to network byte order(big endian)
  

__Available type specifiers__
  
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


> __TIP__: Common rule for (almost) all type specifiers is that all lowercase letters represent signed types and
uppercase letters represent unsigned type.

Additionaly all type specifiers can be preceded by number of occurences.
For example, `pack!"cc"('a', 'b')` is equivalent to `pack!"2c"('a', 'b')`.
Note that behaviour is different with strings: if type specifier is preceded by
a number and parameter is an array, `n` characters are packed.
For example: `pack!"5c"("Hello World")` will pack only first 5 characters.

__Examples__:

 - `2h`  2 signed shorts (native endian)
 - `<2I` 2 insigned integers (little endian)
 - `i4xL` signed integer, 4 null bytes and unsigned long
 - `Sx` or `s` null terminated string

### Quick API reference

 - `pack([string format])(T... params)`

   Packs specified parameters according to `format`. Passing inconvertible parameter and type specifier,
   results in static assert failure. All packed data is returned as `ubyte[]`.
   
 - `pack([string format])(File file, T... params)`
   
   Works exacly like previous one, except that all packed data is written to `file`.

 - `unpack([string format])([ref] Range range, T... params)`
   
   Unpacks data from `range` and writes it to `params`. Range is taken by refernce whenever possible (`auto ref`), which means
   passed array of bytes is modified. To prevent that, pass `yourarray.save` as first parameter.

   > __NOTE__: Specified `Range` must be a valid input range of `ubyte` element type.
  
 - `unpack(string format)([ref] Range range)` <br/>
   `unpack(string format)(File file)`
   
   Works exacly like previous one, except that all data is returned as tuple. 
   In this overload `format` is __required__.

 - `unpacker(string format)(Range range)`
   
   Returns instance of `Unpacker` struct. Usefull when there's repeating binary encoded data.

   ```D
   ubyte[] bytes = pack!`<hshs`(1, "one", 2, "two");
   auto unpacker = unpacker!`<hs`(bytes);
   
   foreach(num, str; unpacker)
   {
       writeln(num, " ", str); // Prints 1 one\n 2 two
   }
   ```

