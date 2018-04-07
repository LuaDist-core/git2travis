module("git2travis", package.seeall)

local pl = {}
pl.dir = require 'pl.dir'
pl.path = require 'pl.path'
pl.pretty = require 'pl.pretty'
pl.utils = require 'pl.utils'

local cfg = require 'git2travis.config'

local logging = require "logging"
require "logging.file"
local log = logging.file(cfg.logDir .. "/git2travis-%s.log", "%Y-%m-%d")

local json = require 'json'

local travisRepos = pl.dir.getdirectories(cfg.repoPath)


-- Connect with Travis CI

local function sleep(seconds)
  os.execute("sleep " .. seconds)
end

local function urlencode(str)
  str = string.gsub(str, "\r?\n", "\r\n")

  str = string.gsub(str, "([^%w%-%.%_%~ ])", function (c)
    return string.format("%%%02X", string.byte(c))
  end)

  str = string.gsub (str, " ", "+")

  return str
end

local function travisRequest(method, endpoint, data)
  local cmd = 'curl -X ' .. method .. ' ' ..
              '-H "Content-Type: application/json" ' ..
              '-H "Travis-API-Version: 3" ' ..
              '-H "User-Agent: LunaCI" ' ..
              '-H "Authorization: token ' .. cfg.travisToken .. '" '

  if data then
    cmd = cmd .. '-d \'' .. data .. '\' '
  end

  cmd = cmd .. 'https://api.travis-ci.org/' .. endpoint

  local ok, _, stdout = pl.utils.executeex(cmd)
  if not ok then
    return ok, nil, cmd
  end

  local function decodeOutput()
    return json.decode(stdout)
  end

  local ok, data = pcall(decodeOutput)
  if ok then
    return data["@type"] ~= "error", data, cmd
  end

  return false, "Error parsing json:\nInput: " .. stdout .. "\nError: "  .. data, cmd
end

local function travisActivateRepo(repo)
  return travisRequest("POST", "repo/" .. urlencode(repo) .. "/activate?include=branch.last_build")
end

local function travisRequestBuild(repo)
  return travisRequest("POST", "repo/" .. urlencode(repo) .. "/requests")
end

local function travisSetEnv(repo)
  return travisRequest(
    "POST",
    "repo/" .. urlencode(repo) .. "/env_vars",
    '{ "env_var.name": "GITHUB_ACCESS_TOKEN", "env_var.value": "' .. cfg.githubToken .. '", "env_var.public": false }'
  )
end

local function travisSync()
  local ok, data, cmd = travisRequest("GET", "user")
  if not ok then
    return ok, data, cmd
  end

  local user_id = data['id']

  return travisRequest("POST", "user/" .. user_id .. "/sync")
end

local function travisWireRepository(repo)
  -- Assume that name of folder with repository is identical to module name
  local modName = pl.path.relpath(repo, cfg.repoPath)

  log:debug("Enabling Travis for '" .. modName .. "'...")

  local ok, data = travisActivateRepo(cfg.githubDir .. "/" .. modName)
  log:debug("Activate:\nData: " .. pl.pretty.write(data))
  if not ok then
    log:error("Error trying to activate repository on Travis-CI.\nData: " .. pl.pretty.write(data))
    return false
  end

  local default_branch = data["default_branch"]
  if not default_branch then
    log:error("Default branch for '" .. modName .. "' is nil even if it shouldn't be.")
    return false
  end

  local last_build = default_branch["last_build"]
  if last_build then
    log:debug("It seems '" .. modName .. "' is already wired up correctly, continuing to the next package...")
    return true
  end

  local ok, data = travisSetEnv(cfg.githubDir .. "/" .. modName)
  log:debug("Set env:\nData: " .. pl.pretty.write(data))
  if not ok then
    log:error("Error setting environment variables on Travis-CI.\nData: " .. pl.pretty.write(data))
    if data["@type"] == "error" and data["error_type"] == "duplicate_resource" then
      log:warn("The required variables seem to be set already, trying to continue as normal...")
    else
      return false
    end
  end

  local ok, data = travisRequestBuild(cfg.githubDir .. "/" .. modName)
  log:debug("Request:\nData: " .. pl.pretty.write(data))
  if not ok then
    log:error("Error requesting Travis-CI build.\nData: " .. pl.pretty.write(data))
    return false
  end

  return true
end

log:debug("Syncing Travis account...")
local retriesRemaining = cfg.travisMaxTries
while retriesRemaining >= 0 do
  local ok, data = travisSync()
  if not ok then
    log:error("Error syncing Travis account.\nData: " .. pl.pretty.write(data))
    log:debug("Trying again. Number of tries left: " .. retriesRemaining)
    retriesRemaining = retriesRemaining - 1
    if retriesRemaining < 0 then
      log:error("Failed to sync Travis, exiting...")
      os.exit(1)
    end
  else
    break
  end
end

log:debug("Waiting for " .. cfg.travisSyncWait .. " seconds...")
sleep(cfg.travisSyncWait)

local stillInactive = travisRepos
log:debug("Repos still inactive on Travis: " .. #stillInactive)
local previousCount = #stillInactive
retriesRemaining = cfg.travisMaxTries

while #stillInactive > 0 do
  travisRepos = stillInactive
  stillInactive = {}

  for _, repo in pairs(travisRepos) do
    if not travisWireRepository(repo) then
      table.insert(stillInactive, repo)
    end
  end

  if #stillInactive > 0 then
    log:debug("There are still some inactive Travis repos (" .. #stillInactive .. ").")

    if #stillInactive == previousCount then
      -- nothing happened, we're at the risk of running into an infinite loop
      retriesRemaining = retriesRemaining - 1
      if retriesRemaining < 0 then
        log:error("Not all repositories were synced with Travis (" .. #stillInactive .. "): " .. pl.pretty.write(stillInactive))
        os.exit(1)
      end


      if retriesRemaining > 0 then
        log:debug((retriesRemaining + 1) .. " tries remaining...")
      else
        log:debug("Last try...")
      end
    else
      previousCount = #stillInactive
      retriesRemaining = cfg.travisMaxTries
    end

    log:debug("Syncing Travis and waiting for " .. cfg.travisSyncWait .. " seconds before trying again.")
    local ok, data = travisSync()
    if not ok then
      log:error("Error syncing Travis account.\nData: " .. pl.pretty.write(data))
    end
    sleep(cfg.travisSyncWait)
  end
end


