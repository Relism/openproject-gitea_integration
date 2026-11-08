# frozen_string_literal: true

class CreateGiteaIntegrationTables < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/AbcSize
    create_table :gitea_users do |t|
      t.bigint :gitea_id, null: false
      t.string :login, null: false
      t.string :name
      t.string :html_url, null: false, index: { unique: true }
      t.string :avatar_url
      t.timestamps
    end

    create_table :gitea_pull_requests do |t|
      t.references :gitea_user, foreign_key: { on_delete: :nullify }
      t.references :merged_by, foreign_key: { to_table: :gitea_users, on_delete: :nullify }
      t.references :reviewed_by, foreign_key: { to_table: :gitea_users, on_delete: :nullify }
      t.bigint :gitea_id, null: false
      t.integer :number, null: false
      t.string :html_url, null: false, index: { unique: true }
      t.string :repository, null: false
      t.string :repository_html_url, null: false
      t.string :state, null: false
      t.boolean :draft, null: false, default: false
      t.string :title, null: false
      t.text :body
      t.jsonb :labels, null: false, default: []
      t.string :head_ref
      t.string :head_sha, index: true
      t.string :base_ref
      t.integer :additions
      t.integer :deletions
      t.integer :changed_files
      t.integer :comments_count
      t.string :review_state
      t.datetime :merged_at
      t.datetime :closed_at
      t.datetime :gitea_created_at
      t.datetime :gitea_updated_at
      t.timestamps
    end

    create_table :gitea_issues do |t|
      t.references :gitea_user, foreign_key: { on_delete: :nullify }
      t.bigint :gitea_id, null: false
      t.integer :number, null: false
      t.string :html_url, null: false, index: { unique: true }
      t.string :repository, null: false
      t.string :repository_html_url, null: false
      t.string :state, null: false
      t.string :title, null: false
      t.text :body
      t.jsonb :labels, null: false, default: []
      t.integer :comments_count
      t.datetime :closed_at
      t.datetime :gitea_created_at
      t.datetime :gitea_updated_at
      t.timestamps
    end

    create_table :gitea_branches do |t|
      t.references :work_package, null: false, foreign_key: { on_delete: :cascade }
      t.references :gitea_user, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.string :repository, null: false
      t.string :repository_html_url, null: false
      t.string :default_branch
      t.string :head_sha
      t.timestamps
      t.index %i[repository_html_url name], unique: true
    end

    create_table :gitea_commits do |t|
      t.references :gitea_user, foreign_key: { on_delete: :nullify }
      t.string :sha, null: false, index: true
      t.string :html_url, null: false, index: { unique: true }
      t.string :repository, null: false
      t.string :repository_html_url, null: false
      t.string :branch
      t.text :message, null: false, default: ""
      t.string :author_name
      t.string :author_email
      t.datetime :authored_at, null: false
      t.timestamps
    end

    create_table :gitea_checks do |t|
      t.bigint :gitea_id, null: false
      t.string :repository_html_url, null: false
      t.string :sha, null: false
      t.string :context, null: false
      t.string :state, null: false
      t.string :description
      t.string :target_url
      t.datetime :gitea_updated_at
      t.timestamps
      t.index %i[repository_html_url sha context], unique: true
    end

    create_table :gitea_workflow_runs do |t|
      t.references :gitea_user, foreign_key: { on_delete: :nullify }
      t.bigint :gitea_id, null: false
      t.string :html_url, null: false, index: { unique: true }
      t.string :repository_html_url, null: false
      t.string :workflow_name, null: false
      t.string :display_title
      t.string :event
      t.integer :run_number
      t.string :head_sha, null: false
      t.string :head_branch
      t.string :status, null: false
      t.string :conclusion
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :gitea_updated_at
      t.timestamps
      t.index %i[repository_html_url head_sha]
      t.index %i[repository_html_url head_branch]
    end

    %i[gitea_pull_requests gitea_issues gitea_commits].each do |table|
      create_join_table table, :work_packages do |t|
        t.index %I[#{table.to_s.singularize}_id work_package_id], unique: true
        t.index :work_package_id
      end
      add_foreign_key :"#{table}_work_packages", table, on_delete: :cascade
      add_foreign_key :"#{table}_work_packages", :work_packages, on_delete: :cascade
    end
  end
end
