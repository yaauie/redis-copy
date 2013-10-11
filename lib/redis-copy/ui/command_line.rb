# encoding: utf-8

module RedisCopy
  module UI
    class CommandLine
      include UI

      def confirm?(prompt)
        $stderr.puts(prompt)
        return true if @options[:yes]
        $stderr.puts("Continue? [yN]")
        abort unless $stdin.gets.chomp =~ /y/i
        true
      end

      def abort(message = nil)
        notify(['ABORTED',message].compact.join(': '))
        exit 1
      end

      def notify(message)
        $stderr.puts(message)
      end
    end
  end
end
