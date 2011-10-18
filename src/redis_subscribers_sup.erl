-module(redis_subscribers_sup).
-behaviour(supervisor).
-export([
    init/1,
    start_child/1,
    start_link/0
]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_child(Opts) ->
    supervisor:start_child(?MODULE, [Opts]).

init([]) ->
    {ok,
        {
            {simple_one_for_one, 100000, 1},
            [
                {undefined, {redis_subscriber, start_link, []}, transient, 10000, worker, [redis_subscriber]}
            ]
        }
    }.
