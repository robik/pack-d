/**
 * Low level binary IO helper.
 * 
 * Examples:
 * ----
 * ubyte[] bytes = pack!`<hh`(42, 16);
 * auto values = bytes.unpack!`<hh`; // Returns Tuple!(short, short)
 * writeln(values[0]); // 42
 * writeln(values[1]); // 16
 * ----
 * ----
 * short a, b;
 * ubyte[] bytes = pack!`<hh`(42, 16);
 * bytes.unpack!`<hh`(a, b); // takes a and b by reference
 * writeln(a); // 42
 * writeln(b); // 16
 * ----
 * ----
 * struct Test
 * {
 *     uint number;
 *     char c;
 * }
 * 
 * Test test;
 * ubyte[] bytes = pack!`<Ic`(102030, 'a');
 * bytes.unpack!`<Ic`(test.tupleof);
 * writeln(test.number); // 102030
 * writeln(test.c);      // a
 * ----
 */
module binary.pack;

import std.bitmanip;
import std.array;
import std.ascii 	 : isDigit, isAlpha;
import std.algorithm : countUntil, map, joiner;
import std.conv 	 : to;
import std.stdio 	 : File;
import std.traits 	 : isSomeString, isArray, Unqual;
import std.typecons  : tuple, Tuple;
import std.typetuple : TypeTuple;
import std.range	 : repeat, isInputRange, ElementType, take, popFrontN, isForwardRange;
import std.string	 : format, startsWith;


/**
 * Endianess to use while encoding or decoding.
 */
enum Endian
{
	/// Use local endianess
	Native,

	/// Big/Network endian
	Big,

	/// Little endian
	Little
}



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
 * 
 * All type specifiers (from table above) can be preceded by number of occurences.
 * For example, `pack!"cc"('a', 'b')` is equivalent to `pack!"2c"('a', 'b')`.
 * Note that behaviour is different with strings. If type specifier is preceded by
 * a number and parameter is an array, `n` elements are packed.
 * For example: `pack!"5c"("Hello World")` will pack only first 5 characters.
 *
 * Params:
 *  format 		= Format specifier
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  value 		= Value to pack
 *  values... 	= Values to pack
 */
ubyte[] pack(string format, Endian endianess = Endian.Native, T, V...)(T value, V values)
	if (!is(T == File))
{
	ubyte[] buf;
	
	// Can't work with empty format
	static assert(format.length > 0, "Empty format string");

	// Endianess modifiers
	static if (formatCharToEndian!(format[0]) != -1)
	{
		static if (format.length < 2)
			return;
		
		buf ~= pack!(format[1..$], formatCharToEndian!(format[0]))(value, values);
	}

	// Repeats
	else static if (isDigit(format[0]))
	{
		// Index where digits end
		mixin repeatCount!format;
		
		static if(isArray!T)
		{
			assert(value.length + 1 >= count);
			buf.reserve(T[0].sizeof * count);
			for(int i = 0; i < count; ++i)
				buf ~= encodeBinary!endianess(value[i]);
			
			static if(firstNonDigit + 1 <= format.length)
				buf ~= pack!(format[firstNonDigit + 1..$], endianess)(values);
		}
		else static if(type == 'x')
		{
			buf ~= (cast(ubyte)0).repeat(count).array;
			buf ~= pack!(format[firstNonDigit + 1..$], endianess)(value, values);
		}
		else
		{
			static assert(values.length + 1 >= count);
			buf.reserve(T.sizeof * count);
			buf ~= pack!(type.repeat(count).array, endianess)(value, values);

			static if(firstNonDigit + 1 < format.length)
				buf ~= pack!(format[firstNonDigit + 1..$], endianess)(values[times-1..$]);
		}
	}

	// Pad byte.
	else static if (format[0] == 'x')
	{
		buf ~= 0;
		buf ~= pack!(format[1..$], endianess)(value, values);
		return buf;
	}

	// Type characters
	else static if (__traits(compiles, formatTypeOf!(format[0])))
	{
		// If value is convertible to format character
		static if (__traits(compiles, cast(formatTypeOf!(format[0]))value)) {
			buf ~= encodeBinary!endianess( cast(formatTypeOf!(format[0]))value );
			if (format[0] == 's')
				buf ~= 0;
		}
		else
		{
			static assert(0, .format("Incompatible types: %s and %s, format character '%c'",
			                         T.stringof, formatTypeOf!(format[0]).stringof, format[0]));
		}
		
		// Missing parameter for format character
		static if (V.length > 0) {
			static assert(format.length != 1, "Format/parameters length mismatch");
			buf ~= pack!(format[1..$], endianess)(values);
		}
	}

	else {
		static assert (0, .format("Invalid format specifier %c", format[0]));
	}

	return buf;
}


