class APN::App < APN::Base
  include Mongoid::Document
  include ActiveModel::Validations

  field :apn_dev_cert, :type => String
  field :apn_prod_cert, :type => String

  has_many :groups, :class_name => 'APN::Group', :dependent => :destroy
  has_many :devices, :class_name => 'APN::Device', :dependent => :destroy

  def notifications
    devices.flat_map(&:notifications)
  end

  def unsent_notifications
    devices.flat_map(&:unsent_notifications)
  end

  def group_notifications
    groups.flat_map(&:group_notifications)
  end

  def unsent_group_notifications
    groups.flat_map(&:unsent_group_notifications)
  end
    
  def cert
    (Rails.env == 'production' ? apn_prod_cert : apn_dev_cert)
  end
  
  # Opens a connection to the Apple APN server and attempts to batch deliver
  # an Array of group notifications.
  # 
  # 
  # As each APN::GroupNotification is sent the <tt>sent_at</tt> column will be timestamped,
  # so as to not be sent again.
  # 
  def send_notifications
    if self.cert.nil?
      raise APN::Errors::MissingCertificateError.new
      return
    end
    APN::App.send_notifications_for_cert(self.cert, self.id)
  end
  
  def self.send_notifications
    apps = APN::App.all
    apps.each do |app|
      app.send_notifications
    end
    send_notifications_for_cert(global_cert, nil)
  end

  def self.send_notifications_for_cert(the_cert, app_id)
    if (app_id == nil)
      conditions = "app_id is null"
    else
      conditions = ["app_id = ?", app_id]
    end
    begin
      APN::Connection.open_for_delivery({:cert => the_cert}) do |conn, sock|
        APN::Device.where(:conditions => conditions).each do |dev|
          Rails.logger.error "        #{__FILE__}:#{__LINE__}"
          dev.unsent_notifications.each do |noty|
            Rails.logger.error "        #{__FILE__}:#{__LINE__}"
            conn.write(noty.message_for_sending)
            Rails.logger.error "        #{__FILE__}:#{__LINE__}"
            noty.sent_at = Time.now
            Rails.logger.error "        #{__FILE__}:#{__LINE__}"
            noty.save
            Rails.logger.error "        #{__FILE__}:#{__LINE__}"
          end
        end
      end
    rescue Exception => e
      log_connection_exception(e)
    end
  end
  
  def send_group_notifications
    if self.cert.nil? 
      raise APN::Errors::MissingCertificateError.new
      return
    end
    unless self.unsent_group_notifications.nil? || self.unsent_group_notifications.empty? 
      APN::Connection.open_for_delivery({:cert => self.cert}) do |conn, sock|
        unsent_group_notifications.each do |gnoty|
          gnoty.devices.all.each do |device|
            conn.write(gnoty.message_for_sending(device))
          end
          gnoty.sent_at = Time.now
          gnoty.save
        end
      end
    end
  end
  
  def send_group_notification(gnoty)
    if self.cert.nil? 
      raise APN::Errors::MissingCertificateError.new
      return
    end
    unless gnoty.nil?
      APN::Connection.open_for_delivery({:cert => self.cert}) do |conn, sock|
        gnoty.devices.all.each do |device|
          conn.write(gnoty.message_for_sending(device))
        end
        gnoty.sent_at = Time.now
        gnoty.save
      end
    end
  end
  
  def self.send_group_notifications
    apps = APN::App.all
    apps.each do |app|
      app.send_group_notifications
    end
  end          
  
  # Retrieves a list of APN::Device instnces from Apple using
  # the <tt>devices</tt> method. It then checks to see if the
  # <tt>last_registered_at</tt> date of each APN::Device is
  # before the date that Apple says the device is no longer
  # accepting notifications then the device is deleted. Otherwise
  # it is assumed that the application has been re-installed
  # and is available for notifications.
  # 
  # This can be run from the following Rake task:
  #   $ rake apn:feedback:process
  def process_devices
    if self.cert.nil?
      raise APN::Errors::MissingCertificateError.new
      return
    end
    APN::App.process_devices_for_cert(self.cert)
  end # process_devices
  
  def self.process_devices
    apps = APN::App.all
    apps.each do |app|
      app.process_devices
    end
    APN::App.process_devices_for_cert(global_cert)
  end
  
  def self.process_devices_for_cert(the_cert)
    puts "in APN::App.process_devices_for_cert"
    APN::Feedback.devices(the_cert).each do |device|
      if device.last_registered_at < device.feedback_at
        puts "device #{device.id} -> #{device.last_registered_at} < #{device.feedback_at}"
        device.destroy
      else 
        puts "device #{device.id} -> #{device.last_registered_at} not < #{device.feedback_at}"
      end
    end
  end

  def self.global_cert
    @global_cert ||= File.read(File.join(Rails.root, "config/apple_push_notification/#{Rails.env}.pem"))
  end
  
  def self.log_connection_exception(ex)
    ex.extend(APN::Errors)
    Rails.logger.error "APN Exception: #{ex.class} - #{ex.message}\n#{ex.backtrace}"
  end

  protected

  def log_connection_exception(ex)
    self.class.log_connection_exception ex
  end

end
