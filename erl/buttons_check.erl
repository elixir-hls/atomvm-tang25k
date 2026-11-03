%% Diagnoses the Dock buttons: prints every level change seen by polling and every GPIO
%% interrupt, so a missing interrupt can be told apart from a pin that never changes.
-module(buttons_check).
-export([start/0]).

-define(BUTTONS, [{1, 0}, {1, 1}]).

start() ->
    GPIO = gpio:start(),
    [ok = gpio:set_pin_mode(B, input) || B <- ?BUTTONS],
    [ok = gpio:set_int(GPIO, B, both) || B <- ?BUTTONS],
    Levels = [gpio:digital_read(B) || B <- ?BUTTONS],
    io:format("buttons_check: levels ~p (released should read high)~n", [Levels]),
    loop(Levels).

loop(Levels) ->
    receive
        {gpio_interrupt, Pin} -> io:format("interrupt ~p~n", [Pin]), loop(Levels)
    after 20 ->
        New = [gpio:digital_read(B) || B <- ?BUTTONS],
        New =/= Levels andalso io:format("poll: levels ~p~n", [New]),
        loop(New)
    end.
