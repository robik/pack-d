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
		if (cast(long)(offset - _position) < 0)
			return;

		skipBytes(cast(size_t)(offset - _position));
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
	void read(T)(ref T value)
	{
		if (empty)
			throw new DecodeException("Input stream is empty.");

		static if (isStaticArray!T) {
			foreach(ref el; value)
				read!(ElementEncodingType!T)(el);
		}
		else static if (isDynamicArray!T) {
			uint size;
			read(size);
			value.length = cast(size_t)size;
			readArray!(ElementEncodingType!T)(value, value.length);
		}
		else {
			value = decodeBinary!T(readBytes(T.sizeof), byteOrder);
		}
	}


	/**
	 * Reads array with `length` elements.
	 * 
	 * Throws:
	 *  DecodeException
	 * 
	 * Params:
	 *  arr = Array to read to.
	 *  length = Number of elements to read.
	 */
	void readArray(T)(ref T[] arr, size_t length)
	{
		arr.length = length;
		for(size_t i=0; i<length; i++) {
			read!T(arr[i]);
		}
	}


	/**
	 * Reads string into `str`.
	 * 
	 * Reads until null terminator. If not found, DecodeException is thrown.
	 * 
	 * Throws:
	 *  DecodeException
	 * 
	 * Params:
	 *  str = String to read to
	 */
	void readString(T)(ref T str)
		if (isSomeString!T)
	{
		char[] data = cast(char[])readUntil(0);
		str = cast(T)data;
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
	T read(T)()
	{
		T value;
		read!T(value);
		return value;
	}

	/**
	 * Reads array of type T with `num` elemetns and returns it.
	 * 
	 * Throws:
	 *  DecodeException
	 * 
	 * Returns:
	 *  Array with `num` elements.
	 */
	T[] readArray(T)(size_t num)
	{
		T[] arr = new T[num];
		readArray(arr, num);
		return arr;
	}


	/**
	 * Reads string and returns it.
	 * 
	 * See_Also:
	 *  `readString`
	 * 
	 * Returns:
	 *  Read string.
	 */
	string readString()
	{
		string str;
		readString(str);
		return str;
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
	reader.readArray(str, cast(size_t)3);
	assert(str == "abc".dup);
	assert(reader.empty);

	reader.source = ['x', 'y', 'z', 0, 90, 0];
	reader.byteOrder = ByteOrder.LittleEndian;
	reader.readString(str);
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

	reader.source = ['a', 'b', 'c', 0,  0, 0, 0, 0, 15, 0];
	assert(reader.position == 0);
	assert(reader.readString == "abc".dup);
	assert(reader.source == [0, 0, 0, 0, 15, 0]);
	reader.skipTo(8);
	assert(reader.source == [15, 0]);
	assert(reader.read!short == 15);

	reader.source = [10, 20, 30, 40];
	assert(reader.readArray!byte(4) == [10, 20, 30, 40]);

	reader.byteOrder = ByteOrder.BigEndian;
	reader.source = [0, 0, 0, 3, 0, 99, 0, 55, 0, 44];
	assert(reader.read!(ushort[])() == [99, 55, 44]);

	reader.source = [0, 0, 0, 5, 'H', 'e', 'l', 'l', 'o'];
	reader.read(str);
	assert(str == "Hello".dup);
}