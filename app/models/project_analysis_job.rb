# frozen_string_literal: true

class ProjectAnalysisJob < Job
  def progress_message
    I18n.t 'jobs.analyze_job.progress_message', name: project.name
  end
end
