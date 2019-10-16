local inject = {}

function inject.dcs_test(uids)
	if not uids then
        print("param error")
        return
    end

    for _, v in pairs(uids) do
		print("dcs---"..v)
    end
end

return inject

