module Spec
  module Support
    module VcrHelper
      def self.with_cassette_library_dir(new_path)
        old_path = VCR.configuration.cassette_library_dir
        VCR.configure { |c| c.cassette_library_dir = new_path }

        yield

      ensure
        VCR.configure { |c| c.cassette_library_dir = old_path }
      end
    end
  end
end
