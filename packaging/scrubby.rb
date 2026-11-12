# Homebrew cask template. To publish, put this in a tap repo (e.g. <you>/homebrew-tap,
# at Casks/scrubby.rb) and fill in the version, sha256 and GitHub owner.
# Users then install with:  brew install --cask <you>/tap/scrubby
cask "scrubby" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_OF_Scrubby.zip"

  url "https://github.com/Kudostoy0u/Scrubby/releases/download/v#{version}/Scrubby.zip"
  name "Scrubby"
  desc "Swipe through browser tabs and windows with your trackpad"
  homepage "https://github.com/Kudostoy0u/Scrubby"

  depends_on macos: ">= :sonoma"

  app "Scrubby.app"

  uninstall quit: "app.scrubby.Scrubby"

  zap trash: "~/Library/Preferences/app.scrubby.Scrubby.plist"
end
