# encoding: utf-8

module RedisCopy
  module UI
    class AutoRun
      implements UI

      def confirm?(prompt)
        $stderr.puts(prompt)
        true
      end
      def abort(message = nil)
        raise RuntimeError, message
      end
      def notify(message)
        $stderr.puts(message)
      end
    end
  end
end
