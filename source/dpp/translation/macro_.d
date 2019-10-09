module dpp.translation.macro_;

import dpp.from;

string[] translateMacro(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.MacroDefinition)
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith, canFind;
    import std.conv: text;

    // we want non-built-in macro definitions to be defined and then preprocessed
    // again

    if(isBuiltinMacro(cursor)) return [];

    const tokens = cursor.tokens;

    // the only sane way for us to be able to see a macro definition
    // for a macro that has already been defined is if an #undef happened
    // in the meanwhile. Unfortunately, libclang has no way of passing
    // that information to us
    string maybeUndef;
    if(context.macroAlreadyDefined(cursor))
        maybeUndef = "#undef " ~ cursor.spelling ~ "\n";

    context.rememberMacro(cursor);
    const spelling = maybeRename(cursor, context);
    const dbody = translateToD(cursor, context, tokens);

    if(isLiteralMacro(tokens))
        return [
            `#ifdef ` ~ spelling,
            `#    undef ` ~ spelling,
            `#endif`,
            `#define _DPP_` ~ spelling ~ ` ` ~ dbody,
            `static if(!is(typeof(` ~ spelling ~ `))) {`,
            `    enum ` ~ spelling ~ ` = ` ~ dbody ~ `;`,
            `}`,
        ];

    const maybeSpace = cursor.isMacroFunction ? "" : " ";
    return [maybeUndef ~ "#define " ~ spelling ~ maybeSpace ~ dbody ~ "\n"];
}


bool isBuiltinMacro(in from!"clang".Cursor cursor)
    @safe @nogc
{
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith;

    if(cursor.kind != Cursor.Kind.MacroDefinition) return false;

    return
        cursor.sourceRange.path == ""
        || !cursor.sourceRange.path.exists
        || cursor.isPredefined
        || cursor.spelling.startsWith("__STDC_")
        ;
}


private bool isLiteralMacro(in from!"clang".Token[] tokens) @safe @nogc pure nothrow {
    import clang: Token;

    return
        tokens.length == 2
        && tokens[0].kind == Token.Kind.Identifier
        && tokens[1].kind == Token.Kind.Literal
        ;
}

private bool isStringRepr(T)(in string str) @safe pure {
    import std.conv: to;
    import std.exception: collectException;
    import std.string: strip;

    T dummy;
    return str.strip.to!T.collectException(dummy) is null;
}


private string translateToD(
    in from!"clang".Cursor cursor,
    in from!"dpp.runtime.context".Context context,
    in from!"clang".Token[] tokens,
    )
    @safe
{
    import dpp.translation.type: translateElaborated;
    if(isLiteralMacro(tokens)) return fixLiteral(tokens[1]);
    if(tokens.length == 1) return ""; // e.g. `#define FOO`

    return tokens
        .fixSizeof(cursor)
        .fixCasts(cursor, context)
        .fixArrow
        .fixNull
        .toString
        .translateElaborated
        ;
}


private string toString(in from!"clang".Token[] tokens) @safe pure {
    import clang: Token;
    import std.algorithm: map;
    import std.array: join;

    // skip the identifier because of DPP_ENUM_
    return tokens[1..$]
        .map!(t => t.spelling)
        .join(" ");
}

private string fixLiteral(in from!"clang".Token token)
    @safe pure
    in(token.kind == from!"clang".Token.Kind.Literal)
    do
{
    return token.spelling
        .fixOctal
        .fixLongLong
        ;
}


private const(from!"clang".Token)[] fixArrow(
    return scope const(from!"clang".Token[]) tokens
    )
    @safe pure
{
    import clang: Token;
    import std.algorithm: map;
    import std.array: array;

    static const(Token) replace(in Token token) {
        return token == Token(Token.Kind.Punctuation, "->")
            ? Token(Token.Kind.Punctuation, ".")
            : token;
    }

    return tokens
        .map!replace
        .array;
}

private const(from!"clang".Token)[] fixNull(
    return scope const(from!"clang".Token[]) tokens
    )
    @safe pure
{
    import clang: Token;
    import std.algorithm: map;
    import std.array: array;

    static const(Token) replace(in Token token) {
        return token == Token(Token.Kind.Identifier, "NULL")
            ? Token(Token.Kind.Identifier, "null")
            : token;
    }

    return tokens
        .map!replace
        .array;
}



private string fixLongLong(in string str) @safe pure nothrow {
    import std.algorithm: endsWith;

    return str.endsWith("LL")
        ? str[0 .. $-1]
        : str;
}


private string fixOctal(in string spelling) @safe pure {
    import clang: Token;
    import std.algorithm: countUntil;
    import std.uni: isNumber;

    const isOctal =
        spelling.length > 1
        && spelling[0] == '0'
        && spelling[1].isNumber
        //&& token.spelling.isStringRepr!long
        ;

    if(!isOctal) return spelling;

    const firstNonZero = spelling.countUntil!(a => a != '0');
    if(firstNonZero == -1) return "0";

    return `std.conv.octal!` ~ spelling[firstNonZero .. $];
}


