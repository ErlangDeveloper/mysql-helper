%%%-------------------------------------------------------------------
%%% @author deadr
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 23. 五月 2017 14:25
%%%-------------------------------------------------------------------
-module(sqlex).
-author("baymaxzhou").

%% @todo include mysql hrl

%% API
-export([select/2, insert/1, update/1, delete/1]).
-export([pack_value_by_type/1, pack_where/1, pack_limit/1, pack_orderby/1, unpack_row/2, pack_update_columns/1, pack_value/1]).
-export([get_key/1]).
%%%===================================================================
%%% 数据库基本操作
%%%===================================================================
select(Sql, Info)->
	DataBase = cache_data:get_sql_name(),
	case fetch(Sql, DataBase) of
		{ok, ColumnName, Result} ->
			AtomColumnName = [dd_util:to_atom(X)||X<-ColumnName],
			Zip = [lists:zip(AtomColumnName, X)||X<-Result],
			UnPack = unpack(Info, Zip, []),
			{ok, UnPack};
		_Other ->
			error
	end.

insert(Sql)->
	DataBase = cache_data:get_sql_name(),
	case fetch(Sql, DataBase) of
		ok ->
			ok;
		_Other ->
			error
	end.

update(Sql)->
	DataBase = cache_data:get_sql_name(),
	case fetch(Sql, DataBase) of
		ok ->
			ok;
		_Other ->
			error
	end.

delete(Sql)->
	DataBase = cache_data:get_sql_name(),
	case fetch(Sql, DataBase) of
		ok ->
			ok;
		_Other ->
			error
	end.

fetch(Sql, Databse)->
%% @todo excute sql 
%%	case cache_util:fetch(Databse, Sql) of
%%		{data, #mysql_result{fieldinfo = Fieldinfo, rows = List}}->
%%			{ok, [X||{_, X, _, _}<-Fieldinfo], List};
%%		{updated, #mysql_result{affectedrows = _Rows}}->
%%			ok;
%%		_N ->
%%			error
%%	end.
	todo.

%%example
get_key(undefined)->
	{success, ServerId} = dd_config:get_cfg(serverid),
	ServerId * 10000000 + 1;
get_key(TableName)->
	[Key] = ets:update_counter(ets_table_autoIncrement_key, TableName, [{2, 1}]),
	Key.

%%%===================================================================
%%% SqlHelper
%%% 辅助拼接Sql函数
%%%===================================================================
unpack(_, [], List)->
	lists:reverse(List);

unpack(Info, [Head|Tail], List)->
	Handle = fun({Column, Value})->
		case  proplists:get_value(Column, Info) of
			tinyint -> Value;
			smallint -> Value;
			int -> Value;		
			mediumint -> Value;
			bigint -> Value;
			
			float -> Value;
			double ->Value;
			
			char -> binary_to_list(Value);
			varchar -> binary_to_list(Value);
			
			tinyblob -> Value;
			blob -> binary_to_term(Value);
			mediumblob -> Value;
			
			term -> {ok, Term} = util:string_to_term(binary_to_list(Value)), Term;
			termc -> {ok, Term} = util:string_to_term(binary_to_list(Value)), Term;
			termb ->binary_to_term(Value);
			_ -> Value
		end
	end,
	T = [Handle(X)||X<-Head],
	unpack(Info, Tail, [T|List]).


pack_update_columns(Columns)->
	KV = pack_kv(Columns, []),
	case length(KV) of
		0 ->
			"";
		_Any ->
			" SET "++string:join(KV, ", ")
	end.

pack_where(Conditions)->
	Sql = pack_kv(Conditions, []),
	case length(Sql) of
		0 ->
			"";
		_Any ->
			" WHERE "++string:join(Sql, " AND ")
	end.

pack_kv([], Sql)->
	lists:reverse(Sql);
pack_kv([{ColumeName,'=',Value}|Tail], Sql)->
	New = atom_to_list(ColumeName)++"="++pack_value_by_type(Value),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName,'!=',Value}|Tail], Sql)->
	New = atom_to_list(ColumeName)++"!="++pack_value_by_type(Value),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName, '>', Value}|Tail], Sql) ->
	New = atom_to_list(ColumeName)++">"++pack_value_by_type(Value),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName, '<', Value}|Tail], Sql) ->
	New = atom_to_list(ColumeName)++"<"++pack_value_by_type(Value),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName, '>=', Value}|Tail], Sql) ->
	New = atom_to_list(ColumeName)++">="++pack_value_by_type(Value),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName, '<=', Value}|Tail], Sql) ->
	New = atom_to_list(ColumeName)++"<="++pack_value_by_type(Value),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName, in, {Value, Type}}|Tail], Sql) when is_list(Value) ->
	New = atom_to_list(ColumeName)++" IN "++pack_set_by_type({Value, Type}),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName, not_in, {Value, Type}}|Tail], Sql) when is_list(Value) ->
	New = atom_to_list(ColumeName)++" NOT IN "++pack_set_by_type({Value, Type}),
	pack_kv(Tail, [New|Sql]);
