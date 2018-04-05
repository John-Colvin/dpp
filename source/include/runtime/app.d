/**
   Code to make the executable do what it does at runtime.
 */
module include.runtime.app;

import include.from;

/**
   The "real" main
 */
void run(in from!"include.runtime.options".Options options) @safe {
    import std.stdio: File;
    import std.exception: enforce;
    import std.path: extension;

    enforce(options.inputFileName.extension != ".h",
            "Cannot directly translate C headers. Please run `include` on a D file.");

    enforce(options.outputFileName.extension == ".d" || options.outputFileName.extension == ".di",
            "Output should be a D file (the extension should be .d or .di)");

    preprocess!File(options);
}


/**
   Preprocesses a quasi-D file, expanding #include directives inline while
   translating all definitions, and redefines any macros defined therein.

   The output is a valid D file that can be compiled.

   Params:
        options = The runtime options.
 */
void preprocess(File)(in from!"include.runtime.options".Options options) {

    import include.runtime.context: Context;
    import include.expansion: maybeExpand;
    import std.algorithm: map, startsWith;
    import std.process: execute;
    import std.exception: enforce;
    import std.conv: text;
    import std.string: splitLines;
    import std.file: remove;

    const tmpFileName = options.outputFileName ~ ".tmp";
    scope(exit) remove(tmpFileName);

    {
        auto outputFile = File(tmpFileName, "w");

        outputFile.writeln(preamble);

        /**
           We remember the cursors already seen so as to not try and define
           something twice (legal in C, illegal in D).
        */
        auto context = Context(options.indent);

        () @trusted {
            foreach(line; File(options.inputFileName).byLine.map!(a => cast(string)a)) {
                outputFile.writeln(line.maybeExpand(context));
            }
        }();

        // if there are any fields that were struct pointers
        // but the struct wasn't declared anywhere, do so now
        foreach(name, _; context.fieldStructPointerSpellings) {
            if(name !in context.aggregateDeclarations) {
                context.log("Could not find '", name, "' in aggregate declarations, defining it");
                outputFile.writeln("struct " ~ name ~ ";");
            }
        }

    }


    const ret = execute(["cpp", tmpFileName]);
    enforce(ret.status == 0, text("Could not run cpp on ", tmpFileName, ":\n", ret.output));

    {
        auto outputFile = File(options.outputFileName, "w");

        foreach(line; ret.output.splitLines) {
            if(!line.startsWith("#"))
                outputFile.writeln(line);
        }
    }
}

private string preamble() @safe pure {
    import std.array: replace, join;
    import std.algorithm: filter;
    import std.string: splitLines;

    return q{

        import core.stdc.config;
        import core.stdc.stdarg: va_list;
        struct __locale_data { int dummy; }  // FIXME
        #define __gnuc_va_list va_list
        alias _Bool = bool;

    }.replace("        ", "").splitLines.filter!(a => a != "").join("\n");
}
