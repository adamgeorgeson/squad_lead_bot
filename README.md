# Squad Lead Bot

Slack bot which schedules daily tasks to support development squads/teams.

### Features:
 - At defined schedules pull down open pull-requests/issues from GitHub's API and post to Slack.
 - Uses environment variables to specify target repos, and target labels if your teams use labels in PR's to seperate out teams.
 - Best guess based on labels to determine what the current status of the PR is.
 - Manual triggering using the `/refresh` endpoint.
 - It says either 'Morning' or 'Afternoon' depending on the time of day. Groundbreaking!

### Todo
 - Handle configuration of PRs which are to post in different Slack channels.
 - Handle labels better when determining status, or just output the labels. Currently opinionated based on main project this is aimed at.
 - Additional tasks to support development teams in a similar fashion. JIRA maybe?
 - Allow the `/refresh` route to take params.

### Usage

 - Set environment variables in current terminal session, or in `~/.bash_profile`.

```
# The access token used to access the GitHub API. See https://help.github.com/articles/creating-an-access-token-for-command-line-use/
$ export SQUAD_NOTIFIER_GITHUB_TOKEN='PersonalAccessToken'

# The Slack webhook URL. See https://api.slack.com/incoming-webhooks
$ export SQUAD_NOTIFIER_SLACK_WEBHOOK='https://hooks.slack.com/services/IM/NOT/REAL'

# Comma seperated list of CRON job schedules
$ export SQUAD_NOTIFIER_SCHEDULES='0 8 * * 1-5,0 12 * * 1-5'

# Comma seperated list of repos we want to check for open PR's
$ export SQUAD_NOTIFIER_TARGET_REPOS="org/repo1,org/repo2,org/repo3,org/repo4"

# Comma seperated list of repos we don't want/need to filter by a squad/team label
$ export SQUAD_NOTIFIER_UNLABELLED_REPOS="org/repo1,org/repo2"

# Comma seperated list of the squad labels we want to track, if any. This allows us to filter PRs between many squads/teams and notify seperately.
$ export SQUAD_NOTIFIER_TARGET_LABELS='label1,label2'

# The target Slack channel to notify
$ export SQUAD_NOTIFIER_TARGET_CHANNEL='#foo_channel'

# The name of the bot as it appears in Slack
$ export SQUAD_NOTIFIER_SLACK_USERNAME='Super Dooper Sqaud Bot'
```

 - Install dependencies with Bundler.
```
$ bundle install
```

 - Run the application with `ruby squad_lead_bot.sh`.
 - Manually trigger by using `curl http://localhost:4567/refresh`

<div style="text-align:center">![be excellent to eachother](https://i.imgflip.com/1dll28.jpg)</div>
