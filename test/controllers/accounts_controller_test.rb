require 'test_helper'
require 'test_helpers/commits_by_project_data'
require 'test_helpers/commits_by_language_data'

describe 'AccountsController' do
  let(:start_date) { (Date.today - 6.years).beginning_of_month }
  let(:admin) { create(:admin) }

  describe 'index' do
    it 'should return claimed persons with their cbp_map and positions_map' do
      create_account_with_commits_by_project

      get :index

      must_respond_with :ok
      assigns(:positions_map).length.must_equal 2
      assigns(:people).length.must_equal 10
      assigns(:cbp_map).length.must_equal 10
    end

    it 'should support being queried via the api' do
      key = create(:api_key, account_id: create(:account).id)
      get :index, format: :xml, api_key: key.oauth_application.uid
      must_respond_with :ok
    end
  end

  describe 'show' do
    it 'should set the account and logos' do
      get :show, id: admin.login

      must_respond_with :ok
      assigns(:account).must_equal admin
      assigns(:logos).must_be_empty
    end

    it 'should support being queried via the api' do
      key = create(:api_key, account_id: create(:account).id)
      get :show, id: admin.login, format: :xml, api_key: key.oauth_application.uid
      must_respond_with :ok
    end

    it 'should support accounts with vitas' do
      best_vita = create(:best_vita)
      key = create(:api_key, account_id: create(:account).id)
      get :show, id: best_vita.account.to_param, format: :xml, api_key: key.oauth_application.uid
      must_respond_with :ok
    end

    it 'should redirect if account is disabled' do
      Account::Access.any_instance.stubs(:disabled?).returns(true)

      get :show, id: admin.login
      must_redirect_to disabled_account_url(admin)
    end

    it 'should redirect json requests if account is disabled' do
      Account::Access.any_instance.stubs(:disabled?).returns(true)

      get :show, id: admin.login, format: :json
      must_redirect_to disabled_account_url(admin)
    end

    it 'should redirect if account is labeled a spammer' do
      account = create(:account)
      account_access = Account::Access.new(account)
      account_access.spam!
      account_access.spam?.must_equal true
      account.level.must_equal Account::Access::SPAM
      get :show, id: account.id
      must_redirect_to disabled_account_url(account)
    end

    it 'should respond to json format' do
      get :show, id: admin.login, format: 'json'

      must_respond_with :ok
      assigns(:account).must_equal admin
    end
  end

  describe 'me' do
    it 'should redirect_to sign in page for unlogged users' do
      get :show, id: 'me'
      must_redirect_to new_session_path
    end

    it 'should render current_users account page for logged users' do
      account = create(:account)
      login_as account
      get :show, id: 'me'
      assigns(:account).must_equal account
      must_respond_with :ok
    end
  end

  describe 'unsubscribe_emails' do
    it 'a valid key for a account should unsubscribe the user' do
      key = Ohloh::Cipher.encrypt(create(:account).id.to_s)
      get :unsubscribe_emails, key: CGI.unescape(key)
      must_respond_with :ok
      assigns(:account).email_master.must_equal false
    end
  end

  describe 'new' do
    it 'must respond with success' do
      get :new

      must_respond_with :success
    end

    it 'must redirect to maintenance during read only mode' do
      ApplicationController.any_instance.stubs(:read_only_mode?).returns(true)
      get :new
      must_redirect_to maintenance_path
    end
  end

  describe 'disabled' do
    it 'must respond with success when queried via html' do
      get :disabled, id: create(:spammer).to_param
      must_respond_with :success
    end

    it 'must respond with success when queried via json' do
      get :disabled, id: create(:spammer).to_param, format: :json
      must_respond_with :success
    end
  end

  describe 'create' do
    let(:account_attributes) do
      FactoryGirl.attributes_for(:account).select do |k, _v|
        %w(login email email_confirmation password password_confirmation).include?(k.to_s)
      end
    end

    let(:account_params) { { account: account_attributes } }

    it 'must render the new template when validations fail' do
      post :create, account_params.merge(account: { email: '' })
      assigns(:account).wont_be :valid?
      must_render_template :new
    end

    it 'must redirect to maintenance during read only mode' do
      ApplicationController.any_instance.stubs(:read_only_mode?).returns(true)
      assert_no_difference 'Account.count' do
        post :create, account_params
        must_redirect_to maintenance_path
      end
    end

    it 'must require login' do
      assert_no_difference 'Account.count' do
        post :create, account_params.merge(account: { login: '' })
        assigns(:account).errors.messages[:login].must_be :present?
      end
    end

    it 'must require password' do
      assert_no_difference 'Account.count' do
        post :create, account_params.merge(account: { password: '' })
        assigns(:account).errors.messages[:password].must_be :present?
      end
    end

    it 'must require email and email_confirmation' do
      assert_no_difference 'Account.count' do
        post :create, account_params.merge(account: { email_confirmation: '', email: '' })
        assigns(:account).errors.messages[:email_confirmation].must_be :present?
        assigns(:account).errors.messages[:email_confirmation].must_be :present?
      end
    end

    it 'must create an action record when relevant params are passed' do
      person = create(:person)

      assert_difference 'Action.count', 1 do
        post :create, account_params.merge(_action: "claim_#{ person.id }")
      end

      action = Action.last
      action.status.must_equal 'after_activation'
      action.claim_person_id.must_equal person.id
      action.account_id.must_equal Account.last.id
    end

    it 'must redirect to the verification page after account is created' do
      assert_difference 'Account.count', 1 do
        post :create, account_params
      end

      created_account = Account.last
      @controller.send(:current_user).must_equal created_account
      must_redirect_to new_account_verification_path(created_account)
    end

    it 'must set digits related data to account object when rendering errors' do
      digits_credentials = Faker::Lorem.sentence
      digits_service_provider_url = Faker::Internet.url
      digits_oauth_timestamp = Faker::Number.number(10)
      post :create, account_params.merge(account: { password: '',
                                                    digits_credentials: digits_credentials,
                                                    digits_service_provider_url: digits_service_provider_url,
                                                    digits_oauth_timestamp: digits_oauth_timestamp })


      assigns(:account).wont_be :valid?
      assigns(:account).digits_credentials.must_equal digits_credentials
      assigns(:account).digits_service_provider_url.must_equal digits_service_provider_url
      assigns(:account).digits_oauth_timestamp.must_equal digits_oauth_timestamp
    end
  end

  describe 'edit' do
    it 'must redirect to verification page when not verified' do
      account = create(:account)
      account.update!(twitter_id: '')
      login_as account

      get :edit, id: account.id

      must_redirect_to new_account_verification_path(account)
    end

    it 'must respond with unauthorized when account does not exist' do
      get :edit, id: :anything
      must_respond_with :redirect
      must_redirect_to new_session_path
    end

    it 'must respond with success' do
      account = create(:account)
      login_as account
      get :edit, id: account.to_param
      must_render_template 'edit'
      must_respond_with :success
    end

    it 'must redirect to new_session if account is not owned' do
      account = create(:account)
      login_as account
      get :edit, id: create(:account).id
      must_redirect_to new_session_path
    end

    it 'must render the edit page if admin' do
      account = create(:account)
      login_as admin
      get :edit, id: account.id
      must_respond_with :success
    end

    it 'must logout spammer trying to edit or update' do
      account = create(:account)
      login_as account
      Account::Access.new(account).spam!

      get :edit, id: account.to_param
      must_respond_with :redirect
      must_redirect_to new_session_path
      session[:account_id].must_be_nil
      account.reload.remember_token.must_be_nil
      cookies[:auth_token].must_be_nil
    end
  end

  describe 'update' do
    let(:account) { create(:account) }
    before { login_as account }

    it 'must fail for invalid data' do
      url = :not_an_url
      post :update, id: account, account: { url: url }
      must_render_template 'edit'
      account.reload.url.wont_equal url
    end

    it 'must display description after a validation error' do
      text = 'about raw content'
      post :update, id: account.to_param, account: { email: '', about_raw: text }

      must_select 'textarea.edit-description', text: text
    end

    it 'must not allow description beyond 500 characters' do
      post :update, id: account.to_param, account: { about_raw: 'a' * 501 }

      assigns(:account).wont_be_nil
      assigns(:account).errors.wont_be_nil
      assigns(:account).errors.messages[:'markup.raw'].must_be :present?
      must_select "p.error[rel='markup.raw']", text: 'is too long (maximum is 500 characters)'
    end

    it 'must accept description within 500 characters' do
      post :update, id: account.to_param, account: {
        about_raw: 'a' * 99 + "\n" + 'a' * 99 + "\r" + 'a' * 300
      }
      must_redirect_to account
    end

    it 'must be successful' do
      location = 'Washington'
      post :update, id: account.to_param, account: { location: location }
      flash[:notice].must_equal 'Save successful!'
      account.reload.location.must_equal location
    end

    it 'must not allow updating other user\'s account' do
      post :update, id: create(:account).id, account: { location: :Wherever }
      must_redirect_to new_session_path
      flash.now[:error].must_match(/You can't edit another's account/)
    end
  end

  describe 'destroy' do
    it 'must allow deletion' do
      AnonymousAccount.create!
      account = create(:account)
      login_as account

      assert_difference 'Account.count', -1 do
        post :destroy, id: account.to_param
        must_redirect_to edit_deleted_account_path(account.login)
      end
    end

    it 'must not allow deletion by other accounts' do
      my_account = create(:account)
      your_account = create(:account)
      login_as my_account
      @controller.session[:account_id] = my_account.id

      assert_no_difference 'Account.count' do
        post :destroy, id: your_account.to_param
      end
      must_redirect_to edit_deleted_account_path(your_account)
    end

    it 'while deleting an account, edits.account_id and edits.undone_by should be marked with Anonymous Coward ID' do
      project = create(:project)
      account = create(:account)
      login_as account
      anonymous_account_id = Account.find_or_create_anonymous_account.id
      Edit.delete_all

      manage = project.manages.create!(account: account)
      manage.update!(approved_by: account.id)
      project.update!(best_analysis_id: nil, editor_account: account)

      project.edits.first.account_id.must_equal account.id
      project.edits.first.undone_by.must_equal nil

      post :destroy, id: account.to_param

      project.edits.first.account_id.must_equal anonymous_account_id
    end

    it 'when deleting an account set the approved_by and deleted_by fields to Anonymous Coward ID' do
      project = create(:project)
      account = create(:account)
      login_as account
      Edit.delete_all

      manage = project.manages.create!(account: account)
      manage.update!(approved_by: account.id)
      project.update!(best_analysis_id: nil, editor_account: account)

      project.manages.wont_be :empty?

      post :destroy, id: account.to_param

      project.reload.manages.must_be :empty?
    end
  end

  describe 'settings' do
    it 'should render settings' do
      get :settings, id: create(:account).id
    end
  end
end
