declare-option -docstring "Sort tags in tagbuf buffer.
  Possible values:
    true:     Sort tags.
    false:    Do not sort tags.
  Default value: true" \
str tagbuf_sort 'true'

declare-option -docstring "Display anonymous tags.
  Possible values: true, false
  Default value: true" \
str tagbuf_display_anon 'true'

declare-option -docstring "Command to generate tags file." \
str tagbuf_ctags_cmd 'ctags'

declare-option -hidden str-list tagbuf_kinds

hook -group tagbuf-highlight global WinSetOption filetype=tagbuf %{
    add-highlighter window/tagbuf group
    add-highlighter window/tagbuf/category regex ^[^\s][^\n]+$ 0:keyword
    add-highlighter window/tagbuf/info regex (?<=:\h)(.*?)$ 1:comment
    add-highlighter window/tagbuf/line line %{%val{cursor_line}} default+b
    hook -always -once window WinSetOption filetype=.* %{ remove-highlighter window/tagbuf }
}

define-command -docstring 'List tags in current buffer' tagbuf %{
    tagbuf-set-kinds
    evaluate-commands %sh{
    if [ -z "$kak_opt_tagbuf_kinds" ]; then
        printf "%s\n" "echo -markup %{{Information}Filetype '$kak_opt_filetype' is not supported by tagbuf}"
        exit
    fi

    tmp=$(mktemp -d "${TMPDIR:-/tmp}/tagbuf.XXXXXXXX")
    tags="$tmp/tags"
    tagbuf_buffer="$tmp/buffer"
    fifo="${tmp}/fifo"
    mkfifo ${fifo}

    printf "%s\n" "hook global -always KakEnd .* %{ nop %sh{ rm -rf $tmp }}"

    case ${kak_opt_tagbuf_ctags_cmd} in
        ctags)
            ctags="ctags --sort='${kak_opt_tagbuf_sort:-yes}' -f '$tags' '$kak_buffile'" ;;
        ctags*|*)
            ctags="${kak_opt_tagbuf_ctags_cmd} -f '$tags' '$kak_buffile'" ;;
    esac

    eval ${ctags} > /dev/null 2>&1

    eval "set -- $kak_opt_tagbuf_kinds"
    while [ $# -gt 0 ]; do
        export tagbuf_description="$2"
        readtags -t "${tags}" -Q '(eq? $kind "'$1'")' -l | awk -F '\t|\n' '
            /^__anon[a-zA-Z0-9]+/ {
                if ( ENVIRON["kak_opt_tagbuf_display_anon"] != "true" ) {
                    $0=""
                }
            }
            /[^\t]+\t[^\t]+\t\/\^.*\$?\// {
                tag = $1;
                info = $0; sub(".*\t/\\^", "", info); sub("\\$?/$", "", info); gsub(/^[\t ]+/, "", info); gsub("\\\\/", "/", info);
                if (length(info) != 0)
                    out = out "  " tag ": \t" info "\n"
            }
            END {
                if (length(out) != 0) {
                    print ENVIRON["tagbuf_description"]
                    print out
                }
            }
        ' >> $tagbuf_buffer
        shift 2
    done

    printf "%s\n" "evaluate-commands -try-client %opt{toolsclient} %{ try %{
                       edit! -debug -fifo ${fifo} *tagbuf*
                       set-option buffer filetype tagbuf
                       map buffer normal '<ret>' ': tagbuf-jump %{${kak_bufname}}<ret>'
                       try %{
                           set-option window tabstop 1
                           remove-highlighter window/wrap
                           remove-highlighter window/numbers
                           remove-highlighter window/whitespace
                           remove-highlighter window/wrap
                       }
                   }}"

    ( cat ${tagbuf_buffer} > ${fifo}; rm -rf ${tmp} ) > /dev/null 2>&1 < /dev/null &
}}

