# Homebrew cask for Utekontor. This repo is also a tap: see README.
# When cutting a new release, update version and sha256 to match the uploaded zip.
cask "utekontor" do
  version "0.1.1"
  sha256 "483d0066ae41172d6bcd177787dbf16188011cf5a837e7acc7a6c158d88a416a"

  url "https://github.com/JorgenStensrud/utekontor-mac/releases/download/v#{version}/Utekontor-#{version}.zip"
  name "Utekontor"
  desc "Menu bar brightness, XDR boost, and external display control"
  homepage "https://github.com/JorgenStensrud/utekontor-mac"

  depends_on macos: ">= :ventura"

  app "Utekontor.app"
end
