class SessionsController < ApplicationController
  skip_before_action :store_location

  def create
    authenticator = Account::Authenticator.new(login: params[:login][:login], password: params[:login][:password])
    if authenticator.authenticated?
      initialize_session authenticator.account
    else
      flash[:error] = t '.error'
      render :new, status: :bad_request
    end
  end

  def destroy
    Account::Authenticator.forget(current_user) if logged_in?
    reset_session
    flash[:notice] = t '.success'
    redirect_back root_path
  end

  private

  def initialize_session(account)
    return if disabled_account?(account)
    return unless activated_account?(account)
    remember_me_if_requested(account)
    session[:account_id] = account.id
    return unless privacy_informed?(account)
    flash[:notice] = t '.success'
    redirect_back account_path(account)
  end

  def remember_me_if_requested(account)
    return unless params[:login][:remember_me] == '1'
    Account::Authenticator.remember(account)
    cookies[:auth_token] = { value: account.remember_token, expires: account.remember_token_expires_at }
  end

  def disabled_account?(account)
    return false unless Account::Access.new(account).disabled?
    flash[:error] = t '.disabled_error'
    render :new, status: :bad_request
    true
  end

  def activated_account?(account)
    return true if Account::Access.new(account).activated?
    flash[:error] = t '.unactivated_error'
    render :new, status: :bad_request
    false
  end

  def privacy_informed?(account)
    return true unless account.email_opportunities_visited.blank?
    flash[:notice] = t '.learn_about_privacy'
    redirect_to edit_account_privacy_account_path(account)
    false
  end
end