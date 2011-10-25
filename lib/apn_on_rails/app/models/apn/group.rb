class APN::Group < APN::Base
  include Mongoid::Document
  include ActiveModel::Validations

  field :name, :type => String

  belongs_to :app, :class_name => 'APN::App'
  has_many   :device_groupings, :class_name => "APN::DeviceGrouping", :dependent => :destroy
  has_many   :group_notifications, :class_name => 'APN::GroupNotification'

  def devices
    device_groupings.flat_map(&:device)
  end

  def unsent_group_notifications
    group_notifications.unsent
  end

  validates_presence_of :app_id
  validates_uniqueness_of :name, :scope => :app_id
    
end
