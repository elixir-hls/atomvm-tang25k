%% S2 check: the first BEAM code on the Tang Primer 25K.
-module(hello).
-export([start/0]).

start() ->
    io:format("Hello from AtomVM on ~p~n", [erlang:system_info(system_architecture)]),
    Self = self(),
    Pids = [spawn(fun() -> Self ! {done, N, N * N} end) || N <- lists:seq(1, 5)],
    Squares = [receive {done, N, Sq} -> Sq end || N <- lists:seq(1, length(Pids))],
    io:format("squares from ~p processes: ~p~n", [length(Pids), Squares]),
    ok.
