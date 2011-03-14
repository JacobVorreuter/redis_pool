%% Copyright (c) 2010 Jacob Vorreuter <jacob.vorreuter@gmail.com>
%% 
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%% 
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%% 
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.
-module(redis_proto).
-export([send_auth/2, build/1]).

-define(NL, <<"\r\n">>).

send_auth(Socket, Pass) ->
    case gen_tcp:send(Socket, [<<"AUTH ">>, Pass, ?NL]) of
        ok ->
            case gen_tcp:recv(Socket, 0) of
                {ok, <<"+OK\r\n">>} -> true;
                {ok, Err} -> {error, Err};
                Err -> Err
            end;
        Err ->
            Err
    end.

build(Packet) when is_binary(Packet) ->
    Packet;

build([[Char|_]|_]=Args) when is_integer(Char) ->
    build_request(Args);

build([Bin|_]=Args) when is_binary(Bin) ->
    build_request(Args);

build(Args) when is_list(Args) ->
    build_pipelined_request(Args, []).

build_request(Args) ->
    Count = length(Args),
    Args1 = [
        [<<"$">>, integer_to_list(iolist_size(Arg)), ?NL, Arg, ?NL]
       || Arg <- Args],
    iolist_to_binary(["*", integer_to_list(Count), ?NL, Args1, ?NL]).

build_pipelined_request([], Acc) ->
    lists:reverse(Acc);

build_pipelined_request([Args|Rest], Acc) ->
    build_pipelined_request(Rest, [build_request(Args)|Acc]).
