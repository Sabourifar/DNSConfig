# 🌐 DNSConfig

A practical PowerShell utility for DNS switching (IPv4 & IPv6), resolver benchmarking, adapter management, and streamlined Windows network troubleshooting.

⚡ Switch between 20 well-known DNS providers, configure custom dual-stack DNS servers, benchmark latency, manage network adapters, flush the DNS cache, or reset your network stack entirely — all from one interactive, color-coded dashboard.

## ✨ Features

- 🔍 **Comprehensive Status Dashboard:** Detects your active network interface, MAC address, and provides split IPv4/IPv6 panels showing Local IP, Gateway, Public IP, and active DNS servers with color-coded connectivity indicators.
- 🚀 **Expanded DNS Providers:** Choose from 20 built-in providers (including Global, Privacy, Regional ISPs, and Anti-Sanction services) with protocol targeting (apply to IPv4, IPv6, or Both).
- ✏️ **Custom Dual-Stack DNS:** Manual DNS configuration with strict `.NET` validation for both IPv4 and IPv6 addresses.
- ⏱️ **Dual-Stack Latency Benchmark:** Tests latency against every provider's IPv4 and IPv6 endpoints, with clear OK/Timeout statuses.
- 🔄 **Granular DHCP Revert:** Switch back to automatic DNS (DHCP) independently for IPv4 or IPv6.
- 🔌 **Network Adapter Management:** Toggle IPv4/IPv6 protocol bindings on the fly, or safely disable the active network adapter.
- 🩹 **Adapter Recovery:** Automatically detects disabled physical adapters and allows you to enable them directly from the "No Interface" recovery screen.
- 🧹 **Instant Cache Flush:** Clears the Windows DNS resolver cache via native API.
- 🛠️ **Robust Network Reset:** Full stack reset (Winsock, TCP/IP, Firewall, DNS, IP release/renew) with a step-by-step progress checklist, `netsh` fallbacks, and clear success/failure reporting.

## 📋 Requirements

- 🪟 Windows 10/11 (or Windows Server 2016+)
- 💻 PowerShell 5.1 (built into Windows) or PowerShell 7+
- 🔑 Administrator rights (the script elevates itself automatically — you'll get a UAC prompt)

## 🚀 Getting started

Windows tags every file downloaded from the internet with a "Mark of the Web," and by default PowerShell blocks unsigned scripts carrying that tag. The one-time command below removes that friction permanently for your user account, so you never have to think about it again.

### 1️⃣ One-time setup (do this once, ever)

Open any PowerShell window and run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
```

No admin rights needed — this only affects your own user account, not the whole machine. **Trade-off, stated plainly:** this tells Windows to stop checking execution policy and Mark-of-the-Web on *any* `.ps1` script you run from now on, not just this one. If you'd rather keep more protection, use `RemoteSigned` instead of `Bypass` — but then you'll need to run `Unblock-File .\DNSConfig.ps1` once per downloaded copy of the script, since `RemoteSigned` still blocks unsigned scripts carrying the Mark of the Web.

### 2️⃣ Running it

1. 📥 Download the latest version of `DNSConfig.ps1` from the [Releases](../../releases) page into any folder.
2. ▶️ Right-click it → **Run with PowerShell**. Do this any time you want to open the tool.
3. ✅ Approve the UAC prompt — the tool needs administrator rights to change network settings.

That one-time setup step is what makes step 2 always work cleanly, with no errors or prompts, every time you run it. 🎉

## 🎮 Usage

Once running, navigate the interactive menus using the number keys:

**Main Dashboard:**
- `1` — **Configure DNS** (Opens a submenu with 20 providers, Custom DNS, and Latency Test)
- `2` — Flush DNS cache
- `3` / `4` — Revert IPv4 / IPv6 DNS to DHCP
- `5` — Full network reset (use if your network is badly misconfigured)
- `6` — Disable the active network adapter
- `7` / `8` — Toggle IPv4 / IPv6 protocol bindings on the active adapter
- `0` — Quit

**Configure DNS Submenu (Option 1):**
- `1`–`20` — Select a built-in provider (prompts to apply to IPv4, IPv6, or Both)
- `21` — Set Custom DNS manually
- `22` — Test Provider Latency

## 📝 Notes

- 📡 **Latency Testing:** The benchmark uses ICMP ping. Some networks/servers block ICMP, which will show as a Timeout even if the DNS service itself is reachable. Additionally, IPv6 pings may fail if your local router or ISP does not route IPv6 ICMP traffic.
- ⚠️ **Toggling Protocols:** Disabling IPv4 (Option 7) will break most standard internet connectivity. Disabling IPv6 (Option 8) may affect specific modern services or local network discovery. Use these toggles primarily for troubleshooting or strict network requirements.
- 🛠️ **Network Reset Failures:** If the network reset reports a failure on the TCP/IP stack step, it's most often caused by third-party antivirus, firewall, or VPN software holding a lock on part of the network stack — temporarily disabling it before resetting usually resolves this.
- 🔁 **Reboot Recommended:** A restart is highly recommended after any full network reset or protocol toggle to fully apply the changes to the Windows network stack.
- 🌐 **Async Lookups:** Public IPv4 and IPv6 addresses are fetched concurrently in the background using `curl.exe` to ensure the dashboard UI loads instantly.

## 📄 License

MIT — see [LICENSE](LICENSE).
