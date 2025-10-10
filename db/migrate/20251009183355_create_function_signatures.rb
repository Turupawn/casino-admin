class CreateFunctionSignatures < ActiveRecord::Migration[8.0]
  def change
    create_table :function_signatures do |t|
      t.string :name
      t.string :signature_str
      t.string :signature_hex
      t.string :contract_name

      t.timestamps
    end
  end
end
