autoload :IRB, "irb"

module Inspec
  # An IRB based shell for inspec. Given a runner (with a configured backend and
  # all that jazz), this shell will produce an IRB shell from which you can run
  # inspec/ruby commands that will be run within the context of the runner.
  class Shell
    def initialize(runner)
      @runner = runner
    end

    def start
      # This will hold a single evaluation binding context as opened within
      # the instance_eval context of the anonymous class that the profile
      # context creates to evaluate each individual test file. We want to
      # pretend like we are constantly appending to the same file and want
      # to capture the local variable context from inside said class.
      @ctx_binding = @runner.eval_with_virtual_profile("binding")
      configure_irb

      # Add a help menu as the default intro
      intro
      print_target_info

      @ctx_binding.irb
    end

    def configure_irb # rubocop:disable Metrics/AbcSize
      # # Delete any before_session, before_eval, and after_eval hooks so we can
      # # replace them with our own. Pry 0.10 used to have a single method to clear
      # # all hooks, but this was removed in Pry 0.11.
      # %i{before_session before_eval after_eval}.each do |event|
      #   Pry.hooks.get_hooks(event).keys.map { |hook| Pry.hooks.delete_hook(event, hook) }
      # end

      that = self

      # Add the help command
      IRB.conf[:IRB_RC] = Proc.new do
        def help(resource = nil)
          that.help(resource)
        end

        @runner.reset

        @runner.load
        @runner.run_tests unless @runner.all_rules.empty?
      end

      # configure IRB shell prompt
      IRB.conf[:PROMPT] ||= {}
      IRB.conf[:PROMPT][:INSPEC] = {
        :AUTO_INDENT => true,
        :PROMPT_I => "#{readline_ignore("\e[1m\e[32m")}inspec> #{readline_ignore("\e[0m")}",
        :PROMPT_N => "#{readline_ignore("\e[1m\e[32m")}inspec> #{readline_ignore("\e[0m")}",
        :PROMPT_S => "#{readline_ignore("\e[1m\e[32m")}inspec%l #{readline_ignore("\e[0m")}",
        :PROMPT_C => "#{readline_ignore("\e[1m\e[32m")}inspec* #{readline_ignore("\e[0m")}",
        :RETURN => "=> %s\n"
      }
      IRB.conf[:PROMPT_MODE] = :INSPEC

      # # Don't print out control class inspection when the user uses DSL methods.
      # # Instead produce a result of evaluating their control.
      # Pry.config.print = proc do |_output_, value, pry|
      #   next unless @runner.all_rules.empty?
      #
      #   pry.pager.open do |pager|
      #     pager.print pry.config.output_prefix
      #     Pry::ColorPrinter.pp(value, pager, Pry::Output.new(pry).width - 1)
      #   end
      # end
    end

    def readline_ignore(code)
      "\001#{code}\002"
    end

    def mark(x)
      "\e[1m\e[39m#{x}\e[0m"
    end

    def intro
      puts "Welcome to the interactive InSpec Shell"
      puts "To find out how to use it, type: #{mark "help"}"
      puts
    end

    def print_target_info
      ctx = @runner.backend
      puts <<~EOF
        You are currently running on:

        #{Inspec::BaseCLI.format_platform_info(params: ctx.platform.params, indent: 4, color: 39)}
      EOF
    end

    def help(topic = nil)
      if topic.nil?

        puts <<~EOF
          Available commands:

              `[resource]` - run resource on target machine
              `help resources` - show all available resources that can be used as commands
              `help [resource]` - information about a specific resource
              `help matchers` - show information about common matchers
              `exit` - exit the InSpec shell

          You can use resources in this environment to test the target machine. For example:

              command('uname -a').stdout
              file('/proc/cpuinfo').content => "value"

          #{print_target_info}
        EOF
      elsif topic == "resources"
        require "inspec/resources"
        resources.sort.each do |resource|
          puts " - #{resource}"
        end
      elsif topic == "matchers"
        print_matchers_help
      elsif !Inspec::Resource.registry[topic].nil? # TODO: fix unnecessary logic
        topic_info = Inspec::Resource.registry[topic]
        info = "#{mark "Name:"} #{topic}\n\n"
        unless topic_info.desc.nil?
          info += "#{mark "Description:"}\n\n"
          info += "#{topic_info.desc}\n\n"
        end

        unless topic_info.example.nil?
          info += "#{mark "Example:"}\n\n"
          info += "#{topic_info.example}\n\n"
        end

        info += "#{mark "Web Reference:"}\n\n"
        info += "https://docs.chef.io/inspec/resources/#{topic}\n\n"
        puts info
      else
        begin
          require "inspec/resources/#{topic}"
          help topic
        rescue LoadError
          # TODO: stderr!
          puts "The resource #{topic} does not exist. For a list of valid resources, type: help resources"
        end
      end
    end

    def resources
      Inspec::Resource.registry.keys
    end

    def print_matchers_help
      puts <<~EOL
        Matchers are used to compare resource values to expectations. While some
        resources implement their own custom matchers, the following matchers are
        common amongst all resources:

        #{mark "be"}

        The #{mark "be"} matcher can be used to compare numeric values.

          its('size') { should be >= 10 }

        #{mark "cmp"}

        The #{mark "cmp"} matcher is like #{mark "eq"} but less restrictive. It will try
        to fit the resource value to the expectation.

        "Protocol" likely returns a string, but cmp will ensure it's a number before
        comparing:

          its('Protocol') { should cmp 2 }
          its('Protocol') { should cmp '2' }

        "users" may return an array, but if it contains only one item, cmp will compare
        it as a string or number as needed:

          its('users') { should cmp 'root' }

        cmp is not case-sensitive:

          its('log_format') { should cmp 'raw' }
          its('log_format') { should cmp 'RAW' }

        #{mark "eq"}

        The #{mark "eq"} matcher tests for exact equality of two values. Value type
        (string, number, etc.) is important and must be the same. For a less-restrictive
        comparison matcher, use the #{mark "cmp"} matcher.

          its('RSAAuthentication') { should_not eq 'no' }

        #{mark "include"}

        The #{mark "include"} matcher tests to see if a value is included in a list.

          its('users') { should include 'my_user' }

        #{mark "match"}

        The #{mark "match"} matcher can be used to test a string for a match using a
        regular expression.

          its('content') { should_not match /^MyKey:\\s+some value/ }

        For more examples, see: https://docs.chef.io/inspec/matchers/

      EOL
    end
  end
end
