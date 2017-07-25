%%%-------------------------------------------------------------------
%%% @author zhouwenhao
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%此文件为自动生成，请勿修改
%%% @end
%%% Auto Created : 2017-7-25 16:59:52
%%%-------------------------------------------------------------------
-module(tablex_user_relationship).
-include("table.hrl").

-define(DATABASE, "sl_user").

-define(ETS_NAME, ets_user_relationship).

%%数据库基本操作
-export([select/2, insert/1, update/1, update_fields/2, insert_or_update/1, delete/1]).

%%已封装好的对数据库的操作
-export([read/1, write/1, find/1, find/3, all/0]).

%%ETS数据表的操作接口
-export([init/1, asyn_load/4, ms_select/1, ms_select_count/1, ets_name/0]).

column_info()->
	[{uin,int},
         {refresh_time,int},
         {refresh_cd,int},
         {get_num,int},
         {supress_num,int},
         {req_list,term},
         {friends_list,term},
         {black_list,term},
         {broken_list,term}].

restore(DataList)->
	Record = list_to_tuple([user_relationship|DataList]),
	true = is_record(Record, user_relationship),
	Record.

where_condition_format(Conditions)->
    where_condition_format(Conditions, []).

where_condition_format([], Ret)->
	Ret;
where_condition_format([{Column, Con, Val}|Conditions], Ret)->
    where_condition_format(Conditions,[{Column, Con, {Val, get_column_datatype(Column)}} | Ret]).

get_column_datatype(Column)->
    proplists:get_value(Column, column_info()).


%%--------------------------------------------------------------------
%% @doc       查询操作
%% @args      FieldList = [id,name]   要查询的字段
%%                Conditions = [{power, '>', 5000}, {level, '>', 65}]   查询条件
%% @return  {ok, AllRows} | {ok, []}
%%--------------------------------------------------------------------
select(FieldList, Conditions)->
    FormatCond = where_condition_format(Conditions),
	Columns=string:join([atom_to_list(Key) || Key<-FieldList], ","),
	Where = sqlex:pack_where(FormatCond),
	Sql = "SELECT " ++ Columns ++ " FROM " ++ "user_relationship" ++ " " ++ Where,
	sqlex:select(Sql, column_info()).


%%--------------------------------------------------------------------
%% @doc		  插入操作
%% @args	  Record | RecordList   要插入的表结构
%% @return	  ok | error
%%--------------------------------------------------------------------
insert_value_list({user_relationship, Uin, Refresh_time, Refresh_cd, Get_num, Supress_num, Req_list, Friends_list, Black_list, Broken_list})->
	"("++ sqlex:pack_value_by_type({Uin,int}) ++ "," ++ sqlex:pack_value_by_type({Refresh_time,int}) ++ "," ++ sqlex:pack_value_by_type({Refresh_cd,int}) ++ "," ++ sqlex:pack_value_by_type({Get_num,int}) ++ "," ++ sqlex:pack_value_by_type({Supress_num,int}) ++ "," ++ sqlex:pack_value_by_type({Req_list,term}) ++ "," ++ sqlex:pack_value_by_type({Friends_list,term}) ++ "," ++ sqlex:pack_value_by_type({Black_list,term}) ++ "," ++ sqlex:pack_value_by_type({Broken_list,term}) ++")".
insert([])->
	error;
insert({user_relationship, Uin, Refresh_time, Refresh_cd, Get_num, Supress_num, Req_list, Friends_list, Black_list, Broken_list})->
	ValueSql = "(`uin`,`refresh_time`,`refresh_cd`,`get_num`,`supress_num`,`req_list`,`friends_list`,`black_list`,`broken_list`) VALUES " ++ insert_value_list({user_relationship, Uin, Refresh_time, Refresh_cd, Get_num, Supress_num, Req_list, Friends_list, Black_list, Broken_list}) ++ ";" ,
	Sql = "INSERT INTO " ++ "user_relationship" ++ " " ++ ValueSql,
	sqlex:insert(Sql);
insert(InsertList) when is_list(InsertList)->
	Sql = "INSERT INTO " ++ "user_relationship" ++ " " ++ pack_list(InsertList),
	sqlex:insert(Sql).
pack_list(InsertList)->
	SqlValueListString = [insert_value_list(X)||X<-InsertList],
	ValueString = string:join(SqlValueListString, ","),
	"(`uin`,`refresh_time`,`refresh_cd`,`get_num`,`supress_num`,`req_list`,`friends_list`,`black_list`,`broken_list`) VALUES "++ ValueString ++ ";".


%%--------------------------------------------------------------------
%% @doc		全纪录更新操作
%% @args	Record | RecordList   要更新的表结构
%% @return	ok | error
%%--------------------------------------------------------------------
update([])->
	error;
