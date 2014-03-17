module binary.reader;

import std.algorithm;
import std.array;
import std.range;
import std.traits;
import binary.common;



/**
 * Creates new instance of Binary reader.
 * 
 * Params:
 *  range = Input range to read from
 *  order = Byte order to use
 */
auto binaryReader(Range)(auto ref Range range, ByteOrder order = ByteOrder.Native)
{
	return BinaryReader!(Range)(range, order);
}


/**
 * Reads binary encoded data.
 */
struct BinaryReader(Range = ubyte[])
	if(isInputRange!Range && is(ElementType!Range == ubyte))
{
	/**
	 * InputRange of ubytes to read from.
	 */
	private Range _source;

	
	/**
	 * Current position in stream.
	 */
	private ulong _position;

	
	/**
	 * Used byte order
	 */
	ByteOrder byteOrder;

	

	/**
	 * Creates instance of BinaryReader.
	 * 
	 * Params:
	 *  source = Range of ubytes to read from.
	 */
	this(ref Range source, ByteOrder byteOrder = ByteOrder.Native)
	{
		_source 	= source;
		_position   = 0;
		this.byteOrder  = byteOrder;
	}

	
	/**
	 * Creates instance of BinaryReader.
	 * 
	 * Params:
	 *  source = Range of ubytes to read from.
	 */
	/*this(Range source, ByteOrder byteOrder = ByteOrder.Native)
	 {
	 this(source, byteOrder);
	 }*/

	
	/**
	 * Skips `num` bytes from source.
	 * 
	 * Params:
	 *  num = Number of bytes to skip.
	 */
	void skipBytes(size_t num)
	{
		_source.popFrontN(num);
	}

	
	/**
	 * Moves cursor to specified position.
	 * 
	 * If specified position is behind current cursor position, 
	 * nothing happens.
	 * 
	 * Params:
	 *  offset = Offset to align to
	 */
	void skipTo(size_t offset)
	{
		if (cast(long)(offset - _position) < 0) return;

		skipBytes(offset - _position);
	}

	
	/**
	 * Reads specified value from input stream.
	 * 
	 * If there is insufficient data in input stream, DecodeException is thrown.
	 * 
	 * Throws:
	 *  DecodeException
	 * 
	 * Params:
	 *  value = Value to read to
	 */
	void read(T)(ref T value, string file = __FILE__, uint line = __LINE__)
	{
		if (empty)
			throw new DecodeException("Input stream is empty.", file, line);

		static if (is(T : char[])) {
			static if(isStaticArray!T) {
				char[] data = cast(char[])readBytes(value.length);
				value[0..min(data.length, value.length)] = data[0 .. min(value.length, data.length)];
			} else {
				value = cast(T)readUntil(0);
			}
		}
		else static if (is (T : wchar[]) || is(T : dchar[])) {
			ubyte[] bytes = readUntil(0);
			static assert(0, "Not implemented");
		}
		else static if (isArray!T) {
			foreach(ref el; value)
				read(el, file, line);
		}
		else {
			value = decodeBinary!T(readBytes(T.sizeof), byteOrder, file, line);
		}
	}

	
	/**
	 * Reads T type from stream and returns it.
	 * 
	 * If there is insufficient data in input stream, DecodeException is thrown.
	 * 
	 * Throws:
	 *  DecodeException
	 * 
	 * Returns:
	 *  Read value of type T.
	 */
	T read(T)(string file = __FILE__, uint line = __LINE__)
	{
		T value;
		read!T(value, file, line);
		return value;
	}

	
	/**
	 * Reads specified values from input stream.
	 * 
	 * Throws:
	 *  DecodeException
	 * 
	 * Params:
	 *  value = Tuple of values to read to
	 */
	void read(T...)(ref T values)
		if(T.length > 1)
	{
		foreach(ref value; values)
			read(value);
	}
	
	
	/**
	 * Determines if input stream is empty.
	 */
	bool empty()
	{
		return source.empty;
	}

	
	/**
	 * Clears source range and position.
	 */
	void clear()
	{
		_source = _source.init;
		_position = 0;
	}

	
	/**
	 * Reads array of bytes from input stream.
	 * 
	 * Returned array may be smaller than requested if end
	 * of input occured.
	 * 
	 * Params:
	 *  bytes = Number of bytes to read
	 * 
	 * Returns:
	 *  Array of bytes read
	 */
	ubyte[] readBytes(size_t bytes)
	{
		ubyte[] arr = _source.take(bytes).array;
		
		static if (isForwardRange!Range)
			_source.popFrontN(bytes);

		_position += arr.length;

		return arr;
	}
	

	/**
	 * Reads bytes until `stop` is found.
	 * 
	 * Returned array can be empty if input stream is empty.
	 * 
	 * Params:
	 *  stop  = Value to read until
	 *  next  = If true, input stream is moved to next byte.
	 * 
	 * Returns:
	 *  Array of bytes. 
	 */
	ubyte[] readUntil(ubyte stop, bool next = true)
	{
		ubyte[] arr = _source.until(0).array;
		
		static if(isForwardRange!Range)
			_source.popFrontN(arr.length);
		
		if (!empty && next && _source.front == 0) {
			_source.popFront();
			_position += 1;
		}

		_position += arr.length;

		return arr;
	}

	
	/**
	 * Gets source range used.
	 */
	Range source() @property
	{
		return _source;
	}

	
	/**
	 * Sets new source range to read from.
	 */
	void source(ref Range source) @property
	{
		_position = 0;
		_source = source;
	}

	
	/**
	 * Sets new source range to read from.
	 */
	void source(Range source) @property
	{
		_position = 0;
		_source = source;
	}

	
	/**
	 * Gets current position in stream.
	 */
	ulong position() @property
	{
		return _position;
	}
}



unittest
{
	import std.exception;

	short sh;
	auto reader = binaryReader(cast(ubyte[])[15, 0, 0, 30]);
	reader.byteOrder = ByteOrder.LittleEndian;
	reader.read(sh);
	assert(sh == 15);
	assert(!reader.empty);
	reader.byteOrder = ByteOrder.BigEndian;
	reader.read(sh);
	assert(sh == 30);
	assert(reader.empty);

	assertThrown!DecodeException(reader.read(sh), "Input stream is empty.");
	reader.source = [9];
	assertThrown!DecodeException(reader.read(sh), 
	                             "Unexpected end of input stream. Trying to read 2 bytes (type short), but got 1.");

	char[] str;
	reader.source = ['a', 'b', 'c'];
	reader.read(str);
	assert(str == "abc".dup);
	assert(reader.empty);

	reader.source = ['x', 'y', 'z', 0, 90, 0];
	reader.byteOrder = ByteOrder.LittleEndian;
	reader.read(str);
	reader.read(sh);
	assert(str == "xyz".dup);
	assert(sh  == 90);
	assert(reader.empty);

	reader.clear();
	assert(reader.empty);
	assert(reader.position == 0);

	long l;
	reader.source = [1, 56, 0, 0, 0,  0, 0, 0, 0];
	assert(!reader.empty);
	assert(reader.source.front == 1);
	reader.skipBytes(1);
	assert(reader.source.front == 56);
	assert(!reader.empty);
	reader.read(l);
	assert(l == 56);
	assert(reader.empty);

	reader.source = ['a', 'b', 'c', 0, 0, 0, 0, 0, 15, 0];
	assert(reader.position == 0);
	assert(reader.read!(char[]) == "abc".dup);
	assert(reader.source == [0, 0, 0, 0, 15, 0]);
	reader.skipTo(8);
	assert(reader.source == [15, 0]);
	assert(reader.read!short == 15);
}