/**
 * Encodes data to binary.
 * 
 * This function packs all specified values into binary data and saves it
 * into file. File must be opened with write access.
 * 
 * Any invalid character specified in format string results in static assert failure.
 * 
 * Params:
 *  format 		= Format specifier
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  file 		= File to write data to
 *  values... 	= Values to pack
 */
void pack(string format, Endian endianess = Endian.Native, T...)(File file, T values)
{
	file.rawWrite(pack!(format, endianess)(values));
}


/**
 * Encodes data to binary.
 * 
 * This function packs all specified values into binary data and returns it.
 * Any invalid character specified in format string results in static assert failure.
 * 
 * Format string is implied from passed parameter types.
 * 
 * Params:
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  value 		= Value to pack
 *  values... 	= Values to pack
 */
ubyte[] pack(Endian endianess = Endian.Native, T, V...)(T value, V values)
	if (!is(T == File))
{
	return pack!(formatOf!(T, V), endianess)(value, values);
}



/**
 * Encodes data to binary.
 * 
 * This function packs all specified values into binary data and saves it
 * into file. File must be opened with write access.
 * 
 * Any invalid character specified in format string results in static assert failure.
 * Format string is implied from passed parameter types.
 * 
 * Params:
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  file 		= File to write data to
 *  values... 	= Values to pack
 */
void pack(Endian endianess = Endian.Native, T...)(File file, T values)
{
	file.rawWrite(pack!(formatOf!T, endianess)(values));
}


/**
 * Decodes binary data.
 * 
 * This function unpacks binary encoded data from `data` and puts them
 * into variables passed as arguments. If `data` is too small, DecodeException
 * is thrown.
 *
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  format 		= Format specifier
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  data 		= Data to unpack
 *  value 		= Value to unpack to
 *  values... 	= Values to un pack to
 */
void unpack(string format, Endian endianess = Endian.Native, Range, T, V...)(auto ref Range data, ref T value, ref V values)
	if(isInputRange!Range && is(ElementType!Range == ubyte))
{
	// Can't work with empty format
	static assert(format.length > 0, "Empty format string");
	
	// Endianess modifiers
	static if (formatCharToEndian!(format[0]) != -1)
	{
		static if (format.length < 2)
			return;

		unpack!(format[1..$], formatCharToEndian!(format[0]))(data, value, values);
	}
	
	// Repeats
	else static if (isDigit(format[0]))
	{
		mixin repeatCount!format;
		
		static if(isArray!T)
		{
			if (value.length < count)
				value.length = count;

			for(int i = 0; i < count; ++i)
				value[i] = decodeBinary!(typeof(value[0]), endianess)(data);
			
			static if(firstNonDigit + 1 < format.length)
				unpack!(format[firstNonDigit + 1..$], endianess)(data, values);
		}
		else static if(type == 'x')
		{
			data.popFrontN(count);
			unpack!(format[firstNonDigit + 1..$], endianess)(data, value, values);
		}
		else
		{
			static assert(values.length + 1 >= count);
			unpack!(type.repeat(count).array, endianess)(data, value, values);
			
			static if(firstNonDigit + 1 < format.length)
				unpack!(format[firstNonDigit + 1..$], endianess)(data, values[count-1..$]);
		}
	}

	// Skip byte
	else static if(format[0] == 'x')
	{
		data.popFront();
		unpack!(format[1..$], endianess)(data, value, values);
	}

	// Type characters
	else static if (__traits(compiles, cast(formatTypeOf!(format[0]))value ))
	{
		// If value is convertible to format character
		static if ( __traits(compiles, cast(T)cast(formatTypeOf!(format[0]))(value)) ) {
			value = cast(T)decodeBinary!(formatTypeOf!(format[0]), endianess)(data);
		}
		else
		{
			static assert(0, .format("Incompatible types: %s and %s, format character '%c'", T.stringof, formatTypeOf!(format[0]).stringof, format[0]));
		}
		
		// Missing parameter for format character
		static if (V.length > 0) {
			static assert(format.length != 1, "Format/parameters length mismatch");
			unpack!(format[1..$], endianess)(data, values);
		}
	}
	
	else {
		static assert (0, .format("Invalid format character %c", format[0]));
	}
}


