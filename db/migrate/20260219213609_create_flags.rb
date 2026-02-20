class CreateFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :flags do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.text :description

      t.timestamps
    end
    add_index :flags, :key, unique: true
  end
end
