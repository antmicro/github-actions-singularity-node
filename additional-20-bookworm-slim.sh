apt-get -qqy update
apt-get -qqy --no-install-recommends install git ca-certificates openssh-client zstd
rm -rf /var/lib/{apt,dpkg,cache,log}/
