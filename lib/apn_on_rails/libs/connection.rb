module APN
  module Connection
    
    class << self
      
      # Yields up an SSL socket to write notifications to.
      # The connections are close automatically.
      # 
      #  Example:
      #   APN::Configuration.open_for_delivery do |conn|
      #     conn.write('my cool notification')
      #   end
      def open_for_delivery(options = {}, &block)
        open(options, &block)
      end
      
      # Yields up an SSL socket to receive feedback from.
      # The connections are close automatically.
      def open_for_feedback(options = {}, &block)
        options = {:cert => ::APN::FEEDBACK_CERT_FILE,
                   :passphrase => ::APN::FEEDBACK_PASSPHRASE,
                   :host => ::APN::FEEDBACK_HOST,
                   :port => ::APN::FEEDBACK_PORT}.merge(options)
        open(options, &block)
      end
      
      private
      def open(options = {}, &block) # :nodoc:
        options = {:cert => ::APN::CERT_FILE,
                   :passphrase => ::APN::PASSPHRASE,
                   :host => ::APN::HOST,
                   :port => ::APN::PORT}.merge(options)
        #cert = File.read(options[:cert])
        cert = options[:cert]
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.key = OpenSSL::PKey::RSA.new(cert, options[:passphrase])
        ctx.cert = OpenSSL::X509::Certificate.new(cert)
  
        sock = TCPSocket.new(options[:host], options[:port])
        ssl = OpenSSL::SSL::SSLSocket.new(sock, ctx)
        ssl.sync = true
        ssl.connect
  
        yield ssl, sock if block_given?
  
        ssl.close
        sock.close
      end
      
    end
    
  end # Connection
end # APN
