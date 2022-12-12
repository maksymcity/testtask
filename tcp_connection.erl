-module(tcp_connection).
-behaviour(gen_statem).

-export([start/2,stop/0, client/2]).
-export([terminate/3,code_change/4,init/1,callback_mode/0]).
-export([establish_connect/3, waiting_data/3]).

name() -> tcp_connection.

start(LPort, Monitor) ->
    gen_statem:start({local,name()}, ?MODULE, [LPort], []),
    gen_statem:cast(?MODULE, [{LPort, [], Monitor}]).

stop() ->
    gen_statem:stop(name()).

terminate(_Reason, _State, _Data) ->
    io:format("terminate::~n",[]),
    void.
code_change(_Vsn, State, Data, _Extra) ->
    {ok,State,Data}.
init([LPort]) ->
    io:format("init:~p~n",[LPort]),
    {ok, establish_connect, LPort}.
callback_mode() -> state_functions.

%%% state callback(s)

establish_connect(cast, [{LPort, _, Monitor}], _) ->
    io:format("establish_connect:~p~n",[LPort]),
    case gen_tcp:listen(LPort, [{active, false}, {packet, 0}]) of
        {ok, ListenSock} ->
            if Monitor ->
                io:format("ListenSock:~p~n",[ListenSock]);
               true -> ok
            end,
      %      reading_data(ListenSock),
            gen_statem:cast(?MODULE, [{LPort, ListenSock, Monitor}]),
            {next_state, waiting_data, {LPort, ListenSock, Monitor}, [{state_timeout,10000,timeout}]};
        Error ->
            io:format("Error:~p~n",[Error]),
            timer:sleep(10000),
            gen_statem:cast(?MODULE, [{LPort, [], Monitor}]),
            {next_state, establish_connect, {LPort, [], Monitor}, [{state_timeout,10000,timeout}]}
    end;
establish_connect(_, _, _) ->
    io:format("establish_connect state_timeout:~n", []).

waiting_data(state_timeout, timeout,  {LPort, ListenSock, Monitor}) ->
    io:format("state_timeout:~p~n", [ListenSock]),
    {next_state, waiting_data, {LPort, ListenSock, Monitor}};
waiting_data(cast, _, {LPort, ListenSock, Monitor}) ->
    reading_data(ListenSock),
    {next_state, establish_connect, {LPort, ListenSock, Monitor}}.
    
reading_data(LSock) ->
    case gen_tcp:accept(LSock, 1000*60) of
        {ok, Sock} ->
            {ok, R} = do_recv(Sock, []),
            io:format("Data:~p~n", [binary_to_list(R)]),
            reading_data(LSock);
        {error, timeout} ->
            io:format("No data during one minute.~n", []),
            reading_data(LSock);
        {error, Reason} ->
            io:format("Error, reason:~p~n", [Reason])
    end.

do_recv(Sock, Bs) ->
    case gen_tcp:recv(Sock, 0) of
        {ok, B} ->
            do_recv(Sock, [Bs, B]);
        {error, closed} ->
            {ok, list_to_binary(Bs)}
    end.



client(PortNo,Message) ->
    {ok,Sock} = gen_tcp:connect("localhost",PortNo,[{active,false},
                                                    {packet,2}]),
    gen_tcp:send(Sock,Message),
    gen_tcp:close(Sock),
    ok.