update({user_relationship, Uin, Refresh_time, Refresh_cd, Get_num, Supress_num, Req_list, Friends_list, Black_list, Broken_list})->
	Sql = "UPDATE user_relationship SET " ++ " `refresh_time`  = " ++ sqlex:pack_value_by_type({Refresh_time,int}) ++ "," " `refresh_cd`  = " ++ sqlex:pack_value_by_type({Refresh_cd,int}) ++ "," " `get_num`  = " ++ sqlex:pack_value_by_type({Get_num,int}) ++ "," " `supress_num`  = " ++ sqlex:pack_value_by_type({Supress_num,int}) ++ "," " `req_list`  = " ++ sqlex:pack_value_by_type({Req_list,term}) ++ "," " `friends_list`  = " ++ sqlex:pack_value_by_type({Friends_list,term}) ++ "," " `black_list`  = " ++ sqlex:pack_value_by_type({Black_list,term}) ++ "," " `broken_list`  = " ++ sqlex:pack_value_by_type({Broken_list,term}) ++  " WHERE" ++ " `uin`  = " ++ sqlex:pack_value_by_type({Uin,int}) ++  ";",
	sqlex:update(Sql);
update(UpdateList) when is_list(UpdateList)->
	Sql = "REPLACE INTO " ++ "user_relationship" ++ " " ++ pack_list(UpdateList),
	sqlex:update(Sql).


%%--------------------------------------------------------------------
%% @doc     纪录部分更新操作
%% @args	FieldValueList = [{id, Value}]   要更新的字段
%%              Conditions = [{power, '>', 5000}, {level, '>', 65}]   更新条件
%% @return	ok | error
%%--------------------------------------------------------------------
update_fields(FieldValueList, Conditions)->
    FormatCond = where_condition_format(Conditions),
	Columns=[{Key, '=', {Value, get_column_datatype(Key)}}||{Key, Value}<-FieldValueList],
	Sql = "UPDATE user_relationship  " ++ sqlex:pack_update_columns(Columns)++sqlex:pack_where(FormatCond),
	sqlex:update(Sql).


%%--------------------------------------------------------------------
%% @doc		插入或更新操作
%% @args	Record  要更新的表结构
%% @return	ok | error
%%--------------------------------------------------------------------
insert_or_update({user_relationship, Uin, Refresh_time, Refresh_cd, Get_num, Supress_num, Req_list, Friends_list, Black_list, Broken_list})->
	InsertSql = "(`uin`,`refresh_time`,`refresh_cd`,`get_num`,`supress_num`,`req_list`,`friends_list`,`black_list`,`broken_list`) VALUES " ++ insert_value_list({user_relationship, Uin, Refresh_time, Refresh_cd, Get_num, Supress_num, Req_list, Friends_list, Black_list, Broken_list}),
	Sql = "INSERT INTO " ++ "user_relationship" ++ InsertSql ++ "ON DUPLICATE KEY UPDATE" ++ " `refresh_time`  = " ++ sqlex:pack_value_by_type({Refresh_time,int}) ++ "," " `refresh_cd`  = " ++ sqlex:pack_value_by_type({Refresh_cd,int}) ++ "," " `get_num`  = " ++ sqlex:pack_value_by_type({Get_num,int}) ++ "," " `supress_num`  = " ++ sqlex:pack_value_by_type({Supress_num,int}) ++ "," " `req_list`  = " ++ sqlex:pack_value_by_type({Req_list,term}) ++ "," " `friends_list`  = " ++ sqlex:pack_value_by_type({Friends_list,term}) ++ "," " `black_list`  = " ++ sqlex:pack_value_by_type({Black_list,term}) ++ "," " `broken_list`  = " ++ sqlex:pack_value_by_type({Broken_list,term}) ++ ";",
	sqlex:insert(Sql).


%%--------------------------------------------------------------------
%% @doc       删除操作
%% @args	  Record 数据表结构
%%                Conditions = [{power, '>', 5000}, {level, '>', 65}]   删除条件
%% @return	  ok | error
%%--------------------------------------------------------------------
delete(_R = {user_relationship, Uin, _, _, _, _, _, _, _, _})when is_tuple(_R)->
	Sql = "DELETE FROM  user_relationship WHERE " ++ " `uin`  = " ++ sqlex:pack_value_by_type({Uin,int}) ++ ";",
	sqlex:delete(Sql);
delete(Conditions)when is_list(Conditions)->
	FormatCond = where_condition_format(Conditions),
	Sql = "DELETE FROM  user_relationship " ++ sqlex:pack_where(FormatCond) ++ ";",
    sqlex:delete(Sql).


