%% SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
%% analgapes :: metacognition/consciousness/swarm_formation_bridge.erl
%% Distributed coordination current (影). A gen_server that registers swarm
%% instances and relays formation vectors between them. Swarm coordination is
%% Erlang's native domain: instances are processes, relays are messages.
-module(swarm_formation_bridge).
-behaviour(gen_server).
-export([start_link/0, register_instance/1, relay/2, instances/0, stop/0]).
-export([init/1, handle_call/3, handle_cast/2]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
register_instance(Id) -> gen_server:call(?MODULE, {register, Id}).
relay(From, Vec) -> gen_server:cast(?MODULE, {relay, From, Vec}).
instances() -> gen_server:call(?MODULE, instances).
stop() -> gen_server:stop(?MODULE).

init([]) -> {ok, #{instances => [], relays => 0}}.

handle_call({register, Id}, _From, S = #{instances := Is}) ->
    {reply, ok, S#{instances := lists:usort([Id | Is])}};
handle_call(instances, _From, S = #{instances := Is}) ->
    {reply, Is, S};
handle_call(relay_count, _From, S = #{relays := R}) ->
    {reply, R, S}.

handle_cast({relay, _From, _Vec}, S = #{relays := R}) ->
    {noreply, S#{relays := R + 1}}.
