%%% -*- coding: utf-8; Mode: erlang; tab-width: 4; c-basic-offset: 4; indent-tabs-mode: nil -*-
%%% ex: set softtabstop=4 tabstop=4 shiftwidth=4 expandtab fileencoding=utf-8:
%%%
%%%------------------------------------------------------------------------
%%% @doc
%%% ==CPG Tests==
%%% @end
%%%
%%% BSD LICENSE
%%% 
%%% Copyright (c) 2013, Michael Truog <mjtruog at gmail dot com>
%%% All rights reserved.
%%% 
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are met:
%%% 
%%%     * Redistributions of source code must retain the above copyright
%%%       notice, this list of conditions and the following disclaimer.
%%%     * Redistributions in binary form must reproduce the above copyright
%%%       notice, this list of conditions and the following disclaimer in
%%%       the documentation and/or other materials provided with the
%%%       distribution.
%%%     * All advertising materials mentioning features or use of this
%%%       software must display the following acknowledgment:
%%%         This product includes software developed by Michael Truog
%%%     * The name of the author may not be used to endorse or promote
%%%       products derived from this software without specific prior
%%%       written permission
%%% 
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
%%% CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
%%% INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
%%% OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%%% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
%%% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
%%% WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%%% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
%%% DAMAGE.
%%%
%%% @author Michael Truog <mjtruog [at] gmail (dot) com>
%%% @copyright 2013 Michael Truog
%%% @version 1.2.2 {@date} {@time}
%%%------------------------------------------------------------------------

-module(cpg_test).

-author('mjtruog [at] gmail (dot) com').

-include_lib("eunit/include/eunit.hrl").

cpg_start_test() ->
    ok = reltool_util:application_start(cpg).

via1_test() ->
    {ok, Pid} = cpg_test_server:start_link("message"),
    % OTP behaviors require that the process group have only a single process
    {error, {already_started, Pid}} = cpg_test_server:start_link("message"),
    ok = cpg_test_server:put("message", "Hello World!"),
    "Hello World!" = cpg_test_server:get("message"),
    erlang:unlink(Pid),
    erlang:exit(Pid, kill),
    ok.

via2_test() ->
    {ok, Pid} = cpg_test_server:start_link("error"),
    erlang:unlink(Pid),
    error = gen_server:call({via, cpg, "error"}, undefined_call),
    false = is_process_alive(Pid),
    ok.

via3_test() ->
    ViaName = {"local group", 4},
    {ok, Pid1} = cpg_test_server:start_link(ViaName),
    {ok, Pid2} = cpg_test_server:start_link(ViaName),
    {ok, Pid3} = cpg_test_server:start_link(ViaName),
    {ok, Pid4} = cpg_test_server:start_link(ViaName),
    Pids = [Pid1, Pid2, Pid3, Pid4],
    I1 = index(cpg_test_server:pid(ViaName), Pids),
    true = is_integer(I1),
    I2 = index(cpg_test_server:pid(ViaName), Pids),
    true = is_integer(I2),
    I3 = index(cpg_test_server:pid(ViaName), Pids),
    true = is_integer(I3),
    I4 = index(cpg_test_server:pid(ViaName), Pids),
    true = is_integer(I4),
    I5 = index(cpg_test_server:pid(ViaName), Pids),
    true = is_integer(I4),
    true = (I1 /= I2 orelse I1 /= I3 orelse I1 /= I4 orelse I1 /= I5),
    erlang:unlink(Pid1),
    erlang:exit(Pid1, kill),
    erlang:unlink(Pid2),
    erlang:exit(Pid2, kill),
    erlang:unlink(Pid3),
    erlang:exit(Pid3, kill),
    erlang:unlink(Pid4),
    erlang:exit(Pid4, kill),
    ok.

pid_age_test() ->
    Pid1 = erlang:spawn(fun busy_pid/0),
    Pid2 = erlang:spawn(fun busy_pid/0),
    Pid3 = erlang:spawn(fun busy_pid/0),
    ok = cpg:join("GroupA", Pid1),
    ok = cpg:join("GroupA", Pid2),
    ok = cpg:join("GroupA", Pid3),
    ok = cpg:join("GroupA", Pid1),
    ok = cpg:join("GroupA", Pid2),
    {ok, "GroupA", Pid2} = cpg:get_newest_pid("GroupA"),
    {ok, "GroupA", Pid1} = cpg:get_newest_pid("GroupA", Pid2),
    {ok, "GroupA", Pid1} = cpg:get_oldest_pid("GroupA"),
    {ok, "GroupA", Pid2} = cpg:get_oldest_pid("GroupA", Pid1),
    erlang:exit(Pid1, kill),
    timer:sleep(1000),
    {ok, "GroupA", Pid3} = cpg:get_oldest_pid("GroupA", Pid2),
    {ok, "GroupA", Pid3} = cpg:get_newest_pid("GroupA", Pid2),
    erlang:exit(Pid2, kill),
    erlang:exit(Pid3, kill),
    ok.

cpg_stop_test() ->
    ok = reltool_util:application_stop(cpg).

busy_pid() ->
    timer:sleep(1000),
    busy_pid().

index(Item, List) ->
    index(Item, List, 1).
index(_, [], _) ->
    not_found;
index(Item, [Item|_], Index) ->
    Index;
index(Item, [_|Tl], Index) ->
    index(Item, Tl, Index + 1).

