require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::MiningWorkerStatusAgent do
  before(:each) do
    @valid_options = Agents::MiningWorkerStatusAgent.new.default_options
    @checker = Agents::MiningWorkerStatusAgent.new(:name => "MiningWorkerStatusAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
