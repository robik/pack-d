module binary.unpack;

import std.ascii;
import std.algorithm;
import std.stdio;
import std.range;
import std.typecons;
import std.traits;
import std.string;
import binary.common;
import binary.format;
import binary.reader;


/**
 * Decodes binary data.
 * 
 * This function unpacks binary encoded data from `range` and puts them
 * into variables passed as arguments. If `range` is too small, DecodeException
 * is thrown.
 *
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  format     = Format specifier
 *  byteOrder  = Byte Order to use, ByteOrder.Native is default.
 *  range      = Data to unpack
 *  values...  = Values to un pack to
 */
void unpackTo(string format, ByteOrder byteOrder = ByteOrder.Native, Range, V...)(auto ref Range range, ref V values)
	if (isInputRange!Range && is(ElementType!Range == ubyte))
{
	auto reader = binaryReader(range, byteOrder);
	unpackTo!(format)(reader, values);
	range = reader.source;
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
 *  format     = Unpack format
 *  byteOrder  = Byte Order to use, ByteOrder.Native is default.
 *  file       = File to read from
 *  values...  = Values to un pack to
 */
void unpackTo(string format, ByteOrder byteOrder = ByteOrder.Native, V...)(File file, ref V values)
{
	if (file.tell > 0) file.seek(-1, SEEK_CUR);

	auto reader = binaryReader(file.byChunk(1).joiner, byteOrder);
	unpackTo!(format)(reader, values);
}


/**
 * Decodes binary data.
 * 
 * This function unpacks binary encoded data from `range` and puts them
 * into variables passed as arguments. If `range` is too small, DecodeException
 * is thrown.
 * 
 * Format string is implied from passed parameter types.
 *
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  byteOrder  = Byte Order to use, ByteOrder.Native is default.
 *  range      = Data to unpack
 *  values...  = Values to unpack to
 */
void unpackTo(ByteOrder byteOrder = ByteOrder.Native, Range, V...)(auto ref Range range, ref V values)
	if (isInputRange!Range && is(ElementType!Range == ubyte))
{
	unpackTo!(formatOf!V, byteOrder)(range, values);
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
 *  byteOrder  = Byte Order to use, ByteOrder.Native is default.
 *  file       = File to read from
 *  values...  = Values to un pack to
 */
void unpackTo(ByteOrder byteOrder = ByteOrder.Native, Range, V...)(File file, ref V values)
{
	unpackTo!(formatOf!V, byteOrder)(file, values);
}



void unpackTo(string format, Range, V...)(ref BinaryReader!Range reader, ref V values)
	if(format.length == 0)
{
}



/**
 * Decodes binary data.
 * 
 * Throws:
 *  DecodeException
 * 
 * Params:
 *  format     = Format specifier
 *  reader     = Reader instance to use
 *  values...  = Values to un pack to
 */
void unpackTo(string format, Range, V...)(ref BinaryReader!Range reader, ref V values)
	if(format.length > 0)
{
	enum char current = format[0];
	
	// Ignore whitespaces
	static if (isWhite(current))
		unpackTo!(format[1..$])(reader, values);
	
	// Endianess modifiers
	else static if (formatCharToEndian!current != -1) {
		reader.byteOrder = formatCharToEndian!current;
		unpackTo!(format[1..$])(reader, values);
	}

	// Dynamic arrays
	else static if (current == '*') {
		static assert(format.length > 1, "Expected star to be followed by type character");
		static assert(V.length > 0, "Missing parameter for type character *"~format[1]);
		static assert(isArray!(V[0]), .format("Expected parameter to be an array, %s given", V[0].stringof));
		alias TargetType = formatTypeOf!(format[1]);
		reader.read(cast(TargetType[])values[0]);
		
		static if (format.length > 2)
			unpackTo!(format[2..$])(reader, values[1..$]);
	}

	// Static arrays
	else static if (isDigit(current))
	{
		// Creates result* variables in local scope
		mixin formatRepeatCount!format;
		static if(resultChar == 'x')
		{
			reader.skipBytes(resultCount);
			unpackTo!(resultRest)(reader, values);
		}
		else static if(resultChar == 'X')
		{
			reader.skipTo(resultCount);
			unpackTo!(resultRest)(reader, values);
		}
		else
		{
			static assert(V.length > 0, .format("No parameter specified for type %c", resultChar));
			alias T = V[0];
			
			static if(isArray!T) {
				reader.read(values[0]);
				unpackTo!(resultRest)(reader, values[1..$]);
			}
			else
			{
				static assert(values.length + 1 >= resultCount, .format("Expected %d parameters", resultCount));
				reader.read(values[0..resultCount]);
				
				unpackTo!(resultRest)(reader, values[resultCount..$]);
			}
		}
	}
	
	// Pad byte.
	else static if (current == 'x')
	{
		reader.skipBytes(1);
		unpackTo!(format[1..$])(reader, values);
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
		static if (__traits(compiles, cast(formatTypeOf!current)values[0])) {
			formatTypeOf!current val;
			static if (current == 's')
				reader.readString(val);
			else static if (current == 'S') {
				if (val.length == 0) {
					throw new DecodeException("Reading string with length 0 ('S' passed to unpack and parameter array length is 0)");
				}
				reader.readArray(val, val.length);
			}
			else
				reader.read(val);

			values[0] = cast(V[0])val;
		}
		else
		{
			static assert(0, .format("Incompatible types: %s and %s, format character '%c'",
			                         V[0].stringof, formatTypeOf!(current).stringof, format[0]));
		}

		unpackTo!(format[1..$])(reader, values[1..$]);
	}
	else {
		static assert (0, .format("Invalid format specifier %c", current));
	}
}


/**
 * Decodes binary data.
 * 
 * This function works similar to other `unpack` functions, except that read data
 * is returned as tuple.
 * 
 * Params:
 *  format     = Format specifier
 *  endianess  = Endianess to use, Endian.Native is default.
 *  data       = Binary encoded data
 * 
 * Returns:
 *  Tuple with read data.
 */
auto unpack(string format, ByteOrder byteOrder = ByteOrder.Native, Range)(auto ref Range data)
	if(isInputRange!Range && is(ElementType!Range == ubyte))
{
	Tuple!(formatTypeTupleOf!format) tup;
	unpackTo!(format, byteOrder)(data, tup.expand);
	return tup;
}


/**
 * Decodes binary data from file.
 * 
 * This function works similar to other `unpack` functions, except that read data
 * is returned as tuple.
 * 
 * Params:
 *  format     = Format specifier
 *  endianess  = Endianess to use, Endian.Native is default.
 *  file       = File to read from
 * 
 * Returns:
 *  Tuple with read data.
 */
auto unpack(string format, ByteOrder byteOrder = ByteOrder.Native)(File file)
{
	Tuple!(formatTypeTupleOf!format) tup;
	unpackTo!(format, byteOrder)(file, tup.expand);
	return tup;
}



/**
 * Returns an instance of unpacker of T.
 * 
 * Params:
 *  format     = Format specifier
 *  byteOrder  = Byte order to use
 *  range      = Range to read from
 */
auto unpacker(string format, ByteOrder byteOrder = ByteOrder.Native, R)(auto ref R range)
	if (isInputRange!R && is(ElementType!R == ubyte))
{
	return Unpacker!(format, byteOrder, R)(range);
}

/**
 * Returns an instance of unpacker of T.
 * 
 * Params:
 *  format     = Format specifier
 *  byteOrder  = Byte order to use
 *  file       = File to read from
 */
auto unpacker(string format, ByteOrder byteOrder = ByteOrder.Native)(File file)
{
	return Unpacker!(format, byteOrder, File)(file);
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
 *        writeln(num, " ", str);
 * }
 * ----
 */
struct Unpacker(string format, ByteOrder byteOrder = ByteOrder.Native, R)
	if ((isInputRange!R && is(ElementType!R == ubyte)) || is(R == File))
{
	/**
	 * Alias for type tuple
	 */
	alias Type = formatTypeTupleOf!format;
	
	/**
	 * Source range/file to read from.
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
		popFront();
	}
	
	
	/**
	 * Unpacks next element from source range.
	 */
	void popFront()
	{
		static if(is(R == File)) {
			empty = source.eof;
		}
		else {
			empty = source.empty;
		}
		
		if (empty) return;
		
		front.expand = front.expand.init;
		source.unpackTo!(format, byteOrder)(front.expand);
	}
}