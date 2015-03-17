class NilVitaFact < NullObject
  attr_reader :first_checkin, :last_checkin
  nought_methods :commits

  def commits_by_language
    []
  end

  def commits_by_project
    []
  end
end