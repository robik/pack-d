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
   ubyte[] data = pack!`sL`("John", 18); // packs string and ulong
   writeln(data.unpack!`sL`); // tuple("John", 18)
   ```
    
 - [`BinaryReader`/`BinaryWriter`](/pack-d/reader-writer/)
 
   Lower level interface that provides more control.
 
   ```D
   BinaryWriter writer = BinaryWriter(ByteOrder.Native);
   writer.write!string("John"); // explicit
   writer.write(18UL); // ulong literal
   ubyte[] data = writer.buffer;
   auto reader = binaryReader(data);
   ulong name = reader.readString();
   ulong age = reader.read!ulong();
   ```


#### License

Licensed under `MIT License`. See `LICENSE` file.

#### Issues

If you encounter any issues with examples/documentation feel free to report issue [here](https://github.com/robik/pack-d/issues).