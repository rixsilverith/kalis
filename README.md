## Kustom Arch Linux Install Script (Kalis)

> A custom bash script that automatically installs Arch Linux without (almost) any user intervention.

### System installation

> Before moving on, it is strongly recommended to have already installed Arch manually on a previous ocassion, to know
how the installation process works and pretty much what each command does. If not the case, please, give a read at the
[official Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide).

Get the latest [Arch Linux installation medium](https://archlinux.org/download/) and write it to a USB stick. Boot 
from the installation media as you would do in a usual Arch installation and load your keyboard map with the
`loadkeys [keymap]` command. For instance, `loadkeys de-latin1` will load a german keyboard configuration.

Internet connection is required for the overall installation. If you are on a wired connection, you should be just fine.
Nevertheless, a wireless WIFI connection can be setup by running the `iwctl` utility as 
```bash
iwctl --passphrase "[WIFI_KEY]" station [WIFI_INTERFACE] connect "[WIFI_ESSID]"
```
where `WIFI_ESSID` is your network name, `WIFI_KEY` your network passphrase and `WIFI_INTERFACE` is the name of interface
of your network adapter, which can be found by running `ip link show | grep -v "lo"`. This `WIFI_INTERFACE` should look something 
similar to `wlan0`.

Download the script, edit the `kalis.conf` with your own preferences and run the script.

```bash
curl -sL https://raw.githubusercontent.com/rixsilverith/kalis/master/bootstrap.sh | bash
vim kalis.conf
./kalis.sh
```
Finally, `reboot` the system to end the installation process.

### Bootstraping dotfiles after installation

**Kalis** is capable of bootstraping dotfiles once the installation is done if wanted through a remote script. For this, set the 
value of the `DOTFILES_BOOTSTRAP_SCRIPT` in the `kalis.conf` file to the URL of the remote script.

[What are dotfiles?](https://medium.com/@webprolific/getting-started-with-dotfiles-43c3602fd789) | [Bootstrap script example](https://raw.githubusercontent.com/rixsilverith/dots/master/bootstrap.sh)

### License

This script is licensed under the GNU General Public License v3.0. For more information, see [LICENSE](LICENSE).

