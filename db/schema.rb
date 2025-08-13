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

ActiveRecord::Schema[8.0].define(version: 2025_08_13_050742) do
  create_table "meetings", force: :cascade do |t|
    t.integer "municipality_id", null: false
    t.string "meeting_type"
    t.string "video_id"
    t.string "video_url"
    t.date "held_on"
    t.text "transcript"
    t.text "summary"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["municipality_id"], name: "index_meetings_on_municipality_id"
    t.index ["video_id"], name: "index_meetings_on_video_id"
  end

  create_table "municipalities", force: :cascade do |t|
    t.string "name"
    t.string "youtube_playlist_url"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_municipalities_on_slug", unique: true
  end

  add_foreign_key "meetings", "municipalities"
end
