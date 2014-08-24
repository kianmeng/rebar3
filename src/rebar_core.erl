%% -*- erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ts=4 sw=4 et
%% -------------------------------------------------------------------
%%
%% rebar: Erlang Build Tools
%%
%% Copyright (c) 2009 Dave Smith (dizzyd@dizzyd.com)
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
%% -------------------------------------------------------------------
-module(rebar_core).

-export([process_command/2]).

-include("rebar.hrl").

%% ===================================================================
%% Internal functions
%% ===================================================================

process_command(State, Command) ->
    true = rebar_utils:expand_code_path(),
    LibDirs = rebar_state:get(State, lib_dirs, ?DEFAULT_LIB_DIRS),
    DepsDir = rebar_state:get(State, deps_dir, ?DEFAULT_DEPS_DIRS),
    _UpdatedCodePaths = update_code_path([DepsDir | LibDirs]),
    rebar_prv_install_deps:setup_env(State),

    TargetProviders = rebar_provider:get_target_providers(Command, State),

    lists:foldl(fun(TargetProvider, Conf) ->
                        Provider = rebar_provider:get_provider(TargetProvider
                                                              ,rebar_state:providers(Conf)),
                        {ok, Conf1} = rebar_provider:do(Provider, Conf),
                        Conf1
                end, State, TargetProviders).

update_code_path([]) ->
    no_change;
update_code_path(Paths) ->
    LibPaths = expand_lib_dirs(Paths, rebar_utils:get_cwd(), []),
    ok = code:add_pathsa(LibPaths),
    %% track just the paths we added, so we can remove them without
    %% removing other paths added by this dep
    {added, LibPaths}.

expand_lib_dirs([], _Root, Acc) ->
    Acc;
expand_lib_dirs([Dir | Rest], Root, Acc) ->
    Apps = filelib:wildcard(filename:join([Dir, "*", "ebin"])),
    FqApps = case filename:pathtype(Dir) of
                 absolute -> Apps;
                 _        -> [filename:join([Root, A]) || A <- Apps]
             end,
    expand_lib_dirs(Rest, Root, Acc ++ FqApps).
