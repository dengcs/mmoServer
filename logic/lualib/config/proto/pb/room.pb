
è
src/room.protogame"÷
roomê
player
uid (	Ruid
nickname (	Rnickname
ulevel (Rulevel
vlevel (Rvlevel
stage (Rstage
skin (Rskina
member)
player (2.game.room.playerRplayer
teamid (Rteamid
state (RstateB
place
id (Rid)
member (2.game.room.memberRmemberê
detail
channel (Rchannel
roomid (Rroomid
owner (	Rowner
state (Rstate(
places (2.game.room.placeRplacesÄ
simple
channel (Rchannel
roomid (Rroomid
state (Rstate
mcount (Rmcount
number (Rnumber"'
room_create
channel (Rchannel"$
room_create_resp
ret (Rret"=
	room_join
channel (Rchannel
roomid (Rroomid""
room_join_resp
ret (Rret"'
room_qkjoin
channel (Rchannel"$
room_qkjoin_resp
ret (Rret"
	room_quit""
room_quit_resp
ret (Rret"%
room_change_owner
uid (	Ruid"*
room_change_owner_resp
ret (Rret"
room_invite
uid (	Ruid"$
room_invite_resp
ret (Rret"t
room_invite_notify
channel (Rchannel
roomid (Rroomid
uid (	Ruid
nickname (	Rnickname"#
	room_seek
roomid (Rroomid"C
room_seek_resp
ret (Rret
v (2.game.room.simpleRv"

room_start"#
room_start_resp
ret (Rret"
	room_stop""
room_stop_resp
ret (Rret"
room_return"$
room_return_resp
ret (Rret"5
room_append_notify
v (2.game.room.simpleRv"5
room_modify_notify
v (2.game.room.simpleRv"F
room_remove_notify
channel (Rchannel
roomid (Rroomid"_
channel_synchronize_notify
channel (Rchannel'
rooms (2.game.room.simpleRrooms":
room_synchronize_notify
v (2.game.room.detailRvbproto3