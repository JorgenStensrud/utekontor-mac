# Homebrew cask for Utekontor. This repo is also a tap: see README.
# When cutting a new release, update version and sha256 to match the uploaded zip.
cask "utekontor" do
  version "0.1.4"
  sha256 "6fd32857b74196b29cc553e945f598f749e39eed81a2667d3ccf0cbdf917a976"

  url "https://github.com/JorgenStensrud/utekontor-mac/releases/download/v#{version}/Utekontor-#{version}.zip"
  name "Utekontor"
  desc "Menylinje-lysstyrke, XDR-boost og DDC-kontroll for ekstern skjerm (notarisert utgivelse, hobbyprosjekt)"
  homepage "https://github.com/JorgenStensrud/utekontor-mac"

  depends_on macos: ">= :ventura"

  app "Utekontor.app"

  uninstall quit: "app.utekontor.macos"
end
