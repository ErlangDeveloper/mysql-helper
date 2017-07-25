%%好友信息 uin = 0 :: 玩家id, refresh_time = 0 :: 刷新时间, refresh_cd = 0 :: 刷新cd, get_num = 0 :: 领取次数, supress_num = 0 :: 除暴次数, req_list = "" :: 请求列表, friends_list = "" :: 好友列表, black_list = "" :: 黑名单, broken_list = "" :: 关系解除 
-record(user_relationship, {uin = 0 :: integer(), refresh_time = 0 :: integer(), refresh_cd = 0 :: integer(), get_num = 0 :: integer(), supress_num = 0 :: integer(), req_list = "" :: term(), friends_list = "" :: term(), black_list = "" :: term(), broken_list = "" :: term()}).

