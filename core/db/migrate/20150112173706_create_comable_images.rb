class CreateComableImages < ActiveRecord::Migration
  def change
    create_table :comable_images do |t|
      t.references :product, null: false, index: true
      t.string :file, null: false
      t.timestamps null: false
    end
  end
end