/**
 * Decodes binary data.
 * 
 * This function unpacks binary encoded data from `data` and puts them
 * into variables passed as arguments. If `data` is too small, DecodeException
 * is thrown.
 * 
 * Format string is implied from passed parameter types.
 *
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  data 		= Data to unpack
 *  value 		= Value to unpack to
 *  values... 	= Values to un pack to
 */
void unpack(Endian endianess = Endian.Native, Range, T, V...)(auto ref Range range, ref T value, ref V values)
	if (isInputRange!Range && is(ElementType!Range == ubyte))
{
	unpack!(formatOf!(T, V))(range, value, values);
}


/**
 * Decodes binary data from file.
 * 
 * This function reads data from file, unpacks binary encoded data and puts them
 * into variables passed as arguments. If read data is too small, DecodeException
 * is thrown.
 * 
 * Passed file must be opened with read access.
 * 
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  format 		= Unpack format
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  file 		= File to read from
 *  value 		= Value to unpack to
 *  values... 	= Values to un pack to
 */
void unpack(string format, Endian endianess = Endian.Native, T, V...)(File file, ref T value, ref V values)
{
	unpack!(format, endianess)(file.byChunk(1).joiner, value, values);
}


/**
 * Decodes binary data from file.
 * 
 * This function reads data from file, unpacks binary encoded data and puts them
 * into variables passed as arguments. If read data is too small, DecodeException
 * is thrown.
 * 
 * Passed file must be opened with read access.
 * Format string is implied from passed parameter types.
 * 
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  file 		= File to read from
 *  value 		= Value to unpack to
 *  values... 	= Values to un pack to
 */
void unpack(Endian endianess = Endian.Native, T, V...)(File file, ref T value, ref V values)
{
	unpack!(formatOf!(T, V))(file, value, values);
}


/**
 * Decodes binary data.
 * 
 * This function works similar to other `unpack` functions, except that read data
 * is returned as tuple.
 * 
 * Params:
 *  format 		= Format specifier
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  data 		= Binary encoded data
 * 
 * Returns:
 *  Tuple with read data.
 */
auto unpack(string format, Endian endianess = Endian.Native, Range)(auto ref Range data)
	if(isInputRange!Range && is(ElementType!Range == ubyte))
{
	formatTypeTupleOf!format tuple;
	unpack!(format, endianess)(data, tuple);
	return .tuple(tuple);
}


/**
 * Decodes binary data from file.
 * 
 * This function works similar to other `unpack` functions, except that read data
 * is returned as tuple.
 * 
 * Params:
 *  format 		= Format specifier
 *  endianess 	= Endianess to use, Endian.Native is default.
 *  file 		= File to read from
 * 
 * Returns:
 *  Tuple with read data.
 */
auto unpack(string format, Endian endianess = Endian.Native)(File file)
{
	formatTypeTupleOf!format tuple;
	unpack!(format, endianess)(file, tuple);
	return .tuple(tuple);
}



/**
 * Encodes specified value.
 * 
 * Binary encodes passed value with specified endianess, which if not set
 * defaults to native.
 * If value is a string, it is encoded without nul terminator character.
 * 
 * Params:
 *  endianess 	= Endianess to use
 *  value 		= Value to encode
 * 
 * Returns:
 *  Encoded value
 */
ubyte[] encodeBinary(Endian endianess = Endian.Native, T)(T value)
{
	ubyte[] res;
	static if(is(T : string)) {
		res = cast(ubyte[])value;
	}
	else {
		static if(endianess == Endian.Big) {
			res ~= nativeToBigEndian(value);
		}
		else static if(endianess == Endian.Little) {
			res ~= nativeToLittleEndian(value);
		}
		else {
			ubyte* tmp = cast(ubyte*)&value;
			foreach(i; 0..T.sizeof)
				res ~= tmp[i];
		}
	}
	
	return res;
}


