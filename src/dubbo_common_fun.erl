%%------------------------------------------------------------------------------
%% Licensed to the Apache Software Foundation (ASF) under one or more
%% contributor license agreements.  See the NOTICE file distributed with
%% this work for additional information regarding copyright ownership.
%% The ASF licenses this file to You under the Apache License, Version 2.0
%% (the "License"); you may not use this file except in compliance with
%% the License.  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%------------------------------------------------------------------------------
-module(dubbo_common_fun).

-include("dubboerl.hrl").
%% API
-export([local_ip_v4/0, local_ip_v4_str/0, parse_url/1, url_to_binary/1,parse_url_parameter/1]).

local_ip_v4() ->
    {ok, Addrs} = inet:getifaddrs(),
    hd([
        Addr || {_, Opts} <- Addrs, {addr, Addr} <- Opts,
        size(Addr) == 4, Addr =/= {127, 0, 0, 1}
    ]).

local_ip_v4_str() ->
    {V1, V2, V3, V4} = local_ip_v4(),
    list_to_binary(io_lib:format("~p.~p.~p.~p", [V1, V2, V3, V4])).


-spec(parse_url(Url :: binary()|list()) -> {ok, #dubbo_url{}}).
parse_url(Url) when is_binary(Url) ->
    parse_url(binary_to_list(Url));
parse_url(Url) ->
    case http_uri:parse(Url, []) of
        {ok, {Scheme, _UserInfo, Host, Port, _Path, Query}} ->
            QueryStr = case lists:prefix("?", Query) of
                           true ->
                               [_ | Query2] = Query,
                               Query2;
                           false ->
                               Query
                       end,
            Parameters = parse_url_parameter(QueryStr),
            Result = #dubbo_url{
                scheme = atom_to_binary(Scheme,utf8),
                host = list_to_binary(Host),
                port = Port,
                parameters = Parameters
            },
            {ok, Result};
        {error, R1} ->
            {error, R1}
    end.


parse_url_parameter(ParameterStr) when is_binary(ParameterStr) ->
    parse_url_parameter(binary_to_list(ParameterStr));
parse_url_parameter(ParameterStr)->
    QueryListTmp = string:tokens(ParameterStr, "&"),
    parse_url_parameter(QueryListTmp,#{}).

parse_url_parameter([], Parameters) ->
    Parameters;
parse_url_parameter([Item | Rest], Parameters) ->
    case string:tokens(Item, "=") of
        KeyPair when length(KeyPair) == 2 ->
            [Key, Value] = KeyPair,
            parse_url_parameter(Rest, maps:put(list_to_binary(Key), list_to_binary(Value), Parameters));
        KeyPair2 ->
            logger:error("parse parameter error, keypair ~p", [KeyPair2]),
            parse_url_parameter(Rest, Parameters)
    end.


url_to_binary(UrlInfo) ->
    ParameterStr =
        case UrlInfo#dubbo_url.parameters of
            undefined ->
                "";
            Parameter ->
                KeyValues = maps:to_list(Parameter),
                KeyValues2 = [io_lib:format("~s=~s", [Key, Value]) || {Key, Value} <- KeyValues],
                ParameterStr1 = string:join(KeyValues2, "&"),
                ParameterStr1
        end,
    Value = lists:flatten(io_lib:format(<<"~s://~s:~p/~s?~s">>,
        [
            UrlInfo#dubbo_url.scheme,
            UrlInfo#dubbo_url.host,
            UrlInfo#dubbo_url.port,
            UrlInfo#dubbo_url.path,
            ParameterStr
        ])),
    list_to_binary(Value).