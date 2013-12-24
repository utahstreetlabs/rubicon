require 'ladon/model'
require 'rubicon/resource/transactions'

module Rubicon
  class Transaction < Ladon::Model
    attr_accessor :profile_id, :transaction_id
    validates :transaction_id, presence: true, numericality: {only_integer: true}

    # Creates and returns a +Transaction+ based on the provided attributes hash.  Returns nil if
    # the service request fails.
    def self.create_or_update(profile_id, transaction_id, attrs)
      transaction = new({transaction_id: transaction_id}.merge(attrs))
      if transaction.valid?
        entity = transaction.serializable_hash(except: [:id, :created_at, :updated_at, :transaction_id])
        saved = Transactions.fire_put(Transactions.profile_transaction_url(profile_id, transaction_id), entity)
        saved ? new(saved) : nil
      else
        transaction
      end
    end
  end
end
