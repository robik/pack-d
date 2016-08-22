---
layout: page
title: Reader and Writer
permalink: /reader-writer/
order: 3
---
 
# BinaryReader

`BinaryReader` (defined in `binary.reader`) provides an interface for reading binary data.

Reading methods (such as `read`) come in two variants: either data is returned or written to
 specified parameter (taken by `ref`).

### Example

```d
auto source = [...]; // binary data
auto reader = binaryReader(source); // Construct BinaryReader with binaryReader helper

byte b;
writeln(reader.read!ulong()); // return ulong
writer.read(b); // reads by reference into ch
writeln(writer.position); // ulong.sizeof + byte.sizeof = 9

// change byte order
writer.byteOrder = ByteOrder.BigEndian;
writer.read!ushort();
writer.clear(); // resets source
```


## Methods

- ####  `T read(T)()` / `void read(T)(ref T target)`

  Reads value of type `T` and returns it or writes it into `target`.

- #### `T[] readArray(T)(size_t num)` / `void readArray(T)(ref T[] arr, size_t length)`

  Reads `num` elements of type `T` from source.

- #### `T readString(T)()` / `void readString(T)(ref T str)`

  Reads null terminated string from source.
  
- ####  `T read(T...)(ref T values)`

  Variable length arguments version of `read`.
  
  ```D
  byte b; int i;
  reader.read(b, i);
  ```

- #### `ubyte[] readBytes(size_t bytes)`

  Reads `bytes` number of raw data from source.  
  
- #### `ubyte[] readUntil(ubyte term, bool skip = true)`

  Reads raw input until `term` is found, skipping `term` if `skip` is `true`.

- #### `void skipBytes(size_t bytes)`

  Skips `bytes` bytes from input.
  
  > **Note**
  >
  > Argument is intentionally made `size_t` rather than `ptrdiff_t` because negative offsets are not supported.

- #### `void skipTo(size_t offset)`

  Moves current position to `offset` (absolute offset).
  If `offset` is smaller than current `position`, current position is not changed.  

- #### `void clear()`

  Clears internal buffer and resets position to 0.

## Fields

- #### `ubyte[] buffer`

  Buffer with built binary data.

## Properties

- #### `size_t position()`

  Gets or sets current position in buffer.
  
- #### `bool empty()`

  Determines whenever source range is empty.
  

# BinaryWriter

`BinaryWriter` (defined in `binary.writer`) provides an interface for writing binary data. It is an valid `OutputRange`. 

### Example

```d
BinaryWriter writer = BinaryWriter(ByteOrder.LittleEndian);
writer.write(15UL);
writer.write!byte('a');
writeln(writer.position); // ulong.sizeof + byte.sizeof = 9
writeln(writer.buffer); // [15, 0, 0, 0,  0, 0, 0, 0,  97]

writer.byteOrder = ByteOrder.BigEndian;
writer.write!ushort(5);
writeln(writer.buffer); // [15, 0, 0, 0,  0, 0, 0, 0,  97, 0, 5]
writer.clear(); // buffer is now empty
```


## Methods

- ####  `void write(T)(T data)` / `void put(T)(T data)`

  Writes `data` of specified type to internal `buffer`. 
  
  > __Since 0.3__
  > 
  > If `data` is an array, data is written as is, without null terminator nor length indicator. To write null
  > terminated arrays (such as strings) use `writeString` instead. To write arrays with their length use 
  > `writeArray` instead.

  > __Before 0.3__
  >
  > If `T` is a string, null terminator is appended, for any other array type `data` is written as is.


- #### `void writeArray(T)(T[] arr)`

  > _Added in 0.3_

  Writes `arr` to `buffer`. First it writes array length down-casted to `uint` which makes it possible to read on 32 bit architectures. Then it writes array elements. If array length is bigger than `uint.max` you'll be informed by subtle `Exception`.

- #### `void writeString(T)(T[] str)`

  > _Added in 0.3_

  Works like `write` for arrays with appending null terminator at the end.

- #### `void fill(size_t times, ubyte value = 0)`

  Writes `value` `times` times.

- #### `void padFill(size_t offset, ubyte value = 0)`

  Writes `value` until position is `offset`. Allows to fill buffer with values up to specified offset.
  If offset is lower than current value, nothing happens.

- #### `void clear()`

  Clears internal buffer and resets position to 0.

## Fields

- #### `ubyte[] buffer`

  Buffer with built binary data.

## Properties

- #### `size_t position()`

  Gets or sets current position in buffer.