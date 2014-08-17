class CreateComableOrders < Comable::Migration
  def change
    create_table :comable_orders do |t|
      t.integer :comable_customer_id
      t.string :guest_token
      t.string :code
      t.string :family_name
      t.string :first_name
      t.datetime :completed_at
    end

    add_index :comable_orders, :code, unique: true, name: :comable_orders_idx_01
  end
end