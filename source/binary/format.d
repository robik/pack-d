module binary.format;

import std.ascii;
import std.algorithm;
import std.conv;
import std.typetuple;
import std.range;
import std.traits;
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
	else static if(c == 'o')
		alias formatTypeOf = bool;
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

	else static if (format[0] == '*')
	{
		static assert(format.length > 1, "Star cannot be last character.");
		static assert(format[1].isAlpha, "Star must be followed by type character.");

		alias formatTypeTupleOf = TypeTuple!(formatTypeOf!(format[1])[], formatTypeTupleOf!(format[2..$]));
	}
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
 * Maps D type to corresponding format type string.
 * 
 * To get complete format string from TypeTuple, use `formatOf` instead.
 * 
 * Any unsupported or not mutable type results in static assert failure.
 * To see supported format specifiers and types, see `pack` function documentaton.
 */
template formatStringOf(Type)
{
	static if(isSomeString!Type) {
		enum string formatStringOf = "s";
	}
	else {
		static if (isDynamicArray!Type) {
			enum string prefix = "*";
			alias T = ElementEncodingType!Type;
		} 
		else static if (isStaticArray!Type) {
			enum string prefix = Type.length.stringof;
			alias T = ElementEncodingType!Type;
		}
		else {
			enum string prefix = "";
			alias T = Type;
		}
		
		static if(is(T == byte))
			enum string formatStringOf = prefix ~ "b";
		else static if(is(T == ubyte))
			enum string formatStringOf = prefix ~ "B";
		else static if(is(T == bool))
			enum string formatStringOf = prefix ~ "o";
		else static if(is(T == char))
			enum string formatStringOf = prefix ~ "c";
		else static if(is(T == wchar))
			enum string formatStringOf = prefix ~ "u";
		else static if(is(T == dchar))
			enum string formatStringOf = prefix ~ "U";
		else static if(is(T == short))
			enum string formatStringOf = prefix ~ "h";
		else static if(is(T == ushort))
			enum string formatStringOf = prefix ~ "H";
		else static if(is(T == int))
			enum string formatStringOf = prefix ~ "i";
		else static if(is(T == uint))
			enum string formatStringOf = prefix ~ "I";
		else static if(is(T == long))
			enum string formatStringOf = prefix ~ "l";
		else static if(is(T == ulong))
			enum string formatStringOf = prefix ~ "L";
		else static if(is(T == float))
			enum string formatStringOf = prefix ~ "f";
		else static if(is(T == double))
			enum string formatStringOf = prefix ~ "d";
		/*else static if(isSomeString!Type)
			enum char formatCharOf = 's';*/
		else
			static assert(0, "Unsupported type "~ Type.stringof);
	}
}


/**
 * Creates format specifier for TypeTuple.
 */
template formatOf(T, V...)
{
	static if (V.length == 0)
		enum string formatOf = formatStringOf!T;
	else
		enum string formatOf = formatStringOf!T ~ formatOf!(V);
	
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
	static assert(formatStringOf!int != "\0");
	static assert(!__traits(compiles, formatStringOf!void)); // does not compile
	static assert(formatOf!(char, string, byte, ubyte, bool, short, ushort) == "csbBohH");
	static assert(formatOf!(int, uint, long, ulong, float, double) == "iIlLfd");
	static assert(formatOf!(int[], uint[], long, ulong[], float, double[]) == "*i*Il*Lf*d");

	static assert(formatCharToEndian!'<' == ByteOrder.LittleEndian);
	static assert(formatCharToEndian!'>' == ByteOrder.BigEndian);
	static assert(formatCharToEndian!'@' == ByteOrder.BigEndian);
	static assert(formatCharToEndian!'=' == ByteOrder.Native);
	static assert(formatCharToEndian!'%' == -1);
	static assert(is(formatTypeTupleOf!`hHiI` == TypeTuple!(short, ushort, int, uint)));
	static assert(is(formatTypeTupleOf!`pPlL` == TypeTuple!(ptrdiff_t, size_t, long, ulong)));
	static assert(is(formatTypeTupleOf!`csbB` == TypeTuple!(char, char[], byte, ubyte)));
	static assert(is(formatTypeTupleOf!`obo` ==  TypeTuple!(bool, byte, bool)));
	static assert(is(formatTypeTupleOf!`fxd`  == TypeTuple!(float, double)));
	static assert(is(formatTypeTupleOf!`x`    == TypeTuple!()));
	static assert(is(formatTypeTupleOf!`3cx2h`== TypeTuple!(char[3], short[2])));
	static assert(is(formatTypeTupleOf!` `    == TypeTuple!()));
	static assert(is(formatTypeTupleOf!`h   2c`    == TypeTuple!(short, char[2])));
	static assert(is(formatTypeTupleOf!`h <I  2c`  == TypeTuple!(short, uint, char[2])));
	static assert(is(formatTypeTupleOf!`*hI*c`     == TypeTuple!(short[], uint, char[])));

	static assert(formatIsTypeLess!'<' == true);
	static assert(formatIsTypeLess!'x' == true);
	static assert(formatIsTypeLess!'@' == true);
	static assert(formatIsTypeLess!'2' == false); /// expected behavior
}