define-command -hidden tagbuf-jump -params 1 %{
    execute-keys '<a-h>;/: <c-v><c-i><ret><a-h>2<s-l><a-l><a-;>'
    evaluate-commands %sh{
        printf "%s: \t%s\n" "${kak_selection}" "$1" | awk -F ': \t' '{
                keys = $2; gsub(/</, "<lt>", keys); gsub(/\t/, "<c-v><c-i>", keys);
                gsub("&", "&&", keys); gsub("#", "##", keys);
                select = $1; gsub(/</, "<lt>", select); gsub(/\t/, "<c-v><c-i>", select);
                gsub("&", "&&", select); gsub("#", "##", select);
                bufname = $3; gsub("&", "&&", bufname); gsub("#", "##", bufname);
                print "try %# buffer %&" bufname "&; execute-keys %&<esc>/\\Q" keys "<ret>vc& # catch %# echo -markup %&{Error}unable to find tag& #; try %# execute-keys %&s\\Q" select "<ret>& #"
            }'
    }
    try %{ focus %opt{jumpclient} }
}


define-command -hidden tagbuf-set-kinds %{ evaluate-commands %sh{
    [ -n "$kak_opt_tagbuf_kinds" ] && exit
    case $kak_opt_filetype in
        ada)                 printf "set-option window tagbuf_kinds 'P' 'Package Specifications' 'p' 'Packages' 't' 'Types' 'u' 'Subtypes' 'c' 'Record Type Components' 'l' 'Enum Type Literals' 'v' 'Variables' 'f' 'Generic Formal Parameters' 'n' 'Constants' 'x' 'User Defined Exceptions' 'R' 'Subprogram Specifications' 'r' 'Subprograms' 'K' 'Task Specifications' 'k' 'Tasks' 'O' 'Protected Data Specifications' 'o' 'Protected Data' 'e' 'Task/Protected Data Entries' 'b' 'Labels' 'i' 'Loop/Declare Identifiers' 'S' 'Ctags Internal Use'" ;;
        ant)                 printf "set-option window tagbuf_kinds 'p' 'Projects' 't' 'Targets' 'P' 'Properties' 'i' 'Antfiles'" ;;
        asciidoc)            printf "set-option window tagbuf_kinds 'c' 'Chapters' 's' 'Sections' 'S' 'Level 2 Sections' 't' 'Level 3 Sections' 'T' 'Level 4 Sections' 'u' 'Level 5 Sections' 'a' 'Anchors'" ;;
        asm|gas)             printf "set-option window tagbuf_kinds 'd' 'Defines' 'l' 'Labels' 'm' 'Macros' 't' 'Types' 's' 'Sections'" ;;
        asp)                 printf "set-option window tagbuf_kinds 'd' 'Constants' 'c' 'Classes' 'f' 'Functions' 's' 'Subroutines' 'v' 'Variables'" ;;
        autoconf)            printf "set-option window tagbuf_kinds 'p' 'Packages' 't' 'Templates' 'm' 'Autoconf Macros' 'w' 'Options Specified With --With-...' 'e' 'Options Specified With --Enable-...' 's' 'Substitution Keys' 'c' 'Automake Conditions' 'd' 'Definitions'" ;;
        autoit)              printf "set-option window tagbuf_kinds 'f' 'Functions' 'r' 'Regions' 'g' 'Global Variables' 'l' 'Local Variables' 'S' 'Included Scripts'" ;;
        automake)            printf "set-option window tagbuf_kinds 'd' 'Directories' 'P' 'Programs' 'M' 'Manuals' 'T' 'Ltlibraries' 'L' 'Libraries' 'S' 'Scripts' 'D' 'Datum' 'c' 'Conditions'" ;;
        awk)                 printf "set-option window tagbuf_kinds 'f' 'Functions'" ;;
        basic)               printf "set-option window tagbuf_kinds 'c' 'Constants' 'f' 'Functions' 'l' 'Labels' 't' 'Types' 'v' 'Variables' 'g' 'Enumerations'" ;;
        beta)                printf "set-option window tagbuf_kinds 'f' 'Fragment Definitions' 's' 'Slots' 'v' 'Patterns'" ;;
        clojure)             printf "set-option window tagbuf_kinds 'f' 'Functions' 'n' 'Namespaces'" ;;
        cmake)               printf "set-option window tagbuf_kinds 'f' 'Functions' 'm' 'Macros' 't' 'Targets' 'v' 'Variable Definitions' 'D' 'Options Specified With -D' 'p' 'Projects' 'r' 'Regex'" ;;
        c)                   printf "set-option window tagbuf_kinds 'd' 'Macro Definitions' 'e' 'Enumerators' 'f' 'Function Definitions' 'g' 'Enumeration Names' 'h' 'Included Header Files' 'm' 'Struct, And Union Members' 's' 'Structure Names' 't' 'Typedefs' 'u' 'Union Names' 'v' 'Variable Definitions'" ;;
        cpp)                 printf "set-option window tagbuf_kinds 'd' 'Macro Definitions' 'e' 'Enumerators' 'f' 'Function Definitions' 'g' 'Enumeration Names' 'h' 'Included Header Files' 'm' 'Class, Struct, And Union Members' 's' 'Structure Names' 't' 'Typedefs' 'u' 'Union Names' 'v' 'Variable Definitions' 'c' 'Classes' 'n' 'Namespaces'" ;;
        cpreprocessor)       printf "set-option window tagbuf_kinds 'd' 'Macro Definitions' 'h' 'Included Header Files'" ;;
        css)                 printf "set-option window tagbuf_kinds 'c' 'Classes' 's' 'Selectors' 'i' 'Identities'" ;;
        csharp)              printf "set-option window tagbuf_kinds 'c' 'Classes' 'd' 'Macro Definitions' 'e' 'Enumerators' 'E' 'Events' 'f' 'Fields' 'g' 'Enumeration Names' 'i' 'Interfaces' 'm' 'Methods' 'n' 'Namespaces' 'p' 'Properties' 's' 'Structure Names' 't' 'Typedefs'" ;;
        ctags)               printf "set-option window tagbuf_kinds 'l' 'Language Definitions' 'k' 'Kind Definitions'" ;;
        cobol)               printf "set-option window tagbuf_kinds 'p' 'Paragraphs' 'd' 'Data Items' 'S' 'Source Code File' 'f' 'File Descriptions' 'g' 'Group Items' 'P' 'Program Ids' 's' 'Sections' 'D' 'Divisions'" ;;
        cuda)                printf "set-option window tagbuf_kinds 'd' 'Macro Definitions' 'e' 'Enumerators' 'f' 'Function Definitions' 'g' 'Enumeration Names' 'h' 'Included Header Files' 'm' 'Struct, And Union Members' 's' 'Structure Names' 't' 'Typedefs' 'u' 'Union Names' 'v' 'Variable Definitions'" ;;
        d)                   printf "set-option window tagbuf_kinds 'a' 'Aliases' 'c' 'Classes' 'g' 'Enumeration Names' 'e' 'Enumerators' 'f' 'Function Definitions' 'i' 'Interfaces' 'm' 'Class, Struct, And Union Members' 'X' 'Mixins' 'M' 'Modules' 'n' 'Namespaces' 's' 'Structure Names' 'T' 'Templates' 'u' 'Union Names' 'v' 'Variable Definitions' 'V' 'Version Statements'" ;;
        diff)                printf "set-option window tagbuf_kinds 'm' 'Modified Files' 'n' 'Newly Created Files' 'd' 'Deleted Files' 'h' 'Hunks'" ;;
        dtd)                 printf "set-option window tagbuf_kinds 'E' 'Entities' 'p' 'Parameter Entities' 'e' 'Elements' 'a' 'Attributes' 'n' 'Notations'" ;;
        dts)                 printf "set-option window tagbuf_kinds 'p' 'Phandlers' 'l' 'Labels' 'r' 'Regex'" ;;
        dosbatch)            printf "set-option window tagbuf_kinds 'l' 'Labels' 'v' 'Variables'" ;;
        eiffel)              printf "set-option window tagbuf_kinds 'c' 'Classes' 'f' 'Features'" ;;
        elm)                 printf "set-option window tagbuf_kinds 'm' 'Module' 'n' 'Renamed Imported Module' 'p' 'Port' 't' 'Type Definition' 'c' 'Type Constructor' 'a' 'Type Alias' 'f' 'Functions'" ;;
        erlang)              printf "set-option window tagbuf_kinds 'd' 'Macro Definitions' 'f' 'Functions' 'm' 'Modules' 'r' 'Record Definitions' 't' 'Type Definitions'" ;;
        falcon)              printf "set-option window tagbuf_kinds 'c' 'Classes' 'f' 'Functions' 'm' 'Class Members' 'v' 'Variables' 'i' 'Imports'" ;;
        flex)                printf "set-option window tagbuf_kinds 'f' 'Functions' 'c' 'Classes' 'm' 'Methods' 'p' 'Properties' 'v' 'Global Variables' 'x' 'Mxtags'" ;;
        fortran)             printf "set-option window tagbuf_kinds 'b' 'Block Data' 'c' 'Common Blocks' 'e' 'Entry Points' 'E' 'Enumerations' 'f' 'Functions' 'i' 'Interface Contents, Generic Names, And Operators' 'k' 'Type And Structure Components' 'l' 'Labels' 'm' 'Modules' 'M' 'Type Bound Procedures' 'n' 'Namelists' 'N' 'Enumeration Values' 'p' 'Programs' 's' 'Subroutines' 't' 'Derived Types And Structures' 'v' 'Program And Module Variables' 'S' 'Submodules'" ;;
        fypp)                printf "set-option window tagbuf_kinds 'm' 'Macros'" ;;
        gdbinit)             printf "set-option window tagbuf_kinds 'd' 'Definitions' 't' 'Toplevel Variables'" ;;
        go)                  printf "set-option window tagbuf_kinds 'p' 'Packages' 'f' 'Functions' 'c' 'Constants' 't' 'Types' 'v' 'Variables' 's' 'Structs' 'i' 'Interfaces' 'm' 'Struct Members' 'M' 'Struct Anonymous Members' 'n' 'Interface Method Specification' 'u' 'Unknown' 'P' 'Name For Specifying Imported Package'" ;;
        html)                printf "set-option window tagbuf_kinds 'a' 'Named Anchors' 'h' 'H1 Headings' 'i' 'H2 Headings' 'j' 'H3 Headings'" ;;
        iniconf)             printf "set-option window tagbuf_kinds 's' 'Sections' 'k' 'Keys'" ;;
        itcl)                printf "set-option window tagbuf_kinds 'c' 'Classes' 'm' 'Methods' 'v' 'Object-Specific Variables' 'C' 'Common Variables' 'p' 'Procedures Within The  Class  Namespace'" ;;
        java)                printf "set-option window tagbuf_kinds 'a' 'Annotation Declarations' 'c' 'Classes' 'e' 'Enum Constants' 'f' 'Fields' 'g' 'Enum Types' 'i' 'Interfaces' 'm' 'Methods' 'p' 'Packages'" ;;
        javaproperties)      printf "set-option window tagbuf_kinds 'k' 'Keys'" ;;
        javascript)          printf "set-option window tagbuf_kinds 'f' 'Functions' 'c' 'Classes' 'm' 'Methods' 'p' 'Properties' 'C' 'Constants' 'v' 'Global Variables' 'g' 'Generators' 'G' 'Getters' 'S' 'Setters'" ;;
        json)                printf "set-option window tagbuf_kinds 'o' 'Objects' 'a' 'Arrays' 'n' 'Numbers' 's' 'Strings' 'b' 'Booleans' 'z' 'Nulls'" ;;
        ldscript)            printf "set-option window tagbuf_kinds 'S' 'Sections' 's' 'Symbols' 'v' 'Versions' 'i' 'Input Sections'" ;;
        lisp)                printf "set-option window tagbuf_kinds 'f' 'Functions'" ;;
        lua)                 printf "set-option window tagbuf_kinds 'f' 'Functions'" ;;
        m4)                  printf "set-option window tagbuf_kinds 'd' 'Macros' 'I' 'Macro Files'" ;;
        man)                 printf "set-option window tagbuf_kinds 't' 'Titles' 's' 'Sections'" ;;
        makefile)            printf "set-option window tagbuf_kinds 'm' 'Macros' 't' 'Targets' 'I' 'Makefiles'" ;;
        markdown)            printf "set-option window tagbuf_kinds 'c' 'Chapsters' 's' 'Sections' 'S' 'Subsections' 't' 'Subsubsections' 'T' 'Level 4 Subsections' 'u' 'Level 5 Subsections' 'r' 'Regex'" ;;
        matlab)              printf "set-option window tagbuf_kinds 'f' 'Function' 'v' 'Variable' 'c' 'Class'" ;;
        myrddin)             printf "set-option window tagbuf_kinds 'f' 'Functions' 'c' 'Constants' 'v' 'Variables' 't' 'Types' 'r' 'Traits' 'p' 'Packages'" ;;
        objectivec)          printf "set-option window tagbuf_kinds 'i' 'Class Interface' 'I' 'Class Implementation' 'P' 'Protocol' 'm' 'Object methods' 'c' 'Class methods' 'v' 'Global Variable' 'E' 'Object Field' 'f' 'A Function' 'p' 'A Property' 't' 'A Type Alias' 's' 'A Type Structure' 'e' 'An Enumeration' 'M' 'A Preprocessor Macro' 'C' 'Categories'" ;;
        ocaml)               printf "set-option window tagbuf_kinds 'c' 'Classes' 'm' 'Object methods' 'M' 'Module Or Functor' 'v' 'Global Variable' 'p' 'Signature Item' 't' 'Type Name' 'f' 'A Function' 'C' 'A Constructor' 'r' 'A Structure Field' 'e' 'An Exception'" ;;
        passwd)              printf "set-option window tagbuf_kinds 'u' 'User Names'" ;;
        pascal)              printf "set-option window tagbuf_kinds 'f' 'Functions' 'p' 'Procedures'" ;;
        perl)                printf "set-option window tagbuf_kinds 'c' 'Constants' 'f' 'Formats' 'l' 'Labels' 'p' 'Packages' 's' 'Subroutines'" ;;
        perl6)               printf "set-option window tagbuf_kinds 'c' 'Classes' 'g' 'Grammars' 'm' 'Methods' 'o' 'Modules' 'p' 'Packages' 'r' 'Roles' 'u' 'Rules' 'b' 'Submethods' 's' 'Subroutines' 't' 'Tokens'" ;;
        php)                 printf "set-option window tagbuf_kinds 'c' 'Classes' 'd' 'Constant Definitions' 'f' 'Functions' 'i' 'Interfaces' 'n' 'Namespaces' 't' 'Traits' 'v' 'Variables' 'a' 'Aliases'" ;;
        pod)                 printf "set-option window tagbuf_kinds 'c' 'Chapters' 's' 'Sections' 'S' 'Subsections' 't' 'Subsubsections'" ;;
        protobuf)            printf "set-option window tagbuf_kinds 'p' 'Packages' 'm' 'Messages' 'f' 'Fields' 'e' 'Enum Constants' 'g' 'Enum Types' 's' 'Services'" ;;
        puppetmanifest)      printf "set-option window tagbuf_kinds 'c' 'Classes' 'd' 'Definitions' 'n' 'Nodes' 'r' 'Resources' 'v' 'Variables'" ;;
        python)              printf "set-option window tagbuf_kinds 'c' 'Classes' 'f' 'Functions' 'm' 'Class Members' 'v' 'Variables' 'I' 'Name Referring A Module Defined In Other File' 'i' 'Modules' 'x' 'Name Referring A Class/Variable/Function/Module Defined In Other Module'" ;;
        pythonloggingconfig) printf "set-option window tagbuf_kinds 'L' 'Logger Sections' 'q' 'Logger Qualnames'" ;;
        qemuhx)              printf "set-option window tagbuf_kinds 'q' 'QEMU Management Protocol Dispatch Table Entries' 'i' 'Item In Texinfo Doc'" ;;
        qtmoc)               printf "set-option window tagbuf_kinds 's' 'Slots' 'S' 'Signals' 'p' 'Properties'" ;;
        r)                   printf "set-option window tagbuf_kinds 'f' 'Functions' 'l' 'Libraries' 's' 'Sources' 'g' 'Global Variables' 'v' 'Function Variables'" ;;
        rspec)               printf "set-option window tagbuf_kinds 'd' 'Describes' 'c' 'Contexts'" ;;
        rexx)                printf "set-option window tagbuf_kinds 's' 'Subroutines'" ;;
        robot)               printf "set-option window tagbuf_kinds 't' 'Testcases' 'k' 'Keywords' 'v' 'Variables'" ;;
        rpmspec)             printf "set-option window tagbuf_kinds 't' 'Tags' 'm' 'Macros' 'p' 'Packages' 'g' 'Global Macros'" ;;
        restructuredtext)    printf "set-option window tagbuf_kinds 'c' 'Chapters' 's' 'Sections' 'S' 'Subsections' 't' 'Subsubsections' 'T' 'Targets'" ;;
        ruby)                printf "set-option window tagbuf_kinds 'c' 'Classes' 'f' 'Methods' 'm' 'Modules' 'S' 'Singleton Methods'" ;;
        rust)                printf "set-option window tagbuf_kinds 'n' 'Module' 's' 'Structural Type' 'i' 'Trait Interface' 'c' 'Implementation' 'f' 'Function' 'g' 'Enum' 't' 'Type Alias' 'v' 'Global Variable' 'M' 'Macro Definitions' 'm' 'Struct Fields' 'e' 'An Enum Variant' 'P' 'Methods'" ;;
        scheme)              printf "set-option window tagbuf_kinds 'f' 'Functions' 's' 'Sets'" ;;
        sh)                  printf "set-option window tagbuf_kinds 'a' 'Aliases' 'f' 'Functions' 's' 'Script Files' 'h' 'Label For Here Document'" ;;
        slang)               printf "set-option window tagbuf_kinds 'f' 'Functions' 'n' 'Namespaces'" ;;
        sml)                 printf "set-option window tagbuf_kinds 'e' 'Exception Declarations' 'f' 'Function Definitions' 'c' 'Functor Definitions' 's' 'Signature Declarations' 'r' 'Structure Declarations' 't' 'Type Definitions' 'v' 'Value Bindings'" ;;
        sql)                 printf "set-option window tagbuf_kinds 'c' 'Cursors' 'f' 'Functions' 'E' 'Record Fields' 'L' 'Block Label' 'P' 'Packages' 'p' 'Procedures' 's' 'Subtypes' 't' 'Tables' 'T' 'Triggers' 'v' 'Variables' 'i' 'Indexes' 'e' 'Events' 'U' 'Publications' 'R' 'Services' 'D' 'Domains' 'V' 'Views' 'n' 'Synonyms' 'x' 'MobiLink Table Scripts' 'y' 'MobiLink Conn Scripts' 'z' 'MobiLink Properties '" ;;
        systemdunit)         printf "set-option window tagbuf_kinds 'u' 'Units'" ;;
        systemtap)           printf "set-option window tagbuf_kinds 'p' 'Probe Aliases' 'f' 'Functions' 'v' 'Variables' 'm' 'Macros' 'r' 'Regex'" ;;
        tcl)                 printf "set-option window tagbuf_kinds 'p' 'Procedures' 'n' 'Namespaces'" ;;
        tcloo)               printf "set-option window tagbuf_kinds 'c' 'Classes' 'm' 'Methods'" ;;
        latex)               printf "set-option window tagbuf_kinds 'p' 'Parts' 'c' 'Chapters' 's' 'Sections' 'u' 'Subsections' 'b' 'Subsubsections' 'P' 'Paragraphs' 'G' 'Subparagraphs' 'l' 'Labels' 'i' 'Includes'" ;;
        ttcn)                printf "set-option window tagbuf_kinds 'M' 'Module Definition' 't' 'Type Definition' 'c' 'Constant Definition' 'd' 'Template Definition' 'f' 'Function Definition' 's' 'Signature Definition' 'C' 'Testcase Definition' 'a' 'Altstep Definition' 'G' 'Group Definition' 'P' 'Module Parameter Definition' 'v' 'Variable Instance' 'T' 'Timer Instance' 'p' 'Port Instance' 'm' 'Record/Set/Union Member' 'e' 'Enumeration Value'" ;;
        vera)                printf "set-option window tagbuf_kinds 'c' 'Classes' 'd' 'Macro Definitions' 'e' 'Enumerators' 'f' 'Function Definitions' 'g' 'Enumeration Names' 'i' 'Interfaces' 'm' 'Class, Struct, And Union Members' 'p' 'Programs' 's' 'Signals' 't' 'Tasks' 'T' 'Typedefs' 'v' 'Variable Definitions' 'h' 'Included Header Files'" ;;
        verilog)             printf "set-option window tagbuf_kinds 'c' 'Constants' 'e' 'Events' 'f' 'Functions' 'm' 'Modules' 'n' 'Net Data Types' 'p' 'Ports' 'r' 'Register Data Types' 't' 'Tasks' 'b' 'Blocks'" ;;
        systemverilog)       printf "set-option window tagbuf_kinds 'c' 'Constants' 'e' 'Events' 'f' 'Functions' 'm' 'Modules' 'n' 'Net Data Types' 'p' 'Ports' 'r' 'Register Data Types' 't' 'Tasks' 'b' 'Blocks' 'A' 'Assertions' 'C' 'Classes' 'V' 'Covergroups' 'E' 'Enumerators' 'I' 'Interfaces' 'M' 'Modports' 'K' 'Packages' 'P' 'Programs' 'R' 'Properties' 'S' 'Structs And Unions' 'T' 'Type Declarations'" ;;
        vhdl)                printf "set-option window tagbuf_kinds 'c' 'Constant Declarations' 't' 'Type Definitions' 'T' 'Subtype Definitions' 'r' 'Record Names' 'e' 'Entity Declarations' 'f' 'Function Prototypes And Declarations' 'p' 'Procedure Prototypes And Declarations' 'P' 'Package Definitions'" ;;
        vim)                 printf "set-option window tagbuf_kinds 'a' 'Autocommand Groups' 'c' 'User-Defined Commands' 'f' 'Function Definitions' 'm' 'Maps' 'v' 'Variable Definitions' 'n' 'Vimball Filename'" ;;
        windres)             printf "set-option window tagbuf_kinds 'd' 'Dialogs' 'm' 'Menus' 'i' 'Icons' 'b' 'Bitmaps' 'c' 'Cursors' 'f' 'Fonts' 'v' 'Versions' 'a' 'Accelerators'" ;;
        yacc)                printf "set-option window tagbuf_kinds 'l' 'Labels'" ;;
        yumrepo)             printf "set-option window tagbuf_kinds 'r' 'Repository Id'" ;;
        zephir)              printf "set-option window tagbuf_kinds 'c' 'Classes' 'd' 'Constant Definitions' 'f' 'Functions' 'i' 'Interfaces' 'n' 'Namespaces' 't' 'Traits' 'v' 'Variables' 'a' 'Aliases'" ;;
        dbusintrospect)      printf "set-option window tagbuf_kinds 'i' 'Interfaces' 'm' 'Methods' 's' 'Signals' 'p' 'Properties'" ;;
        glade)               printf "set-option window tagbuf_kinds 'i' 'Identifiers' 'c' 'Classes' 'h' 'Handlers'" ;;
        maven2)              printf "set-option window tagbuf_kinds 'g' 'Group Identifiers' 'a' 'Artifact Identifiers' 'p' 'Properties' 'r' 'Repository Identifiers'" ;;
        plistxml)            printf "set-option window tagbuf_kinds 'k' 'Keys'" ;;
        relaxng)             printf "set-option window tagbuf_kinds 'e' 'Elements' 'a' 'Attributes' 'n' 'Named Patterns'" ;;
        svg)                 printf "set-option window tagbuf_kinds 'i' 'Id Attributes'" ;;
        xslt)                printf "set-option window tagbuf_kinds 's' 'Stylesheets' 'p' 'Parameters' 'm' 'Matched Template' 'n' 'Matched Template' 'v' 'Variables'" ;;
        yaml)                printf "set-option window tagbuf_kinds 'a' 'Anchors'" ;;
        ansibleplaybook)     printf "set-option window tagbuf_kinds 'p' 'Plays'" ;;
        nim)                 [ -n "$(command -v ntags)" ] && printf "%s\n" "set-option window tagbuf_ctags_cmd 'ntags'
                                                                            set-option window tagbuf_kinds 'f' 'Procedures' 't' 'Types' 'v' 'Variables'" ;;
        *) ;;
    esac
}}
