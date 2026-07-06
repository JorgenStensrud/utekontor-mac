# Homebrew cask for Utekontor. This repo is also a tap: see README.
# When cutting a new release, update version and sha256 to match the uploaded zip.
cask "utekontor" do
  version "0.1.3"
  sha256 "398923f399d12f6b9495819b56cc53b662d522a36cc0294bd09c70de8a2c2777"

  url "https://github.com/JorgenStensrud/utekontor-mac/releases/download/v#{version}/Utekontor-#{version}.zip"
  name "Utekontor"
  desc "Menylinje-lysstyrke, XDR-boost og DDC-kontroll for ekstern skjerm (notarisert utgivelse, hobbyprosjekt)"
  homepage "https://github.com/JorgenStensrud/utekontor-mac"

  depends_on macos: ">= :ventura"

  app "Utekontor.app"

  uninstall quit: "app.utekontor.macos"
end
