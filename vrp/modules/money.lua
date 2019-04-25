local lang = vRP.lang

MySQL.createCommand("vRP/money_tables", [[
CREATE TABLE IF NOT EXISTS vrp_user_moneys(
  user_id INTEGER,
  wallet INTEGER,
  bank INTEGER,
  code INT(4) NOT NULL DEFAULT '0000',
  CONSTRAINT pk_user_moneys PRIMARY KEY(user_id),
  CONSTRAINT fk_user_moneys_users FOREIGN KEY(user_id) REFERENCES vrp_users(id) ON DELETE CASCADE
);
]])

MySQL.createCommand("vRP/money_init_user","INSERT IGNORE INTO vrp_user_moneys(user_id,wallet,bank) VALUES(@user_id,@wallet,@bank)")
MySQL.createCommand("vRP/get_money","SELECT wallet,bank FROM vrp_user_moneys WHERE user_id = @user_id")
MySQL.createCommand("vRP/set_money","UPDATE vrp_user_moneys SET wallet = @wallet, bank = @bank WHERE user_id = @user_id")

-- init tables
MySQL.execute("vRP/money_tables")

-- load config
local cfg = module("cfg/money")

-- API

-- get money
-- cbreturn nil if error
function vRP.getMoney(user_id)
  local tmp = vRP.getUserTmpTable(user_id)
  if tmp then
    return tmp.wallet or 0
  else
    return 0
  end
end

-- set money
function vRP.setMoney(user_id,value)
	value = tonumber(math.ceil(value))
	local tmp = vRP.getUserTmpTable(user_id)
	if tmp then
		tmp.wallet = value
	end

	-- update client display
	local source = vRP.getUserSource(user_id)
	if source ~= nil then
		vRPclient.setDivContent(source,{"money",lang.money.display({vRP.formatThousand(value)})})
	end
end

-- try a payment
-- return true or false (debited if true)
function vRP.tryPayment(user_id,amount)
	amount = parseInt(math.ceil(amount))
	if amount == 0 then return true end
	local money = vRP.getMoney(user_id)
	if money >= amount then
		local total = money-amount
		if total >= 0 and total < 9999999999 then
			local money = vRP.getMoney(user_id)
			vRP.setMoney(user_id,total)
			return true
		else
			return false
		end
	else
		return false
	end
end

function vRP.tryDoPayment(user_id,amount)
	amount = parseInt(math.ceil(amount))
	if amount == 0 then return true end
	local money = vRP.getMoney(user_id)
	if money >= amount then
		local total = money-amount
		if total >= 0 and total < 9999999999 then
			return true
		else
			return false
		end
	else
		return false
	end
end

-- give money
function vRP.giveMoney(user_id,amount)
	amount = math.ceil(tonumber(amount))
	if amount == nil then
		return false
	else
		if amount >= 0 and amount < 9999999999 then
			local money = vRP.getMoney(user_id)
			local total = money+amount
			vRP.setMoney(user_id,total)
			return true
		else
			return false
		end
	end
end

-- get bank money
function vRP.getBankMoney(user_id)
  local tmp = vRP.getUserTmpTable(user_id)
  if tmp then
    return tmp.bank
  else
    return 0
  end
end

-- set bank money
function vRP.setBankMoney(user_id,value)
  value = tonumber(math.ceil(value))
  local tmp = vRP.getUserTmpTable(user_id)
  if tmp then
    tmp.bank = value
  end
  local source = vRP.getUserSource(user_id)
  if source ~= nil then
    vRPclient.setDivContent(source,{"bmoney",lang.money.bdisplay({vRP.formatThousand(tonumber(value))})})
  end
end

-- give bank money
function vRP.giveBankMoney(user_id,amount)
	amount = tonumber(amount)
	local moneyhb = vRP.getMoney(user_id)
    local money = vRP.getBankMoney(user_id)
	vRP.setBankMoney(user_id,money+amount)
end

-- try a withdraw
-- return true or false (withdrawn if true)
function vRP.tryWithdraw(user_id,amount)
  amount = tonumber(math.ceil(amount))
  local money = vRP.getBankMoney(user_id)
  if amount > 0 and money >= amount then
	local moneyhb = vRP.getMoney(user_id)
	local moneybb = vRP.getBankMoney(user_id)
    vRP.setBankMoney(user_id,money-amount)
    vRP.giveMoney(user_id,amount)
    return true
  else
    return false
  end
end

-- try a deposit
-- return true or false (deposited if true)
function vRP.tryDeposit(user_id,amount)
  amount = tonumber(math.ceil(amount))
  if amount > 0 and vRP.tryPayment(user_id,amount) then
	local moneyb = vRP.getBankMoney(user_id)
    vRP.giveBankMoney(user_id,amount)
    return true
  else
    return false
  end
end

function vRP.tryFullDeposit(user_id,amount)
  amount = tonumber(math.ceil(amount))
  if amount > 0 and vRP.tryDoPayment(user_id,amount) then
	local moneyb = vRP.getBankMoney(user_id)
    vRP.giveBankMoney(user_id,amount)
    return true
  else
    return false
  end
end

-- try full payment (wallet + bank to complete payment)
-- return true or false (debited if true)
function vRP.tryFullPayment(user_id,amount)
	local pr = tonumber(amount)
	local flr = math.floor(pr)
	local money = vRP.getMoney(user_id)
	if money >= flr then -- enough, simple payment
		local t = vRP.tryPayment(user_id, flr)
		return t
	else
		if vRP.tryWithdraw(user_id, flr-money) then -- withdraw to complete amount
			return vRP.tryPayment(user_id, flr)
		end
	end
	return false
end

--Todos os direitos reservados a Rodrigo Lujan (Yang#6376), Copyright (C) 2018
--Discord: Yang#6376