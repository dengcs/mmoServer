local nova = require "nova"
local tblDeepClone = table.deep_clone

local inject = {}

function inject.dcs_test(uids, mail)
	if not uids or not mail then
        print("param error")
        return
    end

    for _, v in pairs(uids) do
		print("dcs---"..v)
		local cpMail = tblDeepClone(mail,true)
		nova.send(GLOBAL.WS_NAME.MAILD, "lua", "deliver_mail",v, cpMail)
    end
end

return inject