/**
 * Returns an instance of unpacker of T.
 * 
 * Params:
 *  format 		= Format specifier
 *  endianess	= Endianess to use
 *  range 		= Range to read from
 */
auto unpacker(string format, Endian endianess = Endian.Native, R)(R range)
{
	return Unpacker!(format, endianess, R)(range);
}


/**
 * Unpacker range.
 * 
 * Allows to unpack repeated binary encoded entries with range interface.
 * 
 * Examples:
 * ----
 * ubyte[] bytes = pack!`<hshs`(1, "one", 2, "two");
 * 
 * foreach(num, str; bytes) {
 * 	   writeln(num, " ", str);
 * }
 * ----
 */
struct Unpacker(string format, Endian endianess = Endian.Native, R)
	if (isInputRange!R && is(ElementType!R == ubyte))
{
	/**
	 * Alias for type tuple
	 */
	alias Type = formatTypeTupleOf!format;

	/**
	 * Source range to read from.
	 */
	R source;

	
	/**
	 * Tuple of unpacked elements
	 */
	Tuple!Type front;

	
	/**
	 * Determines if more data can be unpacked.
	 */
	bool empty;

	
	/**
	 * Creates instance of Unpacker.
	 * 
	 * Params:
	 *  range = Range of ubytes to unpack from.
	 */
	this(R range)
	{
		source = range;
		empty = range.empty;
		popFront();
	}

	
	/**
	 * Unpacks next element from source range.
	 */
	void popFront()
	{
		empty = source.empty;

		if (empty) return;
		unpack!(format, endianess)(source, front.expand);
	}
}


/**
 * Decodes binary data.
 * 
 * This function decodes binary encoded value of type T from data.
 * If data is too small to contain type specified, DecodeException
 * is thrown.
 * Data is moved by the size of T.
 * 
 * There is alternative overload for string decoding.
 * 
 * Throws:
 *  DecodeException
 * 
 * Types:
 *  T = Type to decode
 * 
 * Params:
 *  endianess = Endianess to use
 *  data = Binary datta
 */
T decodeBinary(T, Endian endianess = Endian.Native, Range)(auto ref Range range)
	if(isInputRange!Range && !isSomeString!T && is(ElementType!Range == ubyte) && !is(T == void))
{
	auto data = range.take(T.sizeof).array;

	static if(isForwardRange!Range)
		range.popFrontN(T.sizeof);

	if (data.length < T.sizeof)
		throw new DecodeException("Input buffer too small");

	T value;
	
	static if(endianess == Endian.Big) {
		value = bigEndianToNative!T(cast(ubyte[T.sizeof])data[0..T.sizeof]);
	}
	else static if(endianess == Endian.Little) {
		value = littleEndianToNative!T(cast(ubyte[T.sizeof])data[0..T.sizeof]);
	}
	else {
		ubyte* ptr = cast(ubyte*)&value;
		foreach(i; 0 .. T.sizeof)
			*(ptr++) = data[i];
	}
	
	return value;
}


/**
 * Decodes binary strings.
 * 
 * This function decodes binary encoded string from data.
 * Strings are read up to nul terminator. 
 * Data is moved by the length of string (including nul terminator).
 * 
 * Types:
 *  T = Type to decode
 * 
 * Params:
 *  data = Binary datta
 */
T decodeBinary(T, Endian endianess = Endian.Native, Range)(auto ref Range data)
	if(isSomeString!T && isInputRange!Range && is(ElementType!Range == ubyte))
{
	char[] buf;
	size_t i;
	
	while (!data.empty) {
		if (data.front == 0) {
			data.popFront();
			break;
		}
		buf ~= data.front;
		i += 1;
		data.popFront();
	}

	return buf[0..i].idup;
}


/**
 * Thrown when an error occured while decode data.
 */
class DecodeException : Exception
{
	this(string msg, string file = __FILE__, uint line = __LINE__)
	{
		super(msg, file, line);
	}
}


