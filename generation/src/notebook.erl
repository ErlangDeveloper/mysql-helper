%%%-------------------------------------------------------------------
%%% @author zhouwenhao
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%此文件为自动生成，请勿修改
%%% @end
%%% Auto Created : 2017-7-26 16:59:53
%%%-------------------------------------------------------------------
-module(notebook).
-export([init/1]).


init(TableName)->
	tablex_user_relationship:init_key(TableName),
	ok.
