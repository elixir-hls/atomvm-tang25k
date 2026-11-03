%% Small CPU benchmarks for AtomVM on the Tang Primer 25K (50 MHz VexRiscv).
%% Each case runs in its own process with the Fibonacci heap growth strategy: AtomVM's default
%% (bounded free) grows a heap by only a few words, so building a large term garbage-collects
%% every few allocations and the cost becomes quadratic. Prints each case in milliseconds.
-module(bench).
-export([start/0]).

start() ->
    io:format("bench: ~p~n", [erlang:system_info(system_architecture)]),
    run("fib(22)", fun() -> 17711 = fib(22) end),
    run("count to 100000", fun() -> 100000 = count(100000, 0) end),
    run("int64 mul+add+band x200", fun() -> lcg64(200, 12345) end),
    run("lists:sort 2000", fun() -> lists:sort(pseudo_random(2000, 12345, [])) end),
    run("map+foldl 5000", fun() ->
        lists:foldl(fun(X, Acc) -> X + Acc end, 0, lists:map(fun(X) -> X * 3 end, lists:seq(1, 5000)))
    end),
    run("ping-pong 2000 msgs", fun() -> ping_pong(2000) end),
    run("spawn+exit 200 procs", fun() -> spawn_wait(200) end),
    run("binary build 2000 B", fun() -> 2000 = byte_size(build_bin(2000, <<>>)) end),
    run("io_lib:format x50", fun() ->
        [io_lib:format("~p ~s ~b~n", [{I, a}, "str", I]) || I <- lists:seq(1, 50)]
    end),
    ok.

run(Name, Fun) ->
    Self = self(),
    spawn_opt(fun() ->
        T0 = erlang:monotonic_time(millisecond),
        Fun(),
        Self ! {done, erlang:monotonic_time(millisecond) - T0}
    end, [{atomvm_heap_growth, fibonacci}]),
    receive {done, Ms} -> io:format("~-28s ~6b ms~n", [Name, Ms]) end.

fib(N) when N < 2 -> N;
fib(N) -> fib(N - 1) + fib(N - 2).

count(0, Acc) -> Acc;
count(N, Acc) -> count(N - 1, Acc + 1).

%% Small-int generator (values stay below 2^27, unboxed on 32-bit)
pseudo_random(0, _, Acc) -> Acc;
pseudo_random(N, S, Acc) ->
    S1 = (S * 75 + 74) rem 65537,
    pseudo_random(N - 1, S1, [S1 | Acc]).

%% Values above 2^27 are boxed on 32-bit AtomVM: much slower than small ints
lcg64(0, S) -> S;
lcg64(N, S) -> lcg64(N - 1, (S * 1103515245 + 12345) band 16#7fffffff).

ping_pong(N) ->
    Self = self(),
    Pid = spawn(fun() -> pong(Self) end),
    ping(Pid, N),
    Pid ! stop,
    ok.

ping(_, 0) -> ok;
ping(Pid, N) ->
    Pid ! {ping, N},
    receive {pong, N} -> ping(Pid, N - 1) end.

pong(Parent) ->
    receive
        {ping, N} -> Parent ! {pong, N}, pong(Parent);
        stop -> ok
    end.

spawn_wait(N) ->
    Self = self(),
    [spawn(fun() -> Self ! done end) || _ <- lists:seq(1, N)],
    [receive done -> ok end || _ <- lists:seq(1, N)],
    ok.

build_bin(0, Bin) -> Bin;
build_bin(N, Bin) -> build_bin(N - 1, <<Bin/binary, (N band 255)>>).
