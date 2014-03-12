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
import std.ascii       : isDigit, isAlpha;
import std.algorithm   : countUntil, map, joiner, until, OpenRight;
import std.conv        : to;
import std.stdio       : File;
import std.traits      : isSomeString, isArray, Unqual, isMutable, isDynamicArray, isStaticArray;
import std.typecons    : tuple, Tuple;
import std.typetuple   : TypeTuple;
import std.range       : repeat, isInputRange, ElementType, isForwardRange, take, popFrontN;
import std.string      : format, startsWith;


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
 *  format     = Format specifier
 *  endianess  = Endianess to use, Endian.Native is default.
 *  values...  = Values to pack
 */
ubyte[] pack(string format, Endian endianess = Endian.Native, V...)(V values)
    if (!isFirstArgFile!V)
{
    ubyte[] buf;
    
    // Can't work with empty format
    static assert(format.length > 0, "Empty format string");
    
    // Endianess modifiers
    static if (formatCharToEndian!(format[0]) != -1)
    {
        static if (format.length < 2)
            return;
        
        buf ~= pack!(format[1..$], formatCharToEndian!(format[0]))(values);
    }

    // Repeats
    else static if (isDigit(format[0]))
    {
        // Creates aliases in local scope like firstNonDigit, count etc.
        mixin repeatCount!format;

        static if(type == 'x')
        {
            buf ~= (cast(ubyte)0).repeat(count).array;
            static if(firstNonDigit + 1 <= format.length)
                buf ~= pack!(format[firstNonDigit + 1..$], endianess)(values);
        }
        else
        {
            static assert(V.length > 0, .format("No parameter specified for type %c", type));
            alias T = V[0];
            
            static if(isArray!T)
            {
                assert(values[0].length + 1 >= count);
                buf.reserve(T[0].sizeof * count);
                for(int i = 0; i < count; ++i)
                    buf ~= encodeBinary!endianess(values[0][i]);

                static if(firstNonDigit + 1 <= format.length)
                    buf ~= pack!(format[firstNonDigit+1..$], endianess)(values[1..$]);
            }
            else
            {
                static assert(values.length + 1 >= count, .format("Expected %d parameters", count));
                buf.reserve(T.sizeof * count);
                buf ~= pack!(type.repeat(count).array, endianess)(values);

                static if(firstNonDigit + 1 < format.length)
                    buf ~= pack!(format[firstNonDigit + 1..$], endianess)(values[count..$]);
            }
        }
    }

    // Pad byte.
    else static if (format[0] == 'x')
    {
        buf ~= 0;
        
        static if(format.length > 1)
            buf ~= pack!(format[1..$], endianess)(values);
        
        return buf;
    }

    // Type characters
    else static if (__traits(compiles, formatTypeOf!(format[0])))
    {
        static assert(V.length > 0, .format("No parameter specified for type %c", type));
        
        // If value is convertible to format character
        static if (__traits(compiles, cast(formatTypeOf!(format[0]))values[0])) {
            buf ~= encodeBinary!endianess( cast(formatTypeOf!(format[0]))values[0] );
            if (format[0] == 's')
                buf ~= 0;
        }
        else
        {
            static assert(0, .format("Incompatible types: %s and %s, format character '%c'",
                                     V[0].stringof, formatTypeOf!(format[0]).stringof, format[0]));
        }
        
        // Missing parameter for format character
        static if (format.length > 1) {
            buf ~= pack!(format[1..$], endianess)(values[1..$]);
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
 *  format     = Format specifier
 *  endianess  = Endianess to use, Endian.Native is default.
 *  file       = File to write data to
 *  values...  = Values to pack
 */
void pack(string format, Endian endianess = Endian.Native, V...)(File file, V values)
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
 *  endianess  = Endianess to use, Endian.Native is default.
 *  values...  = Values to pack
 */
ubyte[] pack(Endian endianess = Endian.Native, V...)(V values)
    if(!isFirstArgFile!V)
{
    return pack!(formatOf!V, endianess)(values);
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
 *  endianess  = Endianess to use, Endian.Native is default.
 *  file       = File to write data to
 *  values...  = Values to pack
 */
void pack(Endian endianess = Endian.Native, V...)(File file, V values)
{
    pack!(formatOf!V, endianess)(file, values);
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
 *  format     = Format specifier
 *  endianess  = Endianess to use, Endian.Native is default.
 *  data       = Data to unpack
 *  values...  = Values to un pack to
 */
void unpackTo(string format, Endian endianess = Endian.Native, Range, V...)(auto ref Range data, ref V values)
    if(isInputRange!Range && is(ElementType!Range == ubyte))
{
    // Can't work with empty format
    static assert(format.length > 0, "Empty format string");

    // Endianess modifiers
    static if (formatCharToEndian!(format[0]) != -1)
    {
        static if (format.length < 2)
            return;

        unpackTo!(format[1..$], formatCharToEndian!(format[0]))(data, values);
    }
    
    // Repeats
    else static if (isDigit(format[0]))
    {
        mixin repeatCount!format;

        static if(type == 'x')
        {
            data.popFrontN(count);
            
            static if(firstNonDigit + 1 < format.length)
                unpackTo!(format[firstNonDigit + 1..$], endianess)(data, values);
        }
        else
        {
            static assert(V.length > 0, .format("No parameter specified for type %c", type));
            alias T = V[0];
            
            static if(isArray!T)
            {
                static if(isDynamicArray!T) {
                    if (values[0].length < count)
                        values[0].length = count;
                }
                else static if(isStaticArray!T) {
                    static if (count > values[0].length) {
                        static assert(0, .format("Static array '%s' is to small to contain %d elements", V[0].stringof, count));
                    }
                }

                for(int i = 0; i < count; ++i)
                    values[0][i] = decodeBinary!(typeof(values[0][0]), endianess)(data);
                
                static if(firstNonDigit + 1 < format.length)
                    unpackTo!(format[firstNonDigit + 1..$], endianess)(data, values[1..$]);
            }
            else
            {
                static assert(values.length + 1 >= count);
                unpackTo!(type.repeat(count).array, endianess)(data, values);
                
                static if(firstNonDigit + 1 < format.length)
                    unpackTo!(format[firstNonDigit + 1..$], endianess)(data, values[count..$]);
            }
        }
    }

    // Skip byte
    else static if(format[0] == 'x')
    {
        data.popFront();
        
        static if(format.length > 1)
            unpackTo!(format[1..$], endianess)(data, values);
    }

    // Type characters
    else static if (__traits(compiles, cast(formatTypeOf!(format[0]))values[0] ))
    {
        static assert(V.length > 0, .format("No parameter specified for type %c", format[0]));
        
        // If value is convertible to format character
        static if ( __traits(compiles, cast(V[0])cast(formatTypeOf!(format[0]))(values[0])) ) {
            values[0] = cast(V[0])decodeBinary!(formatTypeOf!(format[0]), endianess)(data);
        }
        else
        {
            static assert(0, .format("Incompatible types: %s and %s, format character '%c'", T.stringof, formatTypeOf!(format[0]).stringof, format[0]));
        }
        
        // Missing parameter for format character
        static if (format.length > 1) {
            unpackTo!(format[1..$], endianess)(data, values[1..$]);
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
 *  endianess  = Endianess to use, Endian.Native is default.
 *  data       = Data to unpack
 *  values...  = Values to unpack to
 */
void unpackTo(Endian endianess = Endian.Native, Range, V...)(auto ref Range range, ref V values)
    if (isInputRange!Range && is(ElementType!Range == ubyte))
{
    unpackTo!(formatOf!V)(range, values);
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
 *  endianess  = Endianess to use, Endian.Native is default.
 *  file       = File to read from
 *  values...  = Values to un pack to
 */
void unpackTo(string format, Endian endianess = Endian.Native, V...)(File file, ref V values)
{
    if (file.tell > 0)
        file.seek(-1, std.stdio.SEEK_CUR);
    unpackTo!(format, endianess)(file.byChunk(1).joiner, values);
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
 *  endianess  = Endianess to use, Endian.Native is default.
 *  file       = File to read from
 *  values...  = Values to un pack to
 */
void unpackTo(Endian endianess = Endian.Native, V...)(File file, ref V values)
{
    unpackTo!(formatOf!V, endianess)(file, values);
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
auto unpack(string format, Endian endianess = Endian.Native, Range)(auto ref Range data)
    if(isInputRange!Range && is(ElementType!Range == ubyte))
{
    formatTypeTupleOf!format tup;
    unpackTo!(format, endianess)(data, tup);
    return tuple(tup);
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
auto unpack(string format, Endian endianess = Endian.Native)(File file)
{
    Tuple!(formatTypeTupleOf!format) tup;
    unpackTo!(format, endianess)(file, tup.expand);
    return tup;
}



/**
 * Returns an instance of unpacker of T.
 * 
 * Params:
 *  format     = Format specifier
 *  endianess  = Endianess to use
 *  range      = Range to read from
 */
auto unpacker(string format, Endian endianess = Endian.Native, R)(auto ref R range)
    if (isInputRange!R && is(ElementType!R == ubyte))
{
    return Unpacker!(format, endianess, R)(range);
}

/**
 * Returns an instance of unpacker of T.
 * 
 * Params:
 *  format     = Format specifier
 *  endianess  = Byte order to use
 *  file       = File to read from
 */
auto unpacker(string format, Endian endianess = Endian.Native)(File file)
{
    return Unpacker!(format, endianess, File)(file);
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
struct Unpacker(string format, Endian endianess = Endian.Native, R)
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
        source.unpackTo!(format, endianess)(front.expand);
    }
}



/**
 * Encodes specified value.
 * 
 * Binary encodes passed value with specified endianess, which if not set
 * defaults to native.
 * If value is a string, it is encoded without nul terminator character.
 * 
 * Params:
 *  endianess  = Byte order to use
 *  value      = Value to encode
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
 *  endianess = Byte order to use
 *  range     = Range to read from
 */
T decodeBinary(T, Endian endianess = Endian.Native, Range)(auto ref Range range)
    if(isInputRange!Range && !isSomeString!T && is(ElementType!Range == ubyte) && !is(T == void))
{
    ubyte[] data = range.take(T.sizeof).array;
    
    static if (isForwardRange!Range)
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
 *  endianess = Byte order to use
 *  data      = Binary data
 */
T decodeBinary(T, Endian endianess = Endian.Native, Range)(auto ref Range range)
    if(isSomeString!T && isInputRange!Range && is(ElementType!Range == ubyte))
{
    char[] data;
    
    data = cast(char[])range.until(0).array;
    static if(isForwardRange!Range)
        range.popFrontN(data.length);
    
    
    if (!range.empty && range.front == 0)
        range.popFront();
    
    return data.idup;
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
    static assert(isMutable!T, "Type must be mutable");

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
        static if (type == 'x')
        {
            static if (firstNonDigit + 1 < format.length)
                alias formatTypeTupleOf = formatTypeTupleOf!(format[firstNonDigit+1..$]);
            else 
                alias formatTypeTupleOf = TypeTuple!();
        }
        else static if (firstNonDigit + 1 < format.length)
            alias formatTypeTupleOf = TypeTuple!(formatTypeOf!(type)[count], formatTypeTupleOf!(format[firstNonDigit+1..$]));
        else
            alias formatTypeTupleOf = formatTypeOf!(type)[count];
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

private template isFirstArgFile(V...)
{
    static if(V.length > 0 && is(V[0] == File))
        enum bool isFirstArgFile = true;
    else
        enum bool isFirstArgFile = false;
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
    static assert(is(formatTypeTupleOf!`3cx2h`== TypeTuple!(char[3], short[2])));

    {
        ubyte[] bytes = pack!`cc`('a', 'b');
        assert(bytes == ['a', 'b']);
        assert(bytes.unpack!`cc` == tuple('a', 'b'));
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
        ubyte[] bytes = pack!`h3x2c`(56, 'a', 'c');
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
}
