require 'socket'
require 'openssl'

rails_root = File.join(FileUtils.pwd, 'rails_root')
if defined?(Rails.root.to_s)
  rails_root = Rails.root.to_s
end

rails_env = 'development'
if defined?(Rails.env)
  rails_env = Rails.env
end

APN_HOST = (Rails.env == 'production' ? 'gateway.push.apple.com' : 'gateway.sandbox.push.apple.com') unless defined?(APN_HOST)
APN_PORT = 2195 unless defined?(APN_PORT)
APN_CERT_FILE = File.join(Rails.root, 'config', 'apple_push_notification', "#{Rails.env}.pem") unless defined?(APN_CERT_FILE)
APN_PASSPHRASE = '' unless defined?(APN_PASSPHRASE)

APN_FEEDBACK_HOST = (Rails.env == 'production' ? 'feedback.push.apple.com' : 'feedback.sandbox.push.apple.com') unless defined?(APN_FEEDBACK_HOST)
APN_FEEDBACK_PORT = 2196 unless defined?(APN_FEEDBACK_PORT)
APN_FEEDBACK_CERT_FILE = File.join(Rails.root, 'config', 'apple_push_notification', "#{Rails.env}.pem") unless defined?(APN_FEEDBACK_CERT_FILE)
APN_FEEDBACK_PASSPHRASE = '' unless defined?(APN_FEEDBACK_PASSPHRASE)


module APN # :nodoc:
  
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
