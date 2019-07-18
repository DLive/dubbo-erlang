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
-module(dubbo_service_config).

-include("dubbo.hrl").
-include("dubboerl.hrl").
%% API
-export([export/1]).

-spec(export(#provider_config{})->ok).
export(ProviderInfo)->
    ok.

do_export(ProviderInfo)->

    ok.

do_export_protocol(ProviderInfo)->
    get_registry_url(ProviderInfo),

    ok.




get_registry_url(ProviderInfo)->
    %% zookeeper://127.0.0.1:2181/org.apache.dubbo.registry.RegistryService?application=hello-world&dubbo=2.0.2&export=dubbo%3A%2F%2F127.0.0.1%3A20880%2Forg.apache.dubbo.erlang.sample.service.facade.UserOperator%3Fanyhost%3Dtrue%26application%3Dhello-world%26bean.name%3Dorg.apache.dubbo.erlang.sample.service.facade.UserOperator%26bind.ip%3D127.0.0.1%26bind.port%3D20880%26default.deprecated%3Dfalse%26default.dynamic%3Dfalse%26default.register%3Dtrue%26deprecated%3Dfalse%26dubbo%3D2.0.2%26dynamic%3Dfalse%26generic%3Dfalse%26interface%3Dorg.apache.dubbo.erlang.sample.service.facade.UserOperator%26methods%3DqueryUserInfo%2CqueryUserList%2CgenUserId%2CgetUserInfo%26pid%3D90956%26register%3Dtrue%26release%3D2.7.1%26side%3Dprovider%26timestamp%3D1562725983984&pid=90956&release=2.7.1&timestamp=1562725983974
    {Host,Port} = get_registry_host_port(),
    UrlInfo = #dubbo_url{
        scheme = <<"registry">>,
        host = list_to_binary(Host),
        port = Port,
        path = <<"org.apache.dubbo.registry.RegistryService">>,
        parameters = gen_registry_parameter(ProviderInfo)
    },
    dubbo_common_fun:url_to_binary(UrlInfo).

gen_registry_parameter(ProviderInfo)->
    Para = #{
        <<"application">> => ProviderInfo#provider_config.application,
        <<"dubbo">> => <<"2.0.2">>,
        <<"pid">> => list_to_binary(os:getpid()),
        <<"export">> => get_export_info(ProviderInfo),
        <<"registry">> => get_registry_type(),
        <<"release">> => <<"2.7.1">>,
        <<"timestamp">> => integer_to_binary(dubbo_time_util:timestamp_ms())
    },
    Para.

get_export_info(ProviderInfo)->
    %%dubbo://127.0.0.1:20880/org.apache.dubbo.erlang.sample.service.facade.UserOperator?
    %% anyhost=true&
    %% application=hello-world&
    %% bean.name=org.apache.dubbo.erlang.sample.service.facade.UserOperator&
    %% bind.ip=127.0.0.1&bind.port=20880&default.deprecated=false&
    %% default.dynamic=false&default.register=true&deprecated=false&dubbo=2.0.2&
    %% dynamic=false&generic=false&
    %% interface=org.apache.dubbo.erlang.sample.service.facade.UserOperator&
    %% methods=queryUserInfo,queryUserList,genUserId,getUserInfo&pid=90956&register=true&release=2.7.1&side=provider&timestamp=1562725983984
    Para =[
        {"anyhost","true"},
        {"application",ProviderInfo#provider_config.application},
        {"bean.name",ProviderInfo#provider_config.interface},
        {"bind.ip",dubbo_common_fun:local_ip_v4_str()},
        {"bind.port",ProviderInfo#provider_config.port},
        {"default.deprecated","false"},
        {"default.dynamic","false"},
        {"default.register","true"},
        {"deprecated","false"},
        {"dynamic","false"},
        {"generic","false"},
        {"interface",ProviderInfo#provider_config.interface},
        {"methods",string:join(ProviderInfo#provider_config.methods,",")},
        {"pid",os:getpid()},
        {"register","true"},
        {"release","2.7.1"},
        {"side","provider"},
        {"timestamp",integer_to_list(dubbo_time_util:timestamp_ms())}
    ],
    UrlInfo = #dubbo_url{
        scheme = <<"">>,
        host = dubbo_common_fun:local_ip_v4_str(),
        port = ProviderInfo#provider_config.port,
        path = ProviderInfo#provider_config.interface,
        parameters = Para
    },
    Url = dubbo_common_fun:url_to_binary(UrlInfo),
    list_to_binary(http_uri:encode(binary_to_list(Url))).
