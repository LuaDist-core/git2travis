# Git2Travis

A LuaDist utility used to wire Github repositories with Travis automatically.

## Configuration

Git2Travis can be configured by specifying several environment variables described below.


- `GIT2TRAVIS_REPO_PATH` - the directory with all the repositories (defaults to `data/repos`)
- `GIT2TRAVIS_LOG_DIR` - directory to keep the logs in (defaults to `logs`))

- `GIT2TRAVIS_TRAVIS_TOKEN` - Travis access token for the given account (no default, must be set)
- `GIT2TRAVIS_GITHUB_TOKEN` - Github access token allowing to create repositories on the given account (no default, must be set)

- `GIT2TRAVIS_GITHUB_DIR` - The Github account which contains all the repositories (defaults to `LuaDist2`)

- `GIT2TRAVIS_TRAVIS_SYNC_WAIT` - how long should the pusher wait for Travis to synchronize with the Github account (defaults to `30`)
- `GIT2TRAVIS_TRAVIS_MAX_TRIES` - how many times we should try to activate repositories on Travis if the amount of still inactive packages stays the same (defaults to `5`)

