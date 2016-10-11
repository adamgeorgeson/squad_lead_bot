require 'sinatra'
require 'rufus-scheduler'
require 'octokit'
require 'slack-notifier'
require 'set'

GITHUB_TOKEN = ENV['SQUAD_NOTIFIER_GITHUB_TOKEN']
SLACK_WEBHOOK = ENV['SQUAD_NOTIFIER_SLACK_WEBHOOK']
TARGET_REPOS = ENV['SQUAD_NOTIFIER_TARGET_REPOS'].split(',') || []
UNLABELLED_REPOS = ENV['SQUAD_NOTIFIER_UNLABELLED_REPOS'].split(',') || []
TEAM_LABELS = ENV['SQUAD_NOTIFIER_TEAM_LABELS'].split(',') || []
TARGET_CHANNEL = ENV['SQUAD_NOTIFIER_TARGET_CHANNEL']
SLACK_USERNAME = ENV['SQUAD_NOTIFIER_SLACK_USERNAME'] || 'Squad Bot'
QA_LABELS = ENV['SQUAD_NOTIFIER_QA_LABELS'].split(',').to_set || [].to_set
REVIEW_LABELS = ENV['SQUAD_NOTIFIER_REVIEW_LABELS'].split(',').to_set || [].to_set
MERGE_LABELS = ENV['SQUAD_NOTIFIER_MERGE_LABELS'].split(',').to_set || [].to_set
INCLUSIVE_LABELS = REVIEW_LABELS + QA_LABELS + MERGE_LABELS

configure do
  set :scheduler, Rufus::Scheduler.new
end

# Responsible for querying GitHub's API for issues we want to notify a Slack channel of
module IssueIdentifier
  extend self

  # Create git client with repo access using personal access token
  def git_client
    @git_client ||= Octokit::Client.new(access_token: GITHUB_TOKEN)
  end

  # Request issues from GitHub API for specific repo and label set
  def open_issues_for(repo:, label: nil)
    options = label ? {labels: label} : {}

    issues = git_client.issues(repo, options)

    filter(issues)
  end

  # Filters issues to remove issues with specific labels
  def filter(issues)
    issues.select do |issue|
      issue_labels = issue.labels.map(&:name).to_set
      issue.pull_request? && (issue_labels.empty? || issue_labels.intersect?(INCLUSIVE_LABELS))
    end
  end

  # Returns a string identifying the status of a Pull Request
  def status(labels)
    labels = labels.to_set

    return 'No labels!' if labels.empty?

    if labels.intersect? REVIEW_LABELS
      'Pending review'
    elsif labels.intersect? MERGE_LABELS
      'Ready for merge'
    elsif labels.intersect? QA_LABELS
      'Ready for QA'
    else
      'Open'
    end
  end
end

# Responsible for notifying a Slack channel
module SlackNotifier
  extend self

  def slack_notifier
    @slack_notifier ||= Slack::Notifier.new SLACK_WEBHOOK,
      channel: TARGET_CHANNEL,
      username: SLACK_USERNAME
  end

  # Build formatted slack attachments for GitHub issues
  def build_issue_slack_attachments(issues)
    attachments = []

    issues.each do |issue|
      labels = issue.labels.map(&:name)
      status = IssueIdentifier.status(labels)

      attachment = {
        color: "#{status_colours[status]}",
        fallback: "There is an outstanding PR #{status} created at #{issue.created_at}",
        author_name: "#{issue.user.login}",
        author_link: "#{issue.user.html_url}",
        author_icon: "#{issue.user.avatar_url}",
        title: "#{issue.title}",
        title_link: "#{issue.pull_request&.html_url || issue.html_url}",
        fields: [
          {
            title: 'Status',
            value: status,
            short: true
          },
          {
            title: 'Created At',
            value: issue.created_at,
            short: true
          }
        ]
      }

      attachments << attachment
    end

    attachments
  end

  # Post message for issues/pull requests to Slack
  def post_issues_to_slack(repo, issues, label = nil)
    if issues.count > 0
      time_of_day = (0..11).include?(Time.now.hour) ? 'Morning' : 'Afternoon'
      message = "#{time_of_day} team, here is a summary of #{issues.count} open pull requests for `#{repo}`"
      message += " and label `#{label}`" if label

      attachments = build_issue_slack_attachments(issues)

      post_to_slack(message: message, attachments: attachments)
    end
  end

  # Map the determined status to colours to display against the post in Slack
  def status_colours
    { 'Ready for QA' => '#c5def5',
      'Pending review' => '#fef2c0',
      'Ready for merge' => '#bfe5bf',
      'Requires further action' => '#eb6420',
      'Open' => '#eb6420',
      'No labels!' => '#eb6420'
    }
  end

  # Send the message to the configured Slack channel
  def post_to_slack(message:, attachments:)
    slack_notifier.ping message, attachments: attachments
  end
end

# Responsible for executing tasks when prompted by the scheduler
module Tasks
  extend self

  def notify_slack_of_open_issues
    raise 'No target repos configured' if TARGET_REPOS.count.zero?

    TARGET_REPOS.each do |repo|
      if TEAM_LABELS.empty? || UNLABELLED_REPOS.include?(repo)
        issues = IssueIdentifier.open_issues_for(repo: repo)
        SlackNotifier.post_issues_to_slack(repo, issues)
      else
        TEAM_LABELS.each do |label|
          issues = IssueIdentifier.open_issues_for(repo: repo, label: label)
          SlackNotifier.post_issues_to_slack(repo, issues, label)
        end
      end
    end
  end
end

get '/refresh' do
  puts "#{[Time.now]} EXECUTING: Manual Refresh - Notify Slack of open Pull Requests"

  Tasks.notify_slack_of_open_issues

  puts "#{[Time.now]} COMPLETE: Manual Refresh - Notify Slack of open Pull Requests"
end

# Scheduled task for 08:00 Mon-Fri
settings.scheduler.cron '0 8 * * 1-5' do
  puts "#{[Time.now]} EXECUTING: Notify Slack of open Pull Requests each weekday morning"

  Tasks.notify_slack_of_open_issues

  puts "#{[Time.now]} COMPLETE: Notify Slack of open Pull Requests each weekday morning"
end

# Scheduled task for 12:30 Mon-Fri
settings.scheduler.cron '30 12 * * 1-5' do
  puts "#{[Time.now]} EXECUTING: Notify Slack of open Pull Requests each weekday afternoon"

  Tasks.notify_slack_of_open_issues

  puts "#{[Time.now]} COMPLETE: Notify Slack of open Pull Requests each weekday at afternoon"
end
