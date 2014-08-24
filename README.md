## pack-d

[![Build Status](https://travis-ci.org/robik/pack-d.svg?branch=master)](https://travis-ci.org/robik/pack-d)

### License

Licensed under `MIT License`. See `LICENSE` file.


### About

Pack-D is small binary IO helper written in [D Programming Language](http://dlang.org) based on Python's `struct` module. It provides simple interface for reading and writing binary encoded data.


### Documentation

Documentation can be found on [project's wiki](https://github.com/robik/pack-d/wiki).

### Issues

If you encounter any issues with examples/documentation feel free to report issue [here](https://github.com/robik/pack-d/issues).

### Example

```d
import binary.pack;
import std.stdio;

void main()
{
    int a, b, c;
    ubyte[] bytes;
    
    /// Packing 3 integers to binary
    bytes = pack(20, 30, 40);
    
    /// Unpack 3 integers from bytes to a, b and c
    bytes.unpackTo(a, b, c);
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
