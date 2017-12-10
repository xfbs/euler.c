#!/usr/bin/env ruby
# yes, this script is what you would call ugly. it's a mess. but it's not meant
# to be seen, or to win any beauty contests — it's supposed to kinda do its
# job while still being flexible enough so that you can change it around and
# hack something together if you need to. if you proceed from here... you have
# been warned.

require 'optparse'


class Problem
  BASEDIR = "src"
  attr_accessor :path, :num, :slug

  def self.all
    Pathname.new(BASEDIR).children
      .select{|entry| File.directory? entry}
      .map{|entry| Problem.new entry.to_s}
      .sort
  end

  def initialize p
    p = Dir["#{BASEDIR}/#{p}*"][0] unless p.class == String
    throw "invalid problem" unless File.exists?(File.join(p, "problem.md"))
    @path = p
    @slug = File.basename(p)
    @num = @slug.scan(/(\d\d\d).*/)[0][0].to_i
  end

  def implementations
    Pathname.new(@path).children
      .select{|entry| File.directory? entry}
      .map{|entry| Implementation.new entry.to_s}
  end

  def has_solution?
    !Dir["#{@path}/.solution.bcrypt"].empty?
  end

  def check_solution sol
    return false unless has_solution?
    hash = File.read(File.join(@path, ".solution.bcrypt"))
    p = BCrypt::Password.new(hash)
    p.is_password? sol
  end

  def <=> other
    num <=> other.num
  end

  def == other
    num == other.num
  end
end

class Implementation
  attr_accessor :path, :problem, :lang

  def self.all
    impls = []

    Problem.all.each do |prob|
      prob.implementations.each do |impl|
        impls.unshift impl
      end
    end

    impls.sort
  end

  def initialize path
    @path = path
    @problem = Problem.new File.dirname(@path)
    @lang = File.basename(@path)
  end

  def solve
    stdout, _, status = Open3.capture3("cd \"#{@path}\" && make solve")

    # throw exception if stderr is not empty?
    return nil if status != 0
    stdout.chomp
  end

  def build
    _, _, status = Open3.capture3("cd \"#{@path}\" && make")
    status == 0
  end

  def test
    _, _, status = Open3.capture3("cd \"#{@path}\" && make test")
    status == 0
  end

  def clean
    _, _, status = Open3.capture3("cd \"#{@path}\" && make clean")
    status == 0
  end

  def check
    build
    solution = solve
    @problem.check_solution solution if solution
  end

  def <=> other
    rough = problem <=> other.problem

    if rough == 0
      lang <=> other.lang
    else
      rough
    end
  end
end

