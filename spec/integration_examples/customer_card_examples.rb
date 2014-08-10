require 'spec_helper'

shared_examples "Multiple Customer Cards" do
  it "handles multiple cards" do
    tok1 = Stripe::Token.retrieve stripe_helper.generate_card_token :number => "4242424242420001"
    tok2 = Stripe::Token.retrieve stripe_helper.generate_card_token :number => "4242424242420002"

    cus = Stripe::Customer.create(:email => 'alice@bob.com', :card => tok1.id)
    default_card = cus.cards.first
    cus.cards.create(:card => tok2.id)

    cus = Stripe::Customer.retrieve(cus.id)
    expect(cus.cards.count).to eq(2)
    expect(cus.default_card).to eq default_card.id
  end

  it "gives the same two card numbers the same fingerprints" do
    tok1 = Stripe::Token.retrieve stripe_helper.generate_card_token :number => "4242424242424242"
    tok2 = Stripe::Token.retrieve stripe_helper.generate_card_token :number => "4242424242424242"

    cus = Stripe::Customer.create(:email => 'alice@bob.com', :card => tok1.id)

    cus = Stripe::Customer.retrieve(cus.id)
    card = cus.cards.find do |existing_card|
      existing_card.fingerprint == tok2.card.fingerprint
    end
    expect(card).to_not be_nil
  end

  it "gives different card numbers different fingerprints" do
    tok1 = Stripe::Token.retrieve stripe_helper.generate_card_token :number => "4242424242420001"
    tok2 = Stripe::Token.retrieve stripe_helper.generate_card_token :number => "4242424242420002"

    cus = Stripe::Customer.create(:email => 'alice@bob.com', :card => tok1.id)

    cus = Stripe::Customer.retrieve(cus.id)
    card = cus.cards.find do |existing_card|
      existing_card.fingerprint == tok2.card.fingerprint
    end
    expect(card).to be_nil
  end
end
