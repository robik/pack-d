module binary.pack;

import std.ascii;
import std.array;
import std.stdio;
import std.range;
import std.typetuple;
import std.typecons;
import std.traits;
import binary.common;
import binary.writer;
import binary.format;



/**
 * Encodes data to binary.
 * 
 * This function packs all specified values into binary data and returns it.
 * Any invalid character specified in format string results in static assert failure.
 * 
 * Available modifier characters
 * 
 * Character   | Effect
 * ------------|--------------------
 * `=`         | Change to native endian
 * `<`         | Change to little endian
 * `>`         | Change to big endian
 * '@'         | Change to network byte order(big endian)
 * 
 *  
 * Available type specifiers
 * 
 * Character  | Type       | Size  
 * -----------|------------|----------
 * `c`        | `char`     | 1
 * `b`        | `byte`     | 1
 * `B`        | `ubyte`    | 1
 * `h`        | `short`    | 2 
 * `H`        | `ushort`   | 2
 * `i`        | `int`      | 4
 * `I`        | `uint`     | 4
 * `p`        | `ptrdiff_t`| 4/8
 * `P`        | `size_t`   | 4/8
 * `l`        | `long`     | 8
 * `L`        | `ulong`    | 8
 * `f`        | `float`    | 4
 * `d`        | `double`   | 8
 * `s`        | `string`   | string length + nul
 * `S`        | `string`   | string length
 * `x`        | -          | 1 (zero byte)
 * `X`        | -          | Skip/Pad to position
 * 
 * All type specifiers (from table above) can be preceded by number of occurences.
 * For example, `pack!"cc"('a', 'b')` is equivalent to `pack!"2c"('a', 'b')`.
 * Note that behaviour is different with strings. If type specifier is preceded by
 * a number and parameter is an array, `n` elements are packed.
 * For example: `pack!"5c"("Hello World")` will pack only first 5 characters.
 *
 * Params:
 *  format     = Format specifier
 *  endianess  = Endianess to use, Endian.Native is default
 *  values...  = Values to encode
 */
ubyte[] pack(string format, ByteOrder byteOrder = ByteOrder.Native, V...)(V values)
	if (!isFirstArgFile!V)
{
	BinaryWriter writer = BinaryWriter(byteOrder);
	pack!(format)(writer, values);
	return writer.buffer;
}

/**
 * Binary encodes data to file
 * 
 * Specified file must be opened with write access.
 * 
 * Params:
 *  file   = File to write to
 *  values = Values to encode
 */
void pack(string format, ByteOrder byteOrder = ByteOrder.Native, V...)(File file, V values)
{
	BinaryWriter writer = BinaryWriter(byteOrder);
	pack!(format)(writer, values);
	file.rawWrite(writer.buffer);
}


/**
 * Binary encodes data.
 * 
 * In this overload format string is infered from V type tuple.
 * 
 * Params:
 *  value = Values to encode
 */
ubyte[] pack(ByteOrder byteOrder = ByteOrder.Native, V...)(V values)
	if(!isFirstArgFile!V)
{
	return pack!(formatOf!V, byteOrder)(values);
}


/**
 * Binary encodes data.
 * 
 * In this overload format string is infered from V type tuple.
 * 
 * Params:
 *  file  = File to write to
 *  value = Values to encode
 */
ubyte[] pack(ByteOrder byteOrder = ByteOrder.Native, V...)(File file, V values)
{
	return pack!(formatOf!V, byteOrder)(file, values);
}


void pack(string format, V...)(ref BinaryWriter writer, V values)
	if(format.length == 0)
{
}

/**
 * Encodes data to binary.
 * 
 * Writes all encoded `values` to `writer`.
 * 
 * Params:
 *  writer = Writer to write to
 *  values = Values to encode
 */
void pack(string format, V...)(ref BinaryWriter writer, V values)
	if (format.length > 0)
{
	enum char current = format[0];

	// Ignore whitespaces
	static if (isWhite(current))
		pack!(format[1..$])(writer, values);

	// Endianess modifiers
	else static if (formatCharToEndian!current != -1) {
		writer.byteOrder = formatCharToEndian!current;
		pack!(format[1..$])(writer, values);
	}

	// Repeats
	else static if (isDigit(current))
	{
		// Creates result* variables in local scope
		mixin formatRepeatCount!format;
		static if(resultChar == 'x')
		{
			writer.write( (cast(ubyte)0).repeat(resultCount).array );
			pack!(resultRest)(writer, values);
		}
		else static if(resultChar == 'X')
		{
			writer.padFill(resultCount);
			pack!(resultRest)(writer, values);
		}
		else
		{
			static assert(V.length > 0, .format("No parameter specified for type %c", resultChar));
			alias T = V[0];
			
			static if(isArray!T) {
				writer.write(cast(formatTypeOf!(resultChar)[])values[0][0..resultCount]);
				pack!(resultRest)(writer, values[1..$]);
			}
			else
			{
				static assert(values.length + 1 >= resultCount, .format("Expected %d parameters", resultCount));
				writer.write(values[0..resultCount]);
				
				pack!(resultRest)(writer, values[resultCount..$]);
			}
		}
	}

	// Pad byte.
	else static if (current == 'x')
	{
		writer.write!byte(0);
		pack!(format[1..$])(writer, values);
	}
	
	else static if (current == 'X')
	{
		static assert(0, "Format character 'X' must be preceded by number.");
	}

	// Type characters
	else static if ( !is(formatTypeOf!(current) == void) )
	{
		static assert(V.length > 0, .format("No parameter specified for character '%c'", current));
		
		// If value is convertible to format character
		static if (__traits(compiles, cast(formatTypeOf!(current))values[0])) {
			writer.write(cast(formatTypeOf!current)values[0]);
			static if (current == 's')
				writer.write!byte(0);
		}
		else
		{
			static assert(0, .format("Incompatible types: %s and %s, format character '%c'",
			                         V[0].stringof, formatTypeOf!(current).stringof, format[0]));
		}
		
		pack!(format[1..$])(writer, values[1..$]);
	}
	else {
		static assert (0, .format("Invalid format specifier %c", current));
	}
}



