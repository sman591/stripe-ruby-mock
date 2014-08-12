require 'spec_helper'

shared_examples 'Customer API' do

  it "creates a stripe customer with a default card" do
    customer = Stripe::Customer.create({
      email: 'johnny@appleseed.com',
      card: 'some_card_token',
      description: "a description"
    })
    expect(customer.id).to match(/^test_cus/)
    expect(customer.email).to eq('johnny@appleseed.com')
    expect(customer.description).to eq('a description')

    expect(customer.cards.count).to eq(1)
    expect(customer.cards.data.length).to eq(1)
    expect(customer.default_card).to_not be_nil
    expect(customer.default_card).to eq customer.cards.data.first.id

    expect { customer.card }.to raise_error
  end

  it "creates a stripe customer without a card" do
    customer = Stripe::Customer.create({
      email: 'cardless@appleseed.com',
      description: "no card"
    })
    expect(customer.id).to match(/^test_cus/)
    expect(customer.email).to eq('cardless@appleseed.com')
    expect(customer.description).to eq('no card')

    expect(customer.cards.count).to eq(0)
    expect(customer.cards.data.length).to eq(0)
    expect(customer.default_card).to be_nil
  end

  it 'creates a customer with a plan' do
    plan = stripe_helper.create_plan(id: 'silver')
    customer = Stripe::Customer.create(id: 'test_cus_plan', card: 'tk', :plan => 'silver')

    customer = Stripe::Customer.retrieve('test_cus_plan')
    expect(customer.subscriptions.count).to eq(1)
    expect(customer.subscriptions.data.length).to eq(1)

    expect(customer.subscriptions).to_not be_nil
    expect(customer.subscriptions.first.plan.id).to eq('silver')
    expect(customer.subscriptions.first.customer).to eq(customer.id)
  end

  it "creates a customer with a plan (string/symbol agnostic)" do
    plan = stripe_helper.create_plan(id: 'string_id')
    customer = Stripe::Customer.create(id: 'test_cus_plan', card: 'tk', :plan => :string_id)

    customer = Stripe::Customer.retrieve('test_cus_plan')
    expect(customer.subscriptions.first.plan.id).to eq('string_id')

    plan = stripe_helper.create_plan(:id => :sym_id)
    customer = Stripe::Customer.create(id: 'test_cus_plan', card: 'tk', :plan => 'sym_id')

    customer = Stripe::Customer.retrieve('test_cus_plan')
    expect(customer.subscriptions.first.plan.id).to eq('sym_id')
  end

  context "create customer" do

    it "with a trial when trial_end is set" do
      plan = stripe_helper.create_plan(id: 'no_trial', amount: 999)
      trial_end = Time.now.utc.to_i + 3600
      customer = Stripe::Customer.create(id: 'test_cus_trial_end', card: 'tk', plan: 'no_trial', trial_end: trial_end)

      customer = Stripe::Customer.retrieve('test_cus_trial_end')
      expect(customer.subscriptions.count).to eq(1)
      expect(customer.subscriptions.data.length).to eq(1)

      expect(customer.subscriptions).to_not be_nil
      expect(customer.subscriptions.first.plan.id).to eq('no_trial')
      expect(customer.subscriptions.first.status).to eq('trialing')
      expect(customer.subscriptions.first.current_period_end).to eq(trial_end)
      expect(customer.subscriptions.first.trial_end).to eq(trial_end)
    end

    it 'overrides trial period length when trial_end is set' do
      plan = stripe_helper.create_plan(id: 'silver', amount: 999, trial_period_days: 14)
      trial_end = Time.now.utc.to_i + 3600
      customer = Stripe::Customer.create(id: 'test_cus_trial_end', card: 'tk', plan: 'silver', trial_end: trial_end)

      customer = Stripe::Customer.retrieve('test_cus_trial_end')
      expect(customer.subscriptions.count).to eq(1)
      expect(customer.subscriptions.data.length).to eq(1)

      expect(customer.subscriptions).to_not be_nil
      expect(customer.subscriptions.first.plan.id).to eq('silver')
      expect(customer.subscriptions.first.current_period_end).to eq(trial_end)
      expect(customer.subscriptions.first.trial_end).to eq(trial_end)
    end

    it "returns no trial when trial_end is set to 'now'" do
      plan = stripe_helper.create_plan(id: 'silver', amount: 999, trial_period_days: 14)
      customer = Stripe::Customer.create(id: 'test_cus_trial_end', card: 'tk', plan: 'silver', trial_end: "now")

      customer = Stripe::Customer.retrieve('test_cus_trial_end')
      expect(customer.subscriptions.count).to eq(1)
      expect(customer.subscriptions.data.length).to eq(1)

      expect(customer.subscriptions).to_not be_nil
      expect(customer.subscriptions.first.plan.id).to eq('silver')
      expect(customer.subscriptions.first.status).to eq('active')
      expect(customer.subscriptions.first.trial_start).to be_nil
      expect(customer.subscriptions.first.trial_end).to be_nil
    end

    it "returns an error if trial_end is set to a past time" do
      plan = stripe_helper.create_plan(id: 'silver', amount: 999)
      expect {
        Stripe::Customer.create(id: 'test_cus_trial_end', card: 'tk', plan: 'silver', trial_end: Time.now.utc.to_i - 3600)
      }.to raise_error {|e|
        expect(e).to be_a(Stripe::InvalidRequestError)
        expect(e.message).to eq('Invalid timestamp: must be an integer Unix timestamp in the future')
      }
    end

    it "returns an error if trial_end is set without a plan" do
      expect {
        Stripe::Customer.create(id: 'test_cus_trial_end', card: 'tk', trial_end: "now")
      }.to raise_error {|e|
        expect(e).to be_a(Stripe::InvalidRequestError)
        expect(e.message).to eq('Received unknown parameter: trial_end')
      }
    end

  end

  it 'cannot create a customer with a plan that does not exist' do
    expect {
      customer = Stripe::Customer.create(id: 'test_cus_no_plan', card: 'tk', :plan => 'non-existant')
    }.to raise_error {|e|
      expect(e).to be_a(Stripe::InvalidRequestError)
      expect(e.message).to eq('No such plan: non-existant')
    }
  end

  it 'cannot create a customer with an exsting plan, but no card token' do
    plan = stripe_helper.create_plan(id: 'p')
    expect {
      customer = Stripe::Customer.create(id: 'test_cus_no_plan', :plan => 'p')
    }.to raise_error {|e|
      expect(e).to be_a(Stripe::InvalidRequestError)
      expect(e.message).to eq('You must supply a valid card')
    }
  end

  it "stores a created stripe customer in memory" do
    customer = Stripe::Customer.create({
      email: 'johnny@appleseed.com',
      card: 'some_card_token'
    })
    customer2 = Stripe::Customer.create({
      email: 'bob@bobbers.com',
      card: 'another_card_token'
    })
    data = test_data_source(:customers)
    expect(data[customer.id]).to_not be_nil
    expect(data[customer.id][:email]).to eq('johnny@appleseed.com')

    expect(data[customer2.id]).to_not be_nil
    expect(data[customer2.id][:email]).to eq('bob@bobbers.com')
  end

  it "retrieves a stripe customer" do
    original = Stripe::Customer.create({
      email: 'johnny@appleseed.com',
      card: 'some_card_token'
    })
    customer = Stripe::Customer.retrieve(original.id)

    expect(customer.id).to eq(original.id)
    expect(customer.email).to eq(original.email)
    expect(customer.default_card).to eq(original.default_card)
    expect(customer.subscriptions.count).to eq(0)
    expect(customer.subscriptions.data).to be_empty
  end

  it "cannot retrieve a customer that doesn't exist" do
    expect { Stripe::Customer.retrieve('nope') }.to raise_error {|e|
      expect(e).to be_a Stripe::InvalidRequestError
      expect(e.param).to eq('customer')
      expect(e.http_status).to eq(404)
    }
  end

  it "retrieves all customers" do
    Stripe::Customer.create({ email: 'one@one.com' })
    Stripe::Customer.create({ email: 'two@two.com' })

    all = Stripe::Customer.all
    expect(all.length).to eq(2)
    all.map(&:email).should include('one@one.com', 'two@two.com')
  end

  it "updates a stripe customer" do
    original = Stripe::Customer.create(id: 'test_customer_update')
    email = original.email

    original.description = 'new desc'
    original.save

    expect(original.email).to eq(email)
    expect(original.description).to eq('new desc')

    customer = Stripe::Customer.retrieve("test_customer_update")
    expect(customer.email).to eq(original.email)
    expect(customer.description).to eq('new desc')
  end

  it "updates a stripe customer's card" do
    original = Stripe::Customer.create(id: 'test_customer_update', card: 'token')
    card = original.cards.data.first
    expect(original.default_card).to eq(card.id)
    expect(original.cards.count).to eq(1)

    original.card = 'new_token'
    original.save

    new_card = original.cards.data.first
    expect(original.cards.count).to eq(1)
    expect(original.default_card).to eq(new_card.id)

    expect(new_card.id).to_not eq(card.id)
  end

  it "deletes a customer" do
    customer = Stripe::Customer.create(id: 'test_customer_sub')
    customer = customer.delete
    expect(customer.deleted).to be_true
  end

  context "With strict mode toggled off" do

    before { StripeMock.toggle_strict(false) }

    it "retrieves a stripe customer with an id that doesn't exist" do
      customer = Stripe::Customer.retrieve('test_customer_x')
      expect(customer.id).to eq('test_customer_x')
      expect(customer.email).to_not be_nil
      expect(customer.description).to_not be_nil
    end
  end

end
