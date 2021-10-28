apt-get -qqy update
apt-get -qqy --no-install-recommends install git
rm -rf /var/lib/{apt,dpkg,cache,log}/
