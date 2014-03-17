module binary.format;

import std.ascii;
import std.algorithm;
import std.conv;
import std.typetuple;
import std.range;
import binary.common;


/**
 * Maps format type character to corresponding D type.
 * 
 * To get type tuple from format string use `formatTypeTupleOf` instead.
 * 
 * Any invalid character specified in format string results in void type.
 * To see supported format specifiers and types, see `pack` function documentation.
 */
template formatTypeOf(char c)
{
	static if(c == 'c')
		alias formatTypeOf = char;
	else static if(c == 'u')
		alias formatTypeOf = wchar;
	else static if(c == 'U')
		alias formatTypeOf = dchar;
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
		alias formatTypeOf = char[];
	else static if(c == 'S')
		alias formatTypeOf = char[];
	else
		alias formatTypeOf = void;
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
		alias formatTypeTupleOf = TypeTuple!();
	
	// Whitespaces
	else static if (isWhite(format[0]))
	{
		alias formatTypeTupleOf = formatTypeTupleOf!(format[1..$]);
	}
	
	// Pad bytes
	else static if (formatIsTypeLess!(format[0]))
		alias formatTypeTupleOf = formatTypeTupleOf!(format[1..$]);
	
	// Repeats
	else static if (isDigit(format[0]))
	{
		// TODO: use formatRepeatCount mixin
		enum firstNonDigit = countUntil!(a => !isDigit(a))(format);
		static assert(firstNonDigit != -1, "Digit must be followed by type specifier");
		enum count = to!int(format[0..firstNonDigit]);
		enum type = format[firstNonDigit];
		static assert(firstNonDigit == countUntil!isAlpha(format), "Digit cannot be followed by endianess modifier");
		
		// Pad bytes are skipped
		static if (type == 'x' || type == 'X')
		{
			static if (firstNonDigit + 1 < format.length)
				alias formatTypeTupleOf = formatTypeTupleOf!(format[firstNonDigit+1..$]);
		}
		else
			alias formatTypeTupleOf = TypeTuple!(formatTypeOf!(type)[count], formatTypeTupleOf!(format[firstNonDigit+1..$]));
	}
	
	// Type chars
	else static if ( is(formatTypeOf!(format[0])) ) {
		alias formatTypeTupleOf = TypeTuple!(formatTypeOf!(format[0]), formatTypeTupleOf!(format[1..$]));
	}
	else
		static assert(0, .format("Invalid format character '%c'", format[0]));
}


/**
 * Maps D type to corresponding format type character.
 * 
 * To get format string from TypeTuple, use `formatOf` instead.
 * 
 * Any unsupported or not mutable type results null character.
 * To see supported format specifiers and types, see `pack` function documentaton.
 * 
 * If array type or input range is passed, format character for value
 * type is returned instead.
 */
template formatCharOf(Type)
{
	static if(isInputRange!Type) {
		alias T = ElementEncodingType!Type;
	} else {
		alias T = Type;
	}
	
	static if(is(T == byte))
		enum char formatCharOf = 'b';
	else static if(is(T == ubyte))
		enum char formatCharOf = 'B';
	else static if(is(T == char))
		enum char formatCharOf = 'c';
	else static if(is(T == wchar))
		enum char formatCharOf = 'u';
	else static if(is(T == dchar))
		enum char formatCharOf = 'U';
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
	else static if(is(Type == string) || is(Type == wstring))
		enum char formatCharOf = 's';
	else
		enum char formatCharOf = 0;
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
 * Determines if format string character has type equivalent.
 * 
 * This template does not work with digits however.
 * 
 * In otherwords this template checks if character is neither endian modifier,
 * digit nor 'x'.
 */
template formatIsTypeLess(char c)
{
	enum formatIsTypeLess = (formatCharToEndian!c != -1) || (c == 'x') || (c == 'X');
}

mixin template formatRepeatCount(string format)
{
	import std.algorithm, std.conv;

	enum resultEndIndex = countUntil!(a => !isDigit(a))(format);
	static assert(resultEndIndex != -1, "Digit must be followed by type specifier");
	enum resultCount = to!int(format[0..resultEndIndex]);
	enum resultChar = format[resultEndIndex];
	enum resultRest = format[resultEndIndex + 1 .. $];
	static assert(formatCharToEndian!resultChar == -1, "Digit cannot be followed by endianess modifier");
	static assert(!isWhite(resultChar), "Digit cannot be followed by space");
}

template formatCharToEndian(char c)
{
	static if (c == '<')
		enum formatCharToEndian = ByteOrder.LittleEndian;
	else static if (c == '>' || c == '@')
		enum formatCharToEndian = ByteOrder.BigEndian;
	else static if (c == '=')
		enum formatCharToEndian = ByteOrder.Native;
	else
		enum formatCharToEndian = -1;
}


unittest
{
	static assert(formatCharOf!int != '\0');
	static assert(formatCharOf!void == '\0');
	static assert(formatOf!(char, string, byte, ubyte, short, ushort) == "csbBhH");
	static assert(formatOf!(int, uint, long, ulong, float, double) == "iIlLfd");
	static assert(formatCharToEndian!'<' == ByteOrder.LittleEndian);
	static assert(formatCharToEndian!'>' == ByteOrder.BigEndian);
	static assert(formatCharToEndian!'@' == ByteOrder.BigEndian);
	static assert(formatCharToEndian!'=' == ByteOrder.Native);
	static assert(formatCharToEndian!'%' == -1);
	static assert(is(formatTypeTupleOf!`hHiI` == TypeTuple!(short, ushort, int, uint)));
	static assert(is(formatTypeTupleOf!`pPlL` == TypeTuple!(ptrdiff_t, size_t, long, ulong)));
	static assert(is(formatTypeTupleOf!`csbB` == TypeTuple!(char, char[], byte, ubyte)));
	static assert(is(formatTypeTupleOf!`fxd`  == TypeTuple!(float, double)));
	static assert(is(formatTypeTupleOf!`x`    == TypeTuple!()));
	static assert(is(formatTypeTupleOf!`3cx2h`== TypeTuple!(char[3], short[2])));
	static assert(is(formatTypeTupleOf!` `    == TypeTuple!()));
	static assert(is(formatTypeTupleOf!`h   2c`    == TypeTuple!(short, char[2])));
	static assert(is(formatTypeTupleOf!`h <I  2c`    == TypeTuple!(short, uint, char[2])));

	static assert(formatIsTypeLess!'<' == true);
	static assert(formatIsTypeLess!'x' == true);
	static assert(formatIsTypeLess!'@' == true);
	static assert(formatIsTypeLess!'2' == false); /// expected behavior
}