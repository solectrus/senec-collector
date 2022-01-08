require 'senec'
require_relative './solectrus_record'

class SenecData
  def initialize(host)
    @request = Senec::Request.new host:
  end

  def solectrus_record
    SolectrusRecord.new(@request)
  end
end
