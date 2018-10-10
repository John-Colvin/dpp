module contract.templates;


import contract;


@Tags("contract")
@("Partial and full template specialisation")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                struct Foo; struct Bar; struct Baz; struct Quux;

                template<typename, typename, bool, typename, int, typename>
                struct Template { using Type = bool; };

                template<typename T, bool V0, typename T3, typename T4>
                struct Template<Quux, T, V0, T3, 42, T4> { using Type = short; };

                template<typename T, bool V0, typename T3, typename T4>
                struct Template<T, Quux, V0, T3, 42, T4> { using Type = double; };

                template<>
                struct Template<Quux, Baz, true, Bar, 33, Foo> { using Type = float; };
            }
        )
    );

    tu.children.length.shouldEqual(8);

    auto structs = tu.children[0 .. 4];     // Foo, Bar, Baz, Quux
    auto template_ = tu.children[4];        // The full or pure template
    auto partials = tu.children[5 .. 7];    // The partial template specialisations
    auto full = tu.children[7]; // The last Template declaration

    foreach(struct_; structs) {
        struct_.kind.should == Cursor.Kind.StructDecl;
        struct_.type.numTemplateArguments.should == -1;
    }

    template_.kind.should == Cursor.Kind.ClassTemplate;
    // The actual template, according to clang, has no template arguments
    template_.type.numTemplateArguments.should == -1;
    // To get the template parameters, one must look at the ClassTemplate's children
    template_.children.length.should == 7;
    printChildren(template_);

    const typeAliasDecl = template_.children[$ - 1];
    typeAliasDecl.kind.should == Cursor.Kind.TypeAliasDecl;

    const templateParameters = template_.children[0 .. $ - 1];
    templateParameters[0].kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParameters[1].kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParameters[2].kind.should == Cursor.Kind.NonTypeTemplateParameter;
    templateParameters[3].kind.should == Cursor.Kind.TemplateTypeParameter; // bool
    templateParameters[4].kind.should == Cursor.Kind.NonTypeTemplateParameter;
    templateParameters[5].kind.should == Cursor.Kind.TemplateTypeParameter; // int

    foreach(partial; partials) {
        partial.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;
        partial.type.numTemplateArguments.should == 6;
        partial.specializedCursorTemplate.should == template_;
    }

    full.kind.should == Cursor.Kind.StructDecl;
    full.type.numTemplateArguments.should == 6;
}



@Tags("contract")
@("variadic.only.types")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<typename...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 1;
    const templateParameter = variadic.children[0];

    templateParameter.kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParameter.type.kind.should == Type.Kind.Unexposed;
    templateParameter.type.canonical.kind.should == Type.Kind.Unexposed;
    templateParameter.type.spelling.should == "type-parameter-0-0";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}

@Tags("contract")
@("variadic.only.values")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<int...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 1;
    const templateParameter = variadic.children[0];

    templateParameter.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    templateParameter.type.kind.should == Type.Kind.Int;
    templateParameter.type.canonical.kind.should == Type.Kind.Int;
    templateParameter.type.spelling.should == "int";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}

@Tags("contract")
@("variadic.also.types")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<int, typename, bool, typename...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 4;
    const intParam = variadic.children[0];
    const typeParam = variadic.children[1];
    const boolParam = variadic.children[2];
    const restParam = variadic.children[3];

    intParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    intParam.type.kind.should == Type.Kind.Int;

    typeParam.kind.should == Cursor.Kind.TemplateTypeParameter;
    typeParam.type.kind.should == Type.Kind.Unexposed;
    typeParam.spelling.should == "";

    boolParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    boolParam.type.kind.should == Type.Kind.Bool;

    restParam.kind.should == Cursor.Kind.TemplateTypeParameter;
    restParam.type.kind.should == Type.Kind.Unexposed;
    restParam.type.spelling.should == "type-parameter-0-3";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}

@Tags("contract")
@("variadic.also.values")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<int, typename, bool, short...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 4;
    const intParam = variadic.children[0];
    const typeParam = variadic.children[1];
    const boolParam = variadic.children[2];
    const restParam = variadic.children[3];

    intParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    intParam.type.kind.should == Type.Kind.Int;

    typeParam.kind.should == Cursor.Kind.TemplateTypeParameter;
    typeParam.type.kind.should == Type.Kind.Unexposed;
    typeParam.spelling.should == "";

    boolParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    boolParam.type.kind.should == Type.Kind.Bool;

    restParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    restParam.type.kind.should == Type.Kind.Short;
    restParam.type.spelling.should == "short";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}



@Tags("contract")
@("variadic.specialization")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<typename...>
                struct Variadic {};

                template<typename T0, typename T1>
                struct Variadic<T0, T1> { };
            }
        )
    );

    tu.children.length.shouldEqual(2);

    const template_ = tu.children[0];
    printChildren(template_);

    const special = tu.children[1];
    printChildren(special);

    special.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;
    special.type.numTemplateArguments.should == 2;
    // unexposed - non-specialised type
    special.type.typeTemplateArgument(0).kind.should == Type.Kind.Unexposed;
    special.type.typeTemplateArgument(1).kind.should == Type.Kind.Unexposed;
}


@Tags("contract")
@("lref")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template<typename>
                struct Struct{};

                template<typename T>
                struct Struct<T&> {
                    using Type = T;
                };
            }
        )
    );

    tu.children.length.shouldEqual(2);

    const general = tu.children[0];
    const special = tu.children[1];

    general.kind.should == Cursor.Kind.ClassTemplate;
    special.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;

    special.type.kind.should == Type.Kind.Unexposed;
    special.type.numTemplateArguments.should == 1;
    const templateType = special.type.typeTemplateArgument(0);

    templateType.spelling.should == "type-parameter-0-0 &";
}


@Tags("contract")
@("ParmDecl")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template<typename> struct Struct{};
                template<typename R, typename... A>
                struct Struct<R(A...)> {};
            }
        )
    );

    tu.children.length.should == 2;
    const partial = tu.children[1];

    partial.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;
    printChildren(partial);
    partial.children.length.should == 4;

    partial.children[0].kind.should == Cursor.Kind.TemplateTypeParameter;
    partial.children[0].spelling.should == "R";

    partial.children[1].kind.should == Cursor.Kind.TemplateTypeParameter;
    partial.children[1].spelling.should == "A";

    partial.children[2].kind.should == Cursor.Kind.TypeRef;
    partial.children[2].spelling.should == "R";

    partial.children[3].kind.should == Cursor.Kind.ParmDecl;
    partial.children[3].spelling.should == "";

    const parmDecl = partial.children[3];
    parmDecl.type.kind.should == Type.Kind.Unexposed;
    parmDecl.type.spelling.should == "A...";
}