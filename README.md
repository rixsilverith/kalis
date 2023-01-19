# Kustom [Arch Linux](https://archlinux.org/) Installation Script (Kalis) ![License](https://img.shields.io/github/license/rixsilverith/kalis?color=g)

An opinionated Bash script for an automated and configurable [Arch Linux](https://archlinux.org/) installation without (almost) any user intervention.

## Usage

> **Note** It is strongly recommended to have already installed Arch manually on a previous ocassion in order to have a
solid knowledge about how the installation process works and pretty much what each command does. If not the case, please,
give a read at the [official Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide).

Get the latest [Arch Linux installation medium](https://archlinux.org/download/) and write it to a bootable device (e.g. an
USB stick). Boot from the installation media as you would do in a usual Arch installation (see [Boot the live environment
(ArchWiki)](https://wiki.archlinux.org/title/Installation_guide#Boot_the_live_environment)) and load your keyboard map with the
`loadkeys [keymap]` command. Available keymaps can be listed by running `ls /usr/share/kbd/keymaps/**/*.map.gz`.

Note that Internet connection is required for the overall installation. If you are on a wired connection, you should be just fine.
Nevertheless, a wireless Wi-Fi connection can be setup by running the `iwctl` utility as
```console
iwctl --passphrase [WIFI_KEY] station [WIFI_ITF] connect [WIFI_ESSID]
```
where `[WIFI_ESSID]` is your network name, `[WIFI_KEY]` your network passphrase and `[WIFI_ITF]` is the name of interface
of your network adapter, which can be found by running `ip link show | grep -v "lo"`. This `[WIFI_ITF]` should look something
similar to `wlan0`.

Download the script, edit the `kalis.conf` with your own preferences and run the script.

```console
curl -sL https://raw.githubusercontent.com/rixsilverith/kalis/master/bootstrap.sh | bash
vim kalis.conf
./kalis.sh
```
Finally, `reboot` the system to end the installation process.

---

## License

This script is licensed under the GNU General Public License v3.0. For more information, see [LICENSE](LICENSE). A copy of the license is provided along with the code.

