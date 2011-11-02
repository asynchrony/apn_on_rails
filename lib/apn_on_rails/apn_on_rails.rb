require 'socket'
require 'openssl'




module APN # :nodoc:

  class APNRailtie < Rails::Railtie
    initializer "load APN config" do
      if defined?(Rails)
        rails_env = Rails.env
        rails_root = Rails.root
      else
        rails_env = 'development'
        rails_root = File.join(FileUtils.pwd, 'rails_root')
      end

      begin
        APN_CONFIG = YAML.load_file("#{rails_root}/config/apn.yml")[rails_env]
      rescue => ex
        raise ConfigFileNotFound,new(ex.message)
      end

      begin
        ::APN::HOST = APN_CONFIG['host'] || (rails_env == 'production' ? 'gateway.push.apple.com' : 'gateway.sandbox.push.apple.com') unless defined?(::APN::HOST)
        ::APN::PORT = APN_CONFIG['port'] || 2195 unless defined?(::APN::PORT)
        ::APN::CERT_FILE = APN_CONFIG['cert_file'] || File.join(rails_root, 'config', 'apple_push_notification', "#{rails_env}.pem") unless defined?(::APN::CERT_FILE)
        ::APN::PASSPHRASE = APN_CONFIG['cert_password'] || '' unless defined?(::APN::PASSPHRASE)

        ::APN::FEEDBACK_HOST = APN_CONFIG['feedback_host'] || (rails_env == 'production' ? 'feedback.push.apple.com' : 'feedback.sandbox.push.apple.com') unless defined?(::APN::FEEDBACK_HOST)
        ::APN::FEEDBACK_PORT = APN_CONFIG['feedback_port'] || 2196 unless defined?(::APN::FEEDBACK_PORT)
        ::APN::FEEDBACK_CERT_FILE = APN_CONFIG['feedback_cert_file'] || APN_CONFIG['cert_file'] || File.join(rails_root, 'config', 'apple_push_notification', "#{rails_env}.pem") unless defined?(::APN::FEEDBACK_CERT_FILE)
        ::APN::FEEDBACK_PASSPHRASE = APN_CONFIG['feedback_cert_password'] || APN_CONFIG['cert_password'] || '' unless defined?(::APN::FEEDBACK_PASSPHRASE)
      rescue => ex
        raise APN::Errors::ConfigFileMissingEnvironment.new(ex.message)
      end
    end
  end

  module Errors # :nodoc:
    # Raised when a notification message to Apple is longer than 256 bytes.
    class ExceededMessageSizeError < StandardError
      def initialize(message) # :nodoc:
        super("The maximum size allowed for a notification payload is 256 bytes: '#{message}'")
      end
    end
    
    class MissingCertificateError < StandardError
      def initialize
        super("This app has no certificate")
      end
    end

    class ConfigFileNotFound < StandardError
      def initialize(message)
        super("The config/apn.yml file could not be found or contains errors: '#{message}'")
      end
    end

    class ConfigFileMissingEnvironment < StandardError
      def initialize(message)
        super("The config/apn.yml file doesn't contain data for this environment (#{Rails.env || 'nil'}): '#{message}'")
      end
    end
  end # Errors

end # APN

base = File.join(File.dirname(__FILE__), 'app', 'models', 'apn', 'base.rb')
require base

Dir.glob(File.join(File.dirname(__FILE__), 'app', 'models', 'apn', '*.rb')).sort.each do |f|
  require f
end

%w{ models controllers helpers }.each do |dir| 
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path 
  # puts "Adding #{path}"
  begin
    if ActiveSupport::Dependencies.respond_to? :autoload_paths
      ActiveSupport::Dependencies.autoload_paths << path
      ActiveSupport::Dependencies.autoload_once_paths.delete(path)
    else
      ActiveSupport::Dependencies.load_paths << path 
      ActiveSupport::Dependencies.load_once_paths.delete(path) 
    end
  rescue NameError
    Dependencies.load_paths << path 
    Dependencies.load_once_paths.delete(path) 
  end
end
