# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_10_203507) do
  create_table "games", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "game_state", null: false
    t.string "player_address", null: false
    t.string "player_commit", null: false
    t.datetime "commit_timestamp", null: false
    t.text "bet_amount"
    t.string "house_randomness"
    t.datetime "house_randomness_timestamp"
    t.string "player_secret"
    t.text "player_card"
    t.text "house_card"
    t.datetime "reveal_timestamp"
    t.integer "result", default: 0
    t.integer "total_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bet_amount"], name: "index_games_on_bet_amount"
    t.index ["commit_timestamp"], name: "index_games_on_commit_timestamp"
    t.index ["game_id"], name: "index_games_on_game_id", unique: true
    t.index ["player_address"], name: "index_games_on_player_address"
    t.index ["player_commit"], name: "index_games_on_player_commit"
    t.index ["result"], name: "index_games_on_result"
    t.index ["total_time"], name: "index_games_on_total_time"
  end
end
