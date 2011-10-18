# redis_pool

## Synopsis

minimalistic [redis](http://code.google.com/p/redis/) client for erlang.  

Derived from:  

* <https://github.com/bmizerany/redis-erl/>  

Active forks:  

* <https://github.com/dialtone/redis_pool>  

## Overview

  redis_pool is a redis client implementation that only
  uses redis's [multi bulk command protocol](http://code.google.com/p/redis/wiki/ProtocolSpecification).
  
  It implements connection pools, timeout management, automatic reconnect
  on errors and a very simple sharding mechanism.

## Usage

    make
    erl -pa ebin -s redis_app

## Raw examples

    0> {ok, P} = redis_pool:start_link([], 10).  % connect to default redis port on localhost
    {ok,<0.50.0>}
    1> redis_pool:q(P, ["set", "foo", "bar"]).
    <<"OK">>
    2> redis_pool:q(P, ["get", "foo"]).
    <<"bar">>
    3> redis_pool:q(P, ["sadd", "bar", "a"]).
    1
    4> redis_pool:q(P, ["sadd", "bar", "b"]).
    1
    5> redis_pool:q(P, ["sadd", "bar", "c"]).
    1
    6> redis_pool:q(P, ["lrange", "0", "-1"]).
    {error,<<"ERR wrong number of arguments for 'lrange' command">>}
    7> redis_pool:q(P, ["lrange", "bar", "0", "-1"]).
    {error,<<"ERR Operation against a key holding the wrong kind of value">>}
    8> redis_pool:q(P, ["smembers", "bar"]).
    [<<"c">>,<<"a">>,<<"b">>]
    9> redis_pool:q(P, ["incr", "counter"]).
    1

## Multiple Pools

    1> redis_pool:start_link(one, [], 10).
    {ok,<0.50.0>}
    2> redis_pool:start_link(two, [], 10).
    {ok,<0.64.0>}
    3> redis_pool:start_link(three, [], 10).
    {ok,<0.76.0>}
    4> redis_pool:start_link(four, [], 10). 
    {ok,<0.88.0>}
    5> redis_shard:start_link(shard, [one, two, three, four]).
    {ok,<0.108.0>}
    6> redis_pool:q(redis_shard:pool(shard, "foo"), ["set", "foo", "bar"]).
    <<"OK">>

## Pub/Sub

    %% the standard query function can be used to publish data
    redis_pool:q(pool, [<<"PUBLISH">>, Key, Value])

      Types:

        Key, Value = binary()

    %% the connect method starts a supervised redis child pid with a
    %% socket open to the redis server in active mode
    redis_subscribe:connect(Key, Opts, Callback) -> {ok, Pid}

      Types:

        Key = binary()
        Opts = list()
        Callback = {M,F,A} | {M, F} | fun()
        M = atom()
        F = atom()
        A = list()
        Pid = pid()

    1> redis_pool:start_link(pool, [], 10).
    {ok,<0.50.0>}
    2> redis_pool:q(pool, [<<"PUBLISH">>, <<"foo">>, <<"sandwich">>]).
    0
    3> redis_subscriber:subscribe(<<"foo">>, [], fun(Val) -> io:format("recv'd ~p~n", [Val]) end).
    {ok,<0.65.0>}
    4> redis_pool:q(pool, [<<"PUBLISH">>, <<"foo">>, <<"sandwich">>]).
    recv'd {message,<<"foo">>,<<"sandwich">>}
    1

## Breakdance/Breakdown

    redis_pool:start_link(Opts, PoolSize) -> ok | {error, Reason}
    redis_pool:start_link(Name, Opts, PoolSize) -> ok | {error, Reason}
    redis:start_link(Opts, PoolSize) -> ok | {error, Reason}
    redis:start_link(Name, Opts, PoolSize) -> ok | {error, Reason}
    
      Types:
        
        Name = atom()
        PoolSize = number()
        Options = [Opt]
        Opt = {atom(), Value}
        Value = term()

      Connects to redis server

      The available options are:

      {ip, Ip}

        If the host has several network interfaces, this option
        specifies which one to use.  Default is "127.0.0.1".

      {port, Port}

        Specify which local port number to use.  Default is 6379.

      {pass, Pass}

        Specify to password to auth with upon a successful connect.
        Default is <<>>.

      {db, DbIndex}

        Sepcify the db to use.  Default is 0.

      Name represents the name of the pool you are creating.
      
    redis_pool:info() -> term()
    redis_pool:info(Name) -> term()
    
      Types
      
        Name = atom()

      Returns the current state of the connection pool.
    
    redis_shard:start_link(Servers) -> ok | {error, Reason}
    redis_shard:start_link(Name, Servers) -> ok | {error, Reason}
    
      Types
      
        Servers = [Server]
        Server = term()
        Name = atom()

        Starts a shard manager that splits evenly an md5 interval
        across the given terms in order.
        
        The suggested way of using this is by having each Server be the
        name of a connection pool. But you can also store additional
        information. You'll however need to extract the label to the
        connection pool in order to access it.
    
    redis_shard:pool(Key) -> atom() | {error, Reason}
    redis_shard:pool(Name, Key) -> atom() | {error, Reason}
    
      Types
      
        Key = number() | list()
        Name = atom()
        
        Returns from the given shard the label that contains the
        specified key or index.
    
    redis_shard:update_shards(Servers) -> ok
    redis_shard:update_shards(Name, Servers) -> ok
    
      Types
      
        Servers = [Server]
        Server = term()
        Name = atom()
    
      Updates the initial configuration and redistributes the shards to
      new servers. No consistency checks are done at this point.

    redis_pool:q(Name, Parts) -> {ok, binary()} | {ok, int()} | {error, binary()}
    redis_pool:q(Name, Parts, Timeout) -> {ok, binary()} | {ok, int()} | {error, binary()}
    redis:q(Name, Parts) -> {ok, binary()} | {ok, int()} | {error, binary()}
    redis:q(Name, Parts, Timeout) -> {ok, binary()} | {ok, int()} | {error, binary()}

      Types

        Parts = [Part]

          The sections, in order, of the command to be executed

        Part = binary() | list()

          A section of a redis command

      Tell redis to execute a command.
      
        Name = atom()
        
          Execute a command in a specific pool of connections or a specific connection
        
        Timeout = number()
        
          Specify a timeout in ms after which the call can be considered
          failed and the connection can be recycled.

## LICENSE
Copyright (c) 2010 Jacob Vorreuter <jacob.vorreuter@gmail.com>  
Copyright (c) 2010 Blake Mizerany  <blake.mizerany@gmail.com>  
Copyright (c) 2010 Valentino Volonghi <valentino@adroll.com>  

Permission is hereby granted, free of charge, to any person  
obtaining a copy of this software and associated documentation  
files (the "Software"), to deal in the Software without  
restriction, including without limitation the rights to use,  
copy, modify, merge, publish, distribute, sublicense, and/or sell  
copies of the Software, and to permit persons to whom the  
Software is furnished to do so, subject to the following  
conditions:  

The above copyright notice and this permission notice shall be  
included in all copies or substantial portions of the Software.  

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,  
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES  
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND  
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT  
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,  
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING  
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR  
OTHER DEALINGS IN THE SOFTWARE.  
