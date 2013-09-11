require 'net/http'
require 'java'

# 'java_import' is used to import java classes
java_import 'java.util.concurrent.Callable'
java_import 'java.util.concurrent.FutureTask'
java_import 'java.util.concurrent.LinkedBlockingQueue'
java_import 'java.util.concurrent.ThreadPoolExecutor'
java_import 'java.util.concurrent.TimeUnit'


class LoadTester
  attr_reader :run_time, :total_hits

  def initialize(args)
    @load_test = args[:load_test]
    @threads = args[:threads] || 8
    @total_hits = args[:total_hits] || 10_000
    @run_time = 0
  end

  def run
    executor = ThreadPoolExecutor.new(@threads, # core_pool_treads
                                  @threads, # max_pool_threads
                                  360, #60, # keep_alive_time
                                  TimeUnit::SECONDS,
                                  LinkedBlockingQueue.new)

    num_tests = @total_hits
    num_threads = @threads

    tasks = []

    start = Time.now

    num_tests.times do |i|
      task = FutureTask.new(RunLoadTest.new(@load_test))
      executor.execute(task)
      tasks << task
    end

    tasks.each do |t|
      t.get
    end

    @run_time = Time.now - start

    executor.shutdown()

  end

end


class LoadTest

  attr_reader :site, :pages

  def initialize(args)
    @site = args[:url]
    @pages = args[:pages]
    @stats = args[:stats] || Stats.new
  end

  def run
    visit_page(@pages.shuffle.first)
  end

  def visit_page(page)
    url = URI("http://#{@site}/#{page}")
    start = Time.now
    resp = Net::HTTP.get_response(url)
    total_time = Time.now - start
    @stats.add_log([page,resp.code,start,total_time])
  end

end

class RunLoadTest
  include Callable

  def initialize(load_test)
    @load_test = load_test
  end

  def call
    @load_test.run
  end
end


class Pages
  def self.ad_api_test
    [
      'api/articles/1.json',
      'api/articles/2.json',
      'api/articles/3.json'
    ]
  end

  def self.stopa
    [
      '',
      'blog',
      'most-important-ruby-gem',
      'crazy-traffic-explosion',
      'simple-ruby-web-server',
      'projects',
      'my-story',
      'about',
      'heroku-sinatra-mongoid-get-up-and-running-super-fast',
      'what-does-the-ruby-1-9-tap-method-do-objecttap'
    ]
  end

  def self.opp
    [
      'advisors',
      'advisors/funds',
      'advisors/portfolio-managers',
      'advisors/insights',
      'advisors/advisor-exchange',
      'advisors/fund/developing-markets-fund',
      'advisors/fund/global-fund',
      'advisors/fund/rising-dividends-fund',
      'advisors/fund/global-strategic-income-fund',
      'advisors/fund/gold-&-special-minerals-fund',
      'advisors/fund/international-growth-fund'
    ]
  end

  def self.qa1
    [
      '',
      'funds',
      'portfolio-managers',
      'insights',
      'advisor-exchange',
      'fund/developing-markets-fund',
      'fund/global-fund',
      'fund/rising-dividends-fund',
      'fund/global-strategic-income-fund',
      'fund/gold-&-special-minerals-fund',
      'fund/international-growth-fund'
    ]
  end

end


class Stats
  attr_reader :log

  def initialize
    @log = []
  end

  def add_log(data)
    self.log << data
    puts data
  end

  def errors
    error = self.log.select { |e| e[1] != "200" }.count
  end

end


stats = Stats.new
lt1 = LoadTest.new({url: 'localhost:3005', stats: stats, pages: Pages.opp})
# lt1 = LoadTest.new({url: 'ediststg-qa1.oppfunds.com', stats: stats, pages: Pages.qa1})
# lt1 = LoadTest.new({url: 'mattstopa.com', stats: stats, pages: Pages.stopa})
lt = LoadTester.new(load_test: lt1, total_hits: 100, threads: 16)
puts "The party is starting!"
start = Time.now
puts start
lt.run
fin = Time.now
puts fin - start

puts "It ran #{stats.log.count} times in: #{lt.run_time}"

puts "There were #{stats.errors} non 200 responses"

