# encoding: utf-8
#--
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2008 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 David Chelimsky <dchelimsky@gmail.com>
#   Copyright (C) 2008 Tim Dysinger <tim@dysinger.net>
#   Copyright (C) 2008 Tor Arne Vestbø <tavestbo@trolltech.com>
#   Copyright (C) 2009 Fabio Akita <fabio.akita@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

class Mailer < ActionMailer::Base
  include ActionView::Helpers::SanitizeHelper
  extend ActionView::Helpers::SanitizeHelper::ClassMethods
  include ActionController::UrlWriter
  def signup_notification(user)
    setup_email(user)
    @subject    += I18n.t "mailer.subject"
    @body[:url]  = url_for(
      :controller => 'users',
      :action => 'activate',
      :activation_code => user.activation_code
    )
  end

  def activation(user)
    setup_email(user)
    @subject    += I18n.t "mailer.activated"
  end

  def new_repository_clone(repository)
    setup_email(repository.parent.user)
    @subject += I18n.t "mailer.repository_clone", :login => repository.user.login,
      :slug => repository.parent.url_path
    @body[:user] = repository.parent.user
    @body[:cloner] = repository.user
    @body[:project] = repository.project
    @body[:repository] = repository
    url = if repository.owned_by_group?
      group_project_repository_url(repository.owner, repository.project, repository)
    else
      user_project_repository_url(repository.owner, repository.project, repository)
    end
    @body[:url] =  url
  end

  def notification_copy(recipient, sender, subject, body, notifiable, message_id)
    @recipients       =  recipient.email
    @from             = "Gitorious <no-reply@#{GitoriousConfig['gitorious_host']}>"
    @subject          = sanitize(subject)
    @body[:url]       = url_for({
                                  :controller => 'messages',
                                  :action => 'show',
                                  :id => message_id,
                                  :host => GitoriousConfig['gitorious_host']
                                })
    @body[:body]      = sanitize(body)
    if '1.9'.respond_to?(:force_encoding)
      @body[:recipient] = recipient.title.to_s.force_encoding("utf-8")
      @body[:sender]    = sender.title.to_s.force_encoding("utf-8")
    else
      @body[:recipient] = recipient.title.to_s
      @body[:sender]    = sender.title.to_s
    end
    if notifiable
      @body[:notifiable_url] = build_notifiable_url(notifiable) 
    end
  end

  def forgotten_password(user, password_key)
    setup_email(user)
    @subject += I18n.t "mailer.new_password"
    @body[:url] = reset_password_url(password_key)
  end
  
  def new_email_alias(email)
    @from       = "Gitorious <no-reply@#{GitoriousConfig['gitorious_host']}>"
    @subject    = "[Gitorious] Please confirm this email alias"
    @sent_on    = Time.now
    @recipients = email.address
    @body[:email] = email
    @body[:url] = confirm_user_alias_url(email.user, email.confirmation_code)
  end
  
  def message_processor_error(processor, err, message_body)
      subject     "[Gitorious Processor] fail in #{processor.class.name}"
      from        "Gitorious <no-reply@#{GitoriousConfig['gitorious_host']}>"
      recipients  GitoriousConfig['exception_notification_emails']
      body        :error => err, :message => message_body, :processor => processor
  end

  protected
    def setup_email(user)
      @recipients  = "#{user.email}"
      @from        = "Gitorious <no-reply@#{GitoriousConfig['gitorious_host']}>"
      @subject     = "[Gitorious] "
      @sent_on     = Time.now
      @body[:user] = user
    end
    
    def build_notifiable_url(a_notifiable)
      result = case a_notifiable
      when MergeRequest
        project_repository_merge_request_url(a_notifiable.target_repository.project, a_notifiable.target_repository, a_notifiable)        
      when Membership
        group_path(a_notifiable.group)
      end
      
      return result
    end
end
