class Account < ActiveRecord::Base
  include AffiliationValidation
  include AccountValidations
  include AccountAssociations
  include AccountScopes
  include AccountCallbacks

  attr_accessor :password, :current_password, :validate_current_password, :invite_code,
                :password_confirmation, :email_confirmation
  attr_writer :ip
  attr_reader :about_raw

  oh_delegators :stack_core, :project_core, :position_core, :claim_core
  strip_attributes :name, :email, :login, :invite_code, :twitter_account

  fix_string_column_encodings!
  serialize :reset_password_tokens, Hash

  def about_raw=(value)
    @about_raw = value
    about_markup_id.nil? ? build_markup(raw: value) : markup.raw = value
  end

  def anonymous?
    login == AnonymousAccount::LOGIN
  end

  def valid_current_password?
    authenticator = Account::Authenticator.new(login: login, password: current_password)
    return if authenticator.authenticated? && Account::Access.new(authenticator.account).active_and_not_disabled?
    errors.add(:current_password)
  end

  def to_param
    (login && login.match(Patterns::LOGIN_FORMAT)) ? login : id.to_s
  end

  # It's optional, but used if present by acts_as_editable.
  def ip
    defined?(@ip) ? @ip : '0.0.0.0'
  end

  def edit_count
    edits.where(undone: false).count
  end

  def best_vita
    Vita.where(id: best_vita_id, account_id: id).first || NilVita.new
  end

  def email_topics?
    email_master && email_posts
  end

  def email_kudos?
    email_master && email_kudos
  end

  # To speed up searching, we keep track of an account's 'aliases'.
  def update_akas
    akas = claimed_positions.includes(:name).map do |p|
      p.name.name
    end.uniq.join("\n")

    update_attribute(:akas, akas)
  end

  def run_actions(status)
    actions.where(status: status).each(&:run)
  end

  # Work around problem with has_many:
  # ActiveRecord::HasManyThroughAssociationPolymorphicError:
  #   Cannot have a has_many :through association 'Account#links' on the polymorphic object 'Target#target'.
  def links
    edits.where(target_type: 'Link', type: 'CreateEdit').where.not(undone: true).map(&:target)
  end

  def badges
    @badges ||= Badge.all_eligible(self)
  end

  def most_experienced_language
    language_facts = best_vita.vita_language_facts.ordered
    return if language_facts.empty?
    language_facts.first.language
  end

  def resend_activation!
    AccountMailer.signup_notification(self).deliver_now
    update!(activation_resent_at: Time.current)
  end

  # TODO: Replaces get_first_commit_date
  def first_commit_date
    first_checkin = best_vita.vita_fact.first_checkin
    return if first_checkin.blank?
    first_checkin.to_date.beginning_of_month
  end

  def kudo_rank
    person.try(:kudo_rank) || 1
  end

  def recent_kudos(limit = 3)
    kudos.order(created_at: :desc).limit(limit)
  end

  class << self
    def resolve_login(login)
      Account.where('lower(login) = ?', login.downcase).first
    end

    def hamster
      Account.find_by_login('ohloh_slave')
    end

    def uber_data_crawler
      @uber_data_crawler ||= Account.find_by_login('uber_data_crawler')
    end

    def non_human_ids
      where(login: %w(ohloh_slave uber_data_crawler)).pluck(:id)
    end

    def fetch_by_login_or_email(user_name)
      where(arel_table[:login].eq(user_name).or(arel_table[:email].eq(user_name))).take
    end

    def find_or_create_anonymous_account
      find_by(login: AnonymousAccount::LOGIN) || AnonymousAccount.create!
    end
  end
end
