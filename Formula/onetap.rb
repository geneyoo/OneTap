class Onetap < Formula
  desc "IDE-less iOS development CLI"
  homepage "https://github.com/geneyoo/onetap"
  url "https://github.com/geneyoo/onetap/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "275a15b36bff21e2b277814f493627c69d21ef1768d92ff5961b1115d95a2b74"
  license "MIT"

  depends_on xcode: ["15.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/tap"
  end

  test do
    system "#{bin}/tap", "--version"
  end
end
