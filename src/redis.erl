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
-module(redis).
-behaviour(gen_server).

%% gen_server callbacks
-export([start_link/0, start_link/1, start_link/2, init/1, handle_call/3,
          handle_cast/2, handle_info/2, terminate/2, code_change/3, stop/1]).

-export([q/2, q/3]).

-include_lib("../include/redis.hrl").

-define(TIMEOUT, 5000).

%% API functions
start_link() ->
    start_link([]).

start_link(Opts) ->
    gen_server:start_link(?MODULE, [Opts], []).

start_link(Pool, Opts) ->
    case gen_server:start_link(?MODULE, [Opts], []) of
        {ok, Pid} ->
            redis_pool:register(Pool, Pid),
            {ok, Pid};
        Err ->
            Err
    end.

q(Pid, Parts) ->
    q(Pid, Parts, ?TIMEOUT).

q(Pid, Parts, Timeout) ->
    case catch gen_server:call(Pid, {q, Parts}, Timeout) of
        {'EXIT', {timeout, {gen_server, call, _}}} ->
            gen_server:cast(Pid, {stop, timeout}),
            {error, timeout};
        {'EXIT', {Error,   {gen_server, call, _}}} ->
            {error, Error};
        Reply ->
            Reply
    end.

stop(Pid) ->
    gen_server:cast(Pid, {stop, normal}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%    {ok, State, Timeout} |
%%    ignore                             |
%%    {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([Opts]) ->
    io:format("init redis worker: ~p~n", [self()]),
    State = redis_util:parse_options(Opts),
    case redis_net:connect(State#state.ip, State#state.port, State#state.pass) of
        {ok, Socket} ->
            {ok, State#state{socket=Socket}};
        Error ->
            {stop, Error}
    end.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%    {reply, Reply, State, Timeout} |
%%    {noreply, State} |
%%    {noreply, State, Timeout} |
%%    {stop, Reason, Reply, State} |
%%    {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call({q, Parts}, _From, #state{socket=Socket, ip=Ip, port=Port, pass=Pass}=State) ->
    Packet = redis_proto:build(Parts),
    case redis_net:send_recv(Socket, Ip, Port, Pass, Packet, 1) of
        {error, Error} ->
            {stop, Error, State};
        {Reply, NewSocket} ->
            {reply, Reply, State#state{socket=NewSocket}}
    end;

handle_call(_Msg, _From, State) ->
    {reply, unknown_message, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%    {noreply, State, Timeout} |
%%    {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast({stop, Reason}, State) ->
    {stop, Reason, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%    {noreply, State, Timeout} |
%%    {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, State) ->
    redis_net:disconnect(State#state.socket),
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
