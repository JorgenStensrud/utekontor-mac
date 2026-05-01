# Homebrew cask for Utekontor. This repo is also a tap: see README.
# When cutting a new release, update version and sha256 to match the uploaded zip.
cask "utekontor" do
  version "0.1.2"
  sha256 "605cd27a08bd1ecb6fe31fd25bac2203e950170b52fcff1b7a3c2c40abe7e6fe"

  url "https://github.com/JorgenStensrud/utekontor-mac/releases/download/v#{version}/Utekontor-#{version}.zip"
  name "Utekontor"
  desc "Menu bar brightness, XDR boost, and external display control"
  homepage "https://github.com/JorgenStensrud/utekontor-mac"

  depends_on macos: ">= :ventura"

  app "Utekontor.app"
end
