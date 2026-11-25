# vc520-ports

Enables the LAN switch ports on a **VeloCloud Edge 520** re-imaged with **Turnium SD-WAN** (Debian 12).

After a fresh Turnium install only `eth0`/`eth1` appear. This package brings up the rest at every boot.

## Port map

| Front port | Hardware | Linux |
|---|---|---|
| GE1 / GE2 (RJ45 or SFP combo) | Intel I350 `04:00.0/.1` | `eth0` / `eth1`, work out of the box |
| LAN1–LAN6 | Marvell 88E6176 switch, uplinked to I354 `00:14.0` over SerDes (switch port 4) | **`eth2`**, shared by all LAN ports |
| (internal) | I354 `00:14.1`, `00:14.2` | `eth3`, `eth4`, not wired to a front port as far as tested |
| (internal) | I354 `00:14.3` | left unbound on purpose, used to manage the switch |

## Why it's needed

1. **The I354 ports fail to start.** You'll see `igb: probe of 0000:00:14.x failed with error -2` and `MDI Error` in `dmesg`. The NVM (the port's onboard settings chip) says "SGMII with an external PHY at MDIO address 0", but no PHY answers there. The fix: switch the port to 1000BASE-KX link mode, which needs no PHY, before binding it to `igb`.
2. **The 88E6176 comes out of reset with everything off.** All 7 ports are disabled and all PHYs plus the SerDes are powered down. VeloCloud's firmware normally enables them. The fix: power them up and set every port to Forwarding over MDIO. The switch then behaves as an unmanaged switch.

## Install

```bash
git clone https://github.com/<org>/vc520-ports.git   # or copy the release tarball
cd vc520-ports
sudo ./install.sh --now
```

This installs `/usr/local/sbin/vc520-ports`, `vc520-ports.service` (runs before `network-pre.target`) and `/etc/default/vc520-ports`.

## Use

```bash
vc520-ports status      # I354 binding + switch port/PHY/SerDes state
vc520-ports watch       # live PHY link monitor while you plug cables
vc520-ports up          # what the boot service runs (safe to re-run)
journalctl -u vc520-ports
```

In Turnium, configure **`eth2` as the LAN / Connected-IP interface, not as a leg**.

## Status / known gaps (v0.1.0)

- [x] I354 ports bind (`eth2`–`eth4`), and `eth2` gets a 1G link to the switch.
- [x] Switch PHYs and SerDes powered up, all ports forwarding.
- [ ] **Front LAN jacks not yet confirmed to link.** In testing, PHYs 0–3 never saw link partners.
      The jack→PHY mapping still needs to be confirmed with `vc520-ports watch`.
- [ ] LAN5/LAN6 are probably behind switch ports 5 and 6 (RGMII) through external PHYs that aren't initialized yet.
- [ ] Per-port VLANs (88E6176 VTU), so each LAN jack can be mapped to `eth2.<vid>`.
- [ ] Interface names depend on bind order (`eth0`/`eth1` first, then `eth2`…). Pin them with systemd `.link` files if a future kernel starts binding the I354 ports at boot.

## Turnium boot order

If the Turnium agent starts before this service and misses `eth2`, add a drop-in:

```bash
systemctl edit vc520-ports    # add:  [Unit]  Before=<turnium-agent>.service
```

## Revert

`sudo ./uninstall.sh && reboot`. Nothing is written to flash or NVM; every change is lost at power-off.
