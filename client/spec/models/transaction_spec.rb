require 'spec_helper'
require 'rubicon/models/transaction'

describe Rubicon::Transaction do
  it "creates a valid transaction" do
    profile_id = 1
    transaction_id = 2
    seller_user_id = 5555
    buyer_user_id = 6666
    attrs = {seller_user_id: seller_user_id, buyer_user_id: buyer_user_id}
    entity = {'seller_user_id' => seller_user_id, 'buyer_user_id' => buyer_user_id}
    Rubicon::Transactions.expects(:fire_put).with(Rubicon::Transactions.profile_transaction_url(profile_id, transaction_id), is_a(Hash)).returns(entity)
    transaction = Rubicon::Transaction.create_or_update(profile_id, transaction_id, attrs)
    transaction.should be_a(Rubicon::Transaction)
  end

  it "does not create an invalid transaction" do
    profile_id = 1
    transaction_id = "deadbeef"
    Rubicon::Transactions.expects(:fire_put).never
    transaction = Rubicon::Transaction.create_or_update(profile_id, transaction_id, {})
    transaction.should be_a(Rubicon::Transaction)
  end
end
