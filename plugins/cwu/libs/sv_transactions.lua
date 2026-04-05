function PLUGIN:LogTransaction(data)
	local transactions = ix.data.Get("cwuTransactions", {})

	data.time = data.time or os.time()
	transactions[#transactions + 1] = data

	local maxTransactions = ix.config.Get("cwuMaxTransactions", 500)

	while (#transactions > maxTransactions) do
		table.remove(transactions, 1)
	end

	ix.data.Set("cwuTransactions", transactions)
end

function PLUGIN:GetTransactions()
	return ix.data.Get("cwuTransactions", {})
end

function PLUGIN:GetTreasury()
	return ix.data.Get("cwuTreasury", 0)
end

function PLUGIN:AddTreasury(amount)
	local treasury = self:GetTreasury()
	ix.data.Set("cwuTreasury", treasury + amount)
end

function PLUGIN:WithdrawTreasury(amount)
	local treasury = self:GetTreasury()

	if (amount > treasury) then
		return false
	end

	ix.data.Set("cwuTreasury", treasury - amount)
	return true
end