/**
 * Maps format type character to corresponding D type.
 * 
 * To get type tuple from format string use `formatTypeTupleOf` instead.
 * 
 * Any invalid character specified in format string results in static assert failure.
 * To see supported format specifiers and types, see `pack` function.
 */
template formatTypeOf(char c)
{
	static if(c == 'c')
		alias formatTypeOf = char;
	else static if(c == 'b')
		alias formatTypeOf = byte;
	else static if(c == 'B')
		alias formatTypeOf = ubyte;
	else static if(c == 'h')
		alias formatTypeOf = short;
	else static if(c == 'H')
		alias formatTypeOf = ushort;
	else static if(c == 'i')
		alias formatTypeOf = int;
	else static if(c == 'I')
		alias formatTypeOf = uint;
	else static if(c == 'p')
		alias formatTypeOf = ptrdiff_t;
	else static if(c == 'P')
		alias formatTypeOf = size_t;
	else static if(c == 'l')
		alias formatTypeOf = long;
	else static if(c == 'L')
		alias formatTypeOf = ulong;
	else static if(c == 'f')
		alias formatTypeOf = float;
	else static if(c == 'd')
		alias formatTypeOf = double;
	else static if(c == 's')
		alias formatTypeOf = string;
	else static if(c == 'S')
		alias formatTypeOf = string;
	else static if(c == 'x')
		alias formatTypeOf = void;
	else
		static assert(0, "Unsupported pack format character " ~ [c].idup);
}


/**
 * Maps D type to corresponding format type character.
 * 
 * To get format string from TypeTuple, use `formatOf` instead.
 * 
 * Any invalid character specified in format string results in static assert failure.
 * To see supported format specifiers and types, see `pack` function.
 */
template formatCharOf(T)
{
	static if(is(T == byte))
		enum char formatCharOf = 'b';
	else static if(is(T == ubyte))
		enum char formatCharOf = 'B';
	else static if(is(T == char))
		enum char formatCharOf = 'c';
	else static if(is(T == short))
		enum char formatCharOf = 'h';
	else static if(is(T == ushort))
		enum char formatCharOf = 'H';
	else static if(is(T == int))
		enum char formatCharOf = 'i';
	else static if(is(T == uint))
		enum char formatCharOf = 'I';
	else static if(is(T == long))
		enum char formatCharOf = 'l';
	else static if(is(T == ulong))
		enum char formatCharOf = 'L';
	else static if(is(T == float))
		enum char formatCharOf = 'f';
	else static if(is(T == double))
		enum char formatCharOf = 'd';
	else static if(is(T == string))
		enum char formatCharOf = 's';
	else
		static assert(0, "Unsupported type " ~ T.stringof);
}


/**
 * Creates format specifier for TypeTuple.
 */
template formatOf(T, V...)
{
	static if (V.length == 0)
		enum char formatOf = formatCharOf!T;
	else
		enum string formatOf = [formatCharOf!T] ~ formatOf!(V);

}


/**
 * Maps format string to D type tuple.
 * 
 * Any invalid character specified in format string results in static assert failure.
 * To see supported format specifiers and types, see `pack` function.
 */
template formatTypeTupleOf(string format)
{
	static if (format.length < 1)
		static assert(0, "Unexpected end of format");
	else static if (format[0] == 'x')
	{
		static if (format.length == 1)
			alias formatTypeTupleOf = TypeTuple!();
		else
			alias formatTypeTupleOf = formatTypeTupleOf!(format[1..$]);
	}
	else static if (isDigit(format[0]))
	{
		enum firstNonDigit = countUntil!(a => !isDigit(a))(format);
		static assert(firstNonDigit != -1, "Digit must be followed by type specifier");
		enum count = to!int(format[0..firstNonDigit]);
		enum type = format[firstNonDigit];
		static assert(firstNonDigit == countUntil!isAlpha(format), "Digit cannot be followed by endianess modifier");
		static if (firstNonDigit + 1 < format.length)
			alias formatTypeTupleOf = TypeTuple!(formatTypeTupleOf!(type.repeat(count).array), formatTypeTupleOf!(format[firstNonDigit+1..$]));
		else
			alias formatTypeTupleOf = TypeTuple!(formatTypeTupleOf!(type.repeat(count).array));
	}
	else static if ( __traits(compiles, formatTypeOf!(format[0])) ) {
		static if (format.length == 1)
			alias formatTypeTupleOf = formatTypeOf!(format[0]);
		else
			alias formatTypeTupleOf = TypeTuple!(formatTypeOf!(format[0]), formatTypeTupleOf!(format[1..$]));
	}
	else static if (formatCharToEndian!(format[0]) != -1)
		alias formatTypeTupleOf = formatTypeTupleOf!(format[1..$]);
	else
		static assert(0, .format("Invalid format character '%c'", format[0]));
}


