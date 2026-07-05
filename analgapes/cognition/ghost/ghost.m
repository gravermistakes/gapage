% GHOST – Mercury Logic Lifter with Taint Tracking
% SPDX-License-Identifier: GPL-3.0-or-later
:- module ghost.
:- interface.
:- import_module io.
:- pred main(io::di, io::uo) is det.

:- implementation.
:- import_module list, string, int, bool, maybe.

:- type insn
    --->    mov(string, string)
    ;       add(string, string)
    ;       sub(string, string)
    ;       cmp(string, string)
    ;       jmp(string)
    ;       je(string)
    ;       jne(string)
    ;       call(string)
    ;       ret
    ;       push(string)
    ;       pop(string)
    ;       lea(string, string)
    ;       unknown.

:- type taint_set == list(string).

:- pred parse_line(string::in, maybe(insn)::out) is det.
parse_line(Line, MaybeInsn) :-
    ( if string.sub_string_search(Line, "mov", _) then
        ( if string.words(Line) = [_, Dst, Src | _] then
            MaybeInsn = yes(mov(Dst, Src))
        else
            MaybeInsn = no
        )
    else if string.sub_string_search(Line, "add", _) then
        ( if string.words(Line) = [_, Dst, Src | _] then
            MaybeInsn = yes(add(Dst, Src))
        else
            MaybeInsn = no
        )
    else if string.sub_string_search(Line, "jmp", _) then
        ( if string.words(Line) = [_, Target | _] then
            MaybeInsn = yes(jmp(Target))
        else
            MaybeInsn = no
        )
    else if string.sub_string_search(Line, "call", _) then
        ( if string.words(Line) = [_, Target | _] then
            MaybeInsn = yes(call(Target))
        else
            MaybeInsn = no
        )
    else if string.sub_string_search(Line, "ret", _) then
        MaybeInsn = yes(ret)
    else
        MaybeInsn = no
    ).

:- pred analyze(list(insn)::in, taint_set::in, taint_set::out) is det.
analyze([], !Taint).
analyze([Insn | Rest], !Taint) :-
    ( Insn = mov(Dst, Src), list.member(Src, !.Taint) ->
        !:Taint = [Dst | !.Taint]
    ; Insn = add(Dst, Src), list.member(Src, !.Taint) ->
        !:Taint = [Dst | !.Taint]
    ;
        true
    ),
    analyze(Rest, !Taint).

:- pred report(taint_set::in, io::di, io::uo) is det.
report(Taint, !IO) :-
    ( if Taint = [] then
        io.write_string("[Ghost] No tainted data flow detected.\n", !IO)
    else
        io.write_string("[Ghost] Tainted: ", !IO),
        io.write_string(string.join_list(", ", Taint), !IO),
        io.nl(!IO),
        io.write_string("[Ghost] ⚠ Tainted data flows from attacker-controlled input.\n", !IO)
    ).

:- pred read_lines(io.input_stream::in, list(string)::in, list(string)::out,
    io::di, io::uo) is det.
read_lines(Stream, !Lines, !IO) :-
    io.read_line_as_string(Stream, Result, !IO),
    ( Result = ok(Line) ->
        !:Lines = [Line | !.Lines],
        read_lines(Stream, !Lines, !IO)
    ;
        true
    ).

main(!IO) :-
    io.write_string("[Ghost] Mercury Taint Tracker v3.0\n", !IO),
    io.command_line_arguments(Args, !IO),
    ( if Args = [FileName | _] then
        io.open_input(FileName, Res, !IO),
        ( if Res = ok(Stream) then
            read_lines(Stream, [], Lines, !IO),
            io.close_input(Stream, !IO),
            list.filter_map(
                (pred(L::in, I::out) is semidet :-
                    parse_line(L, yes(I))),
                Lines, Insns),
            % Seed: standard calling-convention argument registers
            Seed = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"],
            analyze(Insns, Seed, Taint),
            report(Taint, !IO)
        else
            io.write_string("[Ghost] Cannot open file.\n", !IO)
        )
    else
        io.write_string("[Ghost] Usage: ghost_bin <disassembly.txt>\n", !IO)
    ).
