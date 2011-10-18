-module(redis_util).
-export([
    binary_to_int/1,
    parse_options/1,
    parse_options/2
]).

-include_lib("../include/redis.hrl").

binary_to_int(B) when is_binary(B) ->
    list_to_integer(binary_to_list(B)).

parse_options(Opts) ->
    parse_options(Opts, #state{}).

parse_options([], State) ->
    State;
parse_options([{ip, Ip} | Rest], State) ->
    parse_options(Rest, State#state{ip = Ip});
parse_options([{port, Port} | Rest], State) ->
    parse_options(Rest, State#state{port = Port});
parse_options([{db, Db} | Rest], State) ->
    parse_options(Rest, State#state{db = Db});
parse_options([{channel, Channel} | Rest], State) ->
    parse_options(Rest, State#state{channel = Channel});
parse_options([{callback, Callback} | Rest], State) ->
    parse_options(Rest, State#state{callback = Callback});
parse_options([{pass, Pass} | Rest], State) ->
    parse_options(Rest, State#state{pass = Pass}).
