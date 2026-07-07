# Homebrew cask for Utekontor. This repo is also a tap: see README.
# When cutting a new release, update version and sha256 to match the uploaded zip.
cask "utekontor" do
  version "0.1.5"
  sha256 "ac4549a72ae73f88810a70565faa10aac31c0fd2e47eec44a5389f5b262ba703"

  url "https://github.com/JorgenStensrud/utekontor-mac/releases/download/v#{version}/Utekontor-#{version}.zip"
  name "Utekontor"
  desc "Menylinje-lysstyrke, XDR-boost og DDC-kontroll for ekstern skjerm (notarisert utgivelse, hobbyprosjekt)"
  homepage "https://github.com/JorgenStensrud/utekontor-mac"

  depends_on macos: :ventura

  app "Utekontor.app"

  uninstall quit: "app.utekontor.macos"
end
