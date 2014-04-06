module binary.writer;

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
	 * Number of writen bytes.
	 */
	ulong position;

	
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
	 * Params:
	 *  value = Value to write
	 * 
	 * Examples:
	 * -----
	 * BinaryWriter writer;
	 * writer.write("abc");
	 * writer.write!byte(10);
	 * -----
	 */
	void write(T)(T value)
	{
		static if(isArray!T) {
			buffer.reserve(T[0].sizeof * value.length);
			foreach(ref el; value)
				write(el);
		}
		else {
			ubyte[] data = encodeBinary(value, byteOrder);
			position += data.length;
			buffer ~= data;
		}
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
		position += times;
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
		if (cast(ptrdiff_t)(offset - position) < 0) return;
		
		fill(cast(size_t)(offset - position), value);
	}
	
	/**
	 * Alias to write.
	 * 
	 * Makes BinaryWriter an OutputRange.
	 */
	alias put = write;

	
	/**
	 * Clears buffer and resets current position.
	 */
	void clear()
	{
		buffer = [];
		position = 0;
	}

}

unittest
{
	import std.stdio;

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
	assert(writer.buffer == ['a', 'b', 'c']);

	writer.clear();
	writer.put("name");
	writer.padFill(1);
	assert(writer.buffer == ['n', 'a', 'm', 'e']);
	assert(writer.position == 4);
	writer.padFill(10);
	assert(writer.buffer == ['n', 'a', 'm', 'e', 0, 0, 0, 0, 0, 0]);
	assert(writer.position == 10);
}