%%--------------------------------------------------------------------
%% @doc      根据纪录读取
%% @args	 Record 数据表结构
%% @return	 [] | Record
%%--------------------------------------------------------------------
read_by_record(_R = {user_relationship, Uin, _, _, _, _, _, _, _, _})when is_record(_R, user_relationship)->
	Sql = "SELECT * FROM  user_relationship WHERE " ++ " `uin`  = " ++ sqlex:pack_value_by_type({Uin,int}) ++ ";",
	case sqlex:select(Sql, column_info()) of
		{ok,[]}->
			[];
		{ok,[RowList]}->
            restore(RowList)
	end.


%%--------------------------------------------------------------------
%% @doc		 读取操作(已封装)
%% @args	 Keys  主键
%% @return	 AllRows | []
%%--------------------------------------------------------------------
read(Uin)->
	Sql = "SELECT * FROM  user_relationship WHERE " ++ " `uin`  = " ++ sqlex:pack_value_by_type({Uin,int}) ++ ";",
	case sqlex:select(Sql, column_info()) of
		{ok,[]}->
			[];
		{ok,[RowList]}->
            restore(RowList)
	end.


%%--------------------------------------------------------------------
%% @doc		插入或更新操作(已封装)
%% @args	Record 要更新的表结构
%% @return	ok | error
%%--------------------------------------------------------------------
write(Record = #user_relationship{uin = undefined})->
	{ok, [[Max]]} = select(['max(`uin`)'], []),
	Key = sqlex:get_key(Max),
	insert(Record#user_relationship{uin = Key}),
	Key;
		
write(Record)when is_record(Record, user_relationship)->
    case read_by_record(Record) of
		[] ->
			insert(Record);
		_Any ->
			update(Record)
	end.


%%--------------------------------------------------------------------
%% @doc		 查找操作,默认(已封装)
%% @args	 Conditions = [{power, '>', 5000}, {level, '>', 65}]   查询条件
%% @return	 AllRows | []
%%--------------------------------------------------------------------
find(Conditions)->
	find(Conditions, undefined, undefined).


%%--------------------------------------------------------------------
%% @doc		查找操作(已封装)
%% @args    Conditions = [{power, '>', 5000}, {level, '>', 65}]    查询条件
%%              Limit = {0,100} | {5, 20},                                          分页
%%              OrderBy = {hpmax, asc} | {hpmax, desc},                排序
%% @return	AllRows | []
%%--------------------------------------------------------------------
find(Conditions, Limit, OrderBy)->
    FormatCond = where_condition_format(Conditions),
	Sql =  "SELECT * FROM  user_relationship  "
			++ sqlex:pack_where(FormatCond)
			++ sqlex:pack_orderby(OrderBy)
			++ sqlex:pack_limit(Limit),
	case sqlex:select(Sql, column_info()) of
		{ok,RowList}->
			[restore(X)||X<-RowList];
		_->
			[]
	end.


%%--------------------------------------------------------------------
%% @doc		    Gat all rows
%% @return	    {ok, AllRows} | Error
%%--------------------------------------------------------------------
all()->
	select(['*'], []).


%%--------------------------------------------------------------------
%% @doc         初始化数据库表对应的ETS表
%%--------------------------------------------------------------------
init(Options)->
	?ETS_NAME = ets:new(?ETS_NAME, [set, named_table, protected, {keypos, 2}]),
	asyn_load(0, 100, self(), Options).


%%--------------------------------------------------------------------
%% @doc 异步载入表数据, 需要在调用进程处理{apply, Fun, Args}消息
%%  proc_msg({apply, Function, Args}, StateName, State)->
%%	apply(Function, Args),
%%  {StateName, State, ok};
%%--------------------------------------------------------------------
asyn_load(LMin, LMax, LPid, Options)->
	PageSize = LMax - LMin,
	Conditions = proplists:get_value(conditions, Options, []),
	Num =
		case find(Conditions, {LMin, LMax}, undefined) of
			[] ->
				0;
			RowList->
				F1 = fun(List)-> [ets:insert(?ETS_NAME, X)||X<-List] end,
				CallBack = proplists:get_value(callback, Options, F1),
				LPid ! {apply, CallBack, [RowList]},
				length(RowList)
		end,
	case Num >= PageSize of
		true ->
			F2 = fun()-> ?MODULE:asyn_load(LMin + PageSize, LMax + PageSize, LPid, Options)end,
			LPid ! {apply, F2, []};
		_ ->
			CompleteCallBack = proplists:get_value(complete_callback, Options, skip),
			case is_function(CompleteCallBack) of
				true ->
					LPid ! {apply, CompleteCallBack, []};
				_V ->
					_V
			end
	end.


%%--------------------------------------------------------------------
%% @doc         ETS API
%%--------------------------------------------------------------------
ets_name()->
	?ETS_NAME.

ms_select(Ms)->
	ets:select(?ETS_NAME, Ms).

ms_select_count(Ms)->
	ets:select_count(?ETS_NAME, Ms).	