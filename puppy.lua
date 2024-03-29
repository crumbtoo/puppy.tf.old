#! /usr/bin/env luvit

local discordia = require("discordia")
local options = require("options")
local cmds = require("commands")
local client = discordia.Client()
_G.ffi = require("ffi")
_G.steamapi = require("./etc/steamapi"):new(options.steamapikey)
local logs = require("./etc/logs-tf.lua")
local misctf = require("./etc/misc-tf.lua")
_G.llogsTF = require("./etc/logs/llogsTF")
local ssfetch = require("./etc/ssfetch.so")
local timer = require("timer")
_G.steam = require("./etc/steam")
_G.sqlite3 = require("lsqlite3")
discordia.extensions()

client:on("ready", function()
	print(client.user.name .. " is up")

	-- check if db exists
	local dbcheck = io.open(options.dbname)
	if not dbcheck then
		print("database '"..options.dbname.."' not found, creating.")

		local db = sqlite3.open(options.dbname)
		db:exec("CREATE TABLE users(id text primary key, sid64 text)")
		db:close()
	else
		io.close(dbcheck)
	end
end)

function show_tf2_server_info(message)
	-- if msg is tf2 connect info
	local hostname, port, password = misctf.ifTF2Connect(message.content)
	if hostname then
		local info = ssfetch.fetch(hostname, port)
		if not info then return end

		local connect = "steam://connect/"..hostname

		if port then connect = connect..":"..port end
		if password then connect = connect..'/'..password:gsub('"', "") end

		if info.vac == "secured" then
			vac = "VAC Secured"
		else
			vac = "VAC Unsecured"
		end

		print(connect)

		message.channel:send {
			embed = {
				title = info.name,
				description = "**"..connect.."**"..'\n'
				..info.map..'\n'
				..string.format("%d/%d Players (%d bots)", info.playercount, info.maxplayers, info.botcount),

				footer = {
					text = string.format("%s (%s)", vac, info.game)
				}
			}
		}

		return
	end
end

function docommand(message)
	-- if msg starts with prefix, run command
	if message.content:sub(1, #options.prefix) == options.prefix then
		local argv = message.content:split(" ")
		local command = cmds[table.remove(argv, 1):sub(2)]
		if command then
			if command.call(argv, message, options) == -1 then
				message.channel:send("usage: " .. command.usage)
			end
		end
		return
	end
end

function show_log_info(message)
	local logno, h = logs.islogsURL(message.content)
	if logno then
		local img, err

		if h then
			img, err = llogsTF.renderlog(logno, steam.sid64_to_sid3(h))
		else
			img, err = llogsTF.renderlog(logno)
		end

		print("log! - " .. img)

		if err then print(err) end

		message.channel:send {
			content = "https://logs.tf/"..logno,
			file = img
		}

		os.remove(img)
		return
	end
end

client:on("messageCreate", function(message)
	if message.author.bot then return end

	-- if not current_vc[message.guild.id] then print("none") else print(current_vc[message.guild.id].id) end

	-- if command
	docommand(message)

	-- if msg is log
	show_log_info(message)

	-- if message is connect info
	show_tf2_server_info(message)
end)

client:on("voiceChannelJoin", function(member, channel)
	if not channel.guild.connection then
		channel:join()
	end
end)

client:on("voiceChannelLeave", function(member, channel)
	if channel.guild.connection then
		channel:leave()
	end
end)

client:run("Bot " .. options.token)