private template isFirstArgFile(V...)
{
	static if(V.length > 0 && is(V[0] == File))
		enum bool isFirstArgFile = true;
	else
		enum bool isFirstArgFile = false;
}


unittest
{
	/// TODO: Check every static if

	import binary.unpack;

	assert(pack!(ByteOrder.LittleEndian)(10, '0') == [10, 0, 0, 0, '0']);
	
	{
		ubyte[] bytes = pack!`c c`('a', 'b');
		assert(bytes == ['a', 'b']);
		assert(bytes.unpack!`cc` == tuple('a', 'b'));
		assert(bytes == []);
	}
	
	
	{
		ubyte[] bytes = pack!`<h8Xi`(18, -3);
		assert(bytes == [18, 0, 0, 0,  0, 0, 0, 0,  253, 255, 255, 255]);
		assert(bytes.unpack!`<h8Xi` == tuple(18, -3));
		assert(bytes == []);
	}

	{
		ubyte[] bytes = pack!`<oboh`(true, true, false, false);
		assert(bytes == [1, 1, 0,  0, 0]);
		assert(bytes.unpack!`<oboh` == tuple(true, true, false, 0));
		assert(bytes == []);
	}
	
	{
		long l;
		int i;
		char a, z;
		
		ubyte[] bytes = pack(1, 22L, 'a', 'z');
		bytes.unpackTo(i, l, a, z);
		assert(i == 1);
		assert(l == 22);
		assert(a == 'a');
		assert(z == 'z');
	}
	
	{
		ubyte[] bytes = pack!`4xx`;
		assert(bytes == [0, 0, 0, 0, 0]);
		assert(bytes.save.unpack!`5c` == tuple(['\0', '\0', '\0', '\0', '\0']));
		ubyte a,b,c,d,e;
		bytes.unpackTo!`5c`(a,b,c,d,e);
		assert(a == 0);
		assert(b == 0);
		assert(c == 0);
		assert(d == 0);
		assert(e == 0);
		assert(bytes == []);
	}

	{
		ubyte[] bytes = pack!`<h>h`(15, 30);
		assert(bytes == [15, 0, 0, 30]);
		assert(bytes.save.unpack!`<h>h` == tuple(15, 30));
		assert(bytes.unpack!`>I`() == tuple(251658270));
		assert(bytes == []);
	}

	{
		ubyte[] bytes = pack!`s`("a");
		assert(bytes == ['a', 0]);
		assert(bytes.unpack!`s`() == tuple("a"));
		assert(bytes == []);
	}

	{
		ubyte[] bytes = pack!`<h3x2c`(56, 'a', 'c');
		assert(bytes == [56, 0,  0, 0, 0,  'a', 'c']);
		assert(bytes.unpack!`h3x2c`() == tuple(56, ['a', 'c']));
		assert(bytes == []);
	}

	{
		ubyte[] bytes = pack!`S`("Hello");
		assert(bytes == ['H', 'e', 'l', 'l', 'o']);
		auto values = bytes.save.unpack!`5c`();
		assert(values == tuple(['H', 'e', 'l', 'l', 'o']));
		assert(bytes.unpack!`s`() == tuple("Hello"));
	}

	
	
	{
		auto file = File.tmpfile;
		scope(exit) file.close();
		
		file.pack!`<hxsH`(95, "Hello", 42);
		file.rewind();
		assert(file.unpack!`<hxsH` == tuple(95, "Hello", 42));
		assert(file.eof);
	}
	
	{
		auto file = File.tmpfile;
		scope(exit) file.close();
		
		file.pack!`<hxhx`(95, 51);
		file.rewind();
		assert(file.unpack!`<hx` == tuple(95));
		assert(file.unpack!`<hx` == tuple(51));
		assert(file.eof);
	}
	
	{
		ubyte[] bytes = pack!`<bhsbhs`(65, 105, "Hello", 'z', 510, " World");
		
		auto unpacker = unpacker!`<bhs`(bytes);
		static assert(isInputRange!(typeof(unpacker)));
		assert(!unpacker.empty);
		assert(unpacker.front == tuple(65, 105, "Hello"));
		unpacker.popFront();
		assert(!unpacker.empty);
		assert(unpacker.front == tuple('z', 510, " World"));
		unpacker.popFront();
		assert(unpacker.empty);
	}
	
	{
		File file = File.tmpfile;
		scope(exit) file.close;
		file.pack!`<bhsbhs`(65, 105, "Hello", 'z', 510, " World");
		
		file.rewind();
		auto unpacker = unpacker!`<bhs`(file);
		static assert(isInputRange!(typeof(unpacker)));
		assert(!unpacker.empty);
		assert(unpacker.front == tuple(65, 105, "Hello"));
		unpacker.popFront();
		assert(!unpacker.empty);
		assert(unpacker.front == tuple('z', 510, " World"));
		unpacker.popFront();
		assert(unpacker.empty);
		assert(file.eof);
	}

	{
		// Issue #4
		ubyte[] bytes = pack!`>L`(12);
		assert(bytes == [0, 0, 0, 0,  0, 0, 0, 12]);
		assert(bytes.unpack!`>L`[0] == 12UL);
	}
}
