if not _P then
	print "dcs----error"
	return
end

local command = _P.lua.conf

if command then
	print "has command"
else
	print "not command"
end

local my_inject = require "inject_test"

if my_inject then
	print "has inject"
	if my_inject.dcs_test then
		print "has test"
	end
end

if command.CMD.deliver_uids_mail then
	command.CMD.deliver_uids_mail = my_inject.dcs_test
	print "has function"
else
	print "not function"
end

print "inject ok"
