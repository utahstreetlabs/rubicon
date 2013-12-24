require 'rubicon/resource/base'

module Rubicon
  class Transactions < Resource::Base
    def self.profile_transaction_url(profile_id, transaction_id)
      absolute_url("/profiles/#{profile_id}/transactions/#{transaction_id}")
    end
  end
end
