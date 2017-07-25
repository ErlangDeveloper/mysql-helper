SET FOREIGN_KEY_CHECKS = 0;
-- ----------------------------
-- Table structure for `sl_user`.`user_relationship`
-- ----------------------------
DROP TABLE IF EXISTS `sl_user`.`user_relationship`;
CREATE TABLE `sl_user`.`user_relationship` (
	`uin` int(10) UNSIGNED NOT NULL  DEFAULT 0  COMMENT "玩家id",
	`refresh_time` int(10) UNSIGNED NOT NULL  DEFAULT 0  COMMENT "刷新时间",
	`refresh_cd` int(10) UNSIGNED NOT NULL  DEFAULT 0  COMMENT "刷新cd",
	`get_num` int(10) UNSIGNED NOT NULL  DEFAULT 0  COMMENT "领取次数",
	`supress_num` int(10) UNSIGNED NOT NULL  DEFAULT 0  COMMENT "除暴次数",
	`req_list` varchar(2048)  NOT NULL  DEFAULT ""  COMMENT "请求列表",
	`friends_list` varchar(2048)  NOT NULL  DEFAULT ""  COMMENT "好友列表",
	`black_list` varchar(2048)  NOT NULL  DEFAULT ""  COMMENT "黑名单",
	`broken_list` varchar(2048)  NOT NULL  DEFAULT ""  COMMENT "关系解除",
	PRIMARY KEY(`uin`)
) ENGINE = innodb DEFAULT CHARSET = utf8 COMMENT = "好友信息";

