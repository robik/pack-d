---
layout: page
permalink: /
title: Home
order: 1
---

`pack-d` is a library written in [D Programming Language](http://dlang.org) that simplifies 
binary data I/O.
It provides two interfaces:

 - [`pack`/`unpack`](/pack-d/pack-unpack/)
 
   Provides interface similar to Python's `struct` module.
    
   ```D
   import binary.pack;
   import binary.unpack;
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
    
 - [`BinaryReader`/`BinaryWriter`](/pack-d/reader-writer/)
 
   Lower level interface that provides more control.
 
   ```D
   import binary.writer;
   import binary.reader;
   import std.stdio;
   import std.range;
   
   void main()
   {
       BinaryWriter writer = BinaryWriter(ByteOrder.BigEndian);
       writer.write("abc");
       writer.write(15);
       writer.write!(ubyte[])([12, 24, 48]);
       writeln(writer.buffer); // [0, 0, 0, 3, 'a', 'b', 'c',  0, 0, 0, 15,  0, 0, 0, 3, 12, 24, 48]
   
       char[] text;
       int num;
       ubyte[] arr;
       auto reader = binaryReader(writer.buffer, ByteOrder.BigEndian);
       reader.read(text, num, arr);
       writefln("text: %s, num: %d, arr: %s", text, num, arr);
   }
   ```


#### License

Licensed under `MIT License`. See `LICENSE` file.

#### Issues

If you encounter any issues with examples/documentation feel free to report issue [here](https://github.com/robik/pack-d/issues).