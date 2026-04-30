# Homebrew cask for Utekontor. This repo is also a tap: see README.
# When cutting a new release, update version and sha256 to match the uploaded zip.
cask "utekontor" do
  version "0.1.0"
  sha256 "aa312121e2a66f1d30cc4c06ffada35ea1b72a7da786d799c039aec2dcb249ee"

  url "https://github.com/JorgenStensrud/utekontor-mac/releases/download/v#{version}/Utekontor-#{version}.zip"
  name "Utekontor"
  desc "Menu bar brightness, XDR boost, and external display control"
  homepage "https://github.com/JorgenStensrud/utekontor-mac"

  depends_on macos: ">= :ventura"

  app "Utekontor.app"
end
