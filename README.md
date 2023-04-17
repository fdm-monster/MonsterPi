# MonsterPi

TBD

This repository is a Raspberry Pi image builder for running FDM Monster.
The work is a culmination of CustomPiOS, FarmPi by M.Kevenaar and my own private 4xOctoPrint Pi OS image.

Please check out FDM Monster here: https://github.com/fdm-monster/fdm-monster

## How to use it?

> :warning: This image is not running [Raspberry Pi OS](https://www.raspberrypi.org/software/), therefore `raspi-config` is not available

* Unzip the image and install it to an sd card [like any other Raspberry Pi image](https://www.raspberrypi.org/documentation/installation/installing-images/README.md)
* Configure your WiFi by editing `monsterpi-wpa-supplicant.txt` on the root of the flashed card when using it like a thumb drive, or use an UTP cable
* Boot the Pi from the card
* Log into your Pi via SSH (it is located at `monsterpi.local` [if your computer supports bonjour](https://learn.adafruit.com/bonjour-zeroconf-networking-for-windows-and-linux/overview) or find the IP address assigned by your router), default username is "pi", default password is "raspberry".
  * To Change the password; run: `passwd`
  * Optionally: Change the configured timezone; run: `sudo dpkg-reconfigure tzdata`
  * Optionally: Change the hostname; run: `echo myhostname | sudo tee /etc/hostname`

    Your MonsterPi instance will then no longer be reachable under `monsterpi.local` but rather the hostname you chose postfixed with `.local`, so keep that in mind.

FDM Monster is located at [http://monsterpi.local](http://monsterpi.local) and also at [https://monsterpi.local](https://monsterpi.local). Since the SSL certificate is self signed (and generated upon first boot), you will get a certificate warning at the latter location, please ignore it.

## Features

* [FDM Monster](https://fdm-monster.net) software for managing and monitoring 100+ Octoprint instances
* [Ubuntu](https://ubuntu.com/download/raspberry-pi) Raspberry Pi distro image.
