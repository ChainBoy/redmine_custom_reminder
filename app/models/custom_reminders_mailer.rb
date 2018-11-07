class CustomRemindersMailer < Mailer
  layout 'mailer'

  def custom_reminder(user, issues)
    @issues = issues
    @issues_url = url_for(controller: 'issues', action: 'index',
                          set_filter: 1, assigned_to_id: user.id,
                          sort: 'due_date:asc')

    mail to: user,
         subject: l(:mail_custom_reminder_subject, count: issues.size)
  end

  def self.custom_reminders(options={})
    user_ids = options[:users]
    project = options[:project] ? Project.find(options[:project]) : nil
    projects = options[:projects] ? Project.where(:id => options[:projects]).to_a : nil

    scope = Issue.open.where("#{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
    scope = scope.where("#{Issue.table_name}.updated_on <= ?", options[:trigger_param].day.until(Date.today)) if options[:trigger] == 'due_date'
    scope = scope.where(:assigned_to_id => user_ids) if user_ids.present? && options[:notification_recipient] == 'assigned_to'
    scope = scope.where(:project_id => project.id) if project
    scope = scope.where(:project_id => projects) if projects

    issues_by_assignee = scope.includes(:status, :assigned_to, :project, :tracker).
        group_by(&:assigned_to)

    issues_by_assignee.keys.each do |assignee|
      if assignee.is_a?(Group)
        assignee.users.each do |user|
          issues_by_assignee[user] ||= []
          issues_by_assignee[user] += issues_by_assignee[assignee]
        end
      end
    end

    issues_by_assignee.each do |assignee, issues|
      if assignee.is_a?(User) && assignee.active? && issues.present?
        visible_issues = issues.select { |i| i.visible?(assignee) }
        custom_reminder(assignee, visible_issues).deliver_later if visible_issues.present?
      end
    end
  end
end