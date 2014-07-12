require 'spec_helper'

shared_examples 'Refund API' do

  it "refunds a stripe charge item" do
    charge = Stripe::Charge.create(
      amount: 999,
      currency: 'USD',
      card: 'card_token_abcde',
      description: 'card charge'
    )

    charge = charge.refund(amount: 999)

    expect(charge.refunded).to eq(true)
    expect(charge.refunds.data.first.amount).to eq(999)
    expect(charge.amount_refunded).to eq(999)
  end

  it "creates a stripe refund with the charge ID", :live => true do
    charge = Stripe::Charge.create(
      amount: 999,
      currency: 'USD',
      card: stripe_helper.generate_card_token,
      description: 'card charge'
    )
    refund = charge.refund

    expect(charge.id).to match(/^(test_)?ch/)
    expect(refund.id).to eq(charge.id)
  end

  it "creates a stripe refund with a refund ID" do
    charge = Stripe::Charge.create(
      amount: 999,
      currency: 'USD',
      card: 'card_token_abcde',
      description: 'card charge'
    )
    refund = charge.refund

    expect(refund.refunds.data.count).to eq 1
    expect(refund.refunds.data.first.id).to match(/^test_re/)
  end

  it "creates a stripe refund with a different balance transaction than the charge" do
    charge = Stripe::Charge.create(
      amount: 999,
      currency: 'USD',
      card: 'card_token_abcde',
      description: 'card charge'
    )
    refund = charge.refund

    expect(charge.balance_transaction).not_to eq(refund.refunds.data.first.balance_transaction)
  end
end
