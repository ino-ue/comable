module Comable
  class Customer < ActiveRecord::Base
    include Decoratable

    has_many :comable_orders, class_name: Comable::Order.name, foreign_key: table_name.singularize.foreign_key
    alias_method :orders, :comable_orders

    def initialize(*args)
      obj = args.first
      case obj.class.name
      when /Cookies/
        @cookies = obj
        super()
      else
        super
      end
    end

    def logged_in?
      !new_record?
    end

    def not_logged_in?
      !logged_in?
    end

    def add_cart_item(obj, quantity: 1)
      process_cart_item(obj) do |stock|
        add_stock_to_cart(stock, quantity)
      end
    end

    def remove_cart_item(obj, quantity: -1)
      process_cart_item(obj) do |stock|
        add_stock_to_cart(stock, quantity)
      end
    end

    def reset_cart_item(obj, quantity: 0)
      process_cart_item(obj) do |stock|
        reset_stock_from_cart(stock, quantity)
      end
    end

    def reset_cart
      cart_items.destroy_all
    end

    def cart_items
      init_cart
    end

    def cart
      Cart.new(cart_items)
    end

    class Cart < Array
      def price
        sum(&:subtotal_price)
      end
    end

    def init_cart
      incomplete_order.order_deliveries.first.order_details
    end

    def load_cart
      Comable::Order
        .incomplete
        .includes(order_deliveries: :order_details)
        .where(
          Comable::Customer.table_name.singularize.foreign_key => id,
          :guest_token => current_guest_token
        )
        .limit(1)
    end

    def incomplete_order
      @incomplete_order ||= init_incomplete_order
    end

    def init_incomplete_order
      orders = load_cart
      return orders.first if orders.exists?
      orders.create!(family_name: family_name, first_name: first_name, order_deliveries_attributes: [{ family_name: family_name, first_name: first_name }])
    end

    def preorder(order_params = {})
      incomplete_order.attributes = order_params
      incomplete_order.precomplete
    end

    def order(order_params = {})
      incomplete_order.attributes = order_params
      result = incomplete_order.complete
      @incomplete_order = nil
      result
    end

    private

    def current_guest_token
      return if logged_in?
      @cookies.signed[:guest_token]
    end

    def process_cart_item(obj)
      case obj
      when Comable::Product
        yield obj.stocks.first
      when Comable::Stock
        yield obj
      when Array
        obj.map { |item| yield item }
      else
        fail
      end
    end

    def add_stock_to_cart(stock, quantity)
      fail I18n.t('comable.carts.product_not_stocked') if stock.soldout?

      cart_items = find_cart_items_by(stock)
      if cart_items.any?
        cart_item = cart_items.first
        cart_item.quantity += quantity
        (cart_item.quantity > 0) ? cart_item.save : cart_item.destroy
      else
        cart_item = cart_items.create(quantity: quantity)
        @cookies.permanent.signed[:guest_token] = cart_item.guest_token if not_logged_in? && !current_guest_token
      end
    end

    def reset_stock_from_cart(stock, quantity)
      cart_items = find_cart_items_by(stock)
      if quantity > 0
        return add_stock_to_cart(stock, quantity) if cart_items.empty?
        cart_item = cart_items.first
        cart_item.quantity = quantity
        cart_item.save
      else
        return false if cart_items.empty?
        cart_item.destroy
      end
    end

    def find_cart_items_by(stock)
      fail I18n.t('comable.carts.product_not_found') unless stock.is_a?(Comable::Stock)
      cart_items.where(Comable::Stock.table_name.singularize.foreign_key => stock.id)
    end
  end
end