private const(from!"clang".Token)[] fixSizeof(
    return scope const(from!"clang".Token)[] tokens,
    in from !"clang".Cursor cursor,
    )
    @safe pure
{
    import clang: Token;
    import std.conv: text;
    import std.algorithm: countUntil;

    // find the closing paren for the function-like macro's argument list
    size_t lastIndex = 0;
    if(cursor.isMacroFunction) {
        lastIndex = tokens
            .countUntil!(t => t == Token(Token.Kind.Punctuation, ")"))
            +1; // skip the right paren

        if(lastIndex == 0)
            throw new Exception(text("Can't fix sizeof in function-like macro with tokens: ", tokens));
    }

    auto ret = tokens[0 .. lastIndex];

    for(size_t i = lastIndex; i < tokens.length - 1; ++i) {
        if(tokens[i] == Token(Token.Kind.Keyword, "sizeof")
           && tokens[i + 1] == Token(Token.Kind.Punctuation, "("))
        {
            // find closing paren
            long open = 1;
            ptrdiff_t scanIndex = i + 2;  // skip i + 1 since that's the open paren

            while(open != 0) {
                if(tokens[scanIndex] == Token(Token.Kind.Punctuation, "("))
                    ++open;
                if(tokens[scanIndex] == Token(Token.Kind.Punctuation, ")"))
                    --open;

                ++scanIndex;
            }

            ret ~= tokens[lastIndex .. i] ~ tokens[i + 1 .. scanIndex] ~ Token(Token.Kind.Keyword, ".sizeof");
            lastIndex = scanIndex;
            // advance i past the sizeof. -1 because of ++i in the for loop
            i = lastIndex - 1;
        }
    }

    ret ~= tokens[lastIndex .. $];

    return ret;
}


private const(from!"clang".Token)[] fixCasts(
    return scope const(from!"clang".Token)[] tokens,
    in from !"clang".Cursor cursor,
    in from!"dpp.runtime.context".Context context,
    )
    @safe pure
{
    import clang: Token;
    import std.conv: text;
    import std.algorithm: countUntil;

    // if the token array is a built-in or user-defined type
    bool isType(in Token[] tokens) {

        if( // fundamental type
            tokens.length == 1
            && tokens[0].kind == Token.Kind.Keyword
            && tokens[0].spelling != "sizeof"
            && tokens[0].spelling != "alignof"
            )
            return true;

        if( // user defined type
            tokens.length == 1
            && tokens[0].kind == Token.Kind.Identifier
            && context.isUserDefinedType(tokens[0].spelling)
            )
            return true;

        if(  // pointer to a type
            tokens.length >= 2
            && tokens[$-1] == Token(Token.Kind.Punctuation, "*")
            && isType(tokens[0 .. $-1])
            )
            return true;

        if( // const type
            tokens.length >= 2
            && tokens[0] == Token(Token.Kind.Keyword, "const")
            && isType(tokens[1..$])
            )
            return true;

        return false;
    }

    size_t lastIndex = 0;
    // find the closing paren for the function-like macro's argument list
    if(cursor.isMacroFunction) {
        lastIndex = tokens
            .countUntil!(t => t == Token(Token.Kind.Punctuation, ")"))
            +1; // skip the right paren
        if(lastIndex == 0)
            throw new Exception(text("Can't fix casts in function-like macro with tokens: ", tokens));
    }

    auto ret = tokens[0 .. lastIndex];

    for(size_t i = lastIndex; i < tokens.length - 1; ++i) {
        if(tokens[i] == Token(Token.Kind.Punctuation, "(")) {
            // find closing paren
            long open = 1;
            ptrdiff_t scanIndex = i + 1;  // skip i + 1 since that's the open paren

            while(open != 0) {
                if(tokens[scanIndex] == Token(Token.Kind.Punctuation, "("))
                    ++open;
                if(tokens[scanIndex] == Token(Token.Kind.Punctuation, ")"))
                    --open;

                ++scanIndex;
            }
            // at this point scanIndex is the 1 + index of closing paren

            // we want to ignore e.g. `(int)(foo).sizeof` even if `foo` is a type
            const followedByDot =
                tokens.length > scanIndex
                && tokens[scanIndex].spelling[0] == '.'
                ;

            if(isType(tokens[i + 1 .. scanIndex - 1]) && !followedByDot) {
                ret ~= tokens[lastIndex .. i] ~
                    Token(Token.Kind.Punctuation, "cast(") ~
                    tokens[i + 1 .. scanIndex]; // includes closing paren
                lastIndex = scanIndex;
                // advance i past the sizeof. -1 because of ++i in the for loop
                i = lastIndex - 1;
            }
        }
    }

    ret ~= tokens[lastIndex .. $];

    return ret;
}
