module binary.writer;

import core.stdc.string;
import std.range;
import std.traits;
import binary.common;


/**
 * Writes binary data.
 * 
 * To write data to buffer, use `write` or `put` function.
 */
struct BinaryWriter
{
	/**
	 * Buffer with binary encoded data.
	 */
	ubyte[] buffer;


	/**
	 * Byte orded used
	 */
	ByteOrder byteOrder;

	
	/**
	 * Creates instance of BinaryWriter
	 * 
	 * Params:
	 *  byteOrder = Byte order to use
	 */
	this(ByteOrder byteOrder)
	{
		this.byteOrder = byteOrder;
	}

	
	/**
	 * Writes `value` to buffer.
	 * 
	 * For simple types:
	 *  Writes binary encoded value to buffer.
	 * 
	 * For Static arrays:
	 *  All array elements are written as-is, without terminator or length indicator.
	 * 
	 * For Dynamic arrays and strings:
	 *  First, an array length is written as 4-byte unsigned integer (regardless if 64 bit or not)
	 *  followed by array elements.
	 * 
	 * For C strings (const char*):
	 *  String is written with null terminator.
	 * 
	 * To write terminated strings use `writeString` instead or pass string wrapped in NullTerminated struct.
	 * To write arrays without length use `writeArray` instead.
	 * 
	 * Params:
	 *  value = Value to write
	 * 
	 * Examples:
	 * -----
	 * BinaryWriter writer;
	 * writer.write("abc");
	 * writer.write!byte(10);
	 * writeln(writer.buffer); // ['a', 'b', 'c', 10]
	 * -----
	 */
	void write(T)(T value)
	{
		static if (isStaticArray!T) {
			buffer.reserve(T[0].sizeof * value.length);
			foreach(ref el; value) {
				write!(ElementEncodingType!T)(el);
			}
		}
		else static if (isDynamicArray!T) {
			if (value.length > uint.max) {
				throw new Exception("Trying to write array with length bigger than uint.max");
			}

			write(cast(uint)value.length);
			writeArray(value);
		}
		else static if (is(T == immutable(char)*)) {
			size_t len = strlen(value) + 1;
			buffer.reserve(len);
			for (size_t i; i<len; i++) {
				buffer ~= value[i];
			}
		}
		else {
			ubyte[] data = encodeBinary!T(value, byteOrder);
			buffer ~= data;
		}
	}

	/**
	 * Writes `array` to buffer.
	 * 
	 * This function writes `array` elements to buffer without terminator or length indicator.
	 * To write array with length indicator use `write` instead.
	 * 
	 * Params:
	 *  array = Array to write
	 */
	void writeArray(T)(T[] array)
	{
		buffer.reserve(T.sizeof * array.length);

		foreach(el; array) {
			write!T(el);
		}
	}

	/**
	 * Writes `str` to buffer.
	 * 
	 * This function writes `str` to buffer and a null terminator.
	 * 
	 * Params:
	 *  str = String to write.
	 */
	void writeString(T)(T str)
		if (isSomeString!T)
	{
		alias ElType = ElementEncodingType!T;
		writeArray(str);
		write!byte(0);
	}

	
	/**
	 * Writes `values` to buffer.
	 * 
	 * Params:
	 *  values = Values to write.
	 */
	void write(T...)(T values)
		if(T.length > 1)
	{
		foreach(value; values)
			write(value);
	}

	
	/**
	 * Fills `value` specified number of `times`.
	 * 
	 * Params:
	 *  times  = Number of repeats
	 *  value  = Value to fill
	 */
	void fill(size_t times, ubyte value = 0)
	{
		buffer ~= repeat(value, times).array;
	}

	/**
	 * Moves cursor to specified position filling stream with zeros if necessary.
	 * 
	 * If specified position is behind current cursor position, 
	 * nothing happens.
	 * 
	 * Params:
	 *  offset = Offset to align to
	 *  value  = Value to fill with if needed
	 */
	void padFill(size_t offset, ubyte value = 0)
	{
		if (cast(ptrdiff_t)(offset - position) < 0) 
			return;
		
		fill(cast(size_t)(offset - position), value);
	}
	
