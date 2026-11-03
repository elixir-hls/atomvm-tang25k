%% Reads lines from the console UART and echoes them back. io:get_line needs a group leader,
%% which this port does not start; the uart module polls the console UART directly.
-module(echo).
-export([start/0]).

start() ->
    UART = uart:open([]),
    io:format("echo: type a line~n"),
    loop(UART, <<>>).

loop(UART, Acc) ->
    case uart:read(UART, 1000) of
        {ok, Data} -> lines(UART, <<Acc/binary, Data/binary>>);
        {error, timeout} -> loop(UART, Acc);
        {error, Reason} -> io:format("error ~p~n", [Reason])
    end.

lines(UART, Buf) ->
    case binary:split(Buf, [<<"\r">>, <<"\n">>]) of
        [Line, Rest] when Line =/= <<>> ->
            io:format("got ~p~n", [Line]),
            lines(UART, Rest);
        [<<>>, Rest] -> lines(UART, Rest);
        [Partial] -> loop(UART, Partial)
    end.
