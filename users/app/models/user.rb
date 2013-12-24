class User < CouchRest::Model::Base
  include LoginFormatValidation

  use_database :users

  property :login, String, :accessible => true
  property :password_verifier, String, :accessible => true
  property :password_salt, String, :accessible => true

  property :enabled, TrueClass, :default => true

  # these will be null by default but we shouldn't ever pull them directly, but only via the methods that will return the full ServiceLevel
  property :desired_service_level_code, Integer, :accessible => true
  property :effective_service_level_code, Integer, :accessible => true

  before_save :update_effective_service_level

  validates :login, :password_salt, :password_verifier,
    :presence => true

  validates :login,
    :uniqueness => true,
    :if => :serverside?

  validate :login_is_unique_alias

  validates :password_salt, :password_verifier,
    :format => { :with => /\A[\dA-Fa-f]+\z/, :message => "Only hex numbers allowed" }

  validates :password, :presence => true,
    :confirmation => true,
    :format => { :with => /.{8}.*/, :message => "needs to be at least 8 characters long" }

  timestamps!

  design do
    own_path = Pathname.new(File.dirname(__FILE__))
    load_views(own_path.join('..', 'designs', 'user'))
    view :by_login
    view :by_created_at
  end # end of design

  def to_json(options={})
    {
      :login => login,
      :ok => valid?
    }.to_json(options)
  end

  def salt
    password_salt.hex
  end

  def verifier
    password_verifier.hex
  end

  def username
    login
  end

  def email_address
    LocalEmail.new(login)
  end

  # Since we are storing admins by login, we cannot allow admins to change their login.
  def is_admin?
    APP_CONFIG['admins'].include? self.login
  end

  def most_recent_tickets(count=3)
    Ticket.for_user(self).limit(count).all #defaults to having most recent updated first
  end

  def messages(unseen = true)

    user_messages = unseen ? UserMessage.by_user_id_and_seen(:key => [self.id, false]).all : UserMessage.by_user_id(:key => self.id).all

    messages = []
    user_messages.each do |um|
      messages << Message.find(um.message.id)
    end
    messages

  end

  # DEPRECATED
  #
  # Please set the key on the identity directly
  # WARNING: This will not be serialized with the user record!
  # It is only a workaround for the key form.
  def public_key=(value)
    identity.set_key(:pgp, value)
  end

  # DEPRECATED
  #
  # Please access identity.keys[:pgp] directly
  def public_key
    identity.keys[:pgp]
  end

  def account
    Account.new(self)
  end

  def identity
    @identity ||= Identity.for(self)
  end

  def refresh_identity
    @identity = Identity.for(self)
  end

  def desired_service_level
    code = self.desired_service_level_code || APP_CONFIG[:default_service_level]
    ServiceLevel.new({id: code})
  end

  def effective_service_level
    code = self.effective_service_level_code || self.desired_service_level.id
    ServiceLevel.new({id: code})
  end

  protected

  ##
  #  Validation Functions
  ##

  def login_is_unique_alias
    alias_identity = Identity.find_by_address(self.email_address)
    return if alias_identity.blank?
    if alias_identity.user != self
      errors.add(:login, "has already been taken")
    end
  end

  def password
    password_verifier
  end

  # used as a condition for validations that are server side only
  def serverside?
    true
  end

  def update_effective_service_level
    # TODO: Is this always the case? Might there be a situation where the admin has set the effective service level and we don't want it changed to match the desired one?
    if self.desired_service_level_code_changed?
      self.effective_service_level_code = self.desired_service_level_code
    end
  end

end