private template formatCharToEndian(char c)
{
	static if (c == '<')
		enum formatCharToEndian = Endian.Little;
	else static if (c == '>' || c == '@')
		enum formatCharToEndian = Endian.Big;
	else static if (c == '=')
		enum formatCharToEndian = Endian.Native;
	else
		enum formatCharToEndian = -1;
}

private mixin template repeatCount(string format)
{
	enum firstNonDigit = countUntil!(a => !isDigit(a))(format);
	static assert(firstNonDigit != -1, "Digit must be followed by type specifier");
	enum count = to!int(format[0..firstNonDigit]);
	enum type = format[firstNonDigit];
	static assert(firstNonDigit == countUntil!isAlpha(format), "Digit cannot be followed by endianess modifier");
}


unittest
{
	static assert(__traits(compiles, formatCharOf!int));
	static assert(!__traits(compiles, formatCharOf!void));
	static assert(formatOf!(char, string, byte, ubyte, short, ushort) == "csbBhH");
	static assert(formatOf!(int, uint, long, ulong, float, double) == "iIlLfd");
	static assert(formatCharToEndian!'<' == Endian.Little);
	static assert(formatCharToEndian!'>' == Endian.Big);
	static assert(formatCharToEndian!'@' == Endian.Big);
	static assert(formatCharToEndian!'=' == Endian.Native);
	static assert(formatCharToEndian!'%' == -1);
	static assert(is(formatTypeTupleOf!`hHiI` == TypeTuple!(short, ushort, int, uint)));
	static assert(is(formatTypeTupleOf!`pPlL` == TypeTuple!(ptrdiff_t, size_t, long, ulong)));
	static assert(is(formatTypeTupleOf!`csbB` == TypeTuple!(char, string, byte, ubyte)));
	static assert(is(formatTypeTupleOf!`fxd`  == TypeTuple!(float, double)));
	static assert(is(formatTypeTupleOf!`x`    == TypeTuple!()));
	static assert(is(formatTypeTupleOf!`3cx2h`== TypeTuple!(char, char, char, short, short)));

	
	{
		ubyte[] bytes = pack!`cc`('a', 'b');
		assert(bytes == ['a', 'b']);
		assert(bytes.unpack!`cc` == tuple('a', 'b'));
	}

	{
		ubyte[] bytes = pack!`<h>h`(15, 30);
		assert(bytes == [15, 0, 0, 30]);
		assert(bytes.save.unpack!`<h>h` == tuple(15, 30));
		assert(bytes.unpack!`>I`() == tuple(251658270));
	}

	{
		ubyte[] bytes = pack!`s`("a");
		assert(bytes == ['a', 0]);
		assert(bytes.unpack!`s`() == tuple("a"));
	}

	{
		ubyte[] bytes = pack!`h3x2c`(56, 'a', 'c');
		assert(bytes == [56, 0,  0, 0, 0,  'a', 'c']);
		assert(bytes.unpack!`h3x2c`() == tuple(56, 'a', 'c'));
	}

	{
		ubyte[] bytes = pack!`S`("Hello");
		assert(bytes == ['H', 'e', 'l', 'l', 'o']);
		auto values = bytes.save.unpack!`5c`();
		assert(values == tuple('H', 'e', 'l', 'l', 'o'));
		assert(bytes.unpack!`s`() == tuple("Hello"));
	}

	{
		auto file = File.tmpfile;
		scope(exit) file.close();

		file.pack!`<hxsH`(95, "Hello", 42);
		file.rewind();
		assert(file.unpack!`<hxsH` == tuple(95, "Hello", 42));
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
}
