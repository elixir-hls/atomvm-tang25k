%% LEDs and buttons of the Tang Primer 25K Dock from Erlang.
%% Pins are {Controller, Pin}: controller 0 = LEDs (gpio_out), 1 = buttons (gpio_in, edge IRQ).
%% LED0 blinks from its own process; each button press (the input reads 0 while pressed)
%% toggles LED1 through a GPIO interrupt message.
-module(gpio_demo).
-export([start/0]).

-define(LED0, {0, 0}).
-define(LED1, {0, 1}).
-define(BUTTONS, [{1, 0}, {1, 1}]).

start() ->
    [ok = gpio:set_pin_mode(Led, output) || Led <- [?LED0, ?LED1]],
    [ok = gpio:set_pin_mode(Button, input) || Button <- ?BUTTONS],
    spawn(fun() -> blink(?LED0, high) end),
    GPIO = gpio:start(),
    [ok = gpio:set_int(GPIO, Button, falling) || Button <- ?BUTTONS],
    io:format("gpio_demo: LED0 blinks, press a Dock button to toggle LED1~n"),
    buttons(low, 0).

blink(Led, Level) ->
    ok = gpio:digital_write(Led, Level),
    timer:sleep(250),
    blink(Led, toggle(Level)).

buttons(Level, Count) ->
    receive
        {gpio_interrupt, Button} ->
            ok = gpio:digital_write(?LED1, toggle(Level)),
            io:format("press ~p on ~p, LED1 ~p~n", [Count + 1, Button, toggle(Level)]),
            buttons(toggle(Level), Count + 1)
    end.

toggle(high) -> low;
toggle(low) -> high.
