module binary.common;

import std.bitmanip;
import std.string;


/**
 * Represents byte order (endianess)
 */
enum ByteOrder
{
	/// Byte order used on local machine
	Native,

	/// Little endian
	LittleEndian,

	/// Big endian
	BigEndian,
}


/**
 * Binary encodes value.
 * 
 * Params:
 *  value     = Value to encode
 *  byteOrder = Byte order to use
 * 
 * Returns:
 *  Encoded value
 */
ubyte[] encodeBinary(T)(T value, ByteOrder byteOrder = ByteOrder.Native)
{
	switch(byteOrder) with (ByteOrder)
	{
		case BigEndian:
			return nativeToBigEndian(value);

		case LittleEndian:
			return nativeToLittleEndian(value);

		case Native:
			ubyte[T.sizeof] buf;
			ubyte* ptr = cast(ubyte*)&value;
			for(int i=0; i < T.sizeof; i++)
				buf[i] = ptr[i];
			return buf[];

		default:
			assert(0, "Invalid byte order");
	}
}


/**
 * Reads T value from source.
 * 
 * If data is to small to carry T, DecodeException is thrown.
 * 
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  data      = Array to read from
 *  byteOrder = Byte order to use
 */
T decodeBinary(T)(ubyte[] data, ByteOrder byteOrder = ByteOrder.Native, string file = __FILE__, uint line = __LINE__)
{
	if (data.length < T.sizeof) {
		throw new DecodeException(format("Unexpected end of input stream. Trying to read %d bytes (type %s), but got %d.",
		                                 T.sizeof, T.stringof, data.length), file, line);
	}

	switch (byteOrder) with (ByteOrder)
	{
		case BigEndian:
			return bigEndianToNative!T( cast(ubyte[T.sizeof])data[0 .. T.sizeof] );
			
		case LittleEndian:
			return littleEndianToNative!T( cast(ubyte[T.sizeof])data[0 .. T.sizeof] );
			
		case Native:
			T value;
			ubyte* ptr = cast(ubyte*)&value;
			for (size_t i=0; i < T.sizeof; ++i)
				ptr[i] = data[i];
			return value;
			
		default:
			assert(0, "Invalid byte order");
	}
}


/**
 * Thrown when an error occured while decoding data.
 */
class DecodeException : Exception
{
	this(string msg, string file = __FILE__, uint line = __LINE__)
	{
		super(msg, file, line);
	}
}