%%%-------------------------------------------------------------------
%%% @author deadr
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 12. 五月 2016 17:36
%%%-------------------------------------------------------------------
-module(sql_version).
-author("baymaxzhou").

%% API
-export([make/0]).

-define(
HEAD,
"%%%-------------------------------------------------------------------
%%% @author zhouwenhao
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%~s
%%% @end
%%% Auto Created : ~s
%%%-------------------------------------------------------------------
-module(~s)."
).
-define(UNICODE2LIST(A), binary_to_list(unicode:characters_to_binary(A))).
-define(IF(C, T, F), (case (C) of true -> (T); false -> (F) end)).
-define(IFDO(C, T),(case (C) of true -> (T); false -> skip end)).

-record(table, {database, table_name, engine, character_set, comment, columns,  option}).
-record(column, {column_name, data_type, data_length, default, key, not_null, unsigned, comment}).

make()->
	{ok, [{table_config, ConfigPath}, {sqlfile, SqlPath}, {history_version, HistoryPath}, {schema, SchemaPath}, {hrl, HrlPath}, {ex, ProtoErlPath}]}
		= file:consult(lists:concat([?MODULE, ".config"])),

	%%列出配置文件列表
	{ok, Filelist} = file:list_dir_all(ConfigPath),
	%%筛选配置文件并获取文件内容
	FileContents = lists:merge([Z||{ok, Z}<-[file:consult(ConfigPath ++ lists:reverse(Y))||Y ="gifnoc" ++ _<-[lists:reverse(X)||X<-Filelist]]]),

	%%列出版本列表
	{ok, DirList} = file:list_dir_all(HistoryPath),
	%%最高版本号
	LastCode =
		case DirList of
			[] ->
				0;
			_ ->
				lists:max([list_to_integer(Code)||"Ver."++ Code <-DirList])
		end,

	%%1.生成全局sql
	io:format("1.Make Global Sql... ~n"),
	generation_sql(FileContents, SqlPath),

	%%2.比较配置文件，生成升级sql
	io:format("2.Make Update Sql... ~n"),
	?IFDO(LastCode > 0, compare(FileContents, HistoryPath, LastCode, SchemaPath)),

	%%3.生成hrl
	io:format("3.Make Hrl... ~n"),
	generation_hrl(FileContents, HrlPath),

	%%4.生成工具化的erl文件
	io:format("4.Make Erl Tool... ~n"),
	generation_erl(FileContents,ProtoErlPath),

	%%5.备份配置文件
	io:format("5.BackUp Old Config... ~n"),
	backup_history_version(ConfigPath, HistoryPath, Filelist, LastCode, SqlPath, SchemaPath),

	halt().

generation_sql(FileContents, SqlPath)->
	file:delete(SqlPath),
	{ok, SqlFd} = file:open(SqlPath, [write,append]),
	lists:map(
		fun(Table)->
			String = create_table_statement(Table),
			io:format(SqlFd, "~s~n", [String])
		end,
		FileContents),
	file:close(SqlFd),
	ok.

compare(FileContents, HistoryPath, LastCode, SchemaPath)->
	file:delete(SchemaPath),
	{ok, SchemaFd} = file:open(SchemaPath, [write,append]),

	LastVerPath =  lists:concat([HistoryPath, "Ver.", LastCode, "/"]),

	%%列出上一版本配置文件列表
	{ok, LastVerFileList} = file:list_dir_all(LastVerPath),
	%%筛选一版本配置文件内容
	LastVerFileContents = lists:merge([Z||{ok, Z}<-[file:consult(LastVerPath ++ lists:reverse(Y))||Y ="gifnoc" ++ _<-[lists:reverse(X)||X<-LastVerFileList]]]),

	lists:map(
		fun(T = #table{database = DB, table_name = TableName})->
			case [X||X = #table{database = XX, table_name = YY}<-LastVerFileContents, XX =:= DB, YY =:= TableName] of
				[]->
					String = create_table_statement(T),
					io:format(SchemaFd, "~s~n", [String]);
				[OldT]->
					if
						T =:= OldT ->
							skip;
						true ->
							case T#table.engine =:= OldT#table.engine andalso T#table.character_set =:= OldT#table.character_set andalso T#table.comment =:= OldT#table.comment of
								true ->
									skip;
								_ ->
									TableAlert =
										io_lib:format("ALTER TABLE `~p`.`~p`", [DB, TableName]) ++
										?IF(T#table.engine =/= OldT#table.engine, io_lib:format("ENGINE = ~p", [T#table.engine]), "") ++
										?IF(T#table.character_set =/= OldT#table.character_set, io_lib:format("CHARSET = ~p", [T#table.character_set]), "") ++
										?IF(T#table.comment =/= OldT#table.comment, io_lib:format("COMMENT = ~c~s~c", [$", ?UNICODE2LIST(T#table.comment), $"]), "") ++
										";\n",
									io:format(SchemaFd, "~s~n", [TableAlert])
							end,
							case T#table.columns =:= OldT#table.columns of
								true ->
									skip;
								_ ->
									%%生成升级sql
									lists:map(
										fun(NewColumn = #column{column_name = A, data_type = B, data_length = C, unsigned = D, not_null = E, default = F, comment = G})->
											case lists:keyfind(A, #column.column_name, OldT#table.columns) of
												false ->
													%%ALTER TABLE `frame_user_data`.`test` ADD COLUMN `cl` INT(10) UNSIGNED DEFAULT 0 NULL COMMENT 'test' AFTER `id`;
													[Before, After] = find_after_or_before(T#table.columns, A, []),
													AddColumn =
														io_lib:format("ALTER TABLE `~p`.`~p` ADD COLUMN ", [DB, TableName]) ++
														io_lib:format("`~p` ~p~s ~s ~s  ~s  COMMENT ~c~s~c", [A,
															?IF(B =:= term, varchar, B),
															?IF(C =:= 0, "", io_lib:format("(~p)", [C])),
															?IF(D, "UNSIGNED", ""), ?IF(E, "NOT NULL", "NULL"),
															?IF(is_blob(B), "", "DEFAULT " ++ ?UNICODE2LIST(?IF(F =:= "", "\"\"", F))), $", ?UNICODE2LIST(G), $"]) ++
														if After =/= null -> io_lib:format(" AFTER `~p`", [After]); Before =/= null -> io_lib:format("BEFORE `~p`", [Before]); true -> "" end ++ ";\n",
													io:format(SchemaFd, "~s~n", [AddColumn]);
												NewColumn ->
													skip;
												_ ->
													%%ALTER TABLE `frame_user_data`.`test` CHANGE `cl` `cl` BIGINT(15) DEFAULT 0 NULL COMMENT 'b';
													AlertColumn =
														io_lib:format("ALTER TABLE `~p`.`~p` CHANGE `~p` `~p` ~p~s ~s ~s  ~s  COMMENT ~c~s~c;\n",
															[DB, TableName, A, A, ?IF(B =:= term, varchar, B),
																?IF(C =:= 0, "", io_lib:format("(~p)", [C])),
																?IF(D, "UNSIGNED", ""), ?IF(E, "NOT NULL", "NULL"), ?IF(is_blob(B), "", "DEFAULT " ++ ?UNICODE2LIST(?IF(F =:= "", "\"\"", F))), $", ?UNICODE2LIST(G), $"]),
													io:format(SchemaFd, "~s~n", [AlertColumn])
											end
										end, T#table.columns),
									lists:map(
										fun(#column{column_name = A})->
											case lists:keyfind(A, #column.column_name, T#table.columns) of
												false ->
													%%ALTER TABLE `frame_user_data`.`test` DROP COLUMN `cl`;
													DropColumn =
														io_lib:format("ALTER TABLE `~p`.`~p` DROP COLUMN `~p`", [DB, TableName, A]),
													io:format(SchemaFd, "~s~n", [DropColumn]);
												_ ->
													skip
											end
										end
										,OldT#table.columns)
							end
					end
			end
		end,
		FileContents),
	file:close(SchemaFd),
	ok.

generation_hrl(FileContents, HrlPath)->
	file:delete(HrlPath),
	{ok, HrlFd} = file:open(HrlPath, [write,append]),

	lists:map(fun(#table{table_name = TableName, comment = TableComment, columns = Columns})->
		io:format(HrlFd, "%%~s ~s ~n-record(~s, {~s}).~n~n",
			[?UNICODE2LIST(TableComment),
				string:join([lists:concat([X#column.column_name, " = ", ?IF(X#column.default =:= "", "\"\"", X#column.default)," :: ", ?UNICODE2LIST(X#column.comment)])||X<-Columns], ", "),
				TableName,
				string:join([lists:concat([X#column.column_name, " = ",
					?IF(X#column.default =:= "", "\"\"", X#column.default),
					" :: ",
					case X#column.data_type of
						int ->
							"integer()";
						smallint ->
							"integer()";
						tinyint->
							"integer()";
						mediumint ->
							"integer()";
						bigint ->
							"integer()";
						term->
							"term()";
						varchar ->
							"string()";
						Other ->
							"term()"
					end])||X<- Columns], ", ")])

	end, FileContents),
	file:close(HrlFd).



generation_erl(FileContents,ProtoErlPath)->
	ToolErlPath = lists:concat([ProtoErlPath, "notebook.erl"]),
	file:delete(ToolErlPath),
	{ok, ToolErlFd} = file:open(ToolErlPath, [write, append]),
	io:format(ToolErlFd, ?HEAD, [?UNICODE2LIST("此文件为自动生成，请勿修改"), time_to_local_string(unixtime()), "notebook"]),
	io:format(ToolErlFd, "\n-export([init/1]).\n", []),
	io:format(ToolErlFd, "\n\ninit(TableName)->", []),
	
	lists:map(fun(#table{table_name = TableName, columns = Columns, database = DataBase, option = Option})->
		io:format("Table ~p is being processed...~n", [TableName]),
		FilePath = lists:concat([ProtoErlPath, tablex_, TableName, ".erl"]),
		file:delete(FilePath),
		{ok, Fd} = file:open(FilePath, [write, append]),

		ColumNames = [A||#column{column_name = A}<-Columns],
		ColumInfo = [{A,B}||#column{column_name = A, data_type = B}<-Columns],
		KeyColumnInfo =  [{A,B}||#column{column_name = A, data_type = B, key = true}<-Columns],
		OtherColumnInfo =  [{A,B}||#column{column_name = A, data_type = B, key = false}<-Columns],
		AutoIncrement = proplists:get_value(auto_increment, Option, false),
		[{MainKeyName, _}|_] = KeyColumnInfo,
		ModuleName = lists:concat([tablex_, TableName]),

		%%1.写入文件头
		io:format(Fd, ?HEAD, [?UNICODE2LIST("此文件为自动生成，请勿修改"), time_to_local_string(unixtime()), ModuleName]),
		io:format(Fd, "\n-include(\"table.hrl\").\n", []),
		io:format(Fd, "\n-define(DATABASE, \"~p\").\n", [DataBase]),
		io:format(Fd, "\n-define(ETS_NAME, ~s).\n", [lists:concat([ets_, TableName])]),
		io:format(Fd, "\n%%~s", [?UNICODE2LIST("数据库基本操作")]),
		io:format(Fd, "\n-export([select/2, insert/1, update/1, update_fields/2, insert_or_update/1, delete/1]).\n", []),
		io:format(Fd, "\n%%~s", [?UNICODE2LIST("已封装好的对数据库的操作")]),
		io:format(Fd, "\n-export([read/~p, write/1, find/1, find/3, all/0]).\n", [length(KeyColumnInfo)]),
		io:format(Fd, "\n%%~s", [?UNICODE2LIST("ETS数据表的操作接口")]),
		io:format(Fd, "\n-export([init/1, asyn_load/4," ++ case AutoIncrement of false -> "" ; true -> " init_key/1," end ++ " ms_select/1, ms_select_count/1, ets_name/0]).\n", []),
		
		case AutoIncrement of
			false ->
				skip;
			true ->
				io:format(ToolErlFd, "\n\t~s:init_key(TableName),", [ModuleName])
		end,

		%%2.写入列的数据类型，将据此做数据转换
		io:format(Fd, "\ncolumn_info()->\n\t~p.\n", [ColumInfo]),


		%%3.查询操作
		A31 = ?UNICODE2LIST("查询操作"),
		A32 = ?UNICODE2LIST("要查询的字段"),
		A33 = ?UNICODE2LIST("查询条件"),
		io:format(Fd, "
restore(DataList)->
	Record = list_to_tuple([~p|DataList]),
	true = is_record(Record, ~p),
	Record.\n\n", [TableName, TableName]),

		io:format(Fd,
"where_condition_format(Conditions)->
    where_condition_format(Conditions, []).

where_condition_format([], Ret)->
	Ret;
where_condition_format([{Column, Con, Val}|Conditions], Ret)->
    where_condition_format(Conditions,[{Column, Con, {Val, get_column_datatype(Column)}} | Ret]).

get_column_datatype(Column)->
    proplists:get_value(Column, column_info()).


%%--------------------------------------------------------------------
%% @doc       ~s
%% @args      FieldList = [id,name]   ~s
%%                Conditions = [{power, '>', 5000}, {level, '>', 65}]   ~s
%% @return  {ok, AllRows} | {ok, []}
%%--------------------------------------------------------------------
select(FieldList, Conditions)->
    FormatCond = where_condition_format(Conditions),
	Columns=string:join([atom_to_list(Key) || Key<-FieldList], \",\"),
	Where = sqlex:pack_where(FormatCond),
	Sql = \"SELECT \" ++ Columns ++ \" FROM \" ++ \"~p\" ++ \" \" ++ Where,
	sqlex:select(Sql, column_info()).\n\n",
			[A31, A32, A33, TableName]),

		%%4.插入操作
		A41 = ?UNICODE2LIST("插入操作"),
		A42 = ?UNICODE2LIST(" 要插入的表结构"),
		A43 = string:join([atom_to_list(TableName)|[words_up(X)||X<-ColumNames]], ", "),
		A44 = string:join([lists:concat(["`", X, "`"])||X<-ColumNames], ","),
		%%全列
		A45 = string:join([io_lib:format("++ sqlex:pack_value_by_type({~s,~p}) ++", [words_up(X), Y])||{X, Y}<-ColumInfo], " \",\" "),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		  ~s
%% @args	  Record | RecordList  ~s
%% @return	  ok | error
%%--------------------------------------------------------------------
insert_value_list({~s})->
	\"(\"~s\")\".
insert([])->
	error;
insert({~s})->
	ValueSql = \"(~s) VALUES \" ++ insert_value_list({~s}) ++ \";\" ,
	Sql = \"INSERT INTO \" ++ \"~p\" ++ \" \" ++ ValueSql,
	sqlex:insert(Sql);
insert(InsertList) when is_list(InsertList)->
	Sql = \"INSERT INTO \" ++ \"~p\" ++ \" \" ++ pack_list(InsertList),
	sqlex:insert(Sql).
pack_list(InsertList)->
	SqlValueListString = [insert_value_list(X)||X<-InsertList],
	ValueString = string:join(SqlValueListString, \",\"),
	\"(~s) VALUES \"++ ValueString ++ \";\".\n\n",
			[A41, A42, A43, A45, A43, A44, A43, TableName, TableName, A44]),

		%%5.更新操作
		A51 = ?UNICODE2LIST("全纪录更新操作"),
		A52 = ?UNICODE2LIST("要更新的表结构"),
		A53 =  string:join([io_lib:format("\" `~p`  = \" ++ sqlex:pack_value_by_type({~s,~p}) ++", [X, words_up(X), Y])||{X, Y}<-OtherColumnInfo], " \",\" "),
		A54 =  string:join([io_lib:format("\" `~p`  = \" ++ sqlex:pack_value_by_type({~s,~p}) ++", [X, words_up(X), Y])||{X, Y}<-KeyColumnInfo], " \" AND \" "),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		~s
%% @args	Record | RecordList   ~s
%% @return	ok | error
%%--------------------------------------------------------------------
update([])->
	error;
update({~s})->
	Sql = \"UPDATE ~p SET \" ++ ~s  \" WHERE\" ++ ~s  \";\",
	sqlex:update(Sql);
update(UpdateList) when is_list(UpdateList)->
	Sql = \"REPLACE INTO \" ++ \"~p\" ++ \" \" ++ pack_list(UpdateList),
	sqlex:update(Sql).\n\n", [A51, A52, A43, TableName, A53, A54, TableName]),

		%%6.部分更新操作
		A61 = ?UNICODE2LIST("纪录部分更新操作"),
		A62 = ?UNICODE2LIST("要更新的字段"),
		A63 = ?UNICODE2LIST("更新条件"),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc     ~s
%% @args	FieldValueList = [{id, Value}]   ~s
%%              Conditions = [{power, '>', 5000}, {level, '>', 65}]   ~s
%% @return	ok | error
%%--------------------------------------------------------------------
update_fields(FieldValueList, Conditions)->
    FormatCond = where_condition_format(Conditions),
	Columns=[{Key, '=', {Value, get_column_datatype(Key)}}||{Key, Value}<-FieldValueList],
	Sql = \"UPDATE ~p  \" ++ sqlex:pack_update_columns(Columns)++sqlex:pack_where(FormatCond),
	sqlex:update(Sql).\n\n", [A61, A62, A63, TableName]),

		%%7.插入或更新操作
		A71 = ?UNICODE2LIST("插入或更新操作"),
		A72 = ?UNICODE2LIST("要更新的表结构"),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		~s
%% @args	Record  ~s
%% @return	ok | error
%%--------------------------------------------------------------------
insert_or_update({~s})->
	InsertSql = \"(~s) VALUES \" ++ insert_value_list({~s}),
	Sql = \"INSERT INTO \" ++ \"~p\" ++ InsertSql ++ \"ON DUPLICATE KEY UPDATE\" ++ ~s \";\",
	sqlex:insert(Sql).\n\n", [A71, A72, A43, A44, A43, TableName, A53]),

		%%8.删除操作
		A81 = ?UNICODE2LIST("删除操作"),
		A82 = ?UNICODE2LIST("数据表结构"),
		A83 = ?UNICODE2LIST("删除条件"),
		A84 = string:join([atom_to_list(TableName)|[case K of true -> words_up(X); _ -> "_" end||#column{column_name = X, key = K}<-Columns]], ", "),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc       ~s
%% @args	  Record ~s
%%                Conditions = [{power, '>', 5000}, {level, '>', 65}]   ~s
%% @return	  ok | error
%%--------------------------------------------------------------------
delete(_R = {~s})when is_tuple(_R)->
	Sql = \"DELETE FROM  ~p WHERE \" ++ ~s \";\",
	sqlex:delete(Sql);
delete(Conditions)when is_list(Conditions)->
	FormatCond = where_condition_format(Conditions),
	Sql = \"DELETE FROM  ~p \" ++ sqlex:pack_where(FormatCond) ++ \";\",
    sqlex:delete(Sql).\n\n", [A81, A82, A83, A84, TableName, A54, TableName]),

		%%9.根据纪录读取
		A91 = ?UNICODE2LIST("根据纪录读取"),
		A92 = ?UNICODE2LIST("数据表结构"),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc      ~s
%% @args	 Record ~s
%% @return	 [] | Record
%%--------------------------------------------------------------------
read_by_record(_R = {~s})when is_record(_R, ~p)->
	Sql = \"SELECT * FROM  ~p WHERE \" ++ ~s \";\",
	case sqlex:select(Sql, column_info()) of
		{ok,[]}->
			[];
		{ok,[RowList]}->
            restore(RowList)
	end.\n\n", [A91, A92, A84, TableName, TableName, A54]),

		%%10.读取操作(已封装)
		B11 = ?UNICODE2LIST("读取操作(已封装)"),
		B12 = ?UNICODE2LIST("主键"),
		B13 = string:join([words_up(X)||{X, _}<-KeyColumnInfo], ","),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		 ~s
%% @args	 Keys  ~s
%% @return	 AllRows | []
%%--------------------------------------------------------------------
read(~s)->
	Sql = \"SELECT * FROM  ~p WHERE \" ++ ~s \";\",
	case sqlex:select(Sql, column_info()) of
		{ok,[]}->
			[];
		{ok,[RowList]}->
            restore(RowList)
	end.\n\n", [B11, B12, B13, TableName, A54]),

		%%11.插入或更新操作(已封装)
		B21 = ?UNICODE2LIST("插入或更新操作(已封装)"),
		B22 = ?UNICODE2LIST("要更新的表结构"),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		~s
%% @args	Record ~s
%% @return	ok | error
%%--------------------------------------------------------------------", [B21, B22]),
		case AutoIncrement of
			false->
				skip;
			_ ->
				io:format(Fd, "
write(Record = #~p{~p = undefined})->
	Key = sqlex:get_key(?MODULE),
	insert(Record#~p{~p = Key}),
	Key;~n		",
				[TableName, MainKeyName, TableName, MainKeyName])
		end,
		io:format(Fd, "
write(Record)when is_record(Record, ~p)->
    case read_by_record(Record) of
		[] ->
			insert(Record);
		_Any ->
			update(Record)
	end.\n\n", [TableName]),

		%%12.查找操作,默认(已封装)
		B31 = ?UNICODE2LIST("查找操作,默认(已封装)"),
		B32 = ?UNICODE2LIST("查询条件"),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		 ~s
%% @args	 Conditions = [{power, '>', 5000}, {level, '>', 65}]   ~s
%% @return	 AllRows | []
%%--------------------------------------------------------------------
find(Conditions)->
	find(Conditions, undefined, undefined).\n\n", [B31, B32]),

		%%13.查找操作(已封装)
		B41 = ?UNICODE2LIST("查找操作(已封装)"),
		B42 = ?UNICODE2LIST("分页"),
		B43 = ?UNICODE2LIST("排序"),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		~s
%% @args    Conditions = [{power, '>', 5000}, {level, '>', 65}]    ~s
%%              Limit = {0,100} | {5, 20},                                          ~s
%%              OrderBy = {hpmax, asc} | {hpmax, desc},                ~s
%% @return	AllRows | []
%%--------------------------------------------------------------------
find(Conditions, Limit, OrderBy)->
    FormatCond = where_condition_format(Conditions),
	Sql =  \"SELECT * FROM  ~p  \"
			++ sqlex:pack_where(FormatCond)
			++ sqlex:pack_orderby(OrderBy)
			++ sqlex:pack_limit(Limit),
	case sqlex:select(Sql, column_info()) of
		{ok,RowList}->
			[restore(X)||X<-RowList];
		_->
			[]
	end.\n\n", [B41, B32, B42, B43, TableName]),

		%%14.取全表
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc		    Gat all rows
%% @return	    {ok, AllRows} | Error
%%--------------------------------------------------------------------
all()->
	select(['*'], []).\n\n", []),

		%%15.初始化数据库表对应的ETS表
		B51 = ?UNICODE2LIST("初始化数据库表对应的ETS表"),
		B52_PER = proplists:get_value(permissions, Option, protected),
		B53 = indexOf(MainKeyName, ColumNames) + 1,
		B54_SIZE = proplists:get_value(pagesize, Option, 2000),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc         ~s
%%--------------------------------------------------------------------
init(Options)->
	?ETS_NAME = ets:new(?ETS_NAME, [set, named_table, ~p, {keypos, ~p}]),
	asyn_load(0, ~p, self(), Options).\n\n", [B51, B52_PER, B53, B54_SIZE]),

		%%16.异步载入表数据
		B61 =?UNICODE2LIST("异步载入表数据, 需要在调用进程处理{apply, Fun, Args}消息"),
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc ~s
%%  proc_msg({apply, Function, Args}, StateName, State)->
%%	apply(Function, Args),
%%  {StateName, State, ok};
%%--------------------------------------------------------------------
asyn_load(LMin, PageSize , LPid, Options)->
	Conditions = proplists:get_value(conditions, Options, []),
	Num =
		case find(Conditions, {LMin, PageSize}, undefined) of
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
			F2 = fun()-> ?MODULE:asyn_load(LMin + PageSize, PageSize, LPid, Options)end,
			LPid ! {apply, F2, []};
		_ ->
			CompleteCallBack = proplists:get_value(complete_callback, Options, skip),
			case is_function(CompleteCallBack) of
				true ->
					LPid ! {apply, CompleteCallBack, []};
				_V ->
					_V
			end
	end.\n\n", [B61]),
		
		
		case AutoIncrement of
			false->
				skip;
			_ ->
				io:format(Fd, "~n
%%--------------------------------------------------------------------
%% @doc     Init AutoIncrement Key
%%--------------------------------------------------------------------
init_key(KeyTableName)->
	case ?MODULE:select(['max(`~p`)'], []) of
		{ok, [[undefined]]} ->
			ets:insert(KeyTableName, {?MODULE, sqlex:get_key(undefined)});
		{ok, [[Max]]} ->
			ets:insert(KeyTableName, {?MODULE, Max})
	end,
	ok.~n		", [MainKeyName])
		end,

		%%ETS Api
		io:format(Fd, "
%%--------------------------------------------------------------------
%% @doc     ETS API
%%--------------------------------------------------------------------
ets_name()->
	?ETS_NAME.

ms_select(Ms)->
	ets:select(?ETS_NAME, Ms).

ms_select_count(Ms)->
	ets:select_count(?ETS_NAME, Ms).	", [])


	end, FileContents),
	io:format(ToolErlFd, "\n\tok.\n", []),
	file:close(ToolErlFd),
	ok.


backup_history_version(ConfigPath, HistoryPath, Filelist, LastCode, SqlPath, SchemaPath)->
	VerCode = LastCode + 1,
	BackupPath = lists:concat([HistoryPath, "Ver.", VerCode, "/"]),
	ok = file:make_dir(BackupPath),
	MoveList = [{ConfigPath ++ lists:reverse(Y), BackupPath ++ lists:reverse(Y)}||Y ="gifnoc" ++ _<-[lists:reverse(X)||X<-Filelist]],
	lists:map(fun({OriFile, NewFile})->
		{ok, Bin} = file:read_file(OriFile),
		ok = file:write_file(NewFile, Bin)
	end,MoveList),
	{ok, Sql} = file:read_file(SqlPath),
	file:write_file(BackupPath ++ "table.sql", Sql),
	{ok, Sc} = file:read_file(SchemaPath),
	file:write_file(BackupPath ++ "schema.sql", Sc),
	ok.

unixtime() ->
	{MegaSecs, Secs, _MicroSecs} = os:timestamp(),
	MegaSecs * 1000000 + Secs.

time_to_local_string(Time)->
	{{Year, Month , Day}, {Hour, Minute, Second}} = calendar:now_to_local_time(s_to_now(Time)),
	lists:concat([Year, "-", Month, "-", Day, " ", Hour, ":", Minute, ":", Second]).

s_to_now(S)->
	{S div 1000000, S rem 1000000, 0}.

words_up(X) when is_atom(X)->
	words_up(atom_to_list(X));
words_up([H|T])->
	string:to_upper([H]) ++ T.


find_after_or_before([#column{column_name = Name}|[]], Name, List)->
	[null|List];
find_after_or_before([#column{column_name = Name}, #column{column_name = Before}|_Tail], Name, List)->
	[Before|?IF(List =:= [], null, List)];
find_after_or_before([#column{column_name = Temp}|Tail], Name, _List)->
	find_after_or_before(Tail, Name, [Temp]).

%%搜索列表中的项，并返回项的索引位置。
indexOf(Value, Lists)->
	indexOf(Lists, Value, 1).
indexOf([], _, _)->
	-1;
indexOf([Head|Tail], Value, Index)->
	case Head of
		Value -> Index;
		_ -> indexOf(Tail, Value, Index + 1)
	end.

create_table_statement(#table{database = DB, table_name = TableName, engine = Engine, character_set = CharSet, comment = TableComment, columns = Columns})->
	ColumnsTemp =
		string:join([io_lib:format("\t`~p` ~p~s ~s ~s  ~s  COMMENT ~c~s~c",
			[
				A,
				?IF(B =:= term, varchar, B),
				?IF(C =:= 0, "", io_lib:format("(~p)", [C])),
				?IF(D, "UNSIGNED", ""),
				?IF(E, "NOT NULL", "NULL"),
				?IF(is_blob(B), "", "DEFAULT " ++ ?UNICODE2LIST(?IF(F =:= "", "\"\"", F))),
				$", ?UNICODE2LIST(G), $"
			])
			||
			#column{column_name = A, data_type = B, data_length = C, unsigned = D, not_null = E, default = F, comment = G}<-Columns], ",\n"),

	[PRIMARY_KEY|OTHER_KEY] = [ColumnName||#column{column_name = ColumnName, key = true}<-Columns],
	KeyTemp = string:join([io_lib:format("\tPRIMARY KEY(`~p`)", [PRIMARY_KEY])|[io_lib:format("\tKEY ~p(`~p`)", [X, X])||X<-OTHER_KEY]], ",\n"),

	"SET FOREIGN_KEY_CHECKS = 0;\n" ++
		"-- ----------------------------\n" ++
		io_lib:format("-- Table structure for `~p`.`~p`\n", [DB, TableName]) ++
		"-- ----------------------------\n" ++
		io_lib:format("DROP TABLE IF EXISTS `~p`.`~p`;\n", [DB, TableName]) ++
		io_lib:format("CREATE TABLE `~p`.`~p` (\n", [DB, TableName]) ++
		ColumnsTemp ++ ",\n" ++
		KeyTemp ++ "\n" ++
		io_lib:format(") ENGINE = ~p DEFAULT CHARSET = ~p COMMENT = ~c~s~c;\n", [Engine, CharSet, $", ?UNICODE2LIST(TableComment), $"]).


is_blob(blob)->
	true;
is_blob(tinyblob )->
	true;
is_blob(mediumblob )->
	true;
is_blob(longblob )->
	true;
is_blob(_ )->
	false.
