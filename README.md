# vc520-ports

Enables the LAN switch ports on a **VeloCloud Edge 520** re-imaged with **Turnium SD-WAN** (Debian 12).

After a fresh Turnium install only `eth0`/`eth1` appear. This package brings up the rest at every boot.

## Port map / interface names

| Front port | Hardware path | Linux name |
|---|---|---|
| GE1 / SFP1 | Intel I350 `04:00.0` | **`eth0`** (SFP works; RJ45 copper not yet) |
| GE2 / SFP2 | Intel I350 `04:00.1` | **`eth1`** (SFP works; RJ45 copper not yet) |
| LAN1–LAN4 | 88E6176 **switch B** ports 0–3 → port 4 SerDes → I354 `00:14.1` | **`eth2`** |
| LAN5–LAN8 | 88E6176 **switch A** ports 0–3 → port 4 SerDes → I354 `00:14.0` | **`eth3`** |
| — | I354 `00:14.2`, no front port found | `eth4` (unused) |
| — | I354 `00:14.3`, left unbound to manage switch A | — |

Names are set **by PCI address** after binding (`NAMES` in `/etc/default/vc520-ports`). The rename is done in two steps, so it works whatever order the kernel found the ports in.

Each switch behaves as an **unmanaged switch**. 802.1Q tags pass through unchanged, so in Turnium use `eth2` / `eth3` or VLAN subinterfaces `eth2.<vid>` / `eth3.<vid>`.
Configure them as LAN / Connected-IP interfaces, **not as legs**.

## Why it's needed

1. **The I354 ports fail to start.** You'll see `igb: probe of 0000:00:14.x failed with error -2` and `MDI Error` in `dmesg`. The NVM (the port's onboard settings chip) says "SGMII with an external PHY", but the ports connect straight to the switch SerDes. The fix: set link mode 1000BASE-KX, which needs no PHY, before binding the port to `igb`.
2. **Both 88E6176 switches come out of reset with everything off.** All ports are disabled and all PHYs plus the SerDes are powered down. VeloCloud's firmware normally enables them. The fix: power them up over MDIO and set every port to Forwarding.
3. **The MDIO bus routing per I354 port (`MDICNFG`) must be correct.** Switch A is on the shared bus (`0xc0000000`). Switch B is on I354 port 1's own bus (`0x80000000`). Warm reboots keep stale values, so the script pins them on every boot.

## Install / upgrade

```bash
git clone https://github.com/chobyong/vc520-ports.git && cd vc520-ports   # or: git pull
sudo ./install.sh --now
```

An existing `/etc/default/vc520-ports` is kept. The new template is installed as `/etc/default/vc520-ports.example`.

## Use

```bash
vc520-ports status            # port table for switch A (switch B shown only if reachable)
vc520-ports status --force    # include switch B; briefly unbinds eth2 (LAN1-4 drop ~2 s)
vc520-ports status --detail   # plus PHY / SerDes registers
vc520-ports watch A           # live link monitor for LAN5-8 (eth3) while you plug cables
vc520-ports up                # what the boot service runs (safe to re-run)
journalctl -u vc520-ports -b
```

`watch B` only works while `eth2` is unbound, because Linux blocks register access to ports owned by `igb`.

## Known gaps

- [ ] **GE1/GE2 RJ45 copper**: no link yet. Candidates: I354 `00:14.2`/`.3` own MDIO buses, or the switches' RGMII ports 5/6.
- [ ] Exact jack → port labels (only LAN6 = switch A port 0 confirmed). Edit `LABELS_A` / `LABELS_B`.
- [ ] Optional per-port access VLANs (88E6176 VTU).
- [ ] Pin interface names with systemd `.link` files.

## Changelog

- **0.3.0**: Fixed names: `eth0`=GE1/SFP1, `eth1`=GE2/SFP2, `eth2`=LAN1–4, `eth3`=LAN5–8 (two-step rename by PCI address). The boot path recovers if `igb` grabbed I354 ports after a warm reboot.

- **0.2.0**: Adds switch B (LAN1–LAN4). Pins `MDICNFG` per port at boot. Adds a port/link table with front labels, `status --force` and `watch A|B`.
- **0.1.0**: Switch A (LAN5–LAN8) and I354 bring-up.

## Revert

`sudo ./uninstall.sh && reboot`. Nothing is written to flash or NVM.
