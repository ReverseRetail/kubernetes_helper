# frozen_string_literal: true

namespace :kubernetes_helper do
  desc 'Verify yml files for possible errors.
        Sample: DEPLOY_ENV=beta rake kubernetes_helper:verify_yml_files'
  task :verify_yml_files do
    ARGV.each { |a| task a.to_sym do; end }
    # TODO: ...
  end
end
