% Bucket Broker
%
% needs:   bucket.erl, stats.erl
% used_by: queue.erl

-module(bucket_broker).
-behaviour(gen_server).
-include("kollekt.hrl").

-export([
  start/1, stop/0,
  lookup/1, create/2, update/2, remove/2,
  init/1,
  handle_call/3, handle_cast/2, handle_info/2,
  terminate/2, code_change/3
  ]).


start(_Args) ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

% caller
stop() ->
  gen_server:call(?MODULE, stop).

lookup(BucketId) ->
  gen_server:call(?MODULE, {search, BucketId}).
create(BucketId, Data) ->
  gen_server:call(?MODULE, {new,    BucketId, Data}).
update(BucketPid, Data) ->
  gen_server:call(?MODULE, {change, BucketPid, Data}).
remove(BucketId, Reason) ->
  gen_server:call(?MODULE, {delete, BucketId, Reason}).


init([]) ->
  {ok, ets:new(?MODULE,[set])}.


handle_call({search, BucketId}, _From, Table) ->
  Reply = ets:lookup(Table, BucketId),
  {reply, Reply, Table};

handle_call({new, BucketId, Data}, _From, Table) ->
  BucketPid = bucket:new(BucketId),
  ets:insert(Table, {BucketId, BucketPid}),
  call_bucket(BucketPid, Data),
  stats:incr({buckets, created}),
  Reply = ok,
  {reply, Reply, Table};

handle_call({change, BucketPid, Data}, _From, Table) ->
  call_bucket(BucketPid, Data),
  stats:incr({buckets, updated}),
  Reply = ok,
  {reply, Reply, Table};

handle_call({delete, BucketId, Reason}, _From, Table) ->
  ets:delete(Table, BucketId),
  stats:incr({buckets, removed, Reason}),
  Reply = ok,
  {reply, Reply, Table};

handle_call({undefined}, _From, Table) ->
  Reply = fail,
  {reply, Reply, Table}.


handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.


% helper

call_bucket(Pid, Data) ->
  Pid ! {data, Data}.
