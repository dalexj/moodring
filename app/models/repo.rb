class Repo < ActiveRecord::Base
  validates :owner, :name, presence: true
  validates :private, exclusion: { in: [nil] }

  def request_repo
    Faraday.get "https://api.github.com/repos/#{owner}/#{name}" do |request|
      request.params['client_id'] = ENV['GITHUB_KEY']
      request.params['client_secret'] = ENV['GITHUB_SECRET']
    end
  end

  def request_commits
    Faraday.get "https://api.github.com/repos/#{owner}/#{name}/commits" do |request|
      request.params['client_id'] = ENV['GITHUB_KEY']
      request.params['client_secret'] = ENV['GITHUB_SECRET']
    end
  end

  def set_privacy
    self.private = repo_info[:private]
  end

  def private?
    private
  end

  def repo_info
    @repo_info ||= JSON.parse request_repo.body, { symbolize_names: true }
  end

  def commits
    @commits ||= JSON.parse request_commits.body, { symbolize_names: true }
  end

  def messages
    commits.map{ |commit| commit[:commit][:message] }
  end

  def sentiments
    @sentiments ||= TimeTracker.track_time("repo.sentiments") do
      messages.map { |commit| analyze_sentiment(commit) }
    end
  end

  def analyze_sentiment(commit)
    # try to restructure commits so they hashes
    # {:sha => "sha_value", :message => "message value"}
    # use rails cache (either memcached or Redis)
    # sentiment_value:<sha>
    (Sentimentalizer.analyze(commit).overall_probability * 100).round
  end

  def messages_with_sentiment
    messages.zip sentiments
  end

  def mood
    sentiments.inject(:+) / messages.count
  end
end
