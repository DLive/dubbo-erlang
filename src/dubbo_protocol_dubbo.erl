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
-module(dubbo_protocol_dubbo).

-include("dubboerl.hrl").
-include("dubbo.hrl").

%% API
-export([refer/2,invoke/2,data_receive/1]).

refer(Url, Acc) ->
    {ok, UrlInfo} = dubbo_common_fun:parse_url(Url),
    case UrlInfo#dubbo_url.scheme of
        <<"dubbo">> ->
            {ok,Invoker} = do_refer(UrlInfo),
            {ok, Invoker};
        _ ->
            {skip, Acc}
    end.

do_refer(UrlInfo) ->
    case dubbo_node_config_util:parse_provider_info(UrlInfo) of
        {ok, ProviderConfig} ->
%%            OldHostList = dubbo_provider_consumer_reg_table:get_interface_provider_node(ProviderConfig#provider_config.interface),
            case getClients(ProviderConfig) of
                {ok, ConnectionInfoList} ->
                    dubbo_provider_consumer_reg_table:update_node_conections(ProviderConfig#provider_config.interface,ConnectionInfoList),
                    HostFlag = dubbo_provider_consumer_reg_table:get_host_flag(ProviderConfig),
                    {ok,#dubbo_invoker{host_flag = HostFlag,handle = ?MODULE}};
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, R1} ->
            logger:error("parse provider info error reason ~p", [R1]),
            {error, R1}
    end.

getClients(ProviderConfig) ->
    %% @todo if connections parameter > 1, need new spec transport
    case new_transport(ProviderConfig) of
        {ok, ConnectionInfoList} ->
%%            ConnectionList = start_provider_process(HostFlag, 30, ProviderConfig),
            {ok, ConnectionInfoList};
        {error, Reason} ->
            {error, Reason}
    end.


%%ok = update_connection_info(ProviderConfig#provider_config.interface, HostFlag, ConnectionList, true),


new_transport(ProviderConfig) ->

    HostFlag = get_host_flag(ProviderConfig),
    case dubbo_provider_consumer_reg_table:get_host_connections(ProviderConfig#provider_config) of
        [] ->
            case dubbo_exchanger:connect(ProviderConfig, ?MODULE) of
                {ok, ConnectionInfo} ->
                    {ok, [ConnectionInfo]};
                {error, Reason} ->
                    logger:warning("start client fail ~p ~p", [Reason, HostFlag]),
                    {error, Reason}
            end;
        ConnectionInfoList ->
            {ok, ConnectionInfoList}
    end.




invoke(#dubbo_rpc_invocation{source_pid = CallBackPid,transport_pid = TransportPid,call_ref = Ref} = Invocation,Acc) ->

%%    Request2 = merge_attachments(Request, RpcContext), %% @todo need add rpc context to attachment
    Request = dubbo_adapter:reference(Invocation),
    {ok, RequestData} = dubbo_codec:encode_request(Request),
    gen_server:cast(TransportPid, {send_request, Ref, Request, RequestData, CallBackPid, Invocation}),
    {ok,Invocation,Acc}.
%%    case is_sync(RequestState) of
%%        true ->
%%            sync_receive(Ref, get_timeout(RequestState));
%%        false -> {ok, Ref}
%%    end.



data_receive(Data)->
    <<Header:16/binary, RestData/binary>> = Data,
    case dubbo_codec:decode_header(Header) of
        {ok, response, ResponseInfo} ->
            process_response(ResponseInfo#dubbo_response.is_event, ResponseInfo, RestData),
            ok;
        {ok, request, RequestInfo} ->
            {ok, Req} = dubbo_codec:decode_request(RequestInfo, RestData),
            logger:info("get one request mid ~p, is_event ~p", [Req#dubbo_request.mid, Req#dubbo_request.is_event]),
            process_request(Req#dubbo_request.is_event, Req),
            ok;
        {error, Type, RelData} ->
            logger:error("process_data error type ~p RelData ~p", [Type, RelData]),
            ok
    end.


%% @doc process event
-spec process_response(IsEvent :: boolean(), #dubbo_response{}) -> ok.
process_response(false, ResponseInfo, RestData) ->
%%    dubbo_traffic_control:decr_count(State#state.host_flag),

    %% @todo traffic need move limit filter
    case get_earse_request_info(ResponseInfo#dubbo_response.mid) of
        undefined ->
            logger:error("dubbo response can't find request data,response ~p", [ResponseInfo]);
        {SourcePid, Ref, Invocation} ->
            {ok, Res} = dubbo_codec:decode_response(ResponseInfo, RestData),
            logger:info("got one response mid ~p, is_event ~p state ~p", [Res#dubbo_response.mid, Res#dubbo_response.is_event, Res#dubbo_response.state]),
            case Res#dubbo_response.is_event of
                false ->
                    %% @todo rpccontent need merge response with request
                    ResponseData = dubbo_type_transfer:response_to_native(Res),
                    dubbo_invoker:invoke_response(Invocation,ResponseData);
                _ ->
                    ok
            end
    end,
    ok;
process_response(true, _ResponseInfo, _RestData) ->
    ok.

process_request(true, #dubbo_request{data = <<"R">>}) ->
    {ok, _} = dubbo_provider_consumer_reg_table:update_connection_readonly(self(), true),
    ok;
process_request(true, Request) ->
    send_heartbeat_msg(Request#dubbo_request.mid, false),
    ok;
process_request(false, Request) ->
    ok.


get_earse_request_info(Mid) ->
    erase(Mid).