% SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
% analgapes :: perception/tool_registry.pl
% Tool registry as a Datalog fact base. Facts loaded from JSON via
% tool_loader.sh. Queries: tools_in_category/2, tool_count/1, has_tool/1.
:- dynamic tool/3.

tools_in_category(Cat, Names) :-
    findall(N, tool(N, Cat, _), Names).

tool_count(N) :- aggregate_all(count, tool(_,_,_), N).

has_tool(Name) :- tool(Name, _, _).

category(Cat) :- distinct(Cat, tool(_, Cat, _)).

% CLI entry: swipl -g "main(Argv)" ...
:- initialization(main, main).  % only when run as script
main([load, Facts, Goal | _]) :- !,
    consult(Facts),
    ( Goal == count -> tool_count(N), format("~w~n", [N])
    ; atom_string(Goal, GS), split_string(GS, ":", "", [_,Cat]),
      tools_in_category(Cat, Ns), length(Ns, L), format("~w~n", [L])
    ).
main(_) :- true.
