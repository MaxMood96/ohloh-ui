FactoryGirl.define do
  factory :commit do
    association :code_set
    association :name
    time { Time.current.at_beginning_of_month }
  end
end