class ActionCheck
  class Formatter
    attr_accessor :problems
    def initialize
    end

    def verbose
      @verbose = true
    end

    def color
      @color = true
    end

    def setup
    end

    def result _, _
    end

    def style text, color={}
      fg = {
        :red => 31,
        :green => 32,
        :yellow => 33,
        :blue => 34,
        :magenta => 35,
        :cyan => 36,
        :white => 37,
      }

      bg = {
        :red => 41,
        :green => 42,
        :yellow => 43,
        :blue => 44,
        :magenta => 45,
        :cyan => 46,
        :white => 47,
      }

      at = {
        :reset => 0,
        :bold => 1,
        :underscore => 4,
        :blink => 5,
        :reverse => 7,
        :conceal => 8
      }

      mode = []
      mode << fg[color[:fg]] if color[:fg]
      mode << bg[color[:bg]] if color[:bg]
      mode << at[color[:at]] if color[:at]

      if @color
        print "\e[#{mode.join(';')}m#{text}\e[0m"
      else
        print text
      end
    end

    def cursor action, arg=nil
      codes = {
        :save => 's',
        :restore => 'u',
        :up => 'A',
        :down => 'B',
        :forward => 'C',
        :backward => 'D'
      }

      print "\e[#{arg||''}#{codes[action]}"
    end

    def done
    end
  end

  class Default < Formatter
    def initialize
      super
    end

    def setup
      puts "checking euler solutions"
    end

    def result impl, result
      if result.nil?
        style "error ", fg: :red
      elsif !result
        style "wrong ", fg: :yellow
      else
        style "right ", fg: :green
      end

      puts impl.path
    end
  end

  class Overview < Formatter
    def initialize
      super
      @good = []
    end

    def setup
      # print list of all problems
      @ps = Problem.all.select do |p|
        if @problems
          @problems.include? p.num
        else
          true
        end
      end.each_slice(20).to_a
      @ps.each do |line|
        line.each do |p|
          print "#{p.num.to_s.rjust(3, '0')} "
        end
        puts
      end

      puts
      print "  "
      style "  ", bg: :green
      print ": all solutions work   "
      style "  ", bg: :yellow
      print ": some solutions work   "
      style "  ", bg: :red
      puts ": no solutions work"
    end

    def result impl, result
      # find location of the problem of the implementation
      p = impl.problem

      x = @ps.index{|r| r.find{|e| e == p}}
      y = @ps[x].index{|e| e == p}

      cursor :save
      cursor :up, (@ps.length - x + 2)
      cursor :forward, 4*y if y > 0

      if(result)
        style p.num.to_s.rjust(3, '0'), fg: :green
      elsif @good.find{|e| e == p}
        style p.num.to_s.rjust(3, '0'), fg: :yellow
      else
        style p.num.to_s.rjust(3, '0'), fg: :red
      end

      print "\r"
      #cursor :restore
      cursor :down, (@ps.length - x + 2)

      @good << p
    end
  end

  def initialize
    require 'pathname'
    require 'open3'
    require 'bcrypt'
    @lang = []
    @prob = []
  end

  def setup
    OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} build [options]"
      opts.version = "1.0.0"
      opts.on('-v', '--verbose') do |o|
        @verbose = true
      end
      opts.on('-o', '--overview') do |o|
        @overview = true
      end
      opts.on('-c', '--color') do |o|
        @color = true
      end
      opts.on('-l', '--language MANDATORY') do |o|
        @lang << o
      end
      opts.on('-p', '--problem MANDATORY') do |o|
        a, b = o.split('-')
        if(b)
          @prob += Range.new(a.to_i, b.to_i).to_a
        else
          @prob << o.to_i
        end
      end
      opts.on('-t', '--threads MANDATORY') do |o|
        @threads = o.to_i
      end
    end.parse!

    if @overview
      @formatter = Overview.new
    else
      @formatter = Default.new
    end

    @formatter.color if @color
    @formatter.verbose if @verbose
    @formatter.problems = @prob

    self
  end

  def run
    @formatter.setup
    to_check = Implementation.all.select do |i|
      if !@lang.empty? then @lang.include? i.lang else true end
    end.select do |i|
      if !@prob.empty? then @prob.include? i.problem.num else true end
    end

    if !@threads
      check_single to_check
    else
      check_threaded to_check, @threads
    end
    @formatter.done
  end

  def check_single to_check
    to_check.each do |impl|
      result = impl.check
      @formatter.result(impl, result)
    end
  end

  def check_threaded to_check, num
    # add all jobs to a queue
    q = Queue.new
    m = Mutex.new
    to_check.each{|i| q << i}

    (0..num).map do
      Thread.new do
        while true
          begin
            job = q.pop(true)
          rescue Exception => _
            break
          end
          res = job.check
          m.synchronize do
            @formatter.result(job, res)
          end
        end
      end
    end.each do |t|
      t.join
    end
  end
end

class ActionBuild
  def initialize
    require 'pathname'
    require 'open3'
  end

  def setup
  end

  def run
    Implementation.all.each do |impl|
      result = impl.build

      if !result
        print "error "
      else
        print "built "
      end

      puts impl.path
    end
  end
end

class ActionClean
  def initialize
    require 'pathname'
    require 'open3'
  end

  def setup
    self
  end

  def run
    Implementation.all.each do |impl|
      result = impl.clean

      if !result
        print "error "
      else
        print "cleaned "
      end

      puts impl.path
    end
  end
end

class ActionTest
  def initialize
    require 'pathname'
    require 'open3'
  end

  def setup
    self
  end

  def run
    Implementation.all.each do |impl|
      result = impl.test

      if !result
        print "error "
      else
        print "tested "
      end

      puts impl.path
    end
  end
end

class ActionGoals
  def initialize
    require 'pathname'
    require 'open3'
  end

  def setup
    OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} goals [options]"
      opts.version = "1.0.0"
      opts.on('-i', '--interactive') do |o|
        @interactive = true
      end
      opts.on('-c', '--color') do |o|
        @color = true
      end
      opts.on('-t', '--threads MANDATORY') do |o|
        @threads = o.to_i
      end
    end.parse!

    if @interactive
      @formatter = Interactive.new
    else
      @formatter = Default.new
    end

    @formatter.color if @color
    @formatter.verbose if @verbose
    @formatter.problems = @prob

    self
  end

  def run
  end
end

class Invocation
  def initialize
    @options = OptionParser.new do |opts|
      opts.banner = "Usage: euler.rb [command] [options]"
      opts.version = "1.0.0"
      opts.separator ""
      opts.separator <<HELP
Available commands are:
  build:  builds all solutions
  check:  checks the solutions
  clean:  cleans the build cache
   test:  runs tests for all solutions
  goals:  checks if goals have been achieved

See 'euler.rb COMMAND --help' for more information.
HELP
    end
  end

  def find_command
    @options.order!
    ARGV.shift
  end

  def run
    actions = {
      'check' => ActionCheck,
      'build' => ActionBuild,
      'clean' => ActionClean,
      'test'  => ActionTest,
      'goals' => ActionGoals
    }

    command = find_command
    unless command
      puts @options
    else
      begin
        ret = actions[command].new.setup.run || 0
      rescue SystemExit => _
        raise
      rescue Exception => e
        puts "error while executing the command"
        puts e
        puts e.backtrace
      end

      ret
    end
  end
end

if __FILE__ == $0
  exit Invocation.new.run
end
