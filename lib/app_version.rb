# Version of this build, injected as ENV by the Dockerfile.
module AppVersion
  # COMMIT_VERSION (git describe) is a real version on branch builds, too,
  # whereas VERSION is just the branch name there. Both are empty strings
  # when the image is built outside CI, so blank counts as unset.
  def self.current
    ENV.values_at('COMMIT_VERSION', 'VERSION').find do |value|
      !value.to_s.strip.empty?
    end
  end
end
