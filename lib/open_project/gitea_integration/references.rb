# frozen_string_literal: true

module OpenProject::GiteaIntegration
  # Work package references in Gitea titles, descriptions, comments and commit messages:
  #   OP#42, OP#PROJ-42                  links the item and comments on the work package
  #   PP#42                              links the item without commenting ("private" reference)
  #   http(s)://<host>/work_packages/42  same as OP#, also with /wp/ and sub-paths
  # Branch names reference a work package when a path segment starts with its id
  # ("feature/42-checkout", "PROJ-42") or, failing that, contain a semantic id ("fix-proj-42-login").
  class References
    attr_reader :ids, :silent_ids

    def self.in_text(*texts)
      text = texts.compact.join("\n")
      wp_id = WorkPackage::SemanticIdentifier::ID_ROUTE_CONSTRAINT
      url = %r{https?://#{Regexp.escape(Setting.host_name)}/(?:\S+?/)*(?:work_packages|wp)/(#{wp_id})}

      loud = text.scan(/(?<![A-Za-z0-9])OP#(#{wp_id})|#{url}/).filter_map { it.compact.first }.map(&:upcase)
      silent = text.scan(/(?<![A-Za-z0-9])PP#(#{wp_id})/).flatten.map(&:upcase)
      new(ids: loud + silent, silent_ids: silent - loud)
    end

    def self.in_branch(name)
      wp_id = WorkPackage::SemanticIdentifier::ID_ROUTE_CONSTRAINT.source
      semantic_id = WorkPackage::SemanticIdentifier::SEMANTIC_ID_PATTERN.source
      prefixed = /\A(#{wp_id})(?:[-_.].*)?\z/i
      embedded = /(?<![A-Za-z0-9_])(#{semantic_id})(?![A-Za-z0-9_])/i

      ids = name.to_s.split("/").filter_map { prefixed.match(it)&.captures&.first }
      ids = name.to_s.scan(embedded).flatten if ids.empty?
      new(ids: ids.first(1).map(&:upcase))
    end

    def initialize(ids:, silent_ids: [])
      @ids = ids.uniq
      @silent_ids = silent_ids.uniq
    end

    # Referenced work packages the user may comment on — the permission GitHub and GitLab require, too.
    def work_packages(user)
      return [] if ids.empty? || user.nil?

      WorkPackage.includes(:project)
                 .where_display_id_in(ids)
                 .select { user.allowed_in_work_package?(:add_work_package_comments, it) }
    end

    def silent?(work_package)
      @silent_pks ||= WorkPackage.ids_by_display_id(silent_ids).values
      @silent_pks.include?(work_package.id)
    end
  end
end
