module Comable
  class Order < ActiveRecord::Base
    belongs_to :customer, class_name: Comable::Customer.name, foreign_key: Comable::Customer.table_name.singularize.foreign_key, autosave: false
    belongs_to :payment, class_name: Comable::Payment.name, foreign_key: Comable::Payment.table_name.singularize.foreign_key, autosave: false
    belongs_to :shipment_method, class_name: Comable::ShipmentMethod.name, autosave: false
    belongs_to :bill_address, class_name: Comable::Address.name, autosave: true, dependent: :destroy
    belongs_to :ship_address, class_name: Comable::Address.name, autosave: true, dependent: :destroy
    has_many :order_details, dependent: :destroy, class_name: Comable::OrderDetail.name, foreign_key: table_name.singularize.foreign_key, inverse_of: :order

    accepts_nested_attributes_for :bill_address
    accepts_nested_attributes_for :ship_address
    accepts_nested_attributes_for :order_details

    with_options if: :completed? do |completed_order|
      completed_order.validates :code, presence: true
      completed_order.validates :email, presence: true
      completed_order.validates :shipment_fee, presence: true
      completed_order.validates :total_price, presence: true
    end

    with_options unless: :completed? do |incomplete_order|
      incomplete_order.validates Comable::Customer.table_name.singularize.foreign_key, uniqueness: { scope: [Comable::Customer.table_name.singularize.foreign_key, :completed_at] }, if: :customer
      incomplete_order.validates :guest_token, uniqueness: { scope: [:guest_token, :completed_at] }, if: :guest_token
    end

    define_model_callbacks :complete
    before_validation :generate_guest_token, on: :create
    before_validation :clone_addresses_from_customer, on: :create
    after_complete :clone_addresses_to_customer

    scope :complete, -> { where.not(completed_at: nil) }
    scope :incomplete, -> { where(completed_at: nil) }
    scope :by_customer, -> (customer) { where(Comable::Customer.table_name.singularize.foreign_key => customer) }

    delegate :full_name, to: :bill_address, allow_nil: true, prefix: :bill
    delegate :full_name, to: :ship_address, allow_nil: true, prefix: :ship

    def complete
      ActiveRecord::Base.transaction do
        run_callbacks :complete do
          save_to_complete.tap { |completed| self.completed_at = nil unless completed }
        end
      end
    end

    def complete!
      fail Comable::InvalidOrder unless complete
      self
    end

    def completed?
      !completed_at.nil?
    end

    # TODO: switch to state_machine
    def completing?
      completed_at && completed_at_was.nil?
    end

    def soldout_stocks
      order_details.to_a.select(&:soldout_stock?)
    end

    # 時価商品合計を取得
    def current_item_total_price
      order_details.to_a.sum(&:current_subtotal_price)
    end

    # 売価商品合計を取得
    def item_total_price
      order_details.to_a.sum(&:subtotal_price)
    end

    # 時価送料を取得
    def current_shipment_fee
      shipment_method.try(:fee) || 0
    end

    # 時価合計を取得
    def current_total_price
      current_item_total_price + current_shipment_fee
    end

    private

    def save_to_complete
      self.completed_at = Time.now
      self.shipment_fee = current_shipment_fee
      self.total_price = current_total_price
      generate_code

      order_details.each(&:complete)

      mark_for_validation_to_order_details
      save
    end

    def generate_code
      self.code = loop do
        random_token = "C#{Array.new(11) { rand(9) }.join}"
        break random_token unless self.class.exists?(code: random_token)
      end
    end

    def generate_guest_token
      return if customer
      self.guest_token ||= loop do
        random_token = SecureRandom.urlsafe_base64(nil, false)
        break random_token unless self.class.exists?(guest_token: random_token)
      end
    end

    def clone_addresses_from_customer
      return unless customer
      self.bill_address ||= customer.bill_address.try(:clone)
      self.ship_address ||= customer.ship_address.try(:clone)
    end

    def clone_addresses_to_customer
      return unless customer
      # TODO: Remove conditions for compatibility.
      customer.update_bill_address_by bill_address if bill_address
      customer.update_ship_address_by ship_address if ship_address
    end

    # HACK: to validate forced for nested attributes
    def mark_for_validation_to_order_details
      order_details.each(&:id_will_change!)
    end
  end
end
