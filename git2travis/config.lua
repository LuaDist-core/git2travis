module("git2travis.config", package.seeall)

local path = require "pl.path"

repoPath = os.getenv("GIT2TRAVIS_REPO_PATH") or path.abspath('data/repos')
logDir   = os.getenv("GIT2TRAVIS_LOG_DIR") or path.abspath('logs')

travisToken = os.getenv("GIT2TRAVIS_TRAVIS_TOKEN") or error("environment variable GIT2TRAVIS_TRAVIS_TOKEN must be set")
githubToken = os.getenv("GIT2TRAVIS_GITHUB_TOKEN") or error("environment variable GIT2TRAVIS_GITHUB_TOKEN must be set")

githubDir = os.getenv("GIT2TRAVIS_GITHUB_DIR") or 'LuaDist2'

-- The time (in seconds) we'll wait for Travis to sync before trying to activate the repositories again
travisSyncWait = tonumber(os.getenv("GIT2TRAVIS_TRAVIS_SYNC_WAIT")) or 30
-- The amount of tries to sync Travis before giving up
travisMaxTries = tonumber(os.getenv("GIT2TRAVIS_TRAVIS_MAX_TRIES")) or 5

