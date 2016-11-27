class PostNotifier < ActionMailer::Base
  default from: 'mailer@blackducksoftware.com'

  def post_creation_notification(user_who_replied, topic)
    @user_who_replied = user_who_replied
    @topic = topic
    key = Account::Subscription.new(@user_who_replied).generate_unsubscription_key
    @unsubscribe_emails_url = unsubscribe_emails_accounts_url(notification_type: 'post', key: key)

    mail(to: @user_who_replied.email,
         subject: t('.subject'),
         template_path: 'mailers',
         template_name: 'post_notifier')
  end

  def post_replied_notification(user, user_who_replied, post)
    @user_who_needs_reply = user
    @user_who_replied = user_who_replied
    @topic = post.topic
    @post = post
    key = Account::Subscription.new(@user_who_needs_reply).generate_unsubscription_key
    to_email = @user_who_needs_reply.email
    @unsubscribe_emails_url = unsubscribe_emails_accounts_url(notification_type: 'post', key: key)
    mail(to: to_email, subject: t('.subject'), template_path: 'mailers', template_name: 'reply_notifier')
  end
end