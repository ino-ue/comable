describe Comable::Order do
  subject(:order) { FactoryGirl.build(:order) }

  subject { order }

  it { is_expected.to belong_to(:bill_address).class_name(Comable::Address.name).dependent(:destroy) }
  it { is_expected.to belong_to(:ship_address).class_name(Comable::Address.name).dependent(:destroy) }
  it { is_expected.to have_one(:shipment).class_name(Comable::Shipment.name).dependent(:destroy).inverse_of(:order) }

  describe 'validations' do
    context 'when user is registered' do
      before { subject.attributes = { guest_token: nil, user: FactoryGirl.create(:user) } }
      before { subject.save }

      it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:completed_at) }
    end

    context 'when user is guest' do
      before { subject.attributes = { guest_token: 'abc123', user: nil } }
      before { allow(subject).to receive(:generate_guest_token) }

      it { is_expected.to validate_presence_of(:guest_token) }
      it { is_expected.to validate_uniqueness_of(:guest_token).scoped_to(:completed_at) }
    end

    describe 'for order items' do
      let!(:order_item) { FactoryGirl.create(:order_item, stock: stock, order: order) }

      context 'when out of stock' do
        let(:stock) { FactoryGirl.create(:stock, :stocked, :with_product) }

        it 'has errors' do
          stock.update_attributes(quantity: 0)
          expect { order.complete! }.to raise_error(ActiveRecord::RecordInvalid, /#{stock.name_with_sku}/)
          expect(order.errors['order_items.quantity'].any?).to be
        end
      end
    end
  end

  describe 'attributes' do
    describe '#save' do
      context 'complete order' do
        let!(:order_item) { FactoryGirl.create(:order_item, order: order, quantity: 10) }

        let(:stock) { order_item.stock }
        let(:product) { stock.product }
        let(:item_total_price) { product.price * order_item.quantity }

        before { subject.complete }
        before { subject.reload }

        its(:completed_at) { should be }
        its(:code) { should match(/^C\d{11}$/) }
        its(:total_price) { should eq(item_total_price) }

        it 'has been subtracted stock' do
          expect { stock.reload }.to change { stock.quantity }.from(order_item.quantity).to(0)
        end

        context 'with shipment method' do
          subject(:order) { FactoryGirl.build(:order, :for_shipment, shipment: shipment) }

          let(:shipment) { FactoryGirl.build(:shipment) }

          its(:shipment_fee) { is_expected.to eq(shipment.fee) }
          its(:total_price) { is_expected.to eq(item_total_price + shipment.fee) }

          it 'shipment has been ready' do
            expect(order.shipment.state).to eq('ready')
          end
        end

        context 'with user' do
          subject(:order) { FactoryGirl.build(:order, user: user, bill_address: address, ship_address: address) }

          let(:address) { FactoryGirl.create(:address) }

          context 'has addresses used in order' do
            let(:user) { FactoryGirl.create(:user, addresses: [address]) }

            it 'has copied address from order to user' do
              user.reload
              expect(user.bill_address).to eq(address)
              expect(user.ship_address).to eq(address)
            end
          end

          context 'has addresses not used in order' do
            let(:user) { FactoryGirl.create(:user, :with_addresses) }

            it 'has cloned address from order to user' do
              user.reload
              expect(user.bill_address.attributes_without_id).to eq(address.attributes_without_id)
              expect(user.ship_address.attributes_without_id).to eq(address.attributes_without_id)
            end
          end
        end
      end

      context 'incomplete order' do
        before { subject.save }
        before { subject.reload }

        its(:completed_at) { should be_nil }
        its(:code) { should be_nil }

        context 'with user address' do
          subject(:order) { FactoryGirl.build(:order, user: user) }

          let(:user) { FactoryGirl.create(:user, :with_addresses) }

          its(:bill_address) { is_expected.to be }
          its(:ship_address) { is_expected.to be }
        end
      end
    end
  end
end
