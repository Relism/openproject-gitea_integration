# frozen_string_literal: true

# Plugin specs run inside OpenProject core (see bin/dev test), so this loads core's spec helper.
require "spec_helper"
Dir[File.join(__dir__, "support/**/*.rb")].each { require it }
