-module(redis_pool).
-behaviour(gen_server).

%% gen_server callbacks
-export([start_link/0, start_link/1, start_link/2, init/1, handle_call/3,
	     handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([pid/0, pid/1, expand_pool/1, expand_pool/2,
         cycle_pool/1, cycle_pool/2, info/0, info/1,
         pool_size/0, pool_size/1]).

-record(state, {opts=[], key='$end_of_table', restarts=0, tid}).

-define(MAX_RESTARTS, 600).

%% API functions
start_link() ->
    start_link(?MODULE, []).

start_link(Name) ->
    start_link(Name, []).

start_link(Name, Opts) when is_atom(Name) ->
	gen_server:start_link({local, Name}, ?MODULE, [Opts], []).

pid() ->
    pid(?MODULE).

pid(Name) when is_atom(Name) ->
    gen_server:call(Name, pid).

pool_size() ->
    pool_size(?MODULE).

pool_size(Name) when is_atom(Name) ->
    gen_server:call(Name, pool_size).

expand_pool(NewSize) ->
    expand_pool(?MODULE, NewSize).

expand_pool(Name, NewSize) when is_atom(Name), is_integer(NewSize) ->
    gen_server:cast(Name, {expand, NewSize}).

cycle_pool(NewOpts) ->
    cycle_pool(?MODULE, NewOpts).

cycle_pool(Name, NewOpts) when is_atom(Name), is_list(NewOpts) ->
    gen_server:cast(Name, {cycle_pool, NewOpts}).

info() ->
    info(?MODULE).

info(Name) when is_atom(Name) ->
    gen_server:call(Name, info).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%% @hidden
%%--------------------------------------------------------------------
init([Opts]) ->
    Tid = ets:new(undefined, [set, protected]),
    Self = self(),
    spawn_link(fun() -> clear_restarts(Self) end),
	{ok, #state{tid=Tid, opts=Opts}}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%% @hidden
%%--------------------------------------------------------------------
handle_call(pid, _From, #state{key='$end_of_table', tid=Tid}=State) ->
    case ets:first(Tid) of
        '$end_of_table' ->
            {reply, undefined, State#state{key='$end_of_table'}};
        Pid ->
            {reply, Pid, State#state{key=Pid}}
    end;

handle_call(pid, _From, #state{key=Prev, tid=Tid}=State) ->
    case ets:next(Tid, Prev) of
        '$end_of_table' ->
            case ets:first(Tid) of
                '$end_of_table' ->
                    {reply, undefined, State#state{key='$end_of_table'}};
                Pid ->
                    {reply, Pid, State#state{key=Pid}}
            end;
        Pid ->
            {reply, Pid, State#state{key=Pid}}
    end;

handle_call(info, _From, State) ->
    {reply, State, State};

handle_call(pool_size, _From, State) ->
    {reply, ets:info(State#state.tid, size), State};

handle_call(_Msg, _From, State) ->
    {reply, {error, invalid_call}, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%% @hidden
%%--------------------------------------------------------------------
handle_cast({expand, NewSize}, State) ->
    case NewSize - ets:info(State#state.tid, size) of
        Additions when Additions > 0 ->
            [start_client(State#state.tid, State#state.opts) || _ <- lists:seq(1, Additions)];
        _ ->
            ok
    end,
    {noreply, State};

handle_cast({cycle_pool, NewOpts}, State) ->
    [gen_server:call(Pid, {reconnect, NewOpts}) || {Pid, _} <- ets:tab2list(State#state.tid)],
    {noreply, State#state{opts=NewOpts}};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%% @hidden
%%--------------------------------------------------------------------
handle_info({'DOWN', _MonitorRef, process, Pid, _Info}, #state{restarts=Restarts, tid=Tid, key=Prev}=State) ->
    ets:delete(Tid, Pid),
    Restarts < ?MAX_RESTARTS andalso start_client(Tid, State#state.opts),
    % If I'm removing the previous element in the ets tab I need to reset
    % the state of the last key otherwise I'll get badarg over and over
    case Prev == Pid of
        true ->
            {noreply, State#state{restarts=Restarts+1, key='$end_of_table'}};
        false ->
            {noreply, State#state{restarts=Restarts+1}}
    end;

handle_info(clear_restarts, State) ->
    {noreply, State#state{restarts=0}};

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%% @hidden
%%--------------------------------------------------------------------
terminate(_Reason, _State) -> 
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%% @hidden
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
start_client(Tid, Opts) ->
    case catch gen_server:start(redis, Opts, []) of
        {ok, Pid} ->
            MonitorRef = erlang:monitor(process, Pid),
            ets:insert(Tid, {Pid, MonitorRef});
        R ->
            io:format("Error ~p while trying to connect to ~p~n", [R, Opts])
    end.

clear_restarts(Pid) ->
    timer:sleep(1000 * 60),
    Pid ! clear_restarts,
    clear_restarts(Pid).