	/**
	 * Alias to write.
	 * 
	 * Makes BinaryWriter an OutputRange.
	 */
	alias put = write;

	/**
	 * Current position in buffer.
	 */
	size_t position() @property
	{
		return buffer.length;
	}

	/**
	 * Sets new position in buffer.
	 */
	void position(size_t newpos) @property
	{
		buffer.length = newpos;
	}

	
	/**
	 * Clears buffer and resets current position.
	 */
	void clear()
	{
		buffer.length = 0;
		buffer.assumeSafeAppend();
	}

}

unittest
{
	import std.stdio;
	import std.string;

	static assert(isOutputRange!(BinaryWriter, int));
	static assert(isOutputRange!(BinaryWriter, int[]));
	static assert(isOutputRange!(BinaryWriter, string));
	static assert(isOutputRange!(BinaryWriter, char));

	BinaryWriter writer = BinaryWriter(ByteOrder.LittleEndian);
	writer.write(15);
	assert(writer.buffer == [15, 0, 0, 0]);
	assert(writer.position == 4);
	writer.write('0');
	assert(writer.buffer == [15, 0, 0, 0, '0']);
	assert(writer.position == 5);

	writer.byteOrder = ByteOrder.BigEndian;
	writer.write!short(70);
	assert(writer.position == 7);
	assert(writer.buffer == [15, 0, 0, 0, '0', 0, 70]);
	writer.clear();
	assert(writer.position == 0);
	assert(writer.buffer == []);
	writer.write("abc");
	assert(writer.buffer == [0, 0, 0, 3, 'a', 'b', 'c']);

	writer.clear();
	writer.writeString("abc");
	assert(writer.buffer == ['a', 'b', 'c', 0]);

	writer.clear();
	writer.put("name");
	writer.padFill(1);
	assert(writer.buffer == [0, 0, 0, 4, 'n', 'a', 'm', 'e']);
	assert(writer.position == 8);
	writer.padFill(10);
	assert(writer.buffer == [0, 0, 0, 4, 'n', 'a', 'm', 'e', 0, 0]);
	assert(writer.position == 10);

	writer.position = 4;
	assert(writer.buffer == [0, 0, 0, 4]);
	assert(writer.position == 4);
	writer.write!ushort(20);
	writer.write!byte(50);
	assert(writer.position == 7);
	assert(writer.buffer == [0, 0, 0, 4, 0, 20, 50]);

	writer.clear();
	assert(writer.buffer == []);
	assert(writer.position == 0);

	// Arrays
	writer.write!(ushort[])([10, 20, 30]);
	assert(writer.buffer == [0, 0, 0, 3,  0, 10,  0, 20,  0, 30]);
	assert(writer.position == 10);
	writer.clear();

	writer.writeArray([50, 30, 120]);
	assert(writer.buffer == [0, 0, 0, 50,  0, 0, 0, 30,  0, 0, 0, 120]);
	assert(writer.position == 12);
	writer.clear();

	writer.write(15, 'c', "foo", false);
	assert(writer.buffer == [0, 0, 0, 15,  'c', 0, 0, 0, 3, 102, 111, 111, 0]);
	writer.clear();


	writer.write("abc"w);
	assert(writer.buffer == [0, 0, 0, 3,  0, 'a', 0, 'b', 0, 'c']);
	writer.clear();
	writer.write("abc"d);
	assert(writer.buffer == [0, 0, 0, 3,  0, 0, 0, 'a', 0, 0, 0, 'b', 0, 0, 0, 'c']);
	writer.clear();

	writer.write(std.string.toStringz("Hello, World!"));
	assert(writer.buffer == ['H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!', 0]);
	assert(writer.position == 14);
	writer.clear();

	// Issue #4
	writer.byteOrder = ByteOrder.BigEndian;
	writer.write(cast(ulong)12);
	assert(writer.position == 8);
	assert(writer.buffer == [0, 0, 0, 0,  0, 0, 0, 12]);
}
