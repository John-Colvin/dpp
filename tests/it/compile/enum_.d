module it.compile.enum_;

import it;

@("Named enum with non-assigned members foo and bar")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Foo {
                    foo,
                    bar
                };
            }
        ),

        D(
            q{
                static assert(foo == 0);
                static assert(bar == 1);
                static assert(Foo.foo == 0);
                static assert(Foo.bar == 1);
            }
        ),

    );}

@("Named enum with non-assigned members quux and toto")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Enum {
                    quux,
                    toto
                };
            }
        ),

        D(
            q{
                static assert(quux == 0);
                static assert(toto == 1);
                static assert(Enum.quux == 0);
                static assert(Enum.toto == 1);
            }
        ),

    );}

@("Named enum with assigned members foo, bar, baz")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum FooBarBaz {
                    foo = 2,
                    bar = 5,
                    baz = 7
                };
            }
        ),

        D(
            q{
                static assert(foo == 2);
                static assert(bar == 5);
                static assert(baz == 7);
                static assert(FooBarBaz.foo == 2);
                static assert(FooBarBaz.bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        ),

    );
}

// TODO: convert to unit test
@("typedef nameless enum")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum {
                    foo = 2,
                    bar = 5,
                    baz = 7
                } FooBarBaz;
            }
        ),

        D(
            q{
                static assert(bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        ),

    );}

// TODO: convert to unit test
@("typedef named enum")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum FooBarBaz_ {
                    foo = 2,
                    bar = 5,
                    baz = 7
                } FooBarBaz;
            }
        ),

        D(
            q{
                static assert(FooBarBaz_.foo == 2);
                static assert(bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
       ),

    );
}

@("named enum with immediate variable declaration")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Numbers {
                    one = 1,
                    two = 2,
                } numbers;
            }
        ),

        D(
            q{
                numbers = cast(Numbers)one;
                numbers = cast(Numbers)two;
                numbers = Numbers.one;
            }
        ),

    );
}

@("nameless enum with immediate variable declaration")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum {
                    one = 1,
                    two = 2,
                } numbers;
            }
        ),

        D(
            q{
                numbers = cast(typeof(numbers))one;
                numbers = cast(typeof(numbers))two;
            }
        ),

    );
}

// TODO: convert to unit test
@("nameless enum inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum {
                        one = 1,
                        two = 2,
                    };
                };
            }
        ),

        D(
            q{
                static assert(Struct.two == 2);
            }
        ),

    );
}

@("nameless enum with variable inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum {
                        one = 1,
                        two = 2,
                    } numbers;
                };
            }
        ),

        D(
            q{
                auto s = Struct();
                s.numbers = cast(typeof(s.numbers)) Struct.one;
            }
        ),

    );
}


// TODO: convert to unit test
@("named enum inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum Numbers {
                        one = 1,
                        two = 2,
                    };
                };
            }
        ),

        D(
            q{
                static assert(Struct.Numbers.two == 2);
            }
        ),

    );
}

// TODO: convert to unit test
@("named enum with variable inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum Numbers {
                        one = 1,
                        two = 2,
                    } numbers;
                };
            }
        ),

        D(
            q{
                auto s = Struct();
                s.numbers = Struct.Numbers.one;
            }
        ),
    );
}
