# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new(:spec)

namespace :rbs do
  desc "Regenerate sig/generated from the rbs-inline annotations in lib/"
  task :generate do
    sh "rbs-inline", "--output=sig/generated", "lib"
  end

  # CI runs this so a forgotten regeneration fails the build instead of shipping stale signatures.
  desc "Fail if sig/generated is out of date with lib/"
  task drift: :generate do
    sh "git", "diff", "--exit-code", "--", "sig/generated"
  end
end

desc "Type-check lib/ against sig/"
task :steep do
  sh "steep", "check"
end

desc "Check Gemfile.lock for vulnerable gems (updates the advisory database first)"
task :audit do
  sh "bundle-audit", "check", "--update"
end

task default: [:rubocop, "rbs:drift", :steep, :spec]