pack_kv([{ColumeName, like, Value}|Tail], Sql) ->
	New = atom_to_list(ColumeName)++" like "++pack_value_by_type(Value),
	pack_kv(Tail, [New|Sql]).

pack_set_by_type({Values, _Type}) ->
	"(" ++ string:join(lists:map(fun pack_value/1, Values), ", ") ++ ")".

pack_value_by_type({Val,_Type}) when is_binary(Val)->
	pack_value(Val);
pack_value_by_type({Val,blob})->
	pack_value(term_to_binary(Val));
pack_value_by_type({Val,term})->
	pack_value(util:term_to_string(Val));
pack_value_by_type({Val,termc})->
	pack_value(util:term_to_string(Val));
pack_value_by_type({Val,termb})->
	pack_value(term_to_binary(Val));
pack_value_by_type({Val,Type}) when Type==time ->
	pack_time(Val);
pack_value_by_type({Val,_Type})->
	pack_value(Val).

pack_value(undefined) ->
	"null";
pack_value(true) ->
	"TRUE";
pack_value(false) ->
	"FALSE";
pack_value(Val) when is_atom(Val) ->
	pack_value(atom_to_list(Val));
pack_value(Val) when is_integer(Val) ->
	integer_to_list(Val);
pack_value(Val) when is_float(Val) ->
	float_to_list(Val);
pack_value({MegaSec, Sec, MicroSec}) when is_integer(MegaSec) andalso is_integer(Sec) andalso is_integer(MicroSec) ->
	pack_datetime({MegaSec, Sec, MicroSec});
pack_value({{_, _, _}, {_, _, _}} = Val) ->
	pack_datetime(Val);
pack_value(V) when is_binary(V) ->
	quote(binary_to_list(V));
pack_value(V) when is_list(V)->%string
	quote(V).

pack_time(undefined) ->
	"null";
pack_time({0, 0, 0}) ->
	"'00:00:00'";
pack_time({H, M, S}) ->
	[format_time(X)||X<-[H,M,S]].

pack_datetime(undefined)->
	"null";
pack_datetime(0)->
	"null";
pack_datetime({0,0,0})->
	"'0000-00-00 00:00:00'";
pack_datetime({{Y,M,D},{H,I,S}})->
	[format_time(X)||X<-[Y,M,D,H,I,S]];
pack_datetime({_,_,_}=Now)->
	{{Y,M,D},{H,I,S}} =calendar:now_to_local_time(Now),
	"'" ++ string:join([format_time(X)||X<-[Y,M,D]], "-") ++ " " ++ string:join([format_time(X)||X<-[H,I,S]], ":") ++ "'".

format_time(Val) when Val < 10 ->
	"0" ++ integer_to_list(Val);
format_time(Val) ->
	integer_to_list(Val).

pack_limit(undefined)->
	"";
pack_limit(Limit) when is_integer(Limit)->
	" LIMIT 0,"++integer_to_list(Limit);
pack_limit({From, Count})->
	" LIMIT "++integer_to_list(From)++","++integer_to_list(Count).

pack_orderby(undefined)->
	"";
pack_orderby({Column, asc})->
	" ORDER BY "++atom_to_list(Column)++" ASC";
pack_orderby({Column, desc})->
	" ORDER BY "++atom_to_list(Column)++" DESC".

unpack_row(Module, RowColumnDataList)->
	list_to_tuple([Module|RowColumnDataList]).

%%  Quote a string or binary value so that it can be included safely in a
%%  MySQL query.
quote(String) when is_list(String) ->
	[39 | lists:reverse([39 | quote(String, [])])];	%% 39 is $'
quote(Bin) when is_binary(Bin) ->
	list_to_binary(quote(binary_to_list(Bin))).

quote([], Acc) ->
	Acc;
quote([0 | Rest], Acc) ->
	quote(Rest, [$0, $\\ | Acc]);
quote([10 | Rest], Acc) ->
	quote(Rest, [$n, $\\ | Acc]);
quote([13 | Rest], Acc) ->
	quote(Rest, [$r, $\\ | Acc]);
quote([$\\ | Rest], Acc) ->
	quote(Rest, [$\\ , $\\ | Acc]);
quote([39 | Rest], Acc) ->		%% 39 is $'
	quote(Rest, [39, $\\ | Acc]);	%% 39 is $'
quote([34 | Rest], Acc) ->		%% 34 is $"
	quote(Rest, [34, $\\ | Acc]);	%% 34 is $"
quote([26 | Rest], Acc) ->
	quote(Rest, [$Z, $\\ | Acc]);
quote([C | Rest], Acc) ->
	quote(Rest, [C | Acc